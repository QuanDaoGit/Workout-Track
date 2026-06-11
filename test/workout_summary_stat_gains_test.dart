import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/workout_summary.dart';

/// Regression for the "buried stat gain": when the session's hero outranks the
/// stat gain (a fresh user's first session levels up), the STR gain must still
/// render in the labelled STAT GAINS row instead of being dropped under the
/// hero's fireworks.
///
/// Lives in its own file: a second full on-mount save in the same test isolate
/// hangs on the calibration step's rootBundle asset load (pre-existing test
/// infra limitation), so this full-save test needs a fresh isolate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'a non-statGain hero still renders the STR gain in the STAT GAINS row',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child!,
          ),
          home: const WorkoutSummaryPage(
            muscleGroup: 'Chest',
            targetMuscleGroups: ['Chest'],
            durationMinutes: 20,
            elapsedSeconds: 600,
            exerciseLogs: [
              ExerciseLog(
                exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
                exerciseName: 'Barbell Bench Press',
                sets: [SetEntry(weight: 40, reps: 8)],
              ),
            ],
            selectedExerciseIds: ['Barbell_Bench_Press_-_Medium_Grip'],
          ),
        ),
      );
      // Let the on-mount save + recompute finish (real async), then settle.
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('STAT GAINS'), findsOneWidget);
      expect(find.text('STR +'), findsOneWidget);
    },
  );
}
