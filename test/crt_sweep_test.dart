import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/motion/crt_sweep.dart';

const _green = TextStyle(fontSize: 10, color: Color(0xFF00FF9C));

Widget _host({required bool reduceMotion, required Widget child}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
}

/// Any glyph rendered brighter (higher luminance) than the green base.
Color? _litGlyphColor(WidgetTester tester) {
  final baseLum = _green.color!.computeLuminance();
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final c = t.style?.color;
    if (c != null && c.computeLuminance() > baseLum + 0.001) return c;
  }
  return null;
}

void main() {
  testWidgets('the sweep lights a glyph mid-pass, rests between sweeps', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        reduceMotion: false,
        child: const CrtSweep(
          text: 'ABC',
          style: _green,
          highlightColor: Color(0xFFFFFFFF),
          sweepDuration: Duration(milliseconds: 850),
          gap: Duration(milliseconds: 1300),
        ),
      ),
    );

    // Merged into one a11y node, not three letters.
    expect(find.bySemanticsLabel('ABC'), findsOneWidget);

    // ~mid-sweep (p ≈ 0.2 of the 2150ms cycle) → the band is over the word.
    await tester.pump(const Duration(milliseconds: 425));
    expect(
      _litGlyphColor(tester),
      isNotNull,
      reason: 'a glyph must brighten while the sweep crosses the word',
    );

    // Advance into the rest gap (p > sweepFraction) → no glyph lit.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(_litGlyphColor(tester), isNull, reason: 'calm during the rest gap');

    await tester.pumpWidget(const SizedBox()); // stop the repeating controller
  });

  testWidgets('reduced motion is a steady green label, no sweep', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        reduceMotion: true,
        child: const CrtSweep(text: 'ABC', style: _green),
      ),
    );

    expect(find.text('ABC'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 425));
    await tester.pump(const Duration(seconds: 1));
    expect(_litGlyphColor(tester), isNull);
    expect(find.text('ABC'), findsOneWidget);
  });
}
