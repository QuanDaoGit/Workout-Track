import 'package:flutter_test/flutter_test.dart';

import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/xp_service.dart';

WorkoutSession _session({
  int seconds = 600,
  List<ExerciseLog> exercises = const [
    ExerciseLog(
      exerciseId: 'bench',
      exerciseName: 'Bench',
      sets: [SetEntry(weight: 10, reps: 1)],
    ),
  ],
}) {
  return WorkoutSession(
    id: 's',
    date: DateTime(2026, 1, 1),
    muscleGroup: 'Chest',
    targetDurationMinutes: 45,
    actualDurationSeconds: seconds,
    estimatedCalories: 0,
    exercises: exercises,
  );
}

void main() {
  test('below-minimum completed sessions are not reward eligible', () {
    final eligibility = XpService.rewardEligibility(_session());
    expect(eligibility.eligible, isFalse);
  });

  test('duration, volume, or exercise count can make a session eligible', () {
    expect(
      XpService.rewardEligibility(_session(seconds: 900)).eligible,
      isTrue,
    );

    expect(
      XpService.rewardEligibility(
        _session(
          exercises: const [
            ExerciseLog(
              exerciseId: 'bench',
              exerciseName: 'Bench',
              sets: [SetEntry(weight: 20, reps: 10)],
            ),
          ],
        ),
      ).eligible,
      isTrue,
    );

    expect(
      XpService.rewardEligibility(
        _session(
          exercises: const [
            ExerciseLog(
              exerciseId: 'a',
              exerciseName: 'A',
              sets: [SetEntry(weight: 0, reps: 1)],
            ),
            ExerciseLog(
              exerciseId: 'b',
              exerciseName: 'B',
              sets: [SetEntry(weight: 0, reps: 1)],
            ),
            ExerciseLog(
              exerciseId: 'c',
              exerciseName: 'C',
              sets: [SetEntry(weight: 0, reps: 1)],
            ),
          ],
        ),
      ).eligible,
      isTrue,
    );
  });

  test('loot bonus XP is additive and unmultiplied', () {
    final breakdown = XpService.buildBreakdown(
      session: _session(seconds: 900),
      baseXP: 100,
      lckMultiplier: 2.0,
      potionMultiplier: 1.5,
      lootBonusXP: 25,
    );

    expect(breakdown.multipliedWorkoutXP, 300);
    expect(breakdown.lootBonusXP, 25);
    expect(breakdown.finalXP, 325);
  });

  test('ineligible breakdown zeros all XP multipliers and cache bonus', () {
    final breakdown = XpService.buildBreakdown(
      session: _session(),
      baseXP: 100,
      lckMultiplier: 2.0,
      potionMultiplier: 1.5,
      lootBonusXP: 25,
    );

    expect(breakdown.baseXP, 0);
    expect(breakdown.lckMultiplier, 1.0);
    expect(breakdown.potionMultiplier, 1.0);
    expect(breakdown.lootBonusXP, 0);
    expect(breakdown.finalXP, 0);
  });
}
