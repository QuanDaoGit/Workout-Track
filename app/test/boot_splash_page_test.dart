import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/pages/boot_splash_page.dart';

void main() {
  // Lightweight destinations so tests never build the real RootPage (which runs
  // a periodic dock timer that won't settle).
  Widget destination(bool isComplete) => Text(
    isComplete ? 'DEST_ROOT' : 'DEST_ONBOARD',
    textDirection: TextDirection.ltr,
  );

  Widget harness({
    required Future<bool> Function() boot,
    bool reduceMotion = false,
    Duration minDisplay = const Duration(milliseconds: 1000),
    Duration maxDisplay = const Duration(milliseconds: 1800),
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: BootSplashPage(
          bootOverride: boot,
          destinationBuilder: destination,
          minDisplay: minDisplay,
          maxDisplay: maxDisplay,
        ),
      ),
    );
  }

  testWidgets('reduced motion reveals the destination once boot resolves', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(boot: () async => true, reduceMotion: true),
    );
    // Reduced-motion min is ~300ms; advance past it.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('DEST_ROOT'), findsOneWidget);
    expect(find.byKey(const ValueKey('boot_splash_overlay')), findsNothing);
  });

  testWidgets('honest min: destination is withheld until minDisplay even when '
      'boot resolves instantly', (tester) async {
    await tester.pumpWidget(harness(boot: () async => true));
    // Boot resolves on the first microtask, but the min gate is 1000ms — the
    // overlay still covers the (opacity-0, behind) destination.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('boot_splash_overlay')), findsOneWidget);
    final hidden = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('DEST_ROOT'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(hidden.opacity, 0.0); // destination withheld (invisible) before min

    // Past the min the reveal fires; let the fade complete.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('boot_splash_overlay')), findsNothing);
    expect(find.text('DEST_ROOT'), findsOneWidget);
  });

  testWidgets('adaptive: reveal waits for slow boot, not a fixed timer', (
    tester,
  ) async {
    final completer = Completer<bool>();
    await tester.pumpWidget(harness(boot: () => completer.future));

    // Past the min, but boot has not resolved → still on the splash.
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('DEST_ROOT'), findsNothing);
    expect(find.byKey(const ValueKey('boot_splash_overlay')), findsOneWidget);

    completer.complete(true);
    await tester.pump(); // boot resolves
    await tester.pump(const Duration(milliseconds: 600)); // reveal fade
    expect(find.text('DEST_ROOT'), findsOneWidget);
  });

  testWidgets('cap backstop: reveals onboarding if boot never resolves', (
    tester,
  ) async {
    final never = Completer<bool>(); // never completed
    await tester.pumpWidget(
      harness(
        boot: () => never.future,
        maxDisplay: const Duration(milliseconds: 1800),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('DEST_ONBOARD'), findsOneWidget);
  });

  testWidgets('routes to onboarding when isComplete is false', (tester) async {
    await tester.pumpWidget(harness(boot: () async => false));
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('DEST_ONBOARD'), findsOneWidget);
    expect(find.text('DEST_ROOT'), findsNothing);
  });
}
