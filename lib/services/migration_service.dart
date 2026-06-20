import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/loot_registry.dart';
import '../data/programs_library.dart';
import '../models/avatar_spec.dart';
import '../models/loot_item.dart';
import '../models/program_models.dart';
import 'body_metrics_service.dart';
import 'calibration_service.dart';
import 'character_service.dart';
import 'loot_service.dart';
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

    await prefs.remove(StatEngine.calibrationSeedKey);
    await prefs.remove(CalibrationService.calibrationSessionCountKey);
    await prefs.remove(CalibrationService.calibrationCompleteKey);
    await prefs.remove(CalibrationService.calibrationSeedSourceKey);

    await StatEngine().calculateAllStats();
    await prefs.setBool(_clearSelfReportedSeedDoneKey, true);
  }

  static const _statsRulesVersionKey = 'stats_rules_version_v1';

  /// Recomputes cached combat stats whenever [StatEngine.statsRulesVersion]
  /// changes, so a re-tune of the stat formula surfaces at app-update boot — not
  /// as a surprise jump mid-workout. Version-gated (re-runs on every future
  /// bump), unlike the one-shot cleanups above.
  ///
  /// Before the recompute, the visible STR/AGI a user already earned under the
  /// old rules is captured once as a grandfather floor: the new currency must
  /// never read as lost progress, so the engine clamps the board to at least
  /// these values forever after (normal growth continues above them).
  static Future<void> runStatsRecomputeIfRulesChanged() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_statsRulesVersionKey) == StatEngine.statsRulesVersion) {
      return;
    }
    if (prefs.getString(StatEngine.grandfatherFloorKey) == null) {
      final cachedRaw = prefs.getString(StatEngine.combatStatsKey);
      // Only grandfather a board that real completed sessions back. A cached
      // value with no history behind it (corruption, cleared data) was never
      // earned — recomputing it away is the correction, not lost progress.
      if (cachedRaw != null && await _hasCompletedSessions(prefs)) {
        final cached = jsonDecode(cachedRaw) as Map<String, dynamic>;
        final floor = <String, int>{
          for (final stat in const ['STR', 'AGI'])
            if ((cached[stat] as num?) != null &&
                (cached[stat] as num).toInt() > StatEngine.baseOutputStatValue)
              stat: (cached[stat] as num).toInt(),
        };
        if (floor.isNotEmpty) {
          await prefs.setString(
            StatEngine.grandfatherFloorKey,
            jsonEncode(floor),
          );
        }
      }
    }
    await StatEngine().calculateAllStats();
    await prefs.setInt(_statsRulesVersionKey, StatEngine.statsRulesVersion);
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
