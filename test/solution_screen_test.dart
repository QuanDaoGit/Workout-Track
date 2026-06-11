import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/onboarding/cold_open_page.dart';
import 'package:workout_track/pages/onboarding/onboarding_flow_page.dart';
import 'package:workout_track/pages/onboarding/problem_question_page.dart';
import 'package:workout_track/pages/onboarding/solution_page.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/pixel_button.dart';
import 'package:workout_track/widgets/streak_orbit_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrapWithApp(Widget child, {bool reducedMotion = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('Reduced motion renders the final solution copy and CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(SolutionView(onContinue: () {}), reducedMotion: true),
    );
    await tester.pump();

    expect(find.text('HERE, EVERY REP'), findsOneWidget);
    expect(find.text('LEVELS YOU UP'), findsOneWidget);
    expect(
      find.text('you can see your work.', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('you become stronger every rep.', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('and you will keep coming back.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text("LET'S BUILD MY CHARACTER"), findsOneWidget);
    expect(find.byKey(const ValueKey('solution_backdrop')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('solution_aspiration_tease')),
      findsOneWidget,
    );
    final streak = tester.widget<StreakOrbitIcon>(
      find.byType(StreakOrbitIcon),
    );
    expect(streak.size, 168);

    final cta = tester.widget<PixelButton>(find.byType(PixelButton));
    expect(cta.fontSize, 12);
    expect(cta.minHeight, 64);

    final levelLine = tester.widget<Text>(find.text('LEVELS YOU UP'));
    expect(levelLine.style?.color, kAmber);
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

    // Tap the background (screen center is well above the CTA at y640).
    await tester.tap(find.byType(SolutionView));
    await tester.pump();

    expect(continued, isFalse);
    // Statement is now in its completed state.
    expect(find.text('LEVELS YOU UP'), findsOneWidget);
  });

  testWidgets('Slam effects cover the full viewport, not the design frame', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(wrapWithApp(SolutionView(onContinue: () {})));
    await tester.pump(const Duration(milliseconds: 650));

    expect(
      tester.getSize(find.byKey(const ValueKey('solution_effect_layer'))),
      const Size(430, 932),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('solution_effect_border'))),
      const Size(430, 932),
    );
    final borderBox = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('solution_effect_border')),
    );
    final decoration = borderBox.decoration as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.top.color, kAmber);
    expect(
      tester.getSize(find.byKey(const ValueKey('solution_design_frame'))),
      const Size(390, 844),
    );
  });

  testWidgets('Solution keeps the promise screen free of transient sprites', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithApp(SolutionView(onContinue: () {})));
    await tester.pump(const Duration(milliseconds: 1220));

    expect(
      find.byKey(const ValueKey('solution_aspiration_tease')),
      findsNothing,
    );
  });

  testWidgets('Reduced motion skips active full-screen effects', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(SolutionView(onContinue: () {}), reducedMotion: true),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('solution_effect_layer')), findsNothing);
    expect(find.byKey(const ValueKey('solution_effect_border')), findsNothing);
  });

  testWidgets('CTA advances after the intro is snapped complete', (
    tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(
      wrapWithApp(SolutionView(onContinue: () => continued = true)),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byType(SolutionView));
    await tester.pump();
    await tester.tap(find.text("LET'S BUILD MY CHARACTER"));
    await tester.pump(const Duration(milliseconds: 300));

    expect(continued, isTrue);
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

    await tester.tap(find.byType(ColdOpenView));
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

  testWidgets('Solution keeps the aspiration tease after settling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(wrapWithApp(SolutionView(onContinue: () {})));
    await tester.pump(const Duration(milliseconds: 1850));

    expect(
      find.byKey(const ValueKey('solution_aspiration_tease')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byKey(const ValueKey('solution_aspiration_tease')),
      findsOneWidget,
    );
    expect(find.byType(StreakOrbitIcon), findsOneWidget);

    final futureSelfBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('solution_aspiration_tease')))
        .dy;
    final ctaTop = tester.getTopLeft(find.byType(PixelButton)).dy;
    expect(ctaTop - futureSelfBottom, greaterThanOrEqualTo(32));
  });
}
