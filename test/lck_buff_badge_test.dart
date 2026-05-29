import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/lck_buff_badge.dart';

void main() {
  testWidgets('hidden when there is no buff (multiplier 1.0)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LckBuffBadge(multiplier: 1.0, lck: 0)),
      ),
    );
    expect(find.textContaining('LCK'), findsNothing);
  });

  testWidgets('shows LCK x label and reason tooltip when buffed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LckBuffBadge(multiplier: 2.0, lck: 28)),
      ),
    );

    expect(find.text('LCK x2.0x'), findsNothing); // no double-x bug
    expect(find.text('LCK x2'), findsOneWidget); // clean "2", no ".0"

    await tester.tap(find.byType(LckBuffBadge));
    await tester.pumpAndSettle();

    // 28-day streak → 4 clean weeks, ×2.0 → +100% XP.
    expect(find.textContaining('4 clean weeks'), findsOneWidget);
    expect(find.textContaining('+100% XP'), findsOneWidget);
  });

  testWidgets('uses day phrasing under one week', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LckBuffBadge(multiplier: 1.5, lck: 4)),
      ),
    );
    await tester.tap(find.byType(LckBuffBadge));
    await tester.pumpAndSettle();
    expect(find.textContaining('4-day streak'), findsOneWidget);
    expect(find.textContaining('+50% XP'), findsOneWidget);
  });
}
