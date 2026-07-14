import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/motion/ambient_drift.dart';
import 'package:workout_track/widgets/motion/hold_depress.dart';
import 'package:workout_track/widgets/motion/phosphor_tap.dart';
import 'package:workout_track/widgets/motion/power_on.dart';

void main() {
  testWidgets('PhosphorTap shows halo on pointer down', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _Harness(
        child: PhosphorTap(
          onTap: () => taps++,
          child: const SizedBox(width: 80, height: 40),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PhosphorTap)),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(PhosphorTap),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    await gesture.up();
    expect(taps, 1);
  });

  testWidgets(
    'HoldDepress translates while pressed and not in reduced motion',
    (tester) async {
      await tester.pumpWidget(
        _Harness(
          child: HoldDepress(
            onTap: () {},
            child: const SizedBox(width: 80, height: 40),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldDepress)),
      );
      await tester.pump();
      final transform = tester.widget<Transform>(_motionTransformInHold());
      expect(transform.transform.getTranslation().y, 2);
      await gesture.up();
    },
  );

  testWidgets('HoldDepress does not translate under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        reduceMotion: true,
        child: HoldDepress(
          onTap: () {},
          child: const SizedBox(width: 80, height: 40),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldDepress)),
    );
    await tester.pump();
    final transform = tester.widget<Transform>(_motionTransformInHold());
    expect(transform.transform.getTranslation().y, 0);
    await gesture.up();
  });

  testWidgets('PowerOn runs once on disabled to enabled transition', (
    tester,
  ) async {
    await tester.pumpWidget(const _PowerHarness(enabled: false));
    expect(find.text('0.0'), findsOneWidget);

    await tester.pumpWidget(const _PowerHarness(enabled: true));
    await tester.pump();
    expect(find.text('0.3'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 70));
    expect(find.text('0.8'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 70));
    expect(find.text('1.0'), findsOneWidget);

    await tester.pumpWidget(const _PowerHarness(enabled: true));
    await tester.pump();
    expect(find.text('1.0'), findsOneWidget);
  });

  testWidgets('AmbientDrift moves scanline layer unless reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness(child: AmbientDrift()));
    final initial = tester.widget<Transform>(_motionTransformInDrift());
    expect(initial.transform.getTranslation().y, 0);

    await tester.pump(const Duration(milliseconds: 1500));
    final moved = tester.widget<Transform>(_motionTransformInDrift());
    expect(moved.transform.getTranslation().y, greaterThan(0));

    await tester.pumpWidget(
      const _Harness(reduceMotion: true, child: AmbientDrift()),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    final staticLayer = tester.widget<Transform>(_motionTransformInDrift());
    expect(staticLayer.transform.getTranslation().y, 0);
  });
}

Finder _motionTransformInHold() => find
    .descendant(of: find.byType(HoldDepress), matching: find.byType(Transform))
    .last;

Finder _motionTransformInDrift() => find
    .descendant(of: find.byType(AmbientDrift), matching: find.byType(Transform))
    .last;

class _PowerHarness extends StatelessWidget {
  const _PowerHarness({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _Harness(
      child: PowerOn(
        enabled: enabled,
        builder: (context, power) => Text(power.toStringAsFixed(1)),
      ),
    );
  }
}

class _Harness extends StatelessWidget {
  const _Harness({required this.child, this.reduceMotion = false});

  final Widget child;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData().copyWith(disableAnimations: reduceMotion),
        child: Scaffold(
          backgroundColor: kBg,
          body: Center(child: child),
        ),
      ),
    );
  }
}
