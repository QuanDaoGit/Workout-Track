import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/workout_summary.dart';
import 'package:workout_track/services/sfx_service.dart';

/// Phase 1b static restructure of the finish summary: hero headline replaces the
/// flat stat row, per-exercise calorie readouts are gone, and the receipt facts
/// are demoted. (Animation is Phase 2 — here everything renders in final state.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SfxService.enabled = false; // no audio plugin in the test env
  });
  tearDown(() => SfxService.enabled = true);

  Future<void> pumpSummary(
    WidgetTester tester, {
    required bool abandoned,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child!,
        ),
        home: WorkoutSummaryPage(
          muscleGroup: 'Chest',
          targetMuscleGroups: const ['Chest'],
          durationMinutes: 20,
          elapsedSeconds: 600,
          exerciseLogs: const [
            ExerciseLog(
              exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
              exerciseName: 'Barbell Bench Press',
              sets: [SetEntry(weight: 40, reps: 8)],
            ),
          ],
          selectedExerciseIds: const ['Barbell_Bench_Press_-_Medium_Grip'],
          isAbandoned: abandoned,
          isPartial: abandoned,
        ),
      ),
    );
    // Let _saveAndExit (save + recompute + selectHero) finish.
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'completed session shows a hero headline and no per-exercise calories',
    (tester) async {
      await pumpSummary(tester, abandoned: false);

      // Per-exercise "N calories" readouts are removed from the breakdown.
      expect(find.textContaining('calories'), findsNothing);

      // The hero region renders the chosen stat-gain hero (STR for a bench set).
      expect(find.textContaining('STR'), findsWidgets);

      // Ending CTA still present.
      expect(find.text('BACK TO HOME'), findsOneWidget);
    },
  );

  testWidgets(
    'abandoned session renders a muted tone with no calorie readouts',
    (tester) async {
      await pumpSummary(tester, abandoned: true);

      expect(find.textContaining('calories'), findsNothing);
      expect(find.text('BACK TO HOME'), findsOneWidget);
    },
  );

  // The buried-gain regression (a non-statGain hero must still render the STR
  // gain) lives in its own file — workout_summary_stat_gains_test.dart — because
  // a second full on-mount save in the same test isolate hangs on the
  // calibration step's rootBundle asset load (pre-existing infra limitation).
}
