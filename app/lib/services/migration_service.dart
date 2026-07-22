import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/loot_registry.dart';
import '../data/programs_library.dart';
import '../models/avatar_spec.dart';
import '../models/loot_item.dart';
import '../models/program_models.dart';
import 'body_metrics_service.dart';
import 'calibration_service.dart';
import 'character_service.dart';
import 'feature_gate_service.dart';
import 'loot_service.dart';
import 'onboarding_service.dart';
import 'profile_service.dart';
import 'program_service.dart';
import 'stat_engine.dart';

/// One-shot cleanup of dead `shared_preferences` keys left over from the
/// battle / dungeon / scrap / ability / ultimate systems.
///
/// Guarded by [_doneKey] so it only runs once per install.
class MigrationService {
  const MigrationService._();

  static const _doneKey = 'migration_v1_battle_strip_done';
  static const _endStatDoneKey = 'migration_v2_end_stat_done';
  static const _clearSelfReportedSeedDoneKey =
      'migration_v_clear_self_reported_stat_seed_done';
  static const _titleUnificationDoneKey = 'migration_v_title_unification_done';
  static const _weightLogRewardAnchorDoneKey =
      'migration_v_weightlog_reward_anchor_done';
  static const _themeLootCleanupDoneKey =
      'migration_v_theme_loot_cleanup_done';
  static const _shadowRemovalDoneKey = 'migration_v_shadow_removal_done';
  static const _weekdayAnchoredScheduleDoneKey =
      'migration_v_weekday_anchored_schedule_done';
  static const _decayRemovalDoneKey = 'migration_v_decay_removal_done';

  static const _deadKeys = <String>[
    // Battle / dungeon / scrap
    'loot_scrap_balance',
    'unclaimed_loot',
    'idle_battle_state',
    'idle_battle_history',
    'idle_battle_last_active',
    'idle_battle_last_floor',
    'idle_battle_last_timestamp',
    'battle_scheduler_pending',
    'battle_scheduler_history',
    'battle_scheduler_floor',
    'last_battle_result',
    'dungeon_floor',
    'scrap',
    'dungeonFloor',
    'lastBattleResult',
    'idle_current_floor',
    'idle_highest_floor',
    'idle_last_session_timestamp',
    'idle_migrated',
    // Class abilities / ultimate
    'class_carryover_v1',
    'class_ultimate_pending_reveal',
    'unlocked_abilities',
    'ultimate_progress',
    // Guild (social feature removed — rebuilt from scratch)
    'guild_v1',
    'guild_members_v1',
    'guild_forge_nods_v1',
  ];

