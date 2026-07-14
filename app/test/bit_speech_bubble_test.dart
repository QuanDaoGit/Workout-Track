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

  testWidgets('typewriter types out and notifies once at completion', (
    tester,
  ) async {
    var typed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BitSpeechBubble(
            text: 'Ready.',
            typewriter: true,
            onTypingComplete: () => typed++,
          ),
        ),
      ),
    );
    // 'Ready.' = 6 chars × ~22 ms ≈ 132 ms; let it finish.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ready.'), findsOneWidget);
    // Notified exactly once — synchronously at the completion frame.
    expect(typed, 1);
  });

  testWidgets('skip completes the typing line immediately', (tester) async {
    Widget tree(bool skip) => MaterialApp(
      home: Scaffold(
        body: BitSpeechBubble(
          text: 'A longer line still typing out slowly here.',
          typewriter: true,
          skip: skip,
        ),
      ),
    );
    await tester.pumpWidget(tree(false));
    await tester.pump(const Duration(milliseconds: 40)); // mid-type
    expect(
      find.text('A longer line still typing out slowly here.'),
      findsNothing,
    );
    await tester.pumpWidget(tree(true)); // a tap flips skip true
    await tester.pump();
    expect(
      find.text('A longer line still typing out slowly here.'),
      findsOneWidget,
    );
  });

  testWidgets('reduced motion turned on mid-type snaps to the full line', (
    tester,
  ) async {
    Widget tree(bool reduce) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: const Scaffold(
          body: BitSpeechBubble(
            text: 'Calibrating your build now.',
            typewriter: true,
          ),
        ),
      ),
    );
    await tester.pumpWidget(tree(false)); // typing under normal motion
    await tester.pump(const Duration(milliseconds: 40)); // a few chars in
    expect(find.text('Calibrating your build now.'), findsNothing);
    // User enables reduced motion mid-type → the line must snap to full.
    await tester.pumpWidget(tree(true));
    await tester.pump();
    expect(find.text('Calibrating your build now.'), findsOneWidget);
  });

  testWidgets('tailDirection right keeps the full line (BIT on the right)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BitSpeechBubble(
            text: 'On your right, warrior.',
            tailDirection: BitTailDirection.right,
          ),
        ),
      ),
    );
    expect(find.text('On your right, warrior.'), findsOneWidget);
  });

  testWidgets('tailDirection none renders a tail-less caption line', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BitSpeechBubble(
            text: 'Caption only.',
            tailDirection: BitTailDirection.none,
          ),
        ),
      ),
    );
    expect(find.text('Caption only.'), findsOneWidget);
    // Tail presence/position is golden-locked (framework internals also use
    // CustomPaint, so a byType count here would be unreliable).
  });
}
