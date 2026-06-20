import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/arcade_bar.dart';

void main() {
  Widget host(Widget child, {bool reduce = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Scaffold(body: Center(child: SizedBox(width: 200, child: child))),
    ),
  );

  testWidgets('continuous mode exposes a clamped fraction and paints', (
    tester,
  ) async {
    await tester.pumpWidget(host(const ArcadeBar(value: 0.5)));
    final bar = tester.widget<ArcadeBar>(find.byType(ArcadeBar));
    expect(bar.isSegments, isFalse);
    expect(bar.fraction, 0.5);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('over-range value clamps to 1', (tester) async {
    await tester.pumpWidget(host(const ArcadeBar(value: 1.5)));
    expect(tester.widget<ArcadeBar>(find.byType(ArcadeBar)).fraction, 1.0);
  });

  testWidgets('segments mode keeps the explicit count', (tester) async {
    await tester.pumpWidget(
      host(const ArcadeBar.segments(litCells: 7, totalCells: 24)),
    );
    final bar = tester.widget<ArcadeBar>(find.byType(ArcadeBar));
    expect(bar.isSegments, isTrue);
    expect(bar.litCells, 7);
    expect(bar.totalCells, 24);
    expect(bar.fraction, closeTo(7 / 24, 0.0001));
  });

  testWidgets('renders a static fill under reduced motion', (tester) async {
    await tester.pumpWidget(host(const ArcadeBar(value: 1), reduce: true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.byType(ArcadeBar), findsOneWidget);
  });
}
