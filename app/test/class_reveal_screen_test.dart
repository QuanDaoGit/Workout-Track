import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/class_reveal_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClassRevealScreen', () {
    for (final answers in [_assassin, _bruiser, _tank]) {
      testWidgets('reduced motion shows final ${answers.clazz.name} reveal', (
        tester,
      ) async {
        await _pumpReveal(tester, answers: answers, reducedMotion: true);

        // The analysis/calibration lives on CalibrationLoadingPage — this is a
        // pure reveal, and frequency/experience aren't known yet (asked after).
        expect(find.text('ANALYZING RECRUIT'), findsNothing);
        expect(find.text(answers.clazz.displayName), findsOneWidget);
        expect(find.text(_focusTag(answers.clazz)), findsOneWidget);
        expect(find.text('I AM ${answers.clazz.displayName}'), findsOneWidget);
        expect(_sigilAssetFinder(answers.clazz), findsOneWidget);
      });
    }

    testWidgets('body tap during cinematic jumps to sustained reveal', (
      tester,
    ) async {
      await _pumpReveal(tester, answers: _assassin);
      await tester.tap(find.byType(ClassRevealScreen));
      await tester.pump();

      expect(find.text('I AM ASSASSIN'), findsOneWidget);
      expect(find.text('speed. precision. low body fat.'), findsOneWidget);
    });

    testWidgets('class name is shown in the class identity color', (
      tester,
    ) async {
      await _pumpReveal(tester, answers: _bruiser);
      await tester.pump(const Duration(milliseconds: 1600));

      expect(find.text('BRUISER'), findsOneWidget);
      expect(_textColor(tester, 'BRUISER'), CharacterClass.bruiser.themeColor);
    });

    testWidgets('reduced motion final class name remains identity colored', (
      tester,
    ) async {
      await _pumpReveal(tester, answers: _assassin, reducedMotion: true);

      expect(find.text('ASSASSIN'), findsOneWidget);
      expect(
        _textColor(tester, 'ASSASSIN'),
        CharacterClass.assassin.themeColor,
      );
    });

    testWidgets('commit fires onConfirmed exactly once', (tester) async {
      var confirmed = 0;
      await _pumpReveal(
        tester,
        answers: _assassin,
        reducedMotion: true,
        onConfirmed: () => confirmed++,
      );

      await tester.tap(find.text('I AM ASSASSIN'));
      await tester.pump();
      expect(confirmed, 1);

      // The committed guard prevents a double-fire.
      await tester.tap(find.text('I AM ASSASSIN'));
      await tester.pump();
      expect(confirmed, 1);
    });

    testWidgets('null bodyweight reveal still renders the class', (
      tester,
    ) async {
      await _pumpReveal(
        tester,
        answers: const PreClassAnswers(
          goal: BodyGoal.recomp,
          bodyWeightKg: null,
          sex: UserProfileSex.preferNotToSay,
        ),
        reducedMotion: true,
      );

      expect(find.text('BRUISER'), findsOneWidget);
    });
  });
}

Future<void> _pumpReveal(
  WidgetTester tester, {
  required PreClassAnswers answers,
  bool reducedMotion = false,
  VoidCallback? onConfirmed,
}) async {
  Widget home = ClassRevealScreen(
    answers: answers,
    onConfirmed: onConfirmed ?? () {},
  );
  if (reducedMotion) {
    home = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: home,
    );
  }
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pump();
}

String _focusTag(CharacterClass cls) => switch (cls) {
  CharacterClass.assassin => 'SHOULDERS + CORE',
  CharacterClass.bruiser => 'CHEST + BACK + ARMS',
  CharacterClass.tank => 'WEIGHT AND STRENGTH',
};

Color? _textColor(WidgetTester tester, String text) {
  final widget = tester.widget<Text>(find.text(text));
  return widget.style?.color;
}

Finder _sigilAssetFinder(CharacterClass cls) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Image) return false;
    final image = widget.image;
    return image is AssetImage &&
        image.assetName == 'assets/classes/sigils/${cls.name}.png';
  });
}

const _assassin = PreClassAnswers(
  goal: BodyGoal.cut,
  bodyWeightKg: 72,
  sex: UserProfileSex.preferNotToSay,
);

const _bruiser = PreClassAnswers(
  goal: BodyGoal.recomp,
  bodyWeightKg: 80,
  sex: UserProfileSex.preferNotToSay,
);

const _tank = PreClassAnswers(
  goal: BodyGoal.bulk,
  bodyWeightKg: 90,
  sex: UserProfileSex.male,
);
