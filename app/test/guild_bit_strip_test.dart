import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/guild/guild_bit_strip.dart';

void main() {
  testWidgets('BIT voice-only host shows the line, no Strike button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: GuildBitStrip(line: 'Rest when you need it.')),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('guild_bit_strip')), findsOneWidget);
    expect(find.textContaining('Rest when you need it'), findsOneWidget);
    // Strike was cut (placebo with no recipient in solo).
    expect(find.bySemanticsLabel('Strike — cheer BIT on'), findsNothing);
  });
}
