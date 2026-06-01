import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/count_up_text.dart';

void main() {
  Widget host(Widget child, {bool reducedMotion = false}) => MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Center(child: child),
      ),
    ),
  );

  testWidgets('counts up to and settles on the final value', (tester) async {
    await tester.pumpWidget(host(const CountUpText(value: 76)));
    await tester.pumpAndSettle();
    expect(find.text('76'), findsOneWidget);
  });

  testWidgets('reduced motion shows the final value on first frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const CountUpText(value: 76), reducedMotion: true),
    );
    await tester.pump();
    expect(find.text('76'), findsOneWidget);
  });

  testWidgets('applies prefix and suffix', (tester) async {
    await tester.pumpWidget(
      host(const CountUpText(value: 12, prefix: 'STR +'), reducedMotion: true),
    );
    await tester.pump();
    expect(find.text('STR +12'), findsOneWidget);
  });
}
