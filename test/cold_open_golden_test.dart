import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/pages/onboarding/cold_open_page.dart';

/// Rendered-artifact proof of the cold open's **settled (awake)** composition —
/// IRONBIT / BIT / voice waveform / WELCOME, WARRIOR / sub-line / PRESS START —
/// to verify the vertical rhythm (breathing room, no overlap). The real fonts
/// are loaded so text metrics match the device; reduced motion snaps the wake to
/// settled on the first tap. 390×844 design frame (1:1). Regenerate with
/// `flutter test --update-goldens`.
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

  testWidgets('cold open — settled (reduced motion)', (tester) async {
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
          child: Scaffold(body: ColdOpenView(onContinue: () {})),
        ),
      ),
    );
    await tester.pump();
    // Tap to wake — under reduced motion this snaps the boot straight to settled.
    await tester.tap(find.byType(ColdOpenView));
    await tester.pump();

    await expectLater(
      find.byType(ColdOpenView),
      matchesGoldenFile('goldens/cold_open_settled.png'),
    );
  });
}
