import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/pages/onboarding/welcome_landing_page.dart';

void main() {
  Widget harness(VoidCallback onGetStarted, {bool reduceMotion = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: Scaffold(body: WelcomeLandingView(onGetStarted: onGetStarted)),
      ),
    );
  }

  testWidgets('renders the brand mark, promise, CTAs, and beta notice', (
    tester,
  ) async {
    await tester.pumpWidget(harness(() {}));

    expect(find.byKey(const ValueKey('welcome_app_logo')), findsOneWidget);
    expect(find.text('IRONBIT'), findsOneWidget);
    expect(find.text('Every rep builds your character.'), findsOneWidget);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(
      find.text('Still in beta version, no accounts management yet.'),
      findsOneWidget,
    );
  });

  testWidgets('GET STARTED plays the departure, then fires onGetStarted', (
    tester,
  ) async {
    var started = 0;
    await tester.pumpWidget(harness(() => started++));

    await tester.tap(find.text('GET STARTED'));
    await tester.pump(); // start the departure (logo zoom + bloom)
    expect(started, 0); // not yet — the departure plays first

    await tester.pump(const Duration(milliseconds: 450)); // departure completes
    expect(started, 1);
  });

  testWidgets('reduced motion fires onGetStarted immediately (no departure)', (
    tester,
  ) async {
    var started = 0;
    await tester.pumpWidget(harness(() => started++, reduceMotion: true));

    await tester.tap(find.text('GET STARTED'));
    await tester.pump();

    expect(started, 1);
  });

  testWidgets('departure advances without error', (tester) async {
    await tester.pumpWidget(harness(() {}));
    await tester.tap(find.text('GET STARTED'));
    for (final ms in const [0, 120, 240, 360]) {
      await tester.pump(Duration(milliseconds: ms));
      expect(find.byKey(const ValueKey('welcome_app_logo')), findsOneWidget);
    }
  });

  testWidgets('SIGN IN is pressable but inert — never calls onGetStarted', (
    tester,
  ) async {
    var started = 0;
    await tester.pumpWidget(harness(() => started++));

    // Press it several times; nothing should happen (no nav, no callback).
    await tester.tap(find.text('SIGN IN'));
    await tester.pump();
    await tester.tap(find.text('SIGN IN'));
    await tester.pump();

    expect(started, 0);
    expect(find.text('SIGN IN'), findsOneWidget); // still on the landing
  });

  testWidgets('reduced motion renders the static landing', (tester) async {
    await tester.pumpWidget(harness(() {}, reduceMotion: true));
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome_app_logo')), findsOneWidget);
  });

  testWidgets('logo idle motion advances without error', (tester) async {
    await tester.pumpWidget(harness(() {}));
    // The idle controller repeats forever — pump frames (never pumpAndSettle)
    // and confirm the logo stays mounted across the loop.
    for (final ms in const [0, 900, 1800, 3600]) {
      await tester.pump(Duration(milliseconds: ms));
      expect(find.byKey(const ValueKey('welcome_app_logo')), findsOneWidget);
    }
  });
}
