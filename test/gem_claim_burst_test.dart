import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/gem_claim_burst.dart';

void main() {
  test('uses reward-only amber shard colors', () {
    expect(GemClaimBurst.shardColors, contains(kAmber));
    expect(GemClaimBurst.shardColors, contains(kAmberDark));
    expect(GemClaimBurst.shardColors, isNot(contains(kCyan)));
  });

  Widget host(Widget child, {bool reducedMotion = false}) => MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Center(child: SizedBox(width: 120, height: 120, child: child)),
      ),
    ),
  );

  testWidgets('reduced motion stays inert (no animation, no timers)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const GemClaimBurst(trigger: 1), reducedMotion: true),
    );
    await tester.pump();
    expect(find.byType(GemClaimBurst), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Nothing scheduled — settles immediately with no pending timers.
    await tester.pumpAndSettle();
  });

  testWidgets('a trigger plays and settles cleanly', (tester) async {
    await tester.pumpWidget(host(const GemClaimBurst(trigger: 0)));
    await tester.pump();
    // Fire the burst.
    await tester.pumpWidget(host(const GemClaimBurst(trigger: 1)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
