import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:workout_track/models/loot_drop.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/loot_drop_service.dart';

WorkoutSession _session(String id, DateTime date) {
  return WorkoutSession(
    id: id,
    date: date,
    muscleGroup: 'Chest',
    targetDurationMinutes: 45,
    actualDurationSeconds: 45 * 60,
    estimatedCalories: 0,
    exercises: const [
      ExerciseLog(
        exerciseId: 'bench',
        exerciseName: 'Bench',
        sets: [SetEntry(weight: 40, reps: 8)],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      LootDropService.installIdKey: 'install-test',
    });
  });

  test('cooldown skips rolling and does not increment pity', () async {
    final now = DateTime(2026, 1, 1, 12);
    SharedPreferences.setMockInitialValues({
      LootDropService.installIdKey: 'install-test',
      LootDropService.stateKey: jsonEncode(
        LootDropState(
          rollAttemptsSinceRare: 4,
          lastRollAt: now.subtract(const Duration(minutes: 30)),
        ).toJson(),
      ),
    });

    final service = LootDropService();
    final drop = await service.rollForSession(
      session: _session('cooldown', now),
      lck: 0,
      now: now,
    );

    expect(drop, isNull);
    final state = await service.debugStateForTest();
    expect(state.rollAttemptsSinceRare, 4);
    expect(state.rolledSessionIds, contains('cooldown'));
  });

  test('pity forces rare-or-better after 10 eligible attempts', () async {
    final now = DateTime(2026, 1, 1, 12);
    SharedPreferences.setMockInitialValues({
      LootDropService.installIdKey: 'install-test',
      LootDropService.stateKey: jsonEncode(
        LootDropState(rollAttemptsSinceRare: 9).toJson(),
      ),
    });

    final drop = await LootDropService().rollForSession(
      session: _session('pity', now),
      lck: 0,
      now: now,
    );

    expect(drop, isNotNull);
    expect(drop!.isRareOrBetter, isTrue);
    final state = await LootDropService().debugStateForTest();
    expect(state.rollAttemptsSinceRare, 0);
  });

  test('unviewed badge state clears when drops are marked viewed', () async {
    final now = DateTime(2026, 1, 1, 12);
    SharedPreferences.setMockInitialValues({
      LootDropService.installIdKey: 'install-test',
      LootDropService.dropsKey: jsonEncode([
        LootDrop(
          id: 'd',
          sessionId: 's',
          tier: LootDropTier.common,
          contentKind: LootDropContentKind.xpBonus,
          xpBonus: 10,
          awardedAt: now,
        ).toJson(),
      ]),
    });

    final service = LootDropService();
    expect(await service.hasUnviewedDrops(), isTrue);
    await service.markAllViewed(now: now.add(const Duration(minutes: 1)));
    expect(await service.hasUnviewedDrops(), isFalse);
  });
}
