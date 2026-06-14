import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/unit_models.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/unit_settings_service.dart';
import 'package:workout_track/services/xp_service.dart';

/// Warm-up sets must reward (the gem bonus) but feed **no** volume/stat/XP path.
/// They live in [ExerciseLog.warmupSets], apart from the working [ExerciseLog.sets]
/// every aggregator reads — so adding them can never change the numbers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Units.weight = WeightUnit.kg;
  });

  WorkoutSession session({required bool withWarmup}) => WorkoutSession(
    id: 's1',
    date: DateTime(2026, 6, 13),
    muscleGroup: 'Chest',
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    exercises: [
      ExerciseLog(
        exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
        exerciseName: 'Bench',
        sets: const [
          SetEntry(weight: 100, reps: 5),
          SetEntry(weight: 100, reps: 5),
        ],
        warmupSets: withWarmup
            // Deliberately heavy/many — if these leaked into any aggregate, the
            // numbers would jump. They must not.
            ? const [
                SetEntry(weight: 200, reps: 20, isWarmup: true),
                SetEntry(weight: 200, reps: 20, isWarmup: true),
              ]
            : const [],
      ),
    ],
    estimatedCalories: 100,
  );

  test('totalVolume ignores warm-up sets', () {
    expect(session(withWarmup: true).exercises.first.totalVolume, 1000);
    expect(session(withWarmup: false).exercises.first.totalVolume, 1000);
  });

  test('session base XP is identical with and without warm-up sets', () {
    final withWarmup = XpService.calculateBaseSessionXP(session(withWarmup: true));
    final without = XpService.calculateBaseSessionXP(session(withWarmup: false));
    expect(withWarmup, without);
  });
}
