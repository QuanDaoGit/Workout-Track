import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/companion/bit_speech_bubble.dart';

void main() {
  testWidgets('renders a plain line', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BitSpeechBubble(text: 'Hello, Nova.')),
      ),
    );
    expect(find.text('Hello, Nova.'), findsOneWidget);
  });

  testWidgets('tints the emphasis substring without dropping the line', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BitSpeechBubble(
            text: 'What should we do first, Nova?',
            emphasis: 'Nova',
          ),
        ),
      ),
    );
    expect(
      find.textContaining('What should we do first', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Nova', findRichText: true), findsOneWidget);
  });

  testWidgets('renders full text under reduced motion (no typewriter)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: BitSpeechBubble(text: 'Steady on, warrior.')),
        ),
      ),
    );
    expect(find.text('Steady on, warrior.'), findsOneWidget);
  });
}
