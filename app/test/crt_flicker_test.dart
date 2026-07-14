import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/motion/crt_flicker.dart';

const _style = TextStyle(fontSize: 10, color: Color(0xFF9494B8));

Widget _host({required bool reduceMotion, required Widget child}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
}

/// The flicking glyph is the only `Text` brighter (higher luminance) than base.
Color? _litGlyphColor(WidgetTester tester) {
  final baseLum = _style.color!.computeLuminance();
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final c = t.style?.color;
    if (c != null && c.computeLuminance() > baseLum + 0.001) return c;
  }
  return null;
}

void main() {
  testWidgets('renders the full label as one a11y node when animated', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        reduceMotion: false,
        child: const CrtFlicker(text: "TODAY'S MISSION", style: _style),
      ),
    );

    // The label is announced once (not letter-by-letter) and reads in full.
    expect(
      find.bySemanticsLabel("TODAY'S MISSION"),
      findsOneWidget,
      reason: 'animated path must merge per-glyph Text into one label',
    );
    // No glyph is lit at rest, before any flicker timer fires.
    expect(_litGlyphColor(tester), isNull);
  });

  testWidgets('a glyph brightens when the flicker fires, then recovers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        reduceMotion: false,
        child: const CrtFlicker(
          text: 'ABC',
          style: _style,
          highlightColor: Color(0xFFE8E8FF),
          minGap: Duration(seconds: 1),
          maxGap: Duration(seconds: 2),
          flickerDuration: Duration(milliseconds: 240),
        ),
      ),
    );

    expect(_litGlyphColor(tester), isNull); // steady at rest

    // Cross the scheduled gap so a glyph is selected, then advance to the hold.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 90)); // ~peak hold
    final lit = _litGlyphColor(tester);
    expect(lit, isNotNull, reason: 'one glyph must brighten at the flash peak');
    expect(
      lit!.computeLuminance(),
      greaterThan(_style.color!.computeLuminance()),
    );

    // The flash completes and the glyph returns to the muted base.
    await tester.pump(const Duration(milliseconds: 160));
    expect(_litGlyphColor(tester), isNull);

    await tester.pumpWidget(const SizedBox()); // cancel the pending timer
  });

  testWidgets('reduced motion is a steady label that never flickers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        reduceMotion: true,
        child: const CrtFlicker(
          text: 'ABC',
          style: _style,
          minGap: Duration(seconds: 1),
          maxGap: Duration(seconds: 2),
        ),
      ),
    );

    // A single plain Text, full label, no flicker scheduling.
    expect(find.text('ABC'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_litGlyphColor(tester), isNull);
    expect(find.text('ABC'), findsOneWidget);
  });
}
