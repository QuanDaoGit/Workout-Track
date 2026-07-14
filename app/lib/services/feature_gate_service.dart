import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'gem_service.dart';
import 'json_safe.dart';
import 'keyed_lock.dart';
import 'loot_service.dart';
import 'workout_storage_service.dart';

/// The meta surfaces that come online through the earned unlock ladder. The
/// tool core (Home, TRAIN, Logs, XP/stats, BIT, Labs) is never gated.
enum FeatureGate { quests, shop, guild, inventory, adventure }

/// One gate's persisted lifecycle. Unlocks are **latched**: once a condition is
/// met the gate stays unlocked forever — deleting history never re-locks.
/// Celebration (the unlock ceremony) and the analytics emission are tracked
/// separately so a blocked/unseen ceremony can never block or burn an unlock,
/// and a crash between commit and emit is retry-safe in both directions.
@immutable
class FeatureGateState {
  const FeatureGateState({this.unlockedAt, this.celebratedAt, this.emittedAt});

  final DateTime? unlockedAt;
  final DateTime? celebratedAt;
  final DateTime? emittedAt;

  bool get unlocked => unlockedAt != null;
  bool get pendingCeremony => unlocked && celebratedAt == null;

  /// Monotonic: a stamp already set is never overwritten — fields are add-only
  /// so no later evaluation/celebration can regress an earlier one.
  FeatureGateState copyWith({
    DateTime? unlockedAt,
    DateTime? celebratedAt,
    DateTime? emittedAt,
  }) {
    return FeatureGateState(
      unlockedAt: this.unlockedAt ?? unlockedAt,
      celebratedAt: this.celebratedAt ?? celebratedAt,
      emittedAt: this.emittedAt ?? emittedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    if (unlockedAt != null) 'unlockedAt': unlockedAt!.toIso8601String(),
    if (celebratedAt != null) 'celebratedAt': celebratedAt!.toIso8601String(),
    if (emittedAt != null) 'emittedAt': emittedAt!.toIso8601String(),
  };

  static FeatureGateState fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? v) => v is String ? DateTime.tryParse(v) : null;
    return FeatureGateState(
      unlockedAt: parse(json['unlockedAt']),
      celebratedAt: parse(json['celebratedAt']),
      emittedAt: parse(json['emittedAt']),
    );
  }
}

/// Static per-gate copy + presentation registry. Copy is invitation-framed —
/// what training opens, never what the user still "owes" (anti-guilt: no
/// deadlines, no debt counters; nothing here ever re-locks or expires).
class FeatureGateSpec {
  const FeatureGateSpec({
    required this.gate,
    required this.title,
    required this.lockedNotice,
    required this.ceremonyLine,
    required this.iconPath,
  });

  final FeatureGate gate;

  /// Ceremony headline noun ("NEW SYSTEM ONLINE — <title>").
  final String title;

  /// Floating-notice copy for a locked tap. Invitation, not debt.
  final String lockedNotice;

  /// BIT's line on the unlock ceremony.
  final String ceremonyLine;

  /// Pixel nav icon reused by the ceremony reveal.
  final String iconPath;
}

const Map<FeatureGate, FeatureGateSpec> featureGateSpecs = {
  FeatureGate.quests: FeatureGateSpec(
    gate: FeatureGate.quests,
    title: 'QUESTS',
    lockedNotice: 'Complete your first workout to power the quest board',
    ceremonyLine: 'The board is live. Your first reward is already waiting.',
    iconPath: 'assets/icons/control/ui/icon_nav_quests.png',
  ),
  FeatureGate.shop: FeatureGateSpec(
    gate: FeatureGate.shop,
    title: 'SHOP',
    lockedNotice: 'Earn your first gems to open the shop',
    ceremonyLine: 'You have gems now. Spend them well, warrior.',
    iconPath: 'assets/icons/economy/icon_gem.png',
  ),
  FeatureGate.guild: FeatureGateSpec(
    gate: FeatureGate.guild,
    title: 'GUILD',
    lockedNotice: 'Complete 3 workouts to found your guild',
    ceremonyLine: 'Three sessions strong. The hall is yours.',
    iconPath: 'assets/icons/control/ui/icon_nav_guild.png',
  ),
  FeatureGate.inventory: FeatureGateSpec(
    gate: FeatureGate.inventory,
    title: 'ITEMS',
    lockedNotice: 'Earn your first item to open the armory',
    ceremonyLine: 'Your first earned piece. The collection starts here.',
    iconPath: 'assets/icons/control/icon_bag.png',
  ),
  FeatureGate.adventure: FeatureGateSpec(
    gate: FeatureGate.adventure,
    title: 'EXPEDITIONS',
    lockedNotice: 'Complete 5 workouts to power the expedition pad',
    ceremonyLine: 'The pad hums. I can scout for us now.',
    iconPath: 'assets/icons/control/icon_boots.png',
  ),
};

