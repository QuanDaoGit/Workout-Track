import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/adventure_routes.dart';
import '../models/adventure_models.dart';
import '../models/workout_models.dart';
import 'class_service.dart';
import 'gem_service.dart';
import 'guild_service.dart';
import 'stat_engine.dart';

/// "Adventure" — workout-fueled expeditions that pay gems scaled by stat
/// rank. The only fuel is a real completed workout: the first qualifying
/// save of the day dispatches the character to the standing-order route;
/// the report greets the user on their next app sitting.
///
/// Invariants (Codex-hardened):
/// - Everything is rolled AT DISPATCH, seeded by the expedition id —
///   reopening can never reroll a payout, and rank drift between dispatch
///   and reveal is irrelevant (reconstructed-value rule).
/// - Settlement (award gems, move to history) is separated from reveal
///   (the ceremony). Dispatch auto-settles a revealable pending first, so a
///   pending expedition can never cost the user a dispatch day.
/// - Every state mutation runs through a single-flight serial queue; the
///   gem award is additionally idempotent by ledger id.
/// - Day/week bookkeeping is max-anchored (clock rollback can't re-dispatch).
///   Clock-FORWARD manipulation is an accepted offline trust boundary
///   (consistent with quests/LCK) — it still costs a real logged workout
///   with at least one non-empty set per dispatch.
class AdventureService {
  AdventureService({
    DateTime Function()? nowProvider,
    StatEngine? statEngine,
    GemService? gemService,
    String? bootIdOverride,
  }) : _nowProvider = nowProvider ?? DateTime.now,
       _statEngine = statEngine ?? StatEngine(),
       _gemService = gemService ?? GemService(),
       _bootId = bootIdOverride ?? bootId;

  static const stateKey = 'adventure_state_v1';

  /// Gems per expedition by rank letter (before the ±variance roll).
  static const payTiers = {'D': 8, 'C': 12, 'B': 18, 'A': 26, 'S': 40};

  /// Uniform payout roll in [base×(1−v), base×(1+v)] — bounded spice,
  /// expected value = base. Deliberately not a jackpot shape.
  static const payoutVariance = 0.3;

  static const weeklyCap = 5;
  static const findChance = 0.35;
  static const historyCap = 30;

  /// Cumulative rarity weights for the find roll (common→legendary).
  static const _rarityWeights = [50, 25, 15, 8, 2];

  /// Per-process boot id: a report dispatched in this sitting only becomes
  /// revealable after a process restart or a day boundary.
  static final String bootId =
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';

  /// Single-flight queue: all state mutations chain here so two concurrent
  /// callers (Home load + storage listener, settle + dispatch) can never
  /// interleave read-modify-write on `adventure_state_v1`.
  static Future<void> _flight = Future.value();

