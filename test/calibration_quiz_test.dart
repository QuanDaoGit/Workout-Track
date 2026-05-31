import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/calibration_quiz_page.dart';
import 'package:workout_track/services/calibration_service.dart';

/// Captures the popped result so each test can assert against it.
class _QuizObserver {
  CalibrationResult? popped;
  bool resolved = false;
}

/// Wraps the quiz inside a MaterialApp that uses [MaterialApp.builder] to
/// install a [MediaQuery] override — this is required because pushed routes
/// are siblings of `home` under the navigator, so anything wrapped inside
/// `home` would not propagate to the pushed quiz route.
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
                observer.popped = await Navigator.of(context)
                    .push<CalibrationResult>(
                      MaterialPageRoute(
                        builder: (_) => const CalibrationQuizPage(),
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

  setUp(() => SharedPreferences.setMockInitialValues({}));

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

      expect(find.text("WHAT'S THE GOAL?"), findsOneWidget);
      expect(find.text('GET LEANER'), findsOneWidget);
      expect(find.text('STAY + STRENGTHEN'), findsOneWidget);
      expect(find.text('GET BIGGER'), findsOneWidget);
      // Borrowed head start: cell 1 from the intro, so Q1 is 2 of 5.
      expect(find.text('2/5'), findsOneWidget);
      expect(find.text('1/5'), findsNothing);
    });

    testWidgets('Q1 goal cards keep derived classes hidden', (tester) async {
      await _openQuiz(tester, reducedMotion: true);

      // The class mapping is revealed later in ClassRevealScreen, not Q1.
      expect(find.text('ASSASSIN'), findsNothing);
      expect(find.text('BRUISER'), findsNothing);
      expect(find.text('TANK'), findsNothing);
      // And the prompt now tells the user this choice matters.
      expect(find.text('this sets your class.'), findsOneWidget);
    });

    testWidgets('Q1 tap advances to Q2', (tester) async {
      await _openQuiz(tester, reducedMotion: true);

      await tester.tap(find.text('GET LEANER'));
      await tester.pumpAndSettle();

      expect(find.text('HOW OFTEN?'), findsOneWidget);
      expect(find.text('3/5'), findsOneWidget);
    });

    testWidgets('Full happy path returns a populated CalibrationResult', (
      tester,
    ) async {
      final obs = await _openQuiz(tester, reducedMotion: true);

      // Q1
      await tester.tap(find.text('GET BIGGER'));
      await tester.pumpAndSettle();
      // Q2
      await tester.tap(find.text('4–5 DAYS'));
      await tester.pumpAndSettle();
      // Q3
      await tester.tap(find.text('INTERMEDIATE'));
      await tester.pumpAndSettle();
      // Q4 — enter bodyweight, pick sex, CONTINUE.
      // pump(Duration) instead of pumpAndSettle past this point because
      // TextField focus starts the cursor blink, which keeps pumpAndSettle
      // spinning indefinitely.
      expect(find.text('DIAL IT IN'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '78');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Male'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('CONTINUE'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(obs.resolved, isTrue);
      expect(obs.popped, isNotNull);
      expect(obs.popped!.goal, BodyGoal.bulk);
      expect(obs.popped!.clazz, CharacterClass.tank);
      expect(obs.popped!.freq, TrainingFreq.mid);
      expect(obs.popped!.exp, Experience.intermediate);
      expect(obs.popped!.bodyWeightKg, 78.0);
      expect(obs.popped!.sex, UserProfileSex.male);
    });

    testWidgets(
      'Q4 CONTINUE with empty bodyweight continues with null weight',
      (tester) async {
        final obs = await _openQuiz(tester, reducedMotion: true);

        await tester.tap(find.text('GET LEANER'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2–3 DAYS'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('NOVICE'));
        await tester.pumpAndSettle();

        // CONTINUE is always enabled now. Empty field => continue with null
        // bodyweight and the default sex. pump(Duration) instead of
        // pumpAndSettle because the TextField cursor blink never settles.
        await tester.tap(find.text('CONTINUE'));
        await tester.pump(const Duration(milliseconds: 400));

        expect(obs.resolved, isTrue);
        expect(obs.popped!.bodyWeightKg, isNull);
        expect(obs.popped!.sex, UserProfileSex.preferNotToSay);
        expect(obs.popped!.goal, BodyGoal.cut);
        expect(obs.popped!.clazz, CharacterClass.assassin);
      },
    );

    testWidgets('Back from Q1 pops with null', (tester) async {
      final obs = await _openQuiz(tester, reducedMotion: true);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      expect(obs.resolved, isTrue);
      expect(obs.popped, isNull);
    });

    testWidgets('Back from Q2 returns to Q1', (tester) async {
      await _openQuiz(tester, reducedMotion: true);

      await tester.tap(find.text('GET LEANER'));
      await tester.pumpAndSettle();
      expect(find.text('HOW OFTEN?'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      expect(find.text("WHAT'S THE GOAL?"), findsOneWidget);
      // The previously-selected card is rendered; the surrounding dimmed
      // siblings prove the "selected" state was restored.
      expect(find.text('GET LEANER'), findsOneWidget);
    });

    testWidgets('returning to a question shows its prompt instantly', (
      tester,
    ) async {
      // Animations ON (reducedMotion defaults to false).
      await _openQuiz(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('GET LEANER'));
      // The auto-advance hold is a bare Future.delayed; pumpAndSettle alone
      // won't flush it (nothing schedules frames during the wait), so drive
      // the clock past the hold before settling the Q2 entrance animation.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('HOW OFTEN?'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      // Single frame only — if the prompt re-typed, one frame would show a
      // partial string and this exact-text match would fail.
      await tester.pump();
      expect(find.text("WHAT'S THE GOAL?"), findsOneWidget);
    });
  });
}
