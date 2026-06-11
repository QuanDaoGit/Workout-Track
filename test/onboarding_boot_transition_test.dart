import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/onboarding/cold_open_page.dart';
import 'package:workout_track/pages/onboarding/onboarding_flow_page.dart';
import 'package:workout_track/pages/onboarding/welcome_landing_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('GET STARTED runs the CRT boot power-cycle, then the cold open', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingFlowPage()));
    expect(find.byType(WelcomeLandingView), findsOneWidget);
    expect(find.byType(ColdOpenView), findsNothing);

    await tester.tap(find.text('GET STARTED'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    // The departure (logo zoom/bloom) plays first — not an instant cut.
    expect(find.byType(ColdOpenView), findsNothing);

    // Drive the power-cycle; the boot overlay owns the seam and the cold open
    // mounts behind it before the overlay clears.
    var sawBootOverlay = false;
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (find.byType(ColdOpenView).evaluate().isEmpty &&
        DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const ValueKey('onboarding_boot_powercycle'))
          .evaluate()
          .isNotEmpty) {
        sawBootOverlay = true;
      }
    }
    expect(sawBootOverlay, isTrue);
    expect(find.byType(ColdOpenView), findsOneWidget);

    // The overlay clears; the cold open remains.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    expect(find.byType(ColdOpenView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding_boot_powercycle')),
      findsNothing,
    );

    // Dispose the tree so the cold open's PowerOn timers are cancelled.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion swaps straight to the cold open (no overlay)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: OnboardingFlowPage(),
        ),
      ),
    );

    await tester.tap(find.text('GET STARTED'));
    await tester.pump();

    expect(find.byType(ColdOpenView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding_boot_powercycle')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
  });
}
