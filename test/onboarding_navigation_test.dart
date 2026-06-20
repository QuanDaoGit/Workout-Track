import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/bit_interview_copy.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/resolve_models.dart';
import 'package:workout_track/models/unit_models.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/calibration_loading_page.dart';
import 'package:workout_track/pages/onboarding/calibration_quiz_page.dart';
import 'package:workout_track/pages/onboarding/class_reveal_screen.dart';
import 'package:workout_track/pages/onboarding/program_loading_page.dart';
import 'package:workout_track/services/unit_settings_service.dart';
import 'package:workout_track/widgets/motion/hold_depress.dart';

/// Covers the onboarding navigation hardening:
/// - system-back (`PopScope`) guards on the unskippable loaders + one-way reveal
/// - the quiz double-tap re-entrancy guard (a fast double-tap must not skip a
///   question or fire onComplete early)
/// - system back inside the quiz steps back instead of popping the route
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The bodyweight label is unit-dependent (app default is lbs); pin kg so the
  // 'BODYWEIGHT (KG)' assertions hold.
  setUp(() {
    Units.weight = WeightUnit.kg;
    Units.height = LengthUnit.cm;
  });

  const preClass = PreClassAnswers(
    goal: BodyGoal.cut,
    bodyWeightKg: 75,
    sex: UserProfileSex.preferNotToSay,
  );

  const recompResult = CalibrationResult(
    goal: BodyGoal.recomp,
    freq: TrainingFreq.mid,
    exp: Experience.beginner,
    bodyWeightKg: 80,
    sex: UserProfileSex.preferNotToSay,
    clazz: CharacterClass.bruiser,
  );

  bool topPopScopeBlocks(WidgetTester tester) {
    // The screen's own guard is the first PopScope under its Scaffold subtree.
    final scope = tester.widgetList<PopScope>(find.byType(PopScope)).first;
    return scope.canPop == false;
  }

  // Tap the opaque card (HoldDepress) wrapping an option label — reliably
  // hit-testable, unlike the Text nested in clip/transform wrappers.
  Finder optionCard(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(HoldDepress));

  // Settle the prompt typewriter + card wipe-in so option cards are hit-testable.
  // BIT's idle is a perpetual ticker on the BIT-asked questions, so pumpAndSettle
  // would never return under normal motion — pump a bounded run of frames instead
  // (a single large pump leaves the card needing paint and the tap misses).
  Future<void> settleQuestion(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  group('system-back guards (PopScope canPop:false)', () {
    testWidgets('calibration loader blocks system back', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CalibrationLoadingPage(
            answers: preClass,
            onCalibrated: (_) async {},
            onReveal: (_) {},
          ),
        ),
      );
      expect(topPopScopeBlocks(tester), isTrue);
    });

    testWidgets('program loader blocks system back', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProgramLoadingPage(result: recompResult, onComplete: () {}),
        ),
      );
      expect(topPopScopeBlocks(tester), isTrue);
    });

    testWidgets('class reveal blocks system back', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ClassRevealScreen(answers: preClass, onConfirmed: () {}),
        ),
      );
      expect(topPopScopeBlocks(tester), isTrue);
    });
  });

  group('CalibrationQuizPage re-entrancy + back', () {
    testWidgets('fast double-tap does not skip the next question', (
      tester,
    ) async {
      var completions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CalibrationQuizPage(
            questions: const [QuizQuestion.frequency, QuizQuestion.weightSex],
            onComplete: (_) => completions++,
          ),
        ),
      );
      // Let the wipe-in stagger finish so the option cards are hit-testable.
      await settleQuestion(tester);

      // Two taps within the 280 ms select-hold window.
      await tester.tap(optionCard('4–5 DAYS'));
      await tester.tap(optionCard('4–5 DAYS'));

      // Resolve the hold. The guard means a single commit → BIT reacts once
      // (not double-fired, not skipped past), and onComplete has not fired.
      await tester.pump(const Duration(milliseconds: 300));

      expect(completions, 0, reason: 'onComplete must not fire early');
      // A single commit → BIT is reacting (the options are replaced by the
      // promise), and it has not advanced past the question into weight/sex.
      expect(find.text('4–5 DAYS'), findsNothing);
      expect(find.text('BODYWEIGHT (KG)'), findsNothing);
    });

    testWidgets('system back steps to the previous question, not a route pop', (
      tester,
    ) async {
      var exits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CalibrationQuizPage(
            questions: const [QuizQuestion.goal, QuizQuestion.weightSex],
            onExit: () => exits++,
            onComplete: (_) {},
          ),
        ),
      );
      await settleQuestion(tester);

      // Advance to weight/sex (goal is ask-only, so a pick advances directly).
      await tester.tap(optionCard('GET LEANER'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('BODYWEIGHT (KG)'), findsOneWidget);

      // System back should return to the goal question (step--), not exit.
      await tester.binding.handlePopRoute();
      await settleQuestion(tester); // BIT re-types the goal ask on back

      expect(find.text(BitInterviewCopy.ask(QuizQuestion.goal)), findsOneWidget);
      expect(exits, 0);
    });

    testWidgets('system back at first step with onExit calls onExit', (
      tester,
    ) async {
      var exits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CalibrationQuizPage(
            questions: const [QuizQuestion.goal, QuizQuestion.weightSex],
            onExit: () => exits++,
            onComplete: (_) {},
          ),
        ),
      );
      await settleQuestion(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(exits, 1);
    });
  });

  group('CalibrationQuizPage interleaved identity beats', () {
    testWidgets('captures multi-select vow and vision into the answers', (
      tester,
    ) async {
      QuizAnswers? captured;
      // Reduced motion freezes BIT's idle ticker (so pumpAndSettle is safe) and
      // types the reactions instantly — this test is about answer capture, not
      // the typewriter, so the deterministic path keeps it focused.
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: CalibrationQuizPage(
              questions: const [
                QuizQuestion.trainingWhy,
                QuizQuestion.winningVision,
              ],
              onComplete: (a) => captured = a,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Vow — multi-select: pick the top two (both on-screen), then CONTINUE.
      await tester.tap(optionCard(TrainingWhy.feelAlive.label));
      await tester.pump();
      await tester.tap(optionCard(TrainingWhy.doneQuitting.label));
      await tester.pump();
      await tester.tap(find.text('CONTINUE')); // confirm the vow set
      await tester.pumpAndSettle();
      // Vow reacts now — tap to continue past BIT's promise to reach vision.
      await tester.tap(find.text('tap to continue ›'));
      await tester.pumpAndSettle();

      // Vision — pick one, CONTINUE → BIT reacts, then tap to continue → done.
      await tester.tap(optionCard(WinningVision.strongCapable.label));
      await tester.pump();
      await tester.tap(find.text('CONTINUE')); // confirm the vision set
      await tester.pumpAndSettle();
      await tester.tap(find.text('tap to continue ›'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.trainingWhy, {
        TrainingWhy.feelAlive,
        TrainingWhy.doneQuitting,
      });
      expect(captured!.winningVision, {WinningVision.strongCapable});
    });
  });
}
