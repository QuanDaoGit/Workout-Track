import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/floating_stat_number.dart';

void main() {
  Widget host(Widget child, {bool reducedMotion = false}) => MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Center(child: child),
      ),
    ),
  );

  testWidgets('counts up to the final value', (tester) async {
    await tester.pumpWidget(
      host(const FloatingStatNumber(stat: 'STR', value: 49)),
    );
    await tester.pumpAndSettle();
    expect(find.text('STR +'), findsOneWidget);
    expect(find.text('49'), findsOneWidget);
  });

  testWidgets('reduced motion shows the final value immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const FloatingStatNumber(stat: 'AGI', value: 8),
        reducedMotion: true,
      ),
    );
    await tester.pump();
    expect(find.text('AGI +'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
  });

  test('a bigger gain ticks for longer than a smaller one', () {
    expect(
      FloatingStatNumber.durationFor(49) > FloatingStatNumber.durationFor(4),
      isTrue,
    );
  });
}
