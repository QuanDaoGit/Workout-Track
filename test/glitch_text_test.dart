import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('renders the text and plays the glitch without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const GlitchText(
          text: 'LEVEL 2',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 18,
            color: Color(0xFFFFD700),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('LEVEL 2'), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 2'), findsWidgets);
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
