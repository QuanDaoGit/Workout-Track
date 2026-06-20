import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/bit_interview_copy.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/unit_models.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/calibration_quiz_page.dart';
import 'package:workout_track/services/calibration_service.dart';
import 'package:workout_track/services/unit_settings_service.dart';

/// Captures the completed answers / exit so each test can assert against it.
class _QuizObserver {
  QuizAnswers? answers;
  bool exited = false;
  bool resolved = false;
}

/// Pushes the quiz with all four questions (the widget is order-agnostic — the
/// onboarding flow runs it in two segments, but this exercises the mechanics).
Future<_QuizObserver> _openQuiz(
  WidgetTester tester, {
  bool reducedMotion = false,
}) async {
  final observer = _QuizObserver();
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              child: const Text('OPEN QUIZ'),
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CalibrationQuizPage(
                      questions: const [
                        QuizQuestion.goal,
                        QuizQuestion.frequency,
                        QuizQuestion.experience,
                        QuizQuestion.weightSex,
                      ],
                      progressBaseCells: 0, // first segment of the 4-question quiz
                      onComplete: (a) {
                        observer.answers = a;
                        Navigator.of(context).pop();
                      },
                      onExit: () {
                        observer.exited = true;
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                );
                observer.resolved = true;
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('OPEN QUIZ'));
  await tester.pumpAndSettle();
  return observer;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Pin units so the bodyweight assertion is in kg and the height question
    // renders a single (cm) field. The app default is lbs/ft-in.
    Units.weight = WeightUnit.kg;
    Units.height = LengthUnit.cm;
  });

  group('deriveClass', () {
    test('cut -> assassin, recomp -> bruiser, bulk -> tank', () {
      expect(deriveClass(BodyGoal.cut), CharacterClass.assassin);
      expect(deriveClass(BodyGoal.recomp), CharacterClass.bruiser);
      expect(deriveClass(BodyGoal.bulk), CharacterClass.tank);
    });
  });

  group('CalibrationService training prefs', () {
    test('round-trips freq and experience', () async {
      final svc = CalibrationService();
      expect(await svc.trainingFreq(), isNull);
      expect(await svc.experience(), isNull);
      await svc.saveTrainingPreferences(
        freq: TrainingFreq.mid,
        exp: Experience.intermediate,
      );
      expect(await svc.trainingFreq(), TrainingFreq.mid);
      expect(await svc.experience(), Experience.intermediate);
    });
  });

  group('CalibrationQuizPage widget', () {
    testWidgets('reduced motion renders Q1 prompt and option cards', (
      tester,
    ) async {
      await _openQuiz(tester, reducedMotion: true);

      // Goal is now BIT-asked (its line replaces the old neon prompt).
      expect(find.text(BitInterviewCopy.ask(QuizQuestion.goal)), findsOneWidget);
      expect(find.text('GET LEANER'), findsOneWidget);
      expect(find.text('STAY + STRENGTHEN'), findsOneWidget);
      expect(find.text('GET BIGGER'), findsOneWidget);
      // The bar measures the seven quiz questions; this segment's goal is 1 of 7.
      expect(find.text('1/7'), findsOneWidget);
      expect(find.text('0/7'), findsNothing);
    });

    testWidgets('Q1 goal cards keep derived classes hidden', (tester) async {
      await _openQuiz(tester, reducedMotion: true);

      // The class mapping is revealed later in ClassRevealScreen, not Q1.
      expect(find.text('ASSASSIN'), findsNothing);
      expect(find.text('BRUISER'), findsNothing);
      expect(find.text('TANK'), findsNothing);
    });

    testWidgets('Q1 tap advances to Q2', (tester) async {
      await _openQuiz(tester, reducedMotion: true);

      await tester.tap(find.text('GET LEANER'));
      await tester.pumpAndSettle();
      // Goal is ask-only, so it advances straight to Q2 (frequency, BIT-asked).
      expect(find.text(BitInterviewCopy.ask(QuizQuestion.frequency)),
          findsOneWidget);
      expect(find.text('2/7'), findsOneWidget);
    });

    testWidgets('Full happy path returns populated answers', (tester) async {
      final obs = await _openQuiz(tester, reducedMotion: true);

      await tester.tap(find.text('GET BIGGER')); // goal ask-only → frequency
      await tester.pumpAndSettle();
      await tester.tap(find.text('4–5 DAYS')); // frequency → reaction
      await tester.pumpAndSettle();
      await tester.tap(find.text('tap to continue ›')); // → experience
      await tester.pumpAndSettle();
      await tester.tap(find.text('INTERMEDIATE')); // experience → reaction
      await tester.pumpAndSettle();
      await tester.tap(find.text('tap to continue ›')); // → weight/sex
      await tester.pumpAndSettle();
      // Q4 — enter bodyweight, pick sex, CONTINUE. pump(Duration) instead of
      // pumpAndSettle because the TextField cursor blink never settles.
      expect(find.text(BitInterviewCopy.ask(QuizQuestion.weightSex)),
          findsOneWidget);
      // Q4 now has weight + height fields; the first is bodyweight.
      await tester.enterText(find.byType(TextField).first, '78');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.ensureVisible(find.text('Male'));
      await tester.tap(find.text('Male'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.ensureVisible(find.text('CONTINUE'));
      await tester.tap(find.text('CONTINUE'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(obs.resolved, isTrue);
      expect(obs.answers, isNotNull);
      expect(obs.answers!.goal, BodyGoal.bulk);
      expect(deriveClass(obs.answers!.goal!), CharacterClass.tank);
      expect(obs.answers!.freq, TrainingFreq.mid);
      expect(obs.answers!.exp, Experience.intermediate);
      expect(obs.answers!.bodyWeightKg, 78.0);
      expect(obs.answers!.sex, UserProfileSex.male);
    });

    testWidgets(
      'Q4 CONTINUE with empty bodyweight continues with null weight',
      (tester) async {
        final obs = await _openQuiz(tester, reducedMotion: true);

        await tester.tap(find.text('GET LEANER')); // goal ask-only → frequency
        await tester.pumpAndSettle();
        await tester.tap(find.text('2–3 DAYS')); // frequency → reaction
        await tester.pumpAndSettle();
        await tester.tap(find.text('tap to continue ›')); // → experience
        await tester.pumpAndSettle();
        await tester.tap(find.text('NOVICE')); // experience → reaction
        await tester.pumpAndSettle();
        await tester.tap(find.text('tap to continue ›')); // → weight/sex
        await tester.pumpAndSettle();

        // Q4's longer layout (unit toggles + height) pushes CONTINUE near the
        // fold — scroll it well into view before tapping.
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CONTINUE'));
        await tester.pump(const Duration(milliseconds: 400));

        expect(obs.resolved, isTrue);
        expect(obs.answers!.bodyWeightKg, isNull);
        expect(obs.answers!.sex, UserProfileSex.preferNotToSay);
        expect(obs.answers!.goal, BodyGoal.cut);
        expect(deriveClass(obs.answers!.goal!), CharacterClass.assassin);
      },
    );

    testWidgets('Back from Q1 fires onExit', (tester) async {
      final obs = await _openQuiz(tester, reducedMotion: true);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      expect(obs.exited, isTrue);
      expect(obs.answers, isNull);
    });

    testWidgets('Back from Q2 returns to Q1 with selection restored', (
      tester,
    ) async {
      await _openQuiz(tester, reducedMotion: true);

      await tester.tap(find.text('GET LEANER')); // goal ask-only → frequency
      await tester.pumpAndSettle();
      expect(find.text(BitInterviewCopy.ask(QuizQuestion.frequency)),
          findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      expect(find.text(BitInterviewCopy.ask(QuizQuestion.goal)), findsOneWidget);
      expect(find.text('GET LEANER'), findsOneWidget);
    });

    testWidgets('returning to a question shows its prompt instantly', (
      tester,
    ) async {
      // Reduced motion freezes BIT's idle ticker, so pumpAndSettle is safe and
      // the return is deterministically instant.
      await _openQuiz(tester, reducedMotion: true);

      await tester.tap(find.text('GET LEANER')); // goal ask-only → frequency
      await tester.pumpAndSettle();
      expect(find.text(BitInterviewCopy.ask(QuizQuestion.frequency)),
          findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pump();
      expect(find.text(BitInterviewCopy.ask(QuizQuestion.goal)), findsOneWidget);
    });
  });
}
