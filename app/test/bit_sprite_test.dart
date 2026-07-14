import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/companion/bit_sprite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders every mood without throwing', (tester) async {
    for (final mood in BitMood.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: BitSprite(mood: mood, size: 56))),
        ),
      );
      expect(find.byType(BitSprite), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('wires a painted fallback for a failed asset load', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BitSprite(size: 56))),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.errorBuilder, isNotNull);

    // Exercise the fallback path directly: it must build a widget (the painted
    // BIT glyph), never rethrow or surface a broken-image placeholder.
    final ctx = tester.element(find.byType(BitSprite));
    final fallback = image.errorBuilder!(ctx, 'load failed', null);
    expect(fallback, isA<Widget>());
  });

  test('every declared BIT sprite asset is bundled and non-empty', () async {
    for (final path in kBitSpriteAssets) {
      final data = await rootBundle.load(path);
      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: '$path is missing or empty',
      );
    }
  });
}
