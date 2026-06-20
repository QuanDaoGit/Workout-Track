import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/companion/bit_companion.dart';
import 'package:workout_track/widgets/companion/bit_sprite.dart' show BitMood;

/// Rendered-artifact proof for the animated companion BIT (the Flutter web
/// preview can't screenshot here). Under reduced motion the idle clock is frozen
/// (t = 5.0), so each mood is deterministic. Regenerate with
/// `flutter test --update-goldens`.
void main() {
  Future<void> shot(WidgetTester tester, BitMood mood, String file) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            backgroundColor: kBg,
            body: Center(child: BitCompanion(mood: mood, size: 184)),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(BitCompanion),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('NEUTRAL', (t) => shot(t, BitMood.neutral, 'bit_companion_neutral.png'));
  testWidgets('CHEER', (t) => shot(t, BitMood.cheer, 'bit_companion_cheer.png'));
  testWidgets('ALERT', (t) => shot(t, BitMood.alert, 'bit_companion_alert.png'));
  testWidgets('REST', (t) => shot(t, BitMood.rest, 'bit_companion_rest.png'));
}
