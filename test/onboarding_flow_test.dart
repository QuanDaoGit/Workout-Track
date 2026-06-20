import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/workout_summary.dart';
import 'package:workout_track/pages/onboarding/calibration_quiz_page.dart';
import 'package:workout_track/pages/onboarding/cold_open_page.dart';
import 'package:workout_track/pages/onboarding/onboarding_flow_page.dart';
import 'package:workout_track/pages/onboarding/problem_question_page.dart';
import 'package:workout_track/pages/onboarding/solution_page.dart';
import 'package:workout_track/pages/onboarding/rank_assessed_page.dart';
import 'package:workout_track/services/onboarding_service.dart';
import 'package:workout_track/widgets/companion/bit_boot.dart';
import 'package:workout_track/widgets/companion/bit_mood_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'OnboardingService defaults to incomplete and flips on markComplete',
    () async {
      final svc = OnboardingService();
      expect(await svc.isComplete(), isFalse);
      await svc.markComplete();
      expect(await svc.isComplete(), isTrue);
    },
  );

  testWidgets(
    'Cold open waits OFF, powers on with the first tap, continues on the second',
    (tester) async {
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColdOpenView(onContinue: () => continued = true),
          ),
        ),
      );
      // OFF/standby: BIT present, the wake affordance shown.
      expect(find.text('IRONBIT'), findsOneWidget);
      expect(find.byType(BitBootCore), findsOneWidget);
      expect(find.text('TAP TO WAKE'), findsOneWidget);

      // First tap powers BIT on — it does NOT continue.
      await tester.tap(find.byType(ColdOpenView));
      await tester.pump();
      expect(continued, isFalse);
      await tester.pump(const Duration(milliseconds: 3100)); // boot completes
      expect(find.text('TAP TO WAKE'), findsNothing);

      // Second tap continues.
      await tester.tap(find.byType(ColdOpenView));
      expect(continued, isTrue);
    },
  );

  testWidgets('Onboarding flow shows problem screen after cold open', (
    tester,
  ) async {
    await _startFlow(tester);

    expect(find.byType(ColdOpenView), findsOneWidget);
    await _advancePastColdOpen(tester);
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump();

    expect(find.byType(ProblemQuestionView), findsOneWidget);
  });

  testWidgets('Welcome to Problem uses a BIT-preserving cross-fade', (
    tester,
  ) async {
    await _startFlow(tester);

    await _advancePastColdOpen(tester);
    await tester.pump(const Duration(milliseconds: 80));

    // Mid cross-fade: the cold open is still present (fading) over the problem,
    // so BIT carries across the cut rather than a full-screen wipe.
    expect(
      find.byKey(const ValueKey('onboarding_crossfade')),
      findsOneWidget,
    );
    expect(find.byType(ColdOpenView), findsOneWidget);
    expect(find.byType(ProblemQuestionView), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 360));
    await tester.pump();
    expect(find.byType(ProblemQuestionView), findsOneWidget);
    expect(find.byType(ColdOpenView), findsNothing);
  });

  testWidgets('Cross-fade end keeps the problem State (no double-play)', (
    tester,
  ) async {
    await _startFlow(tester);
    await _advancePastColdOpen(tester);

    await tester.pump(const Duration(milliseconds: 80)); // mid cross-fade
    final midState = tester.state(find.byType(ProblemQuestionView));

    await tester.pump(const Duration(milliseconds: 400)); // cross-fade ends
    await tester.pump();
    final afterState = tester.state(find.byType(ProblemQuestionView));

    // The incoming problem screen must keep its State across the cross-fade end;
    // if it is rebuilt fresh its intro restarts and the transition plays twice.
    expect(identical(midState, afterState), isTrue);
    expect(find.byType(ColdOpenView), findsNothing);
  });

  testWidgets('Problem to Solution is a BIT-preserving cross-fade (one BIT)', (
    tester,
  ) async {
    await _startFlow(tester);

    await _advancePastColdOpen(tester);
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump();
    await tester.tap(find.byType(ProblemQuestionView));
    await tester.pump();
    await tester.tap(find.byType(ProblemQuestionView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80)); // mid cross-fade

    // The solution has mounted beneath; the outgoing problem hides its BIT, so
    // exactly one BIT carries the cut (no amber ripple, no double BIT).
    expect(find.byType(SolutionView), findsOneWidget);
    expect(find.byType(BitMoodCore), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding_amber_ripple')),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 520));
    await tester.pump();
    expect(find.byType(SolutionView), findsOneWidget);
    expect(find.byType(ProblemQuestionView), findsNothing);
  });

  testWidgets('Problem→Solution keeps the OUTGOING problem State (no re-type)', (
    tester,
  ) async {
    await _startFlow(tester);
    await _advancePastColdOpen(tester);
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump();

    // Complete the problem intro (first tap), then capture its State.
    await tester.tap(find.byType(ProblemQuestionView));
    await tester.pump();
    final beforeState = tester.state(find.byType(ProblemQuestionView));

    // Continue (second tap) starts the problem→solution cross-fade; the problem
    // becomes the fading overlay. Its State must be the SAME instance — a stable
    // key preserves it, otherwise it re-mounts fresh and its question re-types
    // mid-fade (the screen-2→3 "stutter").
    await tester.tap(find.byType(ProblemQuestionView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80)); // mid cross-fade
    final overlayState = tester.state(find.byType(ProblemQuestionView));

    expect(identical(beforeState, overlayState), isTrue);
  });

  testWidgets('Solution CTA starts the onboarding handoff (iris)', (
    tester,
  ) async {
    await _startFlow(tester);

    await _advancePastColdOpen(tester);
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump();
    await tester.tap(find.byType(ProblemQuestionView));
    await tester.pump();
    await tester.tap(find.byType(ProblemQuestionView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 520));
    await tester.pump();
    await tester.tap(find.byType(SolutionView));
    await tester.pump();
    await tester.tap(find.text("LET'S BUILD MY CHARACTER"));
    await tester.pump(const Duration(milliseconds: 140));

    expect(
      find.byKey(const ValueKey('onboarding_handoff_iris')),
      findsOneWidget,
    );
  });

  testWidgets('After the face reveal, no later screen shows a faceless BIT', (
    tester,
  ) async {
    await _startFlow(tester);
    await _advancePastColdOpen(tester);
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump();
    // problem → solution (the reveal screen)
    await tester.tap(find.byType(ProblemQuestionView));
    await tester.pump();
    await tester.tap(find.byType(ProblemQuestionView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 520));
    await tester.pump();
    // Complete the solution intro and advance through the handoff into the quiz.
    await tester.tap(find.byType(SolutionView));
    await tester.pump();
    await tester.tap(find.text("LET'S BUILD MY CHARACTER"));
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (find.byType(CalibrationQuizPage).evaluate().isEmpty &&
        DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();

    expect(find.byType(CalibrationQuizPage), findsOneWidget);
    // Invariant: once BIT has revealed its face on Screen 3, it never reverts to
    // a FACELESS core. The solution's BIT may persist beneath the pushed quiz
    // route, but only fully revealed (reveal == 1); the faceless boot core never
    // reappears.
    for (final bit in tester.widgetList<BitMoodCore>(
      find.byType(BitMoodCore),
    )) {
      expect(
        bit.reveal,
        1.0,
        reason: 'a BIT shown after the reveal must be faced, not faceless',
      );
    }
    expect(find.byType(BitBootCore), findsNothing);
  });

  testWidgets('Calibration summary returns to caller after rank reveal', (
    tester,
  ) async {
    var summaryReturned = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => WorkoutSummaryPage(
                      muscleGroup: 'Full Body',
                      targetMuscleGroups: const ['Full Body'],
                      durationMinutes: 20,
                      elapsedSeconds: 600,
                      exerciseLogs: const [
                        ExerciseLog(
                          exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
                          exerciseName: 'Barbell Bench Press',
                          sets: [SetEntry(weight: 40, reps: 8)],
                        ),
                      ],
                      selectedExerciseIds: const [
                        'Barbell_Bench_Press_-_Medium_Grip',
                      ],
                      isCalibration: true,
                    ),
                  ),
                );
                summaryReturned = true;
              },
              child: const Text('OPEN SUMMARY'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN SUMMARY'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await _pumpUntilFound(tester, find.byType(RankAssessedPage));

    expect(find.text('RANK ASSESSED'), findsOneWidget);
    expect(summaryReturned, isFalse);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('ENTER'));
    await tester.pump();
    await _pumpUntilFound(tester, find.text('OPEN SUMMARY'));

    expect(summaryReturned, isTrue);
  });

  testWidgets('Problem screen reduced motion renders final static copy', (
    tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ProblemQuestionView(onContinue: (_) => continued = true),
          ),
        ),
      ),
    );

    expect(_findProblemQuestion(), findsOneWidget);
    expect(find.text('tap to continue ›'), findsOneWidget);
    // BIT now carries the beat (faceless), not the human failed-lifter sprite.
    expect(find.byType(BitMoodCore), findsOneWidget);
    expect(_usesFontFamily(tester, 'PressStart2P'), isFalse);

    await tester.tap(find.byType(ProblemQuestionView));
    expect(continued, isTrue);
  });

  testWidgets('Problem screen exposes the full question to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: ProblemQuestionView(onContinue: (_) {})),
        ),
      ),
    );

    // The typed RichText is excluded from semantics; the full line is exposed
    // on the screen's own node so a screen reader never reads half-typed text.
    final semantics = tester.getSemantics(find.byType(ProblemQuestionView));
    expect(semantics.label, contains('Ever start strong'));
    expect(semantics.label, contains('then quit by week two?'));
    handle.dispose();
  });

  testWidgets(
    'Problem screen first tap completes intro, second tap continues',
    (tester) async {
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProblemQuestionView(onContinue: (_) => continued = true),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(ProblemQuestionView));
      await tester.pump();

      expect(continued, isFalse);
      expect(_findProblemQuestion(), findsOneWidget);

      await tester.tap(find.byType(ProblemQuestionView));
      expect(continued, isTrue);
    },
  );

  testWidgets('Cold open: tap wakes BIT, greeting shown (reduced motion)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: ColdOpenView(onContinue: () {})),
        ),
      ),
    );
    await tester.pump();

    // OFF/standby until tapped — greeting not yet shown.
    expect(find.byType(BitBootCore), findsOneWidget);
    expect(find.text('TAP TO WAKE'), findsOneWidget);
    expect(find.text('WELCOME, WARRIOR'), findsNothing);

    // Tapping powers BIT on instantly under reduced motion; greeting in full.
    await tester.tap(find.byType(ColdOpenView));
    await tester.pump();
    expect(find.text('WELCOME, WARRIOR'), findsOneWidget);
  });

}

