import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/adventure_routes.dart';
import '../models/adventure_models.dart';
import '../models/workout_models.dart';
import '../utils/iso_week.dart';
import 'gem_service.dart';
import 'stat_engine.dart';

/// "Adventure" — workout-fueled expeditions that pay gems scaled by stat
/// rank. The only fuel is a real completed workout: each qualifying save
/// grants ONE expedition charge (max one/day, banked up to the cap). The user
/// then spends a charge to send the character out on a chosen route for a
/// VIT-scaled 4–8h haul; the report greets them once it returns.
///
/// Invariants (Codex-hardened):
/// - Everything is rolled AT DISPATCH, seeded by the expedition id —
///   reopening can never reroll a payout, and rank/VIT drift between dispatch
///   and reveal is irrelevant (reconstructed-value rule).
/// - Settlement (award gems, move to history) is separated from reveal
///   (the ceremony). Both grant and dispatch auto-settle a revealable pending
///   first, so a returned expedition can never block the next earn.
/// - Every state mutation runs through a single-flight serial queue; the
///   gem award is additionally idempotent by ledger id.
/// - Reveal is wall-clock (`returnsAt`) guarded by a monotonic max-seen time
///   so a clock rollback can't un-return an expedition; charge grants are
///   max-anchored per day. Clock-FORWARD is an accepted offline trust boundary
///   (consistent with quests/LCK): it only skips the wait, never the cost —
///   every dispatch still spends a charge earned by a real logged workout,
///   capped at one/day and [weeklyCap]/ISO-week.
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

  /// The expedition id whose home-room "I'm back" greeting was already shown
  /// (so it fires once when the hologram first appears, not on every reopen).
  /// Keyed on the stable expedition id; a missing/legacy value ⇒ not greeted
  /// (greets once — harmless). Own key, so its idempotent set never races the
  /// state queue.
  static const greetedKey = 'bit_room_greeted_v1';

  /// Gems per expedition by rank letter (before the ±variance roll).
  static const payTiers = {'D': 8, 'C': 12, 'B': 18, 'A': 26, 'S': 40};

  /// Uniform payout roll in [base×(1−v), base×(1+v)] — bounded spice,
  /// expected value = base. Deliberately not a jackpot shape.
  static const payoutVariance = 0.3;

  /// Manual dispatches allowed per ISO week (the gem-budget bound; v1 parity).
  static const weeklyCap = 5;
  static const findChance = 0.35;
  static const historyCap = 30;

  /// VIT-scaled expedition duration bounds (minutes) and payout multiplier.
  static const minDurationMinutes = 240; // 4h
  static const maxDurationMinutes = 480; // 8h
  static const maxVitMultiplier = 1.4;

  /// Maps a VIT (recovery) value across its real [10,100] domain to [0,1].
  /// VIT floors at 10 (see docs/stats-mechanics.md), so a fresh/low-recovery
  /// user lands exactly at the 4h / 1.0× floor, a fully-recovered one at 8h /
  /// 1.4×. Shared by the page preview and dispatch so they can never drift.
  static double _vitFraction(int vit) => (vit.clamp(10, 100) - 10) / 90.0;

  /// Expedition length for a VIT value — 4h…8h.
  static int durationForVit(int vit) =>
      (minDurationMinutes +
              _vitFraction(vit) * (maxDurationMinutes - minDurationMinutes))
          .round();

  /// Which expedition's home-room greeting has been shown (null ⇒ none).
  Future<String?> loadGreetedExpeditionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(greetedKey);
  }

  /// Mark [id]'s greeting consumed — so "I'm back" shows once, then the away
  /// status takes over on the next return.
  Future<void> setGreetedExpeditionId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(greetedKey, id);
  }

  /// Payout multiplier for a VIT value — 1.0…1.4.
  static double multiplierForVit(int vit) =>
      1.0 + _vitFraction(vit) * (maxVitMultiplier - 1.0);

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

  /// Settles a revealable pending expedition (award gems + move to history,
  /// unviewed) if any, then returns the oldest still-unviewed report — WITHOUT
  /// marking it viewed — or null. Settlement is durable and idempotent; the
  /// report is only *acknowledged* (marked viewed) once the UI has actually
  /// shown it, via [acknowledgeReport]. This split means a Home that takes the
  /// report but then bails (route no longer current, unmounted) can never burn
  /// the ceremony — the gems are already safe, and the unviewed report simply
  /// reveals on the next valid open.
  Future<ExpeditionReport?> settleAndPeekReport() => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    var state = _decode(prefs.getString(stateKey));
    state = await _settleIfRevealable(state);
    await _save(prefs, state);

    // Oldest unviewed first — drains a backlog one ceremony per open.
    for (final expedition in state.history.reversed) {
      if (!expedition.viewed) {
        return ExpeditionReport(
          expedition: expedition,
          classDefaultOrders: !state.ordersConfirmed,
        );
      }
    }
    return null;
  });

  /// Marks a settled expedition's report viewed — call only after the reveal
  /// ceremony has actually been presented. Single-flight + idempotent.
  Future<void> acknowledgeReport(String expeditionId) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    final state = _decode(prefs.getString(stateKey));
    var changed = false;
    final history = [
      for (final e in state.history)
        if (e.id == expeditionId && !e.viewed)
          (() {
            changed = true;
            return e.copyWith(viewed: true);
          })()
        else
          e,
    ];
    if (!changed) return;
    await _save(prefs, state.copyWith(history: history));
  });

  /// Highest of wall-clock now and the persisted max-seen time — the rollback
  /// guard, so a returned expedition can't be hidden again by a clock rollback.
  /// (Clock-FORWARD remains the accepted offline trust boundary.)
  DateTime _effectiveNow(AdventureState state) {
    final now = _nowProvider();
    final stored = state.maxSeenAtIso == null
        ? null
        : DateTime.tryParse(state.maxSeenAtIso!);
    return (stored != null && stored.isAfter(now)) ? stored : now;
  }

  /// A pending expedition is revealable once its return time has passed.
  /// A null [Expedition.returnsAtIso] (legacy v1 pending) ⇒ revealable now.
  bool _isRevealable(Expedition pending, DateTime effectiveNow) {
    final returnsAt = pending.returnsAtIso == null
        ? null
        : DateTime.tryParse(pending.returnsAtIso!);
    if (returnsAt == null) return true;
    return !effectiveNow.isBefore(returnsAt);
  }

  /// Stamps the monotonic max-seen clock, then (if the pending has returned)
  /// awards gems + moves it to history (unviewed). Idempotent: the ledger
  /// dedupes by expedition id, and a re-entry with the same pending is harmless.
  Future<AdventureState> _settleIfRevealable(AdventureState state) async {
    final effNow = _effectiveNow(state);
    final next = state.copyWith(maxSeenAtIso: effNow.toIso8601String());
    final pending = next.pending;
    if (pending == null || !_isRevealable(pending, effNow)) return next;
    final route = adventureRouteById(pending.routeId);
    await _gemService.awardAdventureGems(
      expeditionId: pending.id,
      amount: pending.payout,
      label: 'Expedition · ${route.name}',
      now: effNow,
    );
    final settled = pending.copyWith(settledAtIso: effNow.toIso8601String());
    final history = [settled, ...next.history];
    if (history.length > historyCap) {
      history.removeRange(historyCap, history.length);
    }
    return next.copyWith(clearPending: true, history: history);
  }

  // ---------------------------------------------------------------------
  // Dispatch
  // ---------------------------------------------------------------------

  /// Called (awaited) from the completed-workout save path. Settles any
  /// revealable pending first, then grants ONE expedition charge (the instant
  /// workout payoff) — at most one per day, banked up to [AdventureState.chargeCap].
  /// The user spends charges manually via [dispatchExpedition]. Never throws
  /// into the save path.
  Future<void> grantChargeForSession(WorkoutSession session) =>
      _serial(() async {
        try {
          if (session.isPartial || session.isAbandoned) return;
          // Anti-empty-save bar: a charge costs at least one real logged set.
          final hasRealSet = session.exercises.any(
            (log) => log.sets.any((set) => set.reps > 0),
          );
          if (!hasRealSet) return;

          final prefs = await SharedPreferences.getInstance();
          var state = _decode(prefs.getString(stateKey));
          state = await _settleIfRevealable(state);

          // Max-anchored "today": a rolled-back clock can't re-earn a charge
          // for a day that already granted one.
          final wallToday = _dateOnly(_nowProvider());
          final anchor = _parseDay(state.lastChargeDay);
          final today = (anchor != null && anchor.isAfter(wallToday))
              ? anchor
              : wallToday;
          final todayKey = _dayKey(today);

          if (state.lastChargeDay == todayKey) {
            await _save(prefs, state); // already granted today
            return;
          }

          final charges = (state.charges + 1).clamp(0, AdventureState.chargeCap);
          await _save(
            prefs,
            state.copyWith(charges: charges, lastChargeDay: todayKey),
          );
        } catch (_) {
          // Adventure must never break a workout save.
        }
      });

  /// Manually spend a charge to send the character out on [routeId]. Settles
  /// any revealable pending first. Returns the dispatched [Expedition], or null
  /// if ineligible (no charge, one already out, or the weekly cap is reached).
  /// Everything (payout, duration, multiplier, find, flavor) is rolled ONCE
  /// here, seeded by the expedition id — a reopen can never reroll.
  Future<Expedition?> dispatchExpedition(String routeId) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    var state = _decode(prefs.getString(stateKey));
    state = await _settleIfRevealable(state);

    if (state.charges <= 0 || state.pending != null) {
      await _save(prefs, state);
      return null;
    }

    // Monotonic effective clock (max of now and the persisted max-seen time):
    // a rolled-back wall clock can't reset the weekly dispatch cap or backdate
    // the return — same max-anchor discipline as the charge grant (Codex diff
    // review). `_settleIfRevealable` already bumped maxSeenAtIso on `state`.
    final now = _effectiveNow(state);
    final today = _dateOnly(now);
    final weekIso = isoWeekKey(today);
    final weekCount = state.weekIso == weekIso ? state.weekCount : 0;
    if (weekCount >= weeklyCap) {
      await _save(prefs, state.copyWith(weekIso: weekIso, weekCount: weekCount));
      return null;
    }

    final route = adventureRouteById(routeId);
    final stats = await _statEngine.getStoredStats();
    final rank = _statEngine.getRank(stats[route.statKey] ?? 0);
    final vit = (stats['VIT'] ?? 0).clamp(0, 100).toInt();

    // Collision-resistant id (dispatch is decoupled from any session now):
    // microsecond clock + random. Deliberately 0x7fffffff, never 1<<32 (web
    // RangeError). The ledger keys on this id, so a same-day collision would
    // silently suppress a payout.
    final id =
        'exp_${now.microsecondsSinceEpoch}_${Random().nextInt(0x7fffffff)}';
    final rng = Random(id.hashCode);
    final base = basePayoutForRank(rank);
    final multiplier = multiplierForVit(vit);
    final variance = 1 - payoutVariance + rng.nextDouble() * 2 * payoutVariance;
    final payout = max(1, (base * multiplier * variance).round());
    final durationMinutes = durationForVit(vit);
    final returnsAt = now.add(Duration(minutes: durationMinutes));
    final findId = _rollFind(rng);
    final flavorIdx = rng.nextInt(route.flavorLines.length);

    final expedition = Expedition(
      id: id,
      routeId: route.id,
      day: _dayKey(today),
      bootId: _bootId, // forensic stamp only
      rank: rank,
      payout: payout,
      findId: findId,
      flavorIdx: flavorIdx,
      dispatchedAtIso: now.toIso8601String(),
      returnsAtIso: returnsAt.toIso8601String(),
      durationMinutes: durationMinutes,
      multiplier: multiplier,
      vitAtDispatch: vit,
    );

    await _save(
      prefs,
      state.copyWith(
        standingOrderRouteId: route.id,
        ordersConfirmed: true,
        pending: expedition,
        charges: state.charges - 1,
        lastDispatchDay: _dayKey(today),
        weekIso: weekIso,
        weekCount: weekCount + 1,
      ),
    );
    // One-shot UI signal: a live dispatch just happened (the service is the
    // single dispatch authority, so both entry points — the pad sheet and the
    // map — inherit it). The shell listens to land on Home for the send-off.
    dispatchTick.value++;
    return expedition;
  });

  /// Bumped once per successful [dispatchExpedition] — a cosmetic UI beacon
  /// (never persisted, never authoritative). The shell uses it to bring the
  /// home room on stage so the launch send-off is actually seen.
  static final ValueNotifier<int> dispatchTick = ValueNotifier<int>(0);

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
