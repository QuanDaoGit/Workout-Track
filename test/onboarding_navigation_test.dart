import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  // Fully settle the prompt typewriter + card wipe-in so option cards paint at
  // their final transform and are hit-testable (a dirty frame leaves the card
  // NEEDS-PAINT and the tap coordinate misses).
  Future<void> settleQuestion(WidgetTester tester) async {
    await tester.pumpAndSettle();
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
            questions: const [QuizQuestion.goal, QuizQuestion.weightSex],
            onComplete: (_) => completions++,
          ),
        ),
      );
      // Let the wipe-in stagger finish so the option cards are hit-testable.
      await settleQuestion(tester);

      // Two taps within the 280 ms select-hold window.
      await tester.tap(optionCard('GET LEANER'));
      await tester.tap(optionCard('GET LEANER'));

      // Resolve the hold. Only the first tap should advance — to weight/sex.
      await tester.pump(const Duration(milliseconds: 300));

      expect(completions, 0, reason: 'onComplete must not fire early');
      // Weight/sex body labels render immediately (the 'DIAL IT IN' prompt is a
      // typewriter that hasn't finished, so assert on the plain body instead).
      expect(find.text('BODYWEIGHT (KG)'), findsOneWidget);
      expect(find.text("WHAT'S THE GOAL?"), findsNothing);
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

      // Advance to weight/sex.
      await tester.tap(optionCard('GET LEANER'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('BODYWEIGHT (KG)'), findsOneWidget);

      // System back should return to the goal question (step--), not exit.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump();

      expect(find.text("WHAT'S THE GOAL?"), findsOneWidget);
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
      await tester.pumpWidget(
        MaterialApp(
          home: CalibrationQuizPage(
            questions: const [
              QuizQuestion.trainingWhy,
              QuizQuestion.winningVision,
            ],
            onComplete: (a) => captured = a,
          ),
        ),
      );
      await settleQuestion(tester);

      // Vow — multi-select: pick the top two (both on-screen), then CONTINUE.
      await tester.tap(optionCard(TrainingWhy.feelAlive.label));
      await tester.pump();
      await tester.tap(optionCard(TrainingWhy.doneQuitting.label));
      await tester.pump();
      await tester.tap(find.text('CONTINUE'));
      await settleQuestion(tester);

      // Vision — pick one, then CONTINUE → onComplete (last question).
      await tester.tap(optionCard(WinningVision.strongCapable.label));
      await tester.pump();
      await tester.tap(find.text('CONTINUE'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(captured, isNotNull);
      expect(captured!.trainingWhy, {
        TrainingWhy.feelAlive,
        TrainingWhy.doneQuitting,
      });
      expect(captured!.winningVision, {WinningVision.strongCapable});
    });
  });
}