  /// Runs once. Idempotent. Safe to call from `main.dart` before runApp.
  static Future<void> runOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_doneKey) == true) return;

    for (final key in _deadKeys) {
      await prefs.remove(key);
    }

    await prefs.setBool(_doneKey, true);
  }

  /// One-shot: strips the removed theme cosmetics from persisted loot — the
  /// `theme` equipped-slot key and any `theme_*` owned-inventory ids. The load
  /// paths already skip unknown keys/ids, so this only keeps stored data tidy.
  static Future<void> runThemeLootCleanupOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_themeLootCleanupDoneKey) == true) return;

    final equippedRaw = prefs.getString('equipped_loot');
    if (equippedRaw != null && equippedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(equippedRaw) as Map<String, dynamic>;
        if (decoded.remove('theme') != null) {
          await prefs.setString('equipped_loot', jsonEncode(decoded));
        }
      } catch (_) {
        // Malformed JSON — leave it; the loader already tolerates it.
      }
    }

    final owned = prefs.getStringList('loot_inventory');
    if (owned != null) {
      final cleaned = owned.where((id) => !id.startsWith('theme_')).toList();
      if (cleaned.length != owned.length) {
        await prefs.setStringList('loot_inventory', cleaned);
      }
    }

    await prefs.setBool(_themeLootCleanupDoneKey, true);
  }

  /// One-shot: removes the retired "Shadow" boss feature's persisted residue —
  /// its `shadow_state_v1` key, and the two grant-only loot ids it awarded
  /// (`title_shadowbane`, `frame_spectral`) from the equipped slots + owned
  /// inventory. The loot load paths already skip unknown ids (so this is tidy-
  /// up that keeps `getOwnedCount` honest), and clearing an equipped Shadow
  /// frame/title reverts the avatar/title to its default cleanly. Mirrors
  /// [runThemeLootCleanupOnce]; idempotent (gated + exact-id match).
  static Future<void> runShadowRemovalCleanupOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shadowRemovalDoneKey) == true) return;

    const shadowLootIds = {'title_shadowbane', 'frame_spectral'};

    await prefs.remove('shadow_state_v1');

    final equippedRaw = prefs.getString('equipped_loot');
    if (equippedRaw != null && equippedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(equippedRaw) as Map<String, dynamic>;
        final before = decoded.length;
        decoded.removeWhere((_, value) => shadowLootIds.contains(value));
        if (decoded.length != before) {
          await prefs.setString('equipped_loot', jsonEncode(decoded));
        }
      } catch (_) {
        // Malformed JSON — leave it; the loader already tolerates it.
      }
    }

    final owned = prefs.getStringList('loot_inventory');
    if (owned != null) {
      final cleaned = owned.where((id) => !shadowLootIds.contains(id)).toList();
      if (cleaned.length != owned.length) {
        await prefs.setStringList('loot_inventory', cleaned);
      }
    }

    await prefs.setBool(_shadowRemovalDoneKey, true);
  }

  static Future<void> runEndStatBackfillOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_endStatDoneKey) == true) return;

    // One-time recompute so END is backfilled into the cached stats from a
    // user's existing history after the END-from-history stat redesign.
    await StatEngine().calculateAllStats();
    await prefs.setBool(_endStatDoneKey, true);
  }

  static Future<void> runClearSelfReportedStatSeedOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_clearSelfReportedSeedDoneKey) == true) return;
    // A workout-derived seed (the modern calibration path, or the v4 remaster
    // top-up) is legitimate earned/measured volume — never clear it. This
    // one-shot only targets the retired SELF-REPORTED quiz seed.
    if (prefs.getString(CalibrationService.calibrationSeedSourceKey) ==
        CalibrationService.workoutSeedSource) {
      await prefs.setBool(_clearSelfReportedSeedDoneKey, true);
      return;
    }

    await prefs.remove(StatEngine.calibrationSeedKey);
    await prefs.remove(CalibrationService.calibrationSessionCountKey);
    await prefs.remove(CalibrationService.calibrationCompleteKey);
    await prefs.remove(CalibrationService.calibrationSeedSourceKey);

    await StatEngine().calculateAllStats();
    await prefs.setBool(_clearSelfReportedSeedDoneKey, true);
  }

  static const _statsRulesVersionKey = 'stats_rules_version_v1';

  // Legacy (pre-v4) rank thresholds, frozen here for the one-time remaster
  // conversion. The live thresholds moved ×10 in StatEngine.
  static const _legacyRankC = 100;
  static const _legacyRankB = 300;
  static const _legacyRankA = 600;
  static const _legacyRankS = 900;

  /// Recomputes cached combat stats whenever [StatEngine.statsRulesVersion]
  /// changes, so a re-tune of the stat formula surfaces at app-update boot — not
  /// as a surprise jump mid-workout. Version-gated (re-runs on every future
  /// bump), unlike the one-shot cleanups above.
  ///
  /// v4 remaster conversion: a legacy board's per-stat RANK is preserved via a
  /// **volume top-up** written into the seed channel — never an output floor.
  /// (A floor freezes the displayed number until real volume catches up —
  /// exactly the invisible-progress wall v4 removes; a top-up keeps the very
  /// next session moving the stat.) The old v3 floor blob is old-unit and is
  /// consumed into the same conversion, then removed. The recompute runs with
  /// the delta suppressed so the scale jump never reads as a fake earned gain.
  ///
  /// MUST run before any other boot step that calls `calculateAllStats()` —
  /// an earlier recompute would cache v4-scale values that this conversion
  /// would then misread as a legacy board (double-scaling). BootService orders
  /// it accordingly.
  /// Crash-safety marker: the v4 rank targets, frozen from the LEGACY cached
  /// board before any recompute can overwrite it. A kill mid-migration leaves
  /// the version key unset, so the next boot retries — and a retry that
  /// re-derived targets from the by-then v4-scale cache would read e.g. a
  /// 3000 (new B) as a legacy S and inflate the board (double-scaling).
  /// Re-applying top-ups against the frozen targets instead converges: a
  /// landed top-up makes current >= target, so nothing further is added.
  static const _v4RankTargetsPendingKey = 'stats_v4_rank_targets_pending_v1';

  static Future<void> runStatsRecomputeIfRulesChanged() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_statsRulesVersionKey);
    if (storedVersion == StatEngine.statsRulesVersion) return;

    Map<String, int> rankTargets = const {};
    if (storedVersion == null || storedVersion < 4) {
      final pendingRaw = prefs.getString(_v4RankTargetsPendingKey);
      if (pendingRaw != null) {
        // A prior run was killed mid-conversion — reuse its frozen targets.
        rankTargets = _decodeIntMap(pendingRaw);
      } else {
        rankTargets = await _legacyRankTargets(prefs);
        // Persist the frozen targets UNCONDITIONALLY — including an empty map.
        // A kill after the recompute below but before the version key commits
        // must make the retry reuse THESE frozen targets (via the
        // `pendingRaw != null` branch), not re-derive them from the by-then
        // v4-scale cache — which would read a sub-rank-C board's converted
        // (baseline-100+) values as legacy C/A/S and fabricate ranks.
        await prefs.setString(
          _v4RankTargetsPendingKey,
          jsonEncode(rankTargets),
        );
      }
      // Old-unit floor values are meaningless on the ×10 scale; their rank
      // protection is folded into rankTargets above.
      await prefs.remove(StatEngine.grandfatherFloorKey);
      // A pre-v4 seed that is NOT workout-derived is the retired self-reported
      // quiz seed. Drop it rather than blessing it below (the top-up marks the
      // seed workout-sourced, which would exempt it from the self-reported
      // cleanup forever); the rank top-up restores any legitimately-shown rank.
      if (prefs.getString(CalibrationService.calibrationSeedSourceKey) !=
          CalibrationService.workoutSeedSource) {
        await prefs.remove(StatEngine.calibrationSeedKey);
      }
    }

    final engine = StatEngine();
    final stats = await engine.calculateAllStats(suppressDelta: true);

    if (rankTargets.isNotEmpty) {
      final seedRaw = prefs.getString(StatEngine.calibrationSeedKey);
      final seed = <String, double>{};
      if (seedRaw != null) {
        try {
          final decoded = jsonDecode(seedRaw) as Map<String, dynamic>;
          decoded.forEach((key, value) {
            if (value is num) seed[key] = value.toDouble();
          });
        } catch (_) {}
      }
      var changed = false;
      rankTargets.forEach((stat, target) {
        final current = stats[stat] ?? 0;
        if (current >= target) return;
        // Volume-domain top-up: enough credit (in the stat's own currency) to
        // lift the recomputed board back to its legacy rank threshold.
        final topUp = stat == 'END'
            ? StatEngine.enduranceForStat(target) -
                  StatEngine.enduranceForStat(current)
            : StatEngine.volumeForStat(target) -
                  StatEngine.volumeForStat(current);
        if (topUp <= 0) return;
        seed[stat] = (seed[stat] ?? 0) + topUp;
        changed = true;
      });
      if (changed) {
        await prefs.setString(
          StatEngine.calibrationSeedKey,
          jsonEncode(seed),
        );
        // The top-up is derived from real logged history — mark the seed
        // workout-sourced so the self-reported-seed cleanup can never eat it.
        await prefs.setString(
          CalibrationService.calibrationSeedSourceKey,
          CalibrationService.workoutSeedSource,
        );
        // Re-cache the board with the top-up applied (still suppressed).
        await engine.calculateAllStats(suppressDelta: true);
      }
    }

    await prefs.setInt(_statsRulesVersionKey, StatEngine.statsRulesVersion);
    await prefs.remove(_v4RankTargetsPendingKey);
  }

  static Map<String, int> _decodeIntMap(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value is num) entry.key: (entry.value as num).toInt(),
      };
    } catch (_) {
      return const {};
    }
  }

  /// Per growth stat, the v4 rank threshold matching the LEGACY rank of the
  /// user's cached board (max of cached value and any old v3 floor). Empty when
  /// no real completed sessions back the cache (a cached value with no history
  /// behind it was never earned — recomputing it away is the correction).
  static Future<Map<String, int>> _legacyRankTargets(
    SharedPreferences prefs,
  ) async {
    final cachedRaw = prefs.getString(StatEngine.combatStatsKey);
    if (cachedRaw == null || !await _hasCompletedSessions(prefs)) {
      return const {};
    }
    Map<String, dynamic> cached;
    Map<String, dynamic> oldFloor = const {};
    try {
      cached = jsonDecode(cachedRaw) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
    final floorRaw = prefs.getString(StatEngine.grandfatherFloorKey);
    if (floorRaw != null) {
      try {
        oldFloor = jsonDecode(floorRaw) as Map<String, dynamic>;
      } catch (_) {}
    }
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    final targets = <String, int>{};
    for (final stat in const ['STR', 'AGI', 'END']) {
      final value = max(asInt(cached[stat]), asInt(oldFloor[stat]));
      final target = value >= _legacyRankS
          ? StatEngine.rankThresholdS
          : value >= _legacyRankA
          ? StatEngine.rankThresholdA
          : value >= _legacyRankB
          ? StatEngine.rankThresholdB
          : value >= _legacyRankC
          ? StatEngine.rankThresholdC
          : 0;
      if (target > 0) targets[stat] = target;
    }
    return targets;
  }

  static Future<bool> _hasCompletedSessions(SharedPreferences prefs) async {
    final raw = prefs.getString('workout_sessions');
    if (raw == null || raw.isEmpty) return false;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.any((item) {
        final map = item as Map<String, dynamic>;
        return (map['isPartial'] as bool? ?? false) == false &&
            (map['isAbandoned'] as bool? ?? false) == false;
      });
    } catch (_) {
      return false;
    }
  }

  /// One-shot: retires inactivity stat-decay. Earned capability stats are now
  /// immutable, so the persisted decay factor is cleared. If the board was
  /// currently decayed (factor < 1.0), it recomputes once — now un-decayed — and
  /// SUPPRESSES the one-time upward delta so the gain never surfaces as a fake
  /// "board jump" in the finish summary / home last-session tag. Idempotent.
  static Future<void> runDecayRemovalOnce({StatEngine? statEngine}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_decayRemovalDoneKey) == true) return;

    final wasDecayed = (prefs.getDouble('combat_decay_factor_v1') ?? 1.0) < 1.0;
    await prefs.remove('combat_decay_factor_v1');
    await prefs.remove('combat_stats_last_decay_date');
    if (wasDecayed && prefs.getString(StatEngine.combatStatsKey) != null) {
      await (statEngine ?? StatEngine()).calculateAllStats(suppressDelta: true);
    }

    await prefs.setBool(_decayRemovalDoneKey, true);
  }

  static const _avatarSpecSeedDoneKey = 'migration_v_avatar_spec_seed_done';

  /// Seeds the pixel-face avatar for installs that predate the avatar system.
  /// Their old image avatar can't be converted to a 20x20 spec, so an existing
  /// character gets the same gender-seeded starter face a new user would get
  /// (from the stored quiz sex answer), editable from the profile. One-shot;
  /// skips installs that already carry a spec (or have no character yet —
  /// onboarding writes the spec itself).
  static Future<void> runAvatarSpecSeedOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_avatarSpecSeedDoneKey) == true) return;

    final profileService = ProfileService();
    if (!await profileService.hasStoredAvatarSpec()) {
      final character = await CharacterService().loadActiveCharacter();
      if (character != null) {
        await profileService.saveAvatarSpec(
          AvatarDefaults.forSex(character.calibration.sex),
        );
      }
    }
    await prefs.setBool(_avatarSpecSeedDoneKey, true);
  }

  /// Backfills the unified loot-title collection for existing users. Titles used
  /// to live in two systems (quest `selectedTitle` + loot `titleBadge`); they are
  /// now loot-only. For every claimed side-quest title, grant the matching loot
  /// title; if the user had a quest `selectedTitle` and nothing is equipped, equip
  /// it. One-shot + idempotent. Run after [runOnce] on boot.
  static Future<void> runTitleUnificationOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_titleUnificationDoneKey) == true) return;

    final raw = prefs.getString('quest_state_v1');
    if (raw != null && raw.isNotEmpty) {
      final loot = LootService();
      Map<String, dynamic> json;
      try {
        json = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        json = const {};
      }

      final claims = json['claims'];
      if (claims is Map) {
        for (final entry in claims.values) {
          if (entry is Map) {
            final lootId = questTitleNameToLootId[entry['title']];
            if (lootId != null) await loot.grantItem(lootId);
          }
        }
      }

      final lootId = questTitleNameToLootId[json['selectedTitle']];
      if (lootId != null) {
        await loot.grantItem(lootId);
        final equipped = await loot.getEquippedItem(LootCategory.titleBadge);
        if (equipped == null) await loot.equipItem(lootId);
      }
    }

    await prefs.setBool(_titleUnificationDoneKey, true);
  }

  /// Seeds the workout-only progression cursor for the weekday-anchored
  /// schedule. Pre-this-build, `ProgramProgress.currentDayIndex` walked the full
  /// 7-slot workout+rest cycle; now progression tracks `workoutIndex` over the
  /// workout-only sublist and rest is calendar-derived. Maps a mid-program user's
  /// legacy cursor to the next actionable workout (via
  /// [workoutIndexForLegacyDayIndex]) so the first post-update session is neither
  /// skipped nor duplicated. No-op when there is no active program (a fresh start
  /// writes `workoutIndex` directly). One-shot + idempotent; does not touch
  /// shields/streaks (the transition day applies no miss logic).
  static Future<void> runWeekdayAnchoredScheduleOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_weekdayAnchoredScheduleDoneKey) == true) return;

    final raw = prefs.getString(ProgramService.progressKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final progress = ProgramProgress.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        final program = programById(progress.programId);
        if (program != null && program.workouts.isNotEmpty) {
          final mapped = workoutIndexForLegacyDayIndex(
            program,
            progress.currentDayIndex,
          );
          await prefs.setString(
            ProgramService.progressKey,
            jsonEncode(progress.copyWith(workoutIndex: mapped).toJson()),
          );
        }
      } catch (_) {
        // Malformed progress — leave it; ProgramService clamps/ignores on load.
      }
    }

    await prefs.setBool(_weekdayAnchoredScheduleDoneKey, true);
  }

  static const _featureGateSeedDoneKey = 'migration_v_feature_gate_seed_done';

  /// Grandfathers existing installs into the earned feature-unlock ladder.
  ///
  /// Legacy invariant (Codex P2): a user who could reach Shop/Guild/Items/
  /// Quests/Adventure before this release must NEVER lose access — so a legacy
  /// user (onboarding complete OR any stored session, however sparse the rest
  /// of their data) gets **every** gate latched unconditionally, with the
  /// celebration + analytics stamps set (zero locks, zero ceremonies, zero
  /// synthetic events on upgrade). A genuinely fresh install matches neither
  /// signal and starts with the empty map — the ladder — instead. One-shot.
  static Future<void> runFeatureGateSeedOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_featureGateSeedDoneKey) == true) return;

    final onboarded = await OnboardingService().isComplete();
    final hasAnySession = _hasAnyStoredSession(prefs);
    if (onboarded || hasAnySession) {
      await FeatureGateService().evaluate(seedPreCelebrated: true);
    }

    await prefs.setBool(_featureGateSeedDoneKey, true);
  }

  /// ANY stored session (even partial/abandoned) marks a pre-feature install —
  /// broader than [_hasCompletedSessions] on purpose: the grandfather test is
  /// "did this install exist before the ladder", not "did they earn anything".
  static bool _hasAnyStoredSession(SharedPreferences prefs) {
    final raw = prefs.getString('workout_sessions');
    if (raw == null || raw.isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List && decoded.isNotEmpty;
    } catch (_) {
      // Unreadable history on upgrade — grandfather rather than lock out.
      return true;
    }
  }

  /// Seeds the weekly-reward anchor for the decoupled weight-log cadence. Before
  /// this build, the 7-day window gated the *log*; now it gates only the
  /// *reward* (logging is unrestricted). Seeding the new reward anchor from the
  /// legacy last-log token means a returning user is neither handed a free potion
  /// on upgrade nor blocked from their next due one. One-shot + idempotent.
  static Future<void> runWeightLogRewardAnchorOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_weightLogRewardAnchorDoneKey) == true) return;
    await BodyMetricsService().seedRewardAnchorFromLastLog();
    await prefs.setBool(_weightLogRewardAnchorDoneKey, true);
  }
}
