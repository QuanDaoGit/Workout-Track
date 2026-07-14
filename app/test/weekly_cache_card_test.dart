import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/guild/weekly_cache_card.dart';

void main() {
  testWidgets('incomplete cache shows progress + no-guilt rest framing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WeeklyCacheCard(
            activeDays: 1,
            target: 3,
            banked: false,
            reward: 20,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('guild_weekly_cache')), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // active days so far
    expect(find.text('/3'), findsOneWidget);
    expect(find.text('+20'), findsOneWidget);
    expect(
      find.textContaining('the guild rests when you do'),
      findsOneWidget,
    );
    expect(find.text('CACHE BANKED · resets Monday'), findsNothing);
  });

  testWidgets('banked cache shows the calm banked state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WeeklyCacheCard(
            activeDays: 3,
            target: 3,
            banked: true,
            reward: 20,
          ),
        ),
      ),
    );
    expect(find.text('CACHE BANKED · resets Monday'), findsOneWidget);
    expect(find.textContaining('the guild rests'), findsNothing);
  });
}