/// Owns the earned feature-unlock ladder (key `feature_unlocks_v1`).
///
/// Contract (Codex-hardened):
/// - **One serialized transaction**: the whole read → evaluate → merge → write
///   runs inside [prefsWriteLock] on the storage key, so concurrent evaluators
///   (boot migration, shell load, changes events) can't lose an update.
/// - **Monotonic merge**: fields are only ever added, never removed — an
///   unlock/celebration/emission stamp survives any later evaluation.
/// - **Fail toward fuller**: an unreadable blob re-derives from history (an
///   existing user re-latches as unlocked); a never-loaded snapshot reads as
///   unlocked so no first-frame can flash a false lock.
/// - **Settlement ≠ presentation**: pending ceremonies are the persisted
///   `unlocked && !celebrated` predicate, never a held in-memory value.
class FeatureGateService {
  FeatureGateService({
    DateTime Function()? nowProvider,
    Future<bool> Function()? hasCompletedWorkoutsOverride,
    Future<int> Function()? completedWorkoutCountOverride,
    Future<bool> Function()? hasEarnedGemsOverride,
    Future<bool> Function()? hasEarnedLootOverride,
  }) : _now = nowProvider ?? DateTime.now,
       _completedCount =
           completedWorkoutCountOverride ?? _defaultCompletedCount,
       _hasEarnedGems = hasEarnedGemsOverride ?? _defaultHasEarnedGems,
       _hasEarnedLoot = hasEarnedLootOverride ?? _defaultHasEarnedLoot;

  static const String storageKey = 'feature_unlocks_v1';

  /// Gate thresholds — constants, not architecture (tunable if instrumented
  /// funnels later disagree).
  static const int guildWorkouts = 3;
  static const int adventureWorkouts = 5;
  static const int questsWorkouts = 1;

  final DateTime Function() _now;
  final Future<int> Function() _completedCount;
  final Future<bool> Function() _hasEarnedGems;
  final Future<bool> Function() _hasEarnedLoot;

  /// In-memory snapshot for synchronous UI reads. Loaded by [BootService]
  /// before the shell builds (the boot splash covers it); widget code reads
  /// [isUnlockedSync]. Null (never loaded) fails toward UNLOCKED — a missing
  /// load must never flash or enforce a false lock.
  static Map<FeatureGate, FeatureGateState>? _snapshot;

  /// Bumps whenever the snapshot changes so the shell can rebuild.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  @visibleForTesting
  static void resetForTest() {
    _snapshot = null;
    revision.value = 0;
  }

  static Future<int> _defaultCompletedCount() async {
    final sessions = await WorkoutStorageService().getSessions();
    return sessions.where((s) => !s.isPartial && !s.isAbandoned).length;
  }

  static Future<bool> _defaultHasEarnedGems() async {
    final entries = await GemService().ledger();
    return entries.any((entry) => entry.amount > 0);
  }

  static Future<bool> _defaultHasEarnedLoot() async {
    final items = await LootService().getInventory();
    return items.any((item) => !item.isDefault);
  }

  /// Synchronous gate read off the boot-loaded snapshot.
  static bool isUnlockedSync(FeatureGate gate) {
    final snap = _snapshot;
    if (snap == null) return true; // fail toward the fuller experience
    return snap[gate]?.unlocked ?? false;
  }

  /// Gates unlocked but not yet celebrated, oldest unlock first — the persisted
  /// pending-ceremony queue.
  static List<FeatureGate> pendingCeremoniesSync() {
    final snap = _snapshot;
    if (snap == null) return const [];
    final pending = snap.entries
        .where((e) => e.value.pendingCeremony)
        .toList();
    pending.sort((a, b) => a.value.unlockedAt!.compareTo(b.value.unlockedAt!));
    return [for (final e in pending) e.key];
  }

