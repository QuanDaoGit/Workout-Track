import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/xp_level_meter.dart';

void main() {
  Widget host(Widget child, {bool reducedMotion = false}) => MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Center(child: child),
      ),
    ),
  );

  testWidgets('level-up reduced motion shows the big LEVEL headline', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const XpLevelMeter(oldTotalXP: 0, newTotalXP: 20), // level 1 -> 2
        reducedMotion: true,
      ),
    );
    await tester.pump();
    // The meter is the level-up display now (no separate hero beat).
    expect(find.text('LEVEL 2'), findsOneWidget);
    expect(find.text('LV 2'), findsNothing);
  });

  testWidgets('level-up settles on the final LEVEL and fires onLevelUp once', (
    tester,
  ) async {
    var levelUps = 0;
    await tester.pumpWidget(
      host(
        XpLevelMeter(
          oldTotalXP: 0,
          newTotalXP: 20,
          onLevelUp: () => levelUps++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 2'), findsWidgets); // GlitchText renders layers
    expect(levelUps, 1); // crossed exactly one level boundary (1 -> 2)
  });

  testWidgets('no level-up fires no callback and holds the level', (
    tester,
  ) async {
    var levelUps = 0;
    await tester.pumpWidget(
      host(
        XpLevelMeter(
          oldTotalXP: 15, // level 2
          newTotalXP: 30, // still level 2
          onLevelUp: () => levelUps++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('LV 2'), findsOneWidget);
    expect(levelUps, 0);
  });

  // Strict single-peak: when level-up loses the hero ladder (a rank-up wins),
  // the parent passes prominent:false so the meter climbs quietly as `LV n`
  // instead of firing a second big `LEVEL N` headline.
  testWidgets('non-prominent level-up climbs as LV, not the big LEVEL headline', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const XpLevelMeter(oldTotalXP: 0, newTotalXP: 20, prominent: false)),
    );
    // Drive the climb to completion in steps. pumpAndSettle can't drain the
    // meter's bare 240ms post-level-up Future.delayed in non-prominent mode (no
    // local float animation bridges it), so advance the clock explicitly.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('LV 2'), findsOneWidget);
    expect(find.text('LEVEL 2'), findsNothing);
  });

  testWidgets('non-prominent level-up under reduced motion shows small LV', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const XpLevelMeter(oldTotalXP: 0, newTotalXP: 20, prominent: false),
        reducedMotion: true,
      ),
    );
    await tester.pump();
    expect(find.text('LV 2'), findsOneWidget);
    expect(find.text('LEVEL 2'), findsNothing);
  });
}
