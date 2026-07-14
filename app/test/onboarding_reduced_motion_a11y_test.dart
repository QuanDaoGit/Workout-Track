import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/bit_interview_copy.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/pages/onboarding/calibration_quiz_page.dart';
import 'package:workout_track/pages/onboarding/cold_open_page.dart';
import 'package:workout_track/pages/onboarding/onboarding_flow_page.dart';
import 'package:workout_track/pages/onboarding/solution_page.dart';

/// Regression guard for the reduced-motion consistency fix (#3): the onboarding
/// shell + solution + quiz used to gate their cinematics on `disableAnimations`
/// ONLY, so a screen-reader user (accessibleNavigation = true, but no OS
/// reduce-motion) still had to sit through them — unlike the sibling onboarding
/// screens. These pump each surface with **accessibleNavigation only** and prove
/// it now settles instantly. Each test fails on the pre-fix code (single pump →
/// the cinematic is still mid-play), so they are self-validating.
///
/// Single `pump()`s only — never `pumpAndSettle`: the shared `BitMoodCore` idle
/// ticker keeps running under accessibleNavigation (it gates on disableAnimations
/// alone), so the tree never "settles"; it disposes cleanly at teardown.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // accessibleNavigation = true, disableAnimations = false — the exact gap #3
  // closed. Inherits the real test size via copyWith.
  Widget screenReader(Widget child) => MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
        child: child,
      ),
    ),
  );

  testWidgets(
    'shell: a screen reader skips the welcome→cold-open boot cinematic',
    (tester) async {
      await tester.pumpWidget(screenReader(const OnboardingFlowPage()));
      await tester.pump();
      expect(find.byType(ColdOpenView), findsNothing); // on the welcome landing

      await tester.tap(find.text('GET STARTED'));
      await tester.pump(); // one frame — no ~1000ms CRT boot under AT
      expect(find.byType(ColdOpenView), findsOneWidget);
    },
  );

  testWidgets('solution: a screen reader lands on the settled, advanceable CTA', (
    tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(
      screenReader(
        Scaffold(body: SolutionView(onContinue: () => continued = true)),
      ),
    );
    await tester.pump();

    // Settled: both lines shown and the CTA advances immediately (not gated
    // behind a still-playing intro).
    expect(find.text('HERE, EVERY REP\nLEVELS YOU UP'), findsOneWidget);
    await tester.tap(find.text("LET'S BUILD MY CHARACTER"));
    await tester.pump();
    expect(continued, isTrue);
  });

  testWidgets('quiz: a screen reader skips the segment-B intro beat', (
    tester,
  ) async {
    await tester.pumpWidget(
      screenReader(
        CalibrationQuizPage(
          questions: const [
            QuizQuestion.experience,
            QuizQuestion.frequency,
            QuizQuestion.obstacle,
          ],
          progressBaseCells: 4,
          onComplete: (_) {},
        ),
      ),
    );
    await tester.pump();

    // The "just a few more questions" intro line is skipped; the experience
    // question (and its options) are shown immediately.
    expect(find.text(BitInterviewCopy.segmentBIntro), findsNothing);
    expect(find.text('NOVICE'), findsOneWidget);
  });
}
