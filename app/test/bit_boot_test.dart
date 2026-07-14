import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/companion/bit_boot.dart';

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

  testWidgets('renders settled and survives its idle loop', (tester) async {
    await tester.pumpWidget(host(const BitBootCore())); // boot defaults to 1
    expect(find.byType(BitBootCore), findsOneWidget);
    // Bounded pumps — the idle loop never settles.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders dormant / flicker / rising / spin frames without throwing', (
    tester,
  ) async {
    for (final b in [0.0, 0.2, 0.5, 0.8]) {
      await tester.pumpWidget(host(BitBootCore(boot: b)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BitBootCore), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders a static frame under reduced motion', (tester) async {
    await tester.pumpWidget(host(const BitBootCore(boot: 0), reduce: true));
    expect(find.byType(BitBootCore), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Semantics flips OFF → awake with boot', (tester) async {
    await tester.pumpWidget(host(const BitBootCore(boot: 0)));
    expect(find.bySemanticsLabel('Power on BIT'), findsOneWidget);

    await tester.pumpWidget(host(const BitBootCore(boot: 1)));
    expect(find.bySemanticsLabel('BIT, your companion'), findsOneWidget);
  });

  testWidgets('BitVoiceWaveform renders in both motion modes', (tester) async {
    await tester.pumpWidget(host(const BitVoiceWaveform()));
    expect(find.byType(BitVoiceWaveform), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(host(const BitVoiceWaveform(), reduce: true));
    expect(find.byType(BitVoiceWaveform), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
