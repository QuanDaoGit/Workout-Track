import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/recovery_insights.dart';
import 'package:workout_track/services/recovery_insight_service.dart';
import 'package:workout_track/widgets/companion/bit_mood_core.dart';
import 'package:workout_track/widgets/recovery_insight_sheet.dart';

void main() {
  const insight = RecoveryInsight(
    id: 'test_insight',
    category: 'sleep',
    text: 'Most muscle repair runs during deep sleep.',
  );

  Widget host(RecoveryInsightPick pick) => MaterialApp(
        home: Scaffold(
          body: RecoveryInsightSheetContent(pick: pick),
        ),
      );

  testWidgets('renders the insight text, category icon, and close button',
      (tester) async {
    await tester.pumpWidget(host(
        const RecoveryInsightPick(insight: insight, poolWrapped: false)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(
        find.textContaining('deep sleep', findRichText: true), findsOneWidget);
    // Icon-only category marker: no visible tag text, but the category is
    // still announced to screen readers via its Semantics label.
    expect(find.text('SLEEP'), findsNothing);
    expect(find.bySemanticsLabel('sleep'), findsOneWidget);
    expect(find.byType(ImageIcon), findsOneWidget);
    // BIT must render FACED (app doctrine: never faceless after onboarding).
    final bit = tester.widget<BitMoodCore>(find.byType(BitMoodCore));
    expect(bit.reveal, 1);
    expect(find.text('CLOSE'), findsOneWidget);
    expect(find.text(kRecoveryInsightWrapLine), findsNothing);
  });

  testWidgets('shows the honest wrap line only on a wrap day', (tester) async {
    await tester.pumpWidget(host(
        const RecoveryInsightPick(insight: insight, poolWrapped: true)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(kRecoveryInsightWrapLine), findsOneWidget);
  });
}