/// Pumps the flow and advances past the welcome landing — through the departure
/// (logo zoom) and the CRT "boot the cabinet" power-cycle — into the cold open,
/// fully cleared, where the existing assertions begin.
Future<void> _startFlow(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: OnboardingFlowPage()));
  await tester.tap(find.text('GET STARTED'));
  await _pumpUntilFound(tester, find.byType(ColdOpenView));
  // Let the power-on bloom finish and the boot overlay clear.
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump();
}

/// Cold open is user-powered: tap to wake BIT, let it boot, tap to continue.
Future<void> _advancePastColdOpen(WidgetTester tester) async {
  await tester.tap(find.byType(ColdOpenView)); // wake BIT
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 3100)); // power-on completes
  await tester.tap(find.byType(ColdOpenView)); // continue
  await tester.pump();
}

bool _usesFontFamily(WidgetTester tester, String family) {
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    if (_spanUsesFontFamily(richText.text, family)) return true;
  }
  return false;
}

Finder _findProblemQuestion() => find.text(
  'Ever start strong...\nthen quit by week two?',
  findRichText: true,
);

bool _spanUsesFontFamily(InlineSpan span, String family) {
  if (span.style?.fontFamily == family) return true;
  if (span is TextSpan) {
    final children = span.children;
    if (children == null) return false;
    return children.any((child) => _spanUsesFontFamily(child, family));
  }
  return false;
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}
