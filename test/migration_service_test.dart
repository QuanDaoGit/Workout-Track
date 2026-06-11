import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/avatar_spec.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/loot_item.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/body_metrics_service.dart';
import 'package:workout_track/services/calibration_service.dart';
import 'package:workout_track/services/loot_service.dart';
import 'package:workout_track/services/migration_service.dart';
import 'package:workout_track/services/profile_service.dart';
import 'package:workout_track/services/stat_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('removes old battle and class keys once', () async {
    const doneKey = 'migration_v1_battle_strip_done';
    const deadKeys = [
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
      'class_carryover_v1',
      'class_ultimate_pending_reveal',
      'unlocked_abilities',
      'ultimate_progress',
    ];

    SharedPreferences.setMockInitialValues({
      for (final key in deadKeys) key: 'legacy',
      'keep_me': 'still here',
    });

    await MigrationService.runOnce();
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getBool(doneKey), isTrue);
    expect(prefs.getString('keep_me'), 'still here');
    for (final key in deadKeys) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }

    await prefs.setString('scrap', '250');
    await MigrationService.runOnce();

    expect(prefs.getString('scrap'), '250');
  });

  test('END stat migration backfills from existing reps once', () async {
    final prefs = await SharedPreferences.getInstance();
    final session = WorkoutSession(
      id: 'history',
      date: DateTime(2026, 5, 14, 9),
      muscleGroup: 'Chest',
      targetDurationMinutes: 30,
      actualDurationSeconds: 1800,
      exercises: const [
        ExerciseLog(
          exerciseId: 'bench',
          exerciseName: 'Bench',
          sets: [SetEntry(weight: 50, reps: 15)],
        ),
      ],
      estimatedCalories: 100,
    );
    await prefs.setString('workout_sessions', jsonEncode([session.toJson()]));

    await MigrationService.runEndStatBackfillOnce();

    final stored =
        jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
            as Map<String, dynamic>;
    expect(stored['END'], 23);
    expect(prefs.getBool('migration_v2_end_stat_done'), isTrue);

    await prefs.setString(StatEngine.combatStatsKey, jsonEncode({'END': 0}));
    await MigrationService.runEndStatBackfillOnce();

    final secondStored =
        jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
            as Map<String, dynamic>;
    expect(secondStored['END'], 0);
  });

  test('END stat migration leaves baseline-only stats at baseline', () async {
    final prefs = await SharedPreferences.getInstance();

    await MigrationService.runEndStatBackfillOnce();

    final stored =
        jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
            as Map<String, dynamic>;
    expect(stored['END'], StatEngine.baseOutputStatValue);
  });

  test(
    'clears legacy self-reported calibration seed and recomputes stats',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final advancedSeedVolume = StatEngine.volumeForStat(650);
      await prefs.setString(
        StatEngine.calibrationSeedKey,
        jsonEncode({'STR': advancedSeedVolume, 'AGI': advancedSeedVolume}),
      );
      await prefs.setInt(CalibrationService.calibrationSessionCountKey, 3);
      await prefs.setBool(CalibrationService.calibrationCompleteKey, true);
      await prefs.setString(
        CalibrationService.calibrationSeedSourceKey,
        'quiz',
      );

      await MigrationService.runClearSelfReportedStatSeedOnce();

      expect(prefs.containsKey(StatEngine.calibrationSeedKey), isFalse);
      expect(
        prefs.containsKey(CalibrationService.calibrationSessionCountKey),
        isFalse,
      );
      expect(
        prefs.containsKey(CalibrationService.calibrationCompleteKey),
        isFalse,
      );
      expect(
        prefs.containsKey(CalibrationService.calibrationSeedSourceKey),
        isFalse,
      );
      expect(
        prefs.getBool('migration_v_clear_self_reported_stat_seed_done'),
        isTrue,
      );

      final stored =
          jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
              as Map<String, dynamic>;
      expect(stored['STR'], StatEngine.baseOutputStatValue);
      expect(stored['AGI'], StatEngine.baseOutputStatValue);
      expect(stored['END'], StatEngine.baseOutputStatValue);
      expect(stored['VIT'], StatEngine.baseOutputStatValue);
      expect(stored['LCK'], 0);

      await prefs.setString(
        StatEngine.calibrationSeedKey,
        jsonEncode({'STR': advancedSeedVolume}),
      );
      await MigrationService.runClearSelfReportedStatSeedOnce();
      expect(prefs.containsKey(StatEngine.calibrationSeedKey), isTrue);
    },
  );

  test('recomputes cached stats when the stats rules version changes', () async {
    final prefs = await SharedPreferences.getInstance();
    // A stale cache from an older rules version (no sessions back it).
    await prefs.setString(
      StatEngine.combatStatsKey,
      jsonEncode({
        'STR': 999,
        'DEF': 0,
        'VIT': 0,
        'AGI': 0,
        'END': 0,
        'LCK': 0,
      }),
    );

    await MigrationService.runStatsRecomputeIfRulesChanged();

    // Recompute replaced the stale 999 with the real (baseline) value and
    // recorded the current rules version.
    final stored =
        jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
            as Map<String, dynamic>;
    expect(stored['STR'], StatEngine.baseOutputStatValue);
    expect(prefs.getInt('stats_rules_version_v1'), StatEngine.statsRulesVersion);

    // Version now current → a second run is a no-op (a hand-written value is not
    // recomputed away).
    await prefs.setString(
      StatEngine.combatStatsKey,
      jsonEncode({
        'STR': 777,
        'DEF': 0,
        'VIT': 0,
        'AGI': 0,
        'END': 0,
        'LCK': 0,
      }),
    );
    await MigrationService.runStatsRecomputeIfRulesChanged();
    final second =
        jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
            as Map<String, dynamic>;
    expect(second['STR'], 777);
  });

  test('avatar seed migration gives existing characters a gendered default', () async {
    final prefs = await SharedPreferences.getInstance();
    // A pre-avatar-system install: character exists (female quiz answer),
    // profile carries only the legacy image path.
    await prefs.setString(
      'active_character_v1',
      jsonEncode(
        Character(
          name: 'Rae',
          calibration: const CalibrationResult(
            goal: BodyGoal.recomp,
            freq: TrainingFreq.mid,
            exp: Experience.beginner,
            bodyWeightKg: 70,
            sex: UserProfileSex.female,
            clazz: CharacterClass.bruiser,
          ),
          classConfirmedAt: DateTime(2026, 6, 6),
          characterName: 'Rae',
          createdAt: DateTime(2026, 6, 6),
        ).toJson(),
      ),
    );
    await prefs.setString(
      'profile_state_v1',
      '{"displayName":"Rae","avatarPath":"assets/avatar/4.png"}',
    );

    await MigrationService.runAvatarSpecSeedOnce();

    final profile = await ProfileService().loadProfile();
    expect(profile.avatarSpec, AvatarDefaults.forSex(UserProfileSex.female));
    expect(prefs.getBool('migration_v_avatar_spec_seed_done'), isTrue);

    // One-shot: a later custom face is never overwritten by a re-run.
    const custom = AvatarSpec(
      skin: AvatarSkin.tone05,
      eyes: AvatarEyes.neon,
      hair: AvatarHair.bald,
      hairColor: AvatarHairColor.gray,
      expression: AvatarExpression.focused,
    );
    await ProfileService().saveAvatarSpec(custom);
    await MigrationService.runAvatarSpecSeedOnce();
    expect((await ProfileService().loadProfile()).avatarSpec, custom);
  });

  test('avatar seed migration leaves fresh installs untouched', () async {
    await MigrationService.runAvatarSpecSeedOnce();

    // No character → nothing to seed; onboarding will write the spec itself.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('profile_state_v1'), isFalse);
  });

  test('title unification backfills loot ownership and equips the selected title', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'quest_state_v1',
      jsonEncode({
        'dailyPeriodKey': '2026-05-13',
        'weeklyPeriodKey': '2026-05-11',
        'manualDoneKeys': <String>[],
        'selectedTitle': 'Iron Novice',
        'claims': {
          'side:side_first_workout': {
            'xp': 0,
            'gems': 100,
            'claimedAt': DateTime(2026, 5, 13).toIso8601String(),
            'title': 'Iron Novice',
          },
        },
      }),
    );

    await MigrationService.runTitleUnificationOnce();

    final loot = LootService();
    final owned = (await loot.getInventory()).map((item) => item.id);
    expect(owned, contains('title_iron_novice'));
    expect(
      (await loot.getEquippedItem(LootCategory.titleBadge))?.id,
      'title_iron_novice',
    );
    expect(prefs.getBool('migration_v_title_unification_done'), isTrue);

    // One-shot: a second run must not re-equip after a deliberate unequip.
    await loot.unequipCategory(LootCategory.titleBadge);
    await MigrationService.runTitleUnificationOnce();
    expect(await loot.getEquippedItem(LootCategory.titleBadge), isNull);
  });

  test('weight-log reward anchor seeds once from the legacy last log', () async {
    final prefs = await SharedPreferences.getInstance();
    // Pre-decoupling state: a last-log token two days before the upgrade.
    await prefs.setString(
      'body_metrics_last_log_at',
      DateTime(2026, 5, 14).toIso8601String(),
    );

    await MigrationService.runWeightLogRewardAnchorOnce();

    expect(
      prefs.getBool('migration_v_weightlog_reward_anchor_done'),
      isTrue,
    );
    expect(prefs.getString('body_metrics_reward_anchor_v1'), isNotNull);

    // Seeded from the old log → the rolling window is honoured (no free potion).
    final svc = BodyMetricsService(nowProvider: () => DateTime(2026, 5, 16));
    expect(await svc.canEarnReward(), false);
    expect(await svc.daysUntilNextReward(), 5);

    // One-shot: a newer log + re-run must not move the anchor.
    await prefs.setString(
      'body_metrics_last_log_at',
      DateTime(2026, 5, 16).toIso8601String(),
    );
    await MigrationService.runWeightLogRewardAnchorOnce();
    expect(await svc.daysUntilNextReward(), 5);
  });
}
