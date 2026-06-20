import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/pages/onboarding/problem_question_page.dart';

/// Rendered-artifact proof of the BIT-led problem screen's settled composition
/// (BIT in rest + the optimistic opener + the mid-sentence "..." + the turn +
/// sympathy + footer). The real ShareTechMono is loaded so text metrics/wrapping
/// match the device. Reduced motion snaps to the end state. Rendered at the
/// 390×844 design frame (1:1). Regenerate with `flutter test --update-goldens`.
void main() {
  setUpAll(() async {
    final loader = FontLoader('ShareTechMono')
      ..addFont(
        File(
          'fonts/sharetechmono/ShareTechMono-Regular.ttf',
        ).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    await loader.load();
  });

  testWidgets('problem screen — settled (reduced motion)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: ProblemQuestionView(onContinue: (_) {})),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(ProblemQuestionView),
      matchesGoldenFile('goldens/problem_screen_settled.png'),
    );
  });
}