  final DateTime Function() _nowProvider;
  final StatEngine _statEngine;
  final GemService _gemService;
  final String _bootId;

  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _flight.then((_) => op());
    _flight = result.then((_) {}, onError: (_) {});
    return result;
  }

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  Future<AdventureState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(stateKey));
  }

  /// Pay tier (base gems) for a rank letter.
  static int basePayoutForRank(String rank) => payTiers[rank] ?? payTiers['D']!;

  // ---------------------------------------------------------------------
  // Settlement + reveal
  // ---------------------------------------------------------------------

  /// Settles a revealable pending expedition (award + history) if any, then
  /// returns the oldest unviewed report — marked viewed — or null. The ONLY
  /// entry point the reveal UI uses; single-flight, so two Home loads can
  /// never double-award or double-take.
  Future<ExpeditionReport?> settleAndTakeReport() => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    var state = _decode(prefs.getString(stateKey));
    state = await _settleIfRevealable(state);

    Expedition? unviewed;
    for (var i = state.history.length - 1; i >= 0; i--) {
      if (!state.history[i].viewed) unviewed = state.history[i];
    }
    if (unviewed == null) {
      await _save(prefs, state);
      return null;
    }
    final updatedHistory = [
      for (final e in state.history)
        if (e.id == unviewed.id) e.copyWith(viewed: true) else e,
    ];
    state = state.copyWith(history: updatedHistory);
    await _save(prefs, state);
    return ExpeditionReport(
      expedition: unviewed,
      classDefaultOrders: !state.ordersConfirmed,
    );
  });

  /// A pending expedition becomes revealable after a process restart or a
  /// day boundary — never in the sitting that dispatched it.
  bool _isRevealable(Expedition pending) {
    if (pending.bootId != _bootId) return true;
    return _dayKey(_dateOnly(_nowProvider())) != pending.day;
  }

  /// Award + move to history (unviewed). Idempotent: the ledger dedupes by
  /// expedition id, and a re-entry with the same pending is harmless.
  Future<AdventureState> _settleIfRevealable(AdventureState state) async {
    final pending = state.pending;
    if (pending == null || !_isRevealable(pending)) return state;
    final route = adventureRouteById(pending.routeId);
    await _gemService.awardAdventureGems(
      expeditionId: pending.id,
      amount: pending.payout,
      label: 'Expedition · ${route.name}',
      now: _nowProvider(),
    );
    final settled = pending.copyWith(
      settledAtIso: _nowProvider().toIso8601String(),
    );
    final history = [settled, ...state.history];
    if (history.length > historyCap) {
      history.removeRange(historyCap, history.length);
    }
    return state.copyWith(clearPending: true, history: history);
  }

  // ---------------------------------------------------------------------
  // Dispatch
  // ---------------------------------------------------------------------

  /// Called (awaited) from the completed-workout save path. Settles any
  /// revealable pending first, then dispatches if eligible. Never throws
  /// into the save path.
  Future<void> dispatchForSession(WorkoutSession session) => _serial(() async {
    try {
      if (session.isPartial || session.isAbandoned) return;
      // Anti-empty-save bar: dispatch costs at least one real logged set.
      final hasRealSet = session.exercises.any(
        (log) => log.sets.any((set) => set.reps > 0),
      );
      if (!hasRealSet) return;

      final prefs = await SharedPreferences.getInstance();
      var state = _decode(prefs.getString(stateKey));
      state = await _settleIfRevealable(state);

      if (state.pending != null) {
        // Still out (dispatched earlier this sitting/day) — one at a time.
        await _save(prefs, state);
        return;
      }

      // Max-anchored "today": a rolled-back clock can't earn a second
      // dispatch for a day that already had one.
      final wallToday = _dateOnly(_nowProvider());
      final anchor = _parseDay(state.lastDispatchDay);
      final today = (anchor != null && anchor.isAfter(wallToday))
          ? anchor
          : wallToday;
      final todayKey = _dayKey(today);

      if (state.lastDispatchDay == todayKey) {
        await _save(prefs, state);
        return; // one expedition per day
      }

      var weekIso = GuildService.weekIso(today);
      var weekCount = state.weekIso == weekIso ? state.weekCount : 0;
      if (weekCount >= weeklyCap) {
        await _save(
          prefs,
          state.copyWith(weekIso: weekIso, weekCount: weekCount),
        );
        return;
      }

      // Resolve orders (class default until the user confirms their own).
      var routeId = state.standingOrderRouteId;
      if (routeId == null) {
        final cls = await ClassService().getCurrentClass();
        routeId = defaultRouteForClass(cls).id;
      }
      final route = adventureRouteById(routeId);

      // Rank at dispatch — captured, never re-derived.
      final stats = await _statEngine.getStoredStats();
      final rank = _statEngine.getRank(stats[route.statKey] ?? 0);

      // Roll everything now, seeded by the expedition id (deterministic:
      // a reopen can never reroll).
      final id = 'exp_${today.millisecondsSinceEpoch}_${session.id}';
      final rng = Random(id.hashCode);
      final base = basePayoutForRank(rank);
      final roll = 1 - payoutVariance + rng.nextDouble() * 2 * payoutVariance;
      final payout = max(1, (base * roll).round());
      final findId = _rollFind(rng);
      final flavorIdx = rng.nextInt(route.flavorLines.length);

      state = state.copyWith(
        standingOrderRouteId: routeId,
        pending: Expedition(
          id: id,
          routeId: route.id,
          day: todayKey,
          bootId: _bootId,
          rank: rank,
          payout: payout,
          findId: findId,
          flavorIdx: flavorIdx,
        ),
        lastDispatchDay: todayKey,
        weekIso: weekIso,
        weekCount: weekCount + 1,
      );
      await _save(prefs, state);
    } catch (_) {
      // Adventure must never break a workout save.
    }
  });

  String? _rollFind(Random rng) {
    if (rng.nextDouble() >= findChance) return null;
    final total = _rarityWeights.fold<int>(0, (a, b) => a + b);
    var pick = rng.nextInt(total);
    var rarityIdx = 0;
    for (var i = 0; i < _rarityWeights.length; i++) {
      if (pick < _rarityWeights[i]) {
        rarityIdx = i;
        break;
      }
      pick -= _rarityWeights[i];
    }
    final candidates = [
      for (final find in adventureFinds)
        if (find.rarity.index == rarityIdx) find,
    ];
    final pool = candidates.isEmpty ? adventureFinds : candidates;
    return pool[rng.nextInt(pool.length)].id;
  }

  // ---------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------

  Future<void> setStandingOrder(String routeId) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    final state = _decode(prefs.getString(stateKey));
    await _save(
      prefs,
      state.copyWith(
        standingOrderRouteId: adventureRouteById(routeId).id,
        ordersConfirmed: true,
      ),
    );
  });

  // ---------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------

  AdventureState _decode(String? raw) {
    if (raw == null) return AdventureState();
    try {
      return AdventureState.fromJson(jsonDecode(raw) as Map<String, dynamic>?);
    } catch (_) {
      // Malformed state = fresh state; real stats/XP/gems are untouched.
      return AdventureState();
    }
  }

  Future<void> _save(SharedPreferences prefs, AdventureState state) =>
      prefs.setString(stateKey, jsonEncode(state.toJson()));

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime? _parseDay(String? key) =>
      key == null ? null : DateTime.tryParse(key);

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
