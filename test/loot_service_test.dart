import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/loot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('session milestone unlocks exactly at the new boundary', () async {
    final service = LootService();

    final before = await service.evaluateUnlocks(
      stats: const {},
      sessions: _sessions(15),
    );
    expect(before, isNot(contains('frame_neon')));

    final atBoundary = await service.evaluateUnlocks(
      stats: const {},
      sessions: _sessions(16),
    );
    expect(atBoundary, contains('frame_neon'));
  });

  test('all-stats loot ignores hidden DEF, VIT, and LCK scales', () async {
    final service = LootService();

    final missingVisibleGrowthStat = await service.evaluateUnlocks(
      stats: const {
        'STR': 600,
        'DEF': 600,
        'AGI': 600,
        'END': 10,
        'VIT': 100,
        'LCK': 100,
      },
      sessions: const [],
    );
    expect(missingVisibleGrowthStat, isNot(contains('title_ironbit')));

    final growthStats = await service.evaluateUnlocks(
      stats: const {
        'STR': 600,
        'DEF': 10,
        'AGI': 600,
        'END': 600,
        'VIT': 10,
        'LCK': 0,
      },
      sessions: const [],
    );
    expect(growthStats, contains('title_ironbit'));
  });

  test('owned loot is not re-revealed', () async {
    final service = LootService();

    final first = await service.evaluateUnlocks(
      stats: const {},
      sessions: _sessions(16),
    );
    expect(first, contains('frame_neon'));

    final second = await service.evaluateUnlocks(
      stats: const {},
      sessions: _sessions(16),
    );
    expect(second, isNot(contains('frame_neon')));
  });
}

List<WorkoutSession> _sessions(int count) => [
  for (var i = 0; i < count; i++)
    WorkoutSession(
      id: 's$i',
      date: DateTime(2026, 1, 1 + i),
      muscleGroup: 'Chest',
      targetMuscleGroups: const ['Chest'],
      targetDurationMinutes: 45,
      actualDurationSeconds: 45 * 60,
      estimatedCalories: 0,
      exercises: const [
        ExerciseLog(
          exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
          exerciseName: 'Bench Press',
          sets: [SetEntry(weight: 40, reps: 8)],
        ),
      ],
    ),
];
