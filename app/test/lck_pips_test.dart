import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/lck_pips.dart';

void main() {
  Widget host(int lck) => MaterialApp(home: Scaffold(body: LckPips(lck: lck)));

  testWidgets('announces filled-of-4 via Semantics (thresholds 1/3/6/10)', (
    tester,
  ) async {
    await tester.pumpWidget(host(0));
    expect(find.bySemanticsLabel('Luck 0 of 4'), findsOneWidget);

    await tester.pumpWidget(host(3)); // >=1, >=3 → 2 filled
    expect(find.bySemanticsLabel('Luck 2 of 4'), findsOneWidget);

    await tester.pumpWidget(host(100)); // all four
    expect(find.bySemanticsLabel('Luck 4 of 4'), findsOneWidget);
  });
}
