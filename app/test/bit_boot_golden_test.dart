import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/companion/bit_boot.dart';

/// Rendered-artifact proof for BIT's drone-core across the boot (the Flutter web
/// preview can't screenshot here). `boot` is a settable progress, so each phase
/// is deterministic under reduced motion. Regenerate with
/// `flutter test --update-goldens`.
void main() {
  Future<void> shot(WidgetTester tester, double boot, String file) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            backgroundColor: kBg,
            // Taller than the sprite: the box carries floor + sky for the rise.
            body: Center(child: BitBootCore(width: 264, height: 432, boot: boot)),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(BitBootCore),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('DORMANT — slumped on the floor', (t) => shot(t, 0, 'bit_off.png'));
  testWidgets('STIR — accelerating flicker', (t) => shot(t, 0.2, 'bit_flicker.png'));
  testWidgets('FLY UP — mid-lift', (t) => shot(t, 0.5, 'bit_rising.png'));
  testWidgets('SPIN — plates out', (t) => shot(t, 0.8, 'bit_spin_mid.png'));
  testWidgets('SETTLE — docked + hovering', (t) => shot(t, 1, 'bit_docked.png'));
}
