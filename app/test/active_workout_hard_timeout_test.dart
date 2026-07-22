import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/active_workout.dart';
import 'package:workout_track/pages/Workout session/workout_summary.dart';

/// The hard idle boundary on the LIVE page: past `hardIdleTimeout` the session
/// is no longer a question — no STILL TRAINING? dialog, straight to the
/// summary with the credited-to-last-set duration (the ask-forever loop is the
/// 765-hour bug).
///
/// ONE scenario in this file on purpose: the summary save runs through the
/// process-wide `prefsWriteLock`, which an earlier same-isolate test's
/// teardown can strand mid-critical-section (the KeyedLock trap).
Exercise _exercise(String id) =>
    Exercise(id: id, name: id, level: 'beginner', images: const []);

WorkoutSession _resumeWithOneSet() => WorkoutSession(
  id: 'hard-1',
  date: DateTime.now(),
  startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
  muscleGroup: 'Chest',
  targetDurationMinutes: 30,
  actualDurationSeconds: 180,
  estimatedCalories: 20,
  isPartial: true,
  selectedExerciseIds: const ['a', 'b'],
  exercises: const [
    ExerciseLog(
      exerciseId: 'a',
      exerciseName: 'a',
      sets: [SetEntry(weight: 40, reps: 8)],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'past the hard boundary the session auto-banks — no dialog, straight to '
    'the summary with the credited duration',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWorkoutPage(
            muscleGroup: 'Chest',
            durationMinutes: 30,
            exercises: [_exercise('a'), _exercise('b')],
            resumeFromSession: _resumeWithOneSet(),
            idleTimeout: const Duration(seconds: 2),
            // Zero = the idle timer's own firing IS past the hard boundary —
            // the deterministic injection (real-vs-fake clock divergence makes
            // a small nonzero hard window racy in tests).
            hardIdleTimeout: Duration.zero,
          ),
        ),
      );
      await tester.pump();

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('STILL TRAINING?'), findsNothing);
      // The summary save runs real async work — let it land, then pump the
      // route transition.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(WorkoutSummaryPage), findsOneWidget);
    },
  );
}
