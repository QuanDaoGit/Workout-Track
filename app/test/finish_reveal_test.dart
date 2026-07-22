import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/workout_summary.dart';
import 'package:workout_track/widgets/companion/session_ceremony.dart';
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
    // Normal motion: the Session-Complete ceremony owns the screen first and
    // deliberately catches taps ABOVE the reveal's skip overlay — the designed
    // contract is a two-stage skip: tap 1 skips the ceremony, tap 2 skips the
    // staged reveal. (This test's original single-tap premise predates the
    // ceremony layer.)
    await tester.pumpWidget(MaterialApp(home: summary()));
    await letSaveComplete(tester);

    expect(find.byType(SessionCeremony), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);

    // Tap 1 — skip the ceremony; drain to inert so onFinished removes the
    // overlay. The ceremony clock caps dt at 60ms per FRAME (many short pumps,
    // never one long one), and its exit rides real async too — a bounded POLL,
    // not a fixed frame count, keeps this robust under parallel suite load.
    await tester.tap(find.byType(SessionCeremony));
    for (var i = 0;
        i < 100 && find.byType(SessionCeremony).evaluate().isNotEmpty;
        i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(SessionCeremony), findsNothing);

    // The staged reveal is now running: CTA still gated, its skip catcher up.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byKey(const ValueKey('finish_skip_overlay')), findsOneWidget);

    // Tap 2 — skip the staged cadence.
    await tester.tap(find.byKey(const ValueKey('finish_skip_overlay')));
    await tester.pump();

    // Skipped straight to the end — the CTA is revealed, the overlay is gone.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byKey(const ValueKey('finish_skip_overlay')), findsNothing);

    await tester.pumpWidget(const SizedBox()); // dispose, cancel reveal timers
  });
}
