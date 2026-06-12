import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/active_workout.dart';

Exercise _exercise(String id) => Exercise(
  id: id,
  name: id,
  level: 'beginner',
  images: const [],
);

/// A resumed session carrying one logged set, so the page boots with
/// `_loggedSets` populated (hasSets == true) without navigating to log one.
WorkoutSession _resumeWithOneSet() => WorkoutSession(
  id: 'r1',
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
    'idle timeout offers the auto-save reveal for a session with logged sets',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWorkoutPage(
            muscleGroup: 'Chest',
            durationMinutes: 30,
            exercises: [_exercise('a'), _exercise('b')],
            resumeFromSession: _resumeWithOneSet(),
            idleTimeout: const Duration(seconds: 2),
          ),
        ),
      );
      await tester.pump();

      // Not yet idle.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('STILL TRAINING?'), findsNothing);

      // Cross the idle window — the reveal appears with all three actions.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('STILL TRAINING?'), findsOneWidget);
      expect(find.text('SAVE & FINISH'), findsOneWidget);
      expect(find.text('KEEP TRAINING'), findsOneWidget);
      expect(find.text('DISCARD'), findsOneWidget);

      // KEEP TRAINING dismisses and re-arms (no reveal immediately after).
      await tester.tap(find.text('KEEP TRAINING'));
      await tester.pumpAndSettle();
      expect(find.text('STILL TRAINING?'), findsNothing);
    },
  );

  testWidgets('idle timeout drops a zero-set session silently (no reveal)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => ActiveWorkoutPage(
              muscleGroup: 'Chest',
              durationMinutes: 30,
              exercises: [_exercise('a'), _exercise('b')],
              idleTimeout: const Duration(seconds: 2),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('STILL TRAINING?'), findsNothing);
  });
}
