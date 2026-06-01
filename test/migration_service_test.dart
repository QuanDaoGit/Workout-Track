import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/migration_service.dart';
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
    expect(prefs.getBool(StatEngine.endBackfillNoticeKey), isTrue);

    await prefs.setString(StatEngine.combatStatsKey, jsonEncode({'END': 0}));
    await MigrationService.runEndStatBackfillOnce();

    final secondStored =
        jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
            as Map<String, dynamic>;
    expect(secondStored['END'], 0);
  });

  test(
    'END stat migration does not show history notice for baseline only',
    () async {
      final prefs = await SharedPreferences.getInstance();

      await MigrationService.runEndStatBackfillOnce();

      final stored =
          jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
              as Map<String, dynamic>;
      expect(stored['END'], StatEngine.baseOutputStatValue);
      expect(prefs.getBool(StatEngine.endBackfillNoticeKey), isNull);
    },
  );
}
