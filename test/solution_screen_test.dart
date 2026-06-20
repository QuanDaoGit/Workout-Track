import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/onboarding/cold_open_page.dart';
import 'package:workout_track/pages/onboarding/onboarding_flow_page.dart';
import 'package:workout_track/pages/onboarding/problem_question_page.dart';
import 'package:workout_track/pages/onboarding/solution_page.dart';
import 'package:workout_track/widgets/companion/bit_mood_core.dart';
import 'package:workout_track/widgets/pixel_button.dart';
import 'package:workout_track/widgets/strobe_flash.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Real fonts so the golden's text metrics match the device (else tofu boxes).
  setUpAll(() async {
    Future<ByteData> font(String path) async =>
        ByteData.view((await File(path).readAsBytes()).buffer);
    await (FontLoader('ShareTechMono')
          ..addFont(font('fonts/sharetechmono/ShareTechMono-Regular.ttf')))
        .load();
    await (FontLoader('PressStart2P')
          ..addFont(font('fonts/pressstart2p/PressStart2P-Regular.ttf')))
        .load();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrapWithApp(Widget child, {bool reducedMotion = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('Reduced motion renders the settled, revealed solution', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(SolutionView(onContinue: () {}), reducedMotion: true),
    );
    await tester.pump();

    // BIT is present and its face is fully revealed (eyes open) at rest state.
    final bit = tester.widget<BitMoodCore>(find.byType(BitMoodCore));
    expect(bit.reveal, 1.0);
    expect(bit.pose, BitPose.neutral);

    // Both lines are on screen in full.
    expect(find.text('HERE, EVERY REP\nLEVELS YOU UP'), findsOneWidget);
    expect(find.text('YOU WILL KEEP COMING\nBACK FOR MORE'), findsOneWidget);
    // The meter caption was removed (only the bar remains).
    expect(find.text('every rep fills this'), findsNothing);
    // The reveal bloom is the engine's circular glow — never a StrobeFlash
    // rectangle (the "square layer" bug).
    expect(find.byType(StrobeFlash), findsNothing);

    expect(find.text("LET'S BUILD MY CHARACTER"), findsOneWidget);
    expect(find.byKey(const ValueKey('solution_backdrop')), findsOneWidget);

    final cta = tester.widget<PixelButton>(find.byType(PixelButton));
    expect(cta.fontSize, 12);
    expect(cta.minHeight, 64);
  });

  testWidgets('Screen exposes the full spoken line to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrapWithApp(SolutionView(onContinue: () {}), reducedMotion: true),
    );
    await tester.pump();

    final label = tester.getSemantics(find.byType(SolutionView)).label;
    expect(label, contains('every rep levels you up'));
    expect(label, contains('keep coming back'));
    handle.dispose();
  });

  testWidgets('CTA advances the flow (reduced motion fires immediately)', (
    tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(
      wrapWithApp(
        SolutionView(onContinue: () => continued = true),
        reducedMotion: true,
      ),
    );
    await tester.pump();

    await tester.tap(find.text("LET'S BUILD MY CHARACTER"));
    await tester.pump();
    expect(continued, isTrue);
  });

  testWidgets('Background tap completes the intro but does not advance', (
    tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(
      wrapWithApp(SolutionView(onContinue: () => continued = true)),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byType(SolutionView));
    await tester.pump();

    expect(continued, isFalse);
    // Snapped to the completed state: the full line is shown.
    expect(find.text('YOU WILL KEEP COMING\nBACK FOR MORE'), findsOneWidget);
  });

  testWidgets('Background tap mid-anticipation snaps to the settled state', (
    tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(
      wrapWithApp(SolutionView(onContinue: () => continued = true)),
    );
    // Into the anticipation inhale window (~520–760ms) — before the surge/hold —
    // a tap must not strand the user mid-power-up.
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byType(SolutionView));
    await tester.pump();

    // Snapped to settled: never advances, both lines whole, the revealed neutral
    // BIT, and the CTA now advances (skip stays responsive while CTA-gated).
    expect(continued, isFalse);
    expect(find.text('HERE, EVERY REP\nLEVELS YOU UP'), findsOneWidget);
    expect(find.text('YOU WILL KEEP COMING\nBACK FOR MORE'), findsOneWidget);
    final bit = tester.widget<BitMoodCore>(find.byType(BitMoodCore));
    expect(bit.reveal, 1.0);
    expect(bit.pose, BitPose.neutral);

    await tester.tap(find.text("LET'S BUILD MY CHARACTER"));
    await tester.pump();
    expect(continued, isTrue);
  });

  testWidgets('CTA is gated until the intro settles', (tester) async {
    var continued = false;
    await tester.pumpWidget(
      wrapWithApp(SolutionView(onContinue: () => continued = true)),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // Mid-intro: the CTA is disabled, so a tap does not advance.
    await tester.tap(find.byType(PixelButton), warnIfMissed: false);
    await tester.pump();
    expect(continued, isFalse);

    // Complete the intro (background tap), then the CTA advances.
    await tester.tap(find.byType(SolutionView));
    await tester.pump();
    await tester.tap(find.text("LET'S BUILD MY CHARACTER"));
    await tester.pump();
    expect(continued, isTrue);
  });

  testWidgets('Reduced-motion solution matches its golden', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      wrapWithApp(SolutionView(onContinue: () {}), reducedMotion: true),
    );
    await tester.pump();

    await expectLater(
      find.byType(SolutionView),
      matchesGoldenFile('goldens/solution_settled.png'),
    );
  });

  testWidgets('Flow advances from problem screen to solution screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingFlowPage()));

    // Advance past the welcome landing — through the departure + CRT boot
    // power-cycle — into the cold open.
    await tester.tap(find.text('GET STARTED'));
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (find.byType(ColdOpenView).evaluate().isEmpty &&
        DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    // Cold open is user-powered: tap to wake BIT, let it boot, tap to continue.
    await tester.tap(find.byType(ColdOpenView)); // wake
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3100)); // boot completes
    await tester.tap(find.byType(ColdOpenView)); // continue
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump();
    expect(find.byType(ProblemQuestionView), findsOneWidget);

    // Problem screen: first tap completes its intro, second tap continues.
    await tester.tap(find.byType(ProblemQuestionView));
    await tester.pump();
    await tester.tap(find.byType(ProblemQuestionView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 520));
    await tester.pump();

    expect(find.byType(SolutionView), findsOneWidget);
  });
}
