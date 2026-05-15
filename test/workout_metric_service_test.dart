import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/workout_metric_service.dart';

void main() {
  test('training days this week counts distinct non-consecutive days', () {
    final now = DateTime(2026, 5, 14, 12);
    final sessions = [
      _session(DateTime(2026, 5, 11, 9)),
      _session(DateTime(2026, 5, 13, 9)),
      _session(DateTime(2026, 5, 13, 18)),
      _session(DateTime(2026, 5, 10, 9)),
      _session(DateTime(2026, 5, 14, 9), isPartial: true),
      _session(DateTime(2026, 5, 15, 9)),
    ];

    expect(WorkoutMetricService.trainingDaysThisWeek(sessions, now: now), 2);
  });
}

WorkoutSession _session(DateTime date, {bool isPartial = false}) {
  return WorkoutSession(
    id: date.microsecondsSinceEpoch.toString(),
    date: date,
    muscleGroup: 'Chest',
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    exercises: const [],
    estimatedCalories: 100,
    isPartial: isPartial,
  );
}
