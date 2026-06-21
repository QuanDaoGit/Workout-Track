import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/glitch_text.dart';

void main() {
  Widget host(Widget child, {bool reducedMotion = false}) => MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Center(child: child),
      ),
    ),
  );

  // A chromatic-aberration channel: the text re-drawn in the red/cyan split.
  Finder channel(Color color) => find.byWidgetPredicate(
    (w) => w is Text && w.data == 'LEVEL 2' && w.style?.color == color,
  );
  Finder tear() => find.descendant(
    of: find.byType(GlitchText),
    matching: find.byType(CustomPaint),
  );

  testWidgets('plays the chromatic glitch (split + tear) then resolves clean', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const GlitchText(
          text: 'LEVEL 2',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 18,
            color: kAmber,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16)); // first glitch frame

    // The glitch is genuinely rendering: red + cyan channels split off the main
    // text, plus the scanline tear band — not merely clean text that didn't throw.
    expect(channel(kDanger), findsOneWidget);
    expect(channel(kCyan), findsOneWidget);
    expect(tear(), findsWidgets);

    await tester.pumpAndSettle();

    // Resolves to clean text; the tear band is gone once the glitch settles.
    expect(find.text('LEVEL 2'), findsWidgets);
    expect(tear(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion renders a single clean text', (tester) async {
    await tester.pumpWidget(
      host(const GlitchText(text: 'LEVEL 2'), reducedMotion: true),
    );
    await tester.pump();
    expect(find.text('LEVEL 2'), findsOneWidget);
  });
}
