import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/companion/bit_mood_core.dart';
import 'package:workout_track/widgets/companion/bit_speech_bubble.dart';

/// Rendered-artifact proof for (a) the speech bubble's new configurable tail
/// (left / right / none — the shared-primitive generalization) and (b) BIT's
/// quest-board briefing (a small, faced, idle-damped core + his state line).
/// Both are deterministic under reduced motion (BIT's idle clock is frozen).
/// The breathing idle + the on-claim cheer are motion the goldens can't capture
/// — those stay an on-device check. Regenerate with `flutter test --update-goldens`.
void main() {
  setUpAll(() async {
    Future<ByteData> font(String path) async =>
        ByteData.view((await File(path).readAsBytes()).buffer);
    await (FontLoader('ShareTechMono')
          ..addFont(font('fonts/sharetechmono/ShareTechMono-Regular.ttf')))
        .load();
  });

  Future<void> shot(
    WidgetTester tester,
    Widget child,
    String file, {
    double width = 360,
  }) async {
    tester.view.physicalSize = const Size(520, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey('shot'),
                child: Container(
                  width: width,
                  color: kBg,
                  padding: const EdgeInsets.all(16),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('shot')),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('speech-bubble tail variants', (tester) async {
    await shot(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          BitSpeechBubble(text: 'Tail points left (BIT sits left).'),
          SizedBox(height: 16),
          BitSpeechBubble(
            text: 'Tail points right (BIT sits right).',
            tailDirection: BitTailDirection.right,
          ),
          SizedBox(height: 16),
          BitSpeechBubble(
            text: 'No tail (a plain caption).',
            tailDirection: BitTailDirection.none,
          ),
        ],
      ),
      'bit_bubble_tails.png',
    );
  });

  testWidgets('quest briefing — faced BIT + state line', (tester) async {
    await shot(
      tester,
      Row(
        children: const [
          BitMoodCore(
            pose: BitPose.neutral,
            size: 44,
            reveal: 1,
            idleAmp: 0.55,
          ),
          SizedBox(width: 4),
          Expanded(child: BitSpeechBubble(text: '3 rewards ready to claim.')),
        ],
      ),
      'bit_quest_briefing.png',
    );
  });
}
