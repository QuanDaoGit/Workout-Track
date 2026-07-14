import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/arcade_notice.dart';

/// A host with a real Navigator/Overlay (the notice inserts into the root
/// overlay) and a tappable counter button UNDER where the notice appears —
/// the tap-through proof.
Widget _host({
  required VoidCallback onButtonTap,
  required GlobalKey buttonKey,
  bool reduceMotion = false,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      disableAnimations: reduceMotion,
    ),
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  key: buttonKey,
                  onPressed: onButtonTap,
                  child: const Text('UNDER'),
                ),
                TextButton(
                  onPressed: () => showArcadeNotice(context, 'Test notice'),
                  child: const Text('SHOW'),
                ),
                TextButton(
                  onPressed: () => showArcadeNotice(
                    context,
                    'Second notice',
                    duration: ArcadeNoticeDuration.short,
                  ),
                  child: const Text('SHOW2'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  tearDown(resetArcadeNoticeForTest);

  Future<void> pumpHost(
    WidgetTester tester, {
    VoidCallback? onButtonTap,
    GlobalKey? buttonKey,
    bool reduceMotion = false,
  }) {
    return tester.pumpWidget(
      _host(
        onButtonTap: onButtonTap ?? () {},
        buttonKey: buttonKey ?? GlobalKey(),
        reduceMotion: reduceMotion,
      ),
    );
  }

  testWidgets('visible after a single pump (bare-pump contract)', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('SHOW'));
    await tester.pump();
    expect(find.text('Test notice'), findsOneWidget);
  });

  testWidgets('auto-dismisses after power-on + hold + power-off', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('SHOW'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Test notice'), findsOneWidget, reason: 'mid-hold');
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump();
    expect(find.text('Test notice'), findsNothing);
  });

  testWidgets(
    'tap anywhere dismisses immediately AND the underlying tap still lands',
    (tester) async {
      var underTaps = 0;
      final buttonKey = GlobalKey();
      await pumpHost(
        tester,
        onButtonTap: () => underTaps++,
        buttonKey: buttonKey,
      );
      await tester.tap(find.text('SHOW'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // settled hold
      expect(find.text('Test notice'), findsOneWidget);
      // Tap the button that sits under/behind the center notice.
      await tester.tap(find.byKey(buttonKey), warnIfMissed: false);
      await tester.pump(); // the dismissal ticker's zero-frame
      await tester.pump(const Duration(milliseconds: 250)); // power-off
      await tester.pump();
      expect(find.text('Test notice'), findsNothing,
          reason: 'any tap dismisses the notice');
      expect(underTaps, 1,
          reason: 'the notice never participates in hit testing');
    },
  );

  testWidgets('a new notice replaces the current one (non-stacking)', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('SHOW'));
    await tester.pump();
    await tester.tap(find.text('SHOW2'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Test notice'), findsNothing);
    expect(find.text('Second notice'), findsOneWidget);
  });

  testWidgets('short duration dismisses sooner', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('SHOW2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(find.text('Second notice'), findsNothing);
  });

  testWidgets('reduced motion: full plate immediately, still auto-dismisses', (
    tester,
  ) async {
    await pumpHost(tester, reduceMotion: true);
    await tester.tap(find.text('SHOW'));
    await tester.pump();
    expect(find.text('Test notice'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Test notice'),
      findsOneWidget,
      reason: 'live-region announcement node',
    );
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();
    expect(find.text('Test notice'), findsNothing);
  });

  testWidgets('pumpAndSettle completes (timer-free lifecycle)', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('SHOW'));
    await tester.pumpAndSettle();
    expect(find.text('Test notice'), findsNothing);
  });

  testWidgets('golden: settled plate mid-hold', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('SHOW'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/arcade_notice_plate.png'),
    );
  });
}
