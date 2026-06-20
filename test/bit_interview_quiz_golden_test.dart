import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/resolve_models.dart';
import 'package:workout_track/pages/onboarding/calibration_quiz_page.dart';

/// Rendered-artifact proof of the BIT interview — ASKING (BIT's sprite + ask line
/// carry the question) and REACTING (the line morphs to the promise, the
/// `[bracketed]` phrase rendered in amber; BIT swings to cheer). Reduced motion
/// makes both states static (the cheer cross-fade + the bracket shake are
/// frozen). NOTE: the bundled BIT sprite can't load in the test bundle, so the
/// painted fallback shows — the cheer *pose* is an on-device check; the layout +
/// the amber emphasis are what these prove. Regenerate with --update-goldens.
void main() {
  setUpAll(() async {
    Future<ByteData> font(String path) async =>
        ByteData.view((await File(path).readAsBytes()).buffer);
    await (FontLoader('ShareTechMono')
          ..addFont(font('fonts/sharetechmono/ShareTechMono-Regular.ttf')))
        .load();
    await (FontLoader('PressStart2P')
          ..addFont(font('fonts/pressstart2p/PressStart2P-Regular.ttf')))
        .load();
  });

  testWidgets('BIT interview — obstacle ASKING then REACTING', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: CalibrationQuizPage(
              questions: const [QuizQuestion.obstacle, QuizQuestion.goal],
              onExit: () {},
              onComplete: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(CalibrationQuizPage),
      matchesGoldenFile('goldens/bit_interview_obstacle_asking.png'),
    );

    // A single tap commits + BIT reacts in cheer (reduced motion = instant).
    await tester.tap(find.text(Obstacle.boredom.label));
    await tester.pump(); // reaction enters; BIT types (instant under reduced motion)
    await tester.pump(); // typed-complete post-frame flips on the continue hint
    await tester.pump(const Duration(milliseconds: 250)); // the hint fades in

    await expectLater(
      find.byType(CalibrationQuizPage),
      matchesGoldenFile('goldens/bit_interview_obstacle_reacting.png'),
    );
  });

  // The frequency reaction is the longest line and carries TWO amber brackets
  // ([11,700 Reels] + [Breaking Bad series]) — proves multi-bracket emphasis
  // wraps and renders without layout artifacts.
  testWidgets('BIT interview — frequency REACTING (two amber brackets)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: CalibrationQuizPage(
              questions: const [QuizQuestion.frequency, QuizQuestion.weightSex],
              onExit: () {},
              onComplete: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('4–5 DAYS')); // mid frequency
    await tester.pump(); // reaction enters; types instant under reduced motion
    await tester.pump(); // typed-complete post-frame flips on the continue hint
    await tester.pump(const Duration(milliseconds: 250)); // the hint fades in

    await expectLater(
      find.byType(CalibrationQuizPage),
      matchesGoldenFile('goldens/bit_interview_frequency_reacting.png'),
    );
  });
}
