import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/guild/guild_legends_card.dart';

void main() {
  testWidgets('self-referenced badges; improvement shows +N', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GuildLegendsCard(activeDays: 4, streak: 6, improvedDelta: 2),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('guild_legends')), findsOneWidget);
    expect(find.text('ACTIVE DAYS'), findsOneWidget);
    expect(find.text('IRON STREAK'), findsOneWidget);
    expect(find.text('IMPROVED'), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // active days
    expect(find.text('6'), findsOneWidget); // streak
    expect(find.text('+2'), findsOneWidget); // improved
  });

  testWidgets('a lighter week reads STEADY, never a red negative', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GuildLegendsCard(activeDays: 2, streak: 0, improvedDelta: -3),
        ),
      ),
    );
    expect(find.text('STEADY'), findsOneWidget);
    expect(find.text('-3'), findsNothing);
  });
}