  /// Loads the persisted state into the sync snapshot without evaluating.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _publish(_decode(prefs.getString(storageKey)));
  }

  /// The transaction: read → evaluate conditions → monotonic merge → write →
  /// emit analytics for committed transitions. Returns the gates newly
  /// unlocked by THIS call (empty when nothing changed).
  ///
  /// [seedPreCelebrated] is the legacy-migration mode: every gate is latched
  /// unconditionally (grandfather invariant — an existing user must never lose
  /// a previously reachable surface) with celebration + emission stamped, so
  /// existing installs see zero locks, zero ceremonies, zero synthetic events.
  Future<List<FeatureGate>> evaluate({bool seedPreCelebrated = false}) {
    return prefsWriteLock.synchronized(storageKey, () async {
      final prefs = await SharedPreferences.getInstance();
      final state = _decode(prefs.getString(storageKey));
      final now = _now();

      final newlyUnlocked = <FeatureGate>[];
      if (seedPreCelebrated) {
        for (final gate in FeatureGate.values) {
          final existing = state[gate];
          if (existing?.unlocked ?? false) continue;
          state[gate] = FeatureGateState(
            unlockedAt: now,
            celebratedAt: now,
            emittedAt: now,
          );
        }
      } else {
        final locked = FeatureGate.values
            .where((g) => !(state[g]?.unlocked ?? false))
            .toList();
        if (locked.isNotEmpty) {
          final met = await _metConditions(locked);
          for (final gate in met) {
            state[gate] = (state[gate] ?? const FeatureGateState()).copyWith(
              unlockedAt: now,
            );
            newlyUnlocked.add(gate);
          }
        }
      }

      // Retry-safe analytics: stamp + emit for any unlocked-but-unemitted gate
      // (covers a crash between a prior commit and its emission, and never
      // re-fires — emittedAt is part of the same committed write).
      final toEmit = FeatureGate.values
          .where(
            (g) =>
                (state[g]?.unlocked ?? false) && state[g]?.emittedAt == null,
          )
          .toList();
      for (final gate in toEmit) {
        state[gate] = state[gate]!.copyWith(emittedAt: now);
      }

      await prefs.setString(storageKey, _encode(state));
      _publish(state);
      for (final gate in toEmit) {
        await AnalyticsService.instance.logFeatureUnlocked(gate.name);
      }
      return newlyUnlocked;
    });
  }

  /// Marks gates as celebrated (ceremony finished, skipped, or deferred via
  /// LATER — all settle the queue; the surface itself is already unlocked).
  Future<void> markCelebrated(List<FeatureGate> gates) {
    if (gates.isEmpty) return Future.value();
    return prefsWriteLock.synchronized(storageKey, () async {
      final prefs = await SharedPreferences.getInstance();
      final state = _decode(prefs.getString(storageKey));
      final now = _now();
      var changed = false;
      for (final gate in gates) {
        final existing = state[gate];
        if (existing == null || !existing.unlocked) continue;
        if (existing.celebratedAt != null) continue;
        state[gate] = existing.copyWith(celebratedAt: now);
        changed = true;
      }
      if (changed) {
        await prefs.setString(storageKey, _encode(state));
        _publish(state);
      }
    });
  }

  Future<List<FeatureGate>> _metConditions(List<FeatureGate> locked) async {
    final met = <FeatureGate>[];
    final needsCount = locked.any(
      (g) =>
          g == FeatureGate.quests ||
          g == FeatureGate.guild ||
          g == FeatureGate.adventure,
    );
    final count = needsCount ? await _completedCount() : 0;
    for (final gate in locked) {
      switch (gate) {
        case FeatureGate.quests:
          if (count >= questsWorkouts) met.add(gate);
        case FeatureGate.shop:
          if (await _hasEarnedGems()) met.add(gate);
        case FeatureGate.guild:
          if (count >= guildWorkouts) met.add(gate);
        case FeatureGate.inventory:
          if (await _hasEarnedLoot()) met.add(gate);
        case FeatureGate.adventure:
          if (count >= adventureWorkouts) met.add(gate);
      }
    }
    return met;
  }

  static void _publish(Map<FeatureGate, FeatureGateState> state) {
    _snapshot = state;
    revision.value++;
  }

  static Map<FeatureGate, FeatureGateState> _decode(String? raw) {
    // Corruption-tolerant: an unreadable blob yields an EMPTY map here, and the
    // next evaluate() re-derives every gate from history — an existing user
    // re-latches as unlocked (fail toward fuller); only the celebration stamp
    // is lost, so a ceremony may replay once (coalesced, never spammed).
    final decoded = safeDecodeMap(raw, debugLabel: storageKey) ?? const {};
    final state = <FeatureGate, FeatureGateState>{};
    for (final gate in FeatureGate.values) {
      final entry = decoded[gate.name];
      if (entry is Map) {
        state[gate] = FeatureGateState.fromJson(
          Map<String, dynamic>.from(entry),
        );
      }
    }
    return state;
  }

  static String _encode(Map<FeatureGate, FeatureGateState> state) {
    return jsonEncode({
      for (final e in state.entries)
        if (e.value.unlocked) e.key.name: e.value.toJson(),
    });
  }
}
