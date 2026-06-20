import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/companion/bit_mood_core.dart';

void main() {
  Widget host(Widget child, {bool reduce = false}) {
    final scaffold = Scaffold(body: Center(child: child));
    return MaterialApp(
      home: reduce
          ? MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: scaffold,
            )
          : scaffold,
    );
  }

  testWidgets('renders every pose and survives its idle loop', (tester) async {
    for (final pose in BitPose.values) {
      await tester.pumpWidget(host(BitMoodCore(pose: pose)));
      expect(find.byType(BitMoodCore), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('eases between poses without throwing', (tester) async {
    await tester.pumpWidget(host(const BitMoodCore(pose: BitPose.cheer)));
    await tester.pump(const Duration(milliseconds: 200));
    // Flip cheer → rest; pump across the morph.
    await tester.pumpWidget(host(const BitMoodCore(pose: BitPose.rest)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion renders a static posed frame', (tester) async {
    await tester.pumpWidget(
      host(const BitMoodCore(pose: BitPose.rest), reduce: true),
    );
    expect(find.byType(BitMoodCore), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes BIT semantics label', (tester) async {
    await tester.pumpWidget(host(const BitMoodCore(pose: BitPose.neutral)));
    expect(find.bySemanticsLabel('BIT, your companion'), findsOneWidget);
  });
}
