import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/bit_interview_copy.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/resolve_models.dart';
import 'package:workout_track/pages/onboarding/calibration_quiz_page.dart';
import 'package:workout_track/widgets/companion/bit_mood_core.dart';

/// State-matrix coverage for the BIT interview: BIT *types* every question and
/// reacts (in cheer) to the emotional ones (vow, vision, experience, frequency,
/// obstacle); goal + body-metrics are ask-only. Reactions end with a "tap to
/// continue" (no button, no auto-advance). `[bracketed]` phrases are a separate
/// amber widget, so the bubble's plain text drops the brackets. Reduced motion
/// shows full text instantly (no typing).
void main() {
  Widget quiz(
    List<QuizQuestion> questions, {
    required bool reducedMotion,
    void Function(QuizAnswers)? onComplete,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
          child: CalibrationQuizPage(
            questions: questions,
            onExit: () {},
            onComplete: onComplete ?? (_) {},
          ),
        ),
      ),
    );
  }

  bool cheering(WidgetTester tester) => tester
      .widgetList<BitMoodCore>(find.byType(BitMoodCore))
      .any((c) => c.pose == BitPose.cheer);

  // Bounded settle for normal motion (BIT's idle is a perpetual ticker).
  Future<void> pumpFrames(WidgetTester tester, int n, [int ms = 20]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(Duration(milliseconds: ms));
    }
  }

  testWidgets('vow: asks neutral, reacts in cheer with amber, tap to continue', (
    tester,
  ) async {
    await tester.pumpWidget(
      quiz(const [QuizQuestion.trainingWhy, QuizQuestion.goal],
          reducedMotion: true),
    );
    await tester.pump();

    expect(find.text(BitInterviewCopy.ask(QuizQuestion.trainingWhy)),
        findsOneWidget);
    expect(cheering(tester), isFalse);

    await tester.tap(find.text(TrainingWhy.doneQuitting.label));
    await tester.pump();
    await tester.tap(find.text('CONTINUE')); // confirm the vow set
    await tester.pumpAndSettle(); // BIT types the reaction + the hint appears

    expect(find.textContaining('will be our precious material'), findsOneWidget);
    expect(find.text('determined persistence'), findsOneWidget); // amber bracket
    expect(cheering(tester), isTrue);

    // Tap to continue (no button) → the next question.
    await tester.tap(find.text('tap to continue ›'));
    await tester.pumpAndSettle();
    expect(find.text(BitInterviewCopy.ask(QuizQuestion.goal)), findsOneWidget);
    expect(cheering(tester), isFalse);
  });

  testWidgets('vow reaction speaks to the highest-priority pick', (tester) async {
    await tester.pumpWidget(
      quiz(const [QuizQuestion.trainingWhy, QuizQuestion.goal],
          reducedMotion: true),
    );
    await tester.pump();
    await tester.tap(find.text(TrainingWhy.clearsHead.label));
    await tester.pump();
    await tester.tap(find.text(TrainingWhy.doneQuitting.label));
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(find.text('determined persistence'), findsOneWidget);
    expect(find.text('showing up'), findsNothing);
  });

  testWidgets('goal is ask-only: a pick advances with no reaction', (
    tester,
  ) async {
    await tester.pumpWidget(
      quiz(const [QuizQuestion.goal, QuizQuestion.frequency],
          reducedMotion: true),
    );
    await tester.pump();
    expect(find.text(BitInterviewCopy.ask(QuizQuestion.goal)), findsOneWidget);

    await tester.tap(find.text('GET LEANER'));
    await tester.pumpAndSettle();

    expect(find.text(BitInterviewCopy.ask(QuizQuestion.frequency)),
        findsOneWidget);
    expect(cheering(tester), isFalse);
    expect(find.text('tap to continue ›'), findsNothing);
  });

  testWidgets('frequency reacts; no auto-advance; tap to continue', (
    tester,
  ) async {
    await tester.pumpWidget(
      quiz(const [QuizQuestion.frequency, QuizQuestion.weightSex],
          reducedMotion: true),
    );
    await tester.pump();

    await tester.tap(find.text('4–5 DAYS'));
    await tester.pumpAndSettle();
    // The bracketed reaction renders as rich text (amber [11,700 Reels] /
    // [Breaking Bad series]); match a plain, frequency-specific portion.
    expect(find.textContaining('97.5h'), findsOneWidget);
    // Both bracketed phrases render as separate amber widgets (multi-bracket).
    expect(find.text('11,700 Reels'), findsOneWidget);
    expect(find.text('Breaking Bad series'), findsOneWidget);

    // No auto-advance — it holds.
    await tester.pump(const Duration(seconds: 10));
    expect(find.textContaining('97.5h'), findsOneWidget);

    await tester.tap(find.text('tap to continue ›'));
    await tester.pumpAndSettle();
    expect(find.text(BitInterviewCopy.ask(QuizQuestion.weightSex)),
        findsOneWidget);
  });

  testWidgets('experience: novice amber, others plain', (tester) async {
    await tester.pumpWidget(
      quiz(const [QuizQuestion.experience, QuizQuestion.weightSex],
          reducedMotion: true),
    );
    await tester.pump();

    await tester.tap(find.text('NOVICE'));
    await tester.pumpAndSettle();
    expect(find.text('step up'), findsOneWidget); // amber bracket
    expect(find.text('full potential'), findsOneWidget); // second amber bracket

    await tester.tap(find.byIcon(Icons.chevron_left_sharp));
    await tester.pumpAndSettle();
    await tester.tap(find.text('INTERMEDIATE'));
    await tester.pumpAndSettle();
    expect(
      find.text(BitInterviewCopy.experienceReaction(Experience.intermediate)),
      findsOneWidget,
    );
  });

  testWidgets('obstacle is single-select and reacts', (tester) async {
    await tester.pumpWidget(
      quiz(const [QuizQuestion.obstacle], reducedMotion: true),
    );
    await tester.pump();

    await tester.tap(find.text(Obstacle.boredom.label));
    await tester.pumpAndSettle();
    expect(find.text('the depth of boredom'), findsOneWidget); // amber bracket
    expect(cheering(tester), isTrue);
  });

  testWidgets(
    'last reaction question completes WITHOUT flashing back to the options',
    (tester) async {
      // The final question of each onboarding quiz segment is a reaction
      // question whose continue calls onComplete (which pushReplaces a loader).
      // The loader animates in semi-transparent, so if the page reverts to its
      // ASKING state on the way out, the answered question's options flash
      // through the incoming loader. Completion must keep the reaction up.
      QuizAnswers? completed;
      await tester.pumpWidget(
        quiz(const [QuizQuestion.obstacle],
            reducedMotion: true, onComplete: (a) => completed = a),
      );
      await tester.pump();

      await tester.tap(find.text(Obstacle.boredom.label));
      await tester.pumpAndSettle();
      expect(find.text('tap to continue ›'), findsOneWidget);

      await tester.tap(find.text('tap to continue ›'));
      await tester.pump(); // the frame where the bug would revert to ASKING

      // onComplete fired, and the page did NOT flash back to the options / ask.
      expect(completed, isNotNull);
      expect(find.text(Obstacle.boredom.label), findsNothing);
      expect(find.text(Obstacle.time.label), findsNothing);
      expect(find.text(BitInterviewCopy.ask(QuizQuestion.obstacle)),
          findsNothing);
    },
  );

  testWidgets('back during a reaction returns to the question', (tester) async {
    await tester.pumpWidget(
      quiz(const [QuizQuestion.frequency, QuizQuestion.weightSex],
          reducedMotion: true),
    );
    await tester.pump();

    await tester.tap(find.text('2–3 DAYS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('58.5h'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_sharp));
    await tester.pumpAndSettle();
    expect(find.textContaining('58.5h'), findsNothing);
    expect(find.text(BitInterviewCopy.ask(QuizQuestion.frequency)),
        findsOneWidget);
    expect(cheering(tester), isFalse);
  });

  testWidgets('normal motion TYPES the reaction (not instant), then continues', (
    tester,
  ) async {
    await tester.pumpWidget(
      quiz(const [QuizQuestion.frequency, QuizQuestion.weightSex],
          reducedMotion: false),
    );
    await pumpFrames(tester, 40); // entrance

    await tester.tap(find.text('4–5 DAYS'));
    await tester.pump(const Duration(milliseconds: 320)); // hold → typing starts
    // Mid-type: the frequency-specific portion has not been typed yet.
    expect(find.textContaining('97.5h'), findsNothing);

    await pumpFrames(tester, 70, 60); // ~4.2 s → fully typed
    expect(find.textContaining('97.5h'), findsOneWidget);

    await tester.tap(find.text('tap to continue ›'));
    await pumpFrames(tester, 80, 40); // advance + the ask types in
    expect(find.text(BitInterviewCopy.ask(QuizQuestion.weightSex)),
        findsOneWidget);
  });

  testWidgets('segment B types the intro, then the question', (tester) async {
    await tester.pumpWidget(
      quiz(const [QuizQuestion.experience, QuizQuestion.frequency],
          reducedMotion: false),
    );
    await tester.pump();
    await pumpFrames(tester, 45); // ~900 ms → intro typed, timer not yet fired
    expect(find.text(BitInterviewCopy.segmentBIntro), findsOneWidget);

    await pumpFrames(tester, 130); // intro timer fires + the question types
    expect(find.text(BitInterviewCopy.ask(QuizQuestion.experience)),
        findsOneWidget);
  });

  testWidgets('Back during the 280ms select-hold cancels the commit', (
    tester,
  ) async {
    await tester.pumpWidget(
      quiz(const [QuizQuestion.goal, QuizQuestion.frequency],
          reducedMotion: false),
    );
    await pumpFrames(tester, 40); // entrance

    await tester.tap(find.text('GET LEANER'));
    await tester.pump(const Duration(milliseconds: 80)); // within the 280ms hold
    await tester.tap(find.byIcon(Icons.chevron_left_sharp)); // cancel the commit
    await tester.pump(const Duration(milliseconds: 400)); // the hold would have fired

    // The pending commit was cancelled — still on goal, never advanced.
    expect(find.text(BitInterviewCopy.ask(QuizQuestion.goal)), findsOneWidget);
    expect(find.text(BitInterviewCopy.ask(QuizQuestion.frequency)), findsNothing);
  });
}
