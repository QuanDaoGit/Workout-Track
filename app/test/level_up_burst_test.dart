import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/level_up_burst.dart';

/// The burst draws *nothing* while idle, actually paints once when triggered,
/// and is provably inert under reduced motion. These assert the rendered state,
/// not merely "it didn't throw" — a no-op or always-on burst would fail.
void main() {
  Widget host({required int trigger, required ValueChanged<VoidCallback> bind,
      bool reduceMotion = false}) {
    return MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: StatefulBuilder(
            builder: (context, setState) {
              bind(() => setState(() => trigger++));
              return Stack(
                children: [
                  Positioned.fill(child: LevelUpBurst(trigger: trigger)),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => setState(() => trigger++),
                      child: const Text('GO'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // The burst paints through a CustomPaint only while 0 < controller < 1.
  Finder burstPaint() => find.descendant(
        of: find.byType(LevelUpBurst),
        matching: find.byType(CustomPaint),
      );

  testWidgets('idle paints nothing; triggering plays the burst, then clears', (
    tester,
  ) async {
    await tester.pumpWidget(host(trigger: 0, bind: (_) {}));
    await tester.pump();

    // Idle: the burst renders SizedBox.expand, never a painter.
    expect(burstPaint(), findsNothing);

    await tester.tap(find.text('GO'));
    await tester.pump(); // trigger bump → controller.forward(from: 0)
    await tester.pump(const Duration(milliseconds: 120)); // mid-burst

    // It actually plays — a painter is on screen during the animation.
    expect(burstPaint(), findsOneWidget);

    await tester.pumpAndSettle();

    // …and tears itself down once finished (back to SizedBox.expand), no error.
    expect(burstPaint(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion stays inert on trigger — it never paints', (
    tester,
  ) async {
    await tester.pumpWidget(host(trigger: 0, bind: (_) {}, reduceMotion: true));
    await tester.pump();
    expect(burstPaint(), findsNothing);

    await tester.tap(find.text('GO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // disableAnimations short-circuits didUpdateWidget → the controller never
    // forwards → no painter is ever produced (true inertness, not just no-throw).
    expect(burstPaint(), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
