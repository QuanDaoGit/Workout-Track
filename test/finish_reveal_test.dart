import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/workout_summary.dart';
import 'package:workout_track/widgets/xp_level_meter.dart';

/// Phase 2: the staged reveal. The CTA is gated behind the cadence and a
/// "tap to continue" skips to it; reduced motion renders the full arc instantly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  WorkoutSummaryPage summary() => const WorkoutSummaryPage(
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
  );

  // Let the on-mount save + recompute finish (real async), then settle a frame.
  Future<void> letSaveComplete(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('reduced motion renders the full arc instantly with no overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child!,
        ),
        home: summary(),
      ),
    );
    await letSaveComplete(tester);

    // No staged wait: the CTA and the XP/level bar are present; no skip overlay.
    expect(find.byKey(const ValueKey('finish_skip_overlay')), findsNothing);
    expect(find.text('BACK TO HOME'), findsOneWidget);
    expect(find.byType(XpLevelMeter), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('CTA is gated behind the reveal; tap-to-continue skips to it', (
    tester,
  ) async {
    // Normal motion: the staged cadence is running (only the 150ms beat has
    // fired during the save window, so the CTA is still hidden).
    await tester.pumpWidget(MaterialApp(home: summary()));
    await letSaveComplete(tester);

    expect(find.byType(FilledButton), findsNothing);
    expect(find.byKey(const ValueKey('finish_skip_overlay')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('finish_skip_overlay')));
    await tester.pump();

    // Skipped straight to the end — the CTA is revealed, the overlay is gone.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byKey(const ValueKey('finish_skip_overlay')), findsNothing);

    await tester.pumpWidget(const SizedBox()); // dispose, cancel reveal timers
  });
}
