import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/companion/bit_mood_core.dart';

/// Rendered-artifact proof for BIT's faceless mood poses (the web preview can't
/// screenshot here). Each pose is deterministic under reduced motion (frozen
/// idle clock, snapped to target). Regenerate with
/// `flutter test --update-goldens`.
void main() {
  Future<void> shot(WidgetTester tester, BitPose pose, String file) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            backgroundColor: kBg,
            body: Center(child: BitMoodCore(pose: pose, size: 264)),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(BitMoodCore),
      matchesGoldenFile('goldens/$file'),
    );
  }

  Future<void> shotReveal(
    WidgetTester tester,
    double reveal,
    String file, {
    BitPose pose = BitPose.neutral,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: BitMoodCore(pose: pose, size: 264, reveal: reveal),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(BitMoodCore),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('CHEER — lifted + bright', (t) => shot(t, BitPose.cheer, 'bit_mood_cheer.png'));
  testWidgets('NEUTRAL — level + steady', (t) => shot(t, BitPose.neutral, 'bit_mood_neutral.png'));
  testWidgets('REST — slumped + dim', (t) => shot(t, BitPose.rest, 'bit_mood_rest.png'));

  // Face reveal: dot → eyes opening → full face (the screen-3 beat).
  testWidgets('REVEAL mid — eyes opening', (t) => shotReveal(t, 0.75, 'bit_mood_reveal_mid.png'));
  testWidgets('REVEAL full — neutral face', (t) => shotReveal(t, 1.0, 'bit_mood_faced.png'));
  // The cheer reveal burst — amber screen, wide eyes + grin.
  testWidgets('REVEAL full — cheer face', (t) => shotReveal(t, 1.0, 'bit_mood_cheer_face.png', pose: BitPose.cheer));
}
