import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/home.dart';

void main() {
  test('completed mission copy uses actual workout target, not suggestion', () {
    final session = _session(
      muscleGroup: 'Back',
      targetMuscleGroups: const ['Back'],
      selectedExerciseIds: const ['row', 'pulldown', 'curl'],
    );

    final copy = completedMissionCopy(session);

    expect(copy.title, 'BACK');
    expect(copy.detail, 'Today | 12 min | 3 exercises');
  });

  test('completed mission copy keeps compact multi-target label', () {
    final session = _session(
      muscleGroup: 'Back',
      targetMuscleGroups: const ['Back', 'Shoulders', 'Arms'],
      selectedExerciseIds: const ['row', 'press', 'curl'],
    );

    final copy = completedMissionCopy(session);

    expect(copy.title, 'BACK + 2');
  });

  test('completed mission copy has neutral fallback without a session', () {
    final copy = completedMissionCopy(null);

    expect(copy.title, 'TODAY\'S MISSION');
    expect(copy.detail, 'Cleared');
  });
}

WorkoutSession _session({
  required String muscleGroup,
  required List<String> targetMuscleGroups,
  required List<String> selectedExerciseIds,
}) {
  return WorkoutSession(
    id: 'session',
    date: DateTime(2026, 5, 24, 10),
    muscleGroup: muscleGroup,
    targetMuscleGroups: targetMuscleGroups,
    targetDurationMinutes: 60,
    actualDurationSeconds: 720,
    exercises: [
      for (final id in selectedExerciseIds)
        ExerciseLog(
          exerciseId: id,
          exerciseName: id,
          sets: const [SetEntry(weight: 50, reps: 8)],
        ),
    ],
    estimatedCalories: 100,
    selectedExerciseIds: selectedExerciseIds,
  );
}
