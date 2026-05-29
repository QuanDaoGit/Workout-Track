import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/avatar_select_screen.dart';
import 'package:workout_track/pages/onboarding/calibration_quiz_page.dart';
import 'package:workout_track/pages/onboarding/class_reveal_screen.dart';
import 'package:workout_track/services/body_goal_service.dart';
import 'package:workout_track/services/calibration_service.dart';
import 'package:workout_track/services/class_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ClassRevealScreen', () {
    for (final result in [_assassinResult, _bruiserResult, _tankResult]) {
      testWidgets('reduced motion shows final ${result.clazz.name} reveal', (
        tester,
      ) async {
        await _pumpReveal(tester, result: result, reducedMotion: true);

        expect(find.text('ANALYZING RECRUIT'), findsOneWidget);
        expect(
          find.text('PATH OF THE ${_pathLabel(result.goal)}'),
          findsOneWidget,
        );
        expect(
          find.textContaining('goal ${_goalEchoLabel(result.goal)}'),
          findsOneWidget,
        );
        expect(find.text(result.clazz.displayName), findsOneWidget);
        expect(find.text(_focusTag(result.clazz)), findsOneWidget);
        expect(find.text(_buttonLabel(result.clazz)), findsOneWidget);
      });
    }

    testWidgets('body tap during cinematic jumps to sustained reveal', (
      tester,
    ) async {
      await _pumpReveal(tester, result: _assassinResult);
      await tester.tap(find.byType(ClassRevealScreen));
      await tester.pump();

      expect(find.text('I AM ASSASSIN'), findsOneWidget);
      expect(find.text('speed. precision. low body fat.'), findsOneWidget);
    });

    testWidgets('path waits for bodyweight echo to finish typing', (
      tester,
    ) async {
      await _pumpReveal(tester, result: _bruiserResult);

      await tester.pump(const Duration(milliseconds: 1700));

      expect(find.textContaining('goal recomp'), findsOneWidget);
      expect(find.text('PATH OF THE RECOMP'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1800));

      expect(find.text('PATH OF THE RECOMP'), findsOneWidget);
    });

    testWidgets('path waits for single-line echo when bodyweight is omitted', (
      tester,
    ) async {
      await _pumpReveal(
        tester,
        result: const CalibrationResult(
          goal: BodyGoal.recomp,
          freq: TrainingFreq.low,
          exp: Experience.novice,
          bodyWeightKg: null,
          sex: UserProfileSex.preferNotToSay,
          clazz: CharacterClass.bruiser,
        ),
      );

      await tester.pump(const Duration(milliseconds: 1700));

      expect(find.textContaining('goal recomp'), findsOneWidget);
      expect(find.text('PATH OF THE RECOMP'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text('PATH OF THE RECOMP'), findsOneWidget);
    });

    testWidgets('back pops reveal without confirming class', (tester) async {
      var confirmed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => _ReducedMotion(
                      child: ClassRevealScreen(
                        result: _assassinResult,
                        onClassConfirmed: (_, _) async => confirmed = true,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('OPEN'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left_sharp));
      await tester.pumpAndSettle();

      expect(find.text('OPEN'), findsOneWidget);
      expect(confirmed, isFalse);
    });

    testWidgets('commit confirms once and pushes avatar picker', (
      tester,
    ) async {
      var confirmed = 0;
      DateTime? stampedAt;
      await _pumpReveal(
        tester,
        result: _assassinResult,
        reducedMotion: true,
        onClassConfirmed: (_, classConfirmedAt) async {
          confirmed++;
          stampedAt = classConfirmedAt;
        },
      );

      await tester.tap(find.text('I AM ASSASSIN'));
      await tester.pumpAndSettle();

      expect(confirmed, 1);
      expect(stampedAt, isNotNull);
      expect(find.byType(AvatarSelectScreen), findsOneWidget);
      expect(find.text('CHOOSE YOUR FACE'), findsOneWidget);
    });

    testWidgets('null bodyweight omits the weight line', (tester) async {
      await _pumpReveal(
        tester,
        result: const CalibrationResult(
          goal: BodyGoal.recomp,
          freq: TrainingFreq.low,
          exp: Experience.novice,
          bodyWeightKg: null,
          sex: UserProfileSex.preferNotToSay,
          clazz: CharacterClass.bruiser,
        ),
        reducedMotion: true,
      );

      expect(find.textContaining('weight'), findsNothing);
      expect(find.textContaining('goal recomp'), findsOneWidget);
    });

    testWidgets('commit persists quiz result and class confirmation time', (
      tester,
    ) async {
      DateTime? persistedAt;
      await _pumpReveal(
        tester,
        result: _tankResult,
        reducedMotion: true,
        onClassConfirmed: (result, classConfirmedAt) async {
          persistedAt = classConfirmedAt;
          await _persistLikeOnboarding(result, classConfirmedAt);
        },
      );

      await tester.tap(find.text('I AM TANK'));
      // ClassService snapshots current workout volume, which loads the
      // exercise catalog through the test asset bundle. Let that real async IO
      // complete before waiting for the route push.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await _pumpUntilFound(tester, find.byType(AvatarSelectScreen));

      expect((await BodyGoalService().getGoalState())!.goal, BodyGoal.bulk);
      expect(await ClassService().getCurrentClass(), CharacterClass.tank);
      expect(await CalibrationService().trainingFreq(), TrainingFreq.high);
      expect(await CalibrationService().experience(), Experience.advanced);
      expect(await CalibrationService().bodyweightKg(), 90);
      expect(await CalibrationService().classConfirmedAt(), persistedAt);
    });

    testWidgets('avatar preview selection is restored after backing out', (
      tester,
    ) async {
      await _pumpReveal(tester, result: _assassinResult, reducedMotion: true);

      await tester.tap(find.text('I AM ASSASSIN'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Avatar 5 of eight'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left_sharp));
      await tester.pumpAndSettle();

      expect(find.text('I AM ASSASSIN'), findsOneWidget);

      await tester.tap(find.text('I AM ASSASSIN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('THIS IS ME'));
      await tester.pumpAndSettle();

      expect(find.text('NAME YOUR CHARACTER'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Nova');
      await tester.pump();
      await tester.tap(find.text('I AM NOVA'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('selectedAvatarId: avatar_05'),
        findsOneWidget,
      );
    });
  });

  testWidgets(
    'quiz completion pushes reveal over Q4 so back restores answers',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              _ReducedMotion(child: child ?? const SizedBox.shrink()),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (quizContext) => CalibrationQuizPage(
                      onResult: (result) async {
                        await Navigator.of(quizContext).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ClassRevealScreen(
                              result: result,
                              onClassConfirmed: (_, _) async {},
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              child: const Text('OPEN QUIZ'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN QUIZ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GET BIGGER'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('6+ DAYS'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('ADVANCED'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), '90');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.byType(ClassRevealScreen), findsOneWidget);
      expect(find.text('I AM TANK'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left_sharp));
      await tester.pumpAndSettle();

      expect(find.text('CALIBRATE'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
    },
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

Future<void> _pumpReveal(
  WidgetTester tester, {
  required CalibrationResult result,
  bool reducedMotion = false,
  ClassConfirmedCallback? onClassConfirmed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: _ReducedMotion(
        enabled: reducedMotion,
        child: ClassRevealScreen(
          result: result,
          onClassConfirmed: onClassConfirmed ?? (_, _) async {},
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _persistLikeOnboarding(
  CalibrationResult result,
  DateTime classConfirmedAt,
) async {
  await BodyGoalService().setGoal(result.goal);
  await ClassService().selectClass(result.clazz);
  await CalibrationService().saveCalibrationInputs(
    bodyweightKg: result.bodyWeightKg,
    sex: result.sex,
  );
  await CalibrationService().saveTrainingPreferences(
    freq: result.freq,
    exp: result.exp,
  );
  await CalibrationService().markClassConfirmed(at: classConfirmedAt);
}

class _ReducedMotion extends StatelessWidget {
  const _ReducedMotion({required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: enabled),
      child: child,
    );
  }
}

String _pathLabel(BodyGoal goal) => switch (goal) {
  BodyGoal.cut => 'CUT',
  BodyGoal.recomp => 'RECOMP',
  BodyGoal.bulk => 'BULK',
};

String _goalEchoLabel(BodyGoal goal) => switch (goal) {
  BodyGoal.cut => 'leaner',
  BodyGoal.recomp => 'recomp',
  BodyGoal.bulk => 'bigger',
};

String _focusTag(CharacterClass cls) => switch (cls) {
  CharacterClass.assassin => 'SHOULDERS + CORE',
  CharacterClass.bruiser => 'CHEST + BACK + ARMS',
  CharacterClass.tank => 'LEGS',
  CharacterClass.vanguard => 'ALL-ROUND',
};

String _buttonLabel(CharacterClass cls) => 'I AM ${cls.displayName}';

const _assassinResult = CalibrationResult(
  goal: BodyGoal.cut,
  freq: TrainingFreq.mid,
  exp: Experience.beginner,
  bodyWeightKg: 72,
  sex: UserProfileSex.preferNotToSay,
  clazz: CharacterClass.assassin,
);

const _bruiserResult = CalibrationResult(
  goal: BodyGoal.recomp,
  freq: TrainingFreq.low,
  exp: Experience.novice,
  bodyWeightKg: 80,
  sex: UserProfileSex.preferNotToSay,
  clazz: CharacterClass.bruiser,
);

const _tankResult = CalibrationResult(
  goal: BodyGoal.bulk,
  freq: TrainingFreq.high,
  exp: Experience.advanced,
  bodyWeightKg: 90,
  sex: UserProfileSex.male,
  clazz: CharacterClass.tank,
);
