import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/home.dart';
import 'package:workout_track/widgets/arcade_bar.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(Widget child, {bool reduceMotion = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: SizedBox(width: 360, child: child)),
      ),
    );
  }

  testWidgets('shows level, an XP bar, and a profile-button semantics label', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(HomeLevelStrip(level: 7, totalXP: 1500, todayXP: 0, onTap: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('LV.7'), findsOneWidget);
    expect(find.byType(ArcadeBar), findsOneWidget);
    // Exposed to assistive tech as a labelled button to the profile (the button
    // node merges its child labels, so match the prefix rather than the whole).
    expect(
      find.bySemanticsLabel(
        RegExp(r'Level 7, \d+ percent to next level, open profile'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tap opens the profile', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(HomeLevelStrip(level: 3, totalXP: 200, todayXP: 0, onTap: () => taps++)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('home_level_strip')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('surfaces today gain when positive', (tester) async {
    await tester.pumpWidget(
      host(HomeLevelStrip(level: 5, totalXP: 800, todayXP: 120, onTap: () {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('+120 today'), findsOneWidget);
  });

  testWidgets('renders a still, legible bar under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        HomeLevelStrip(level: 7, totalXP: 1500, todayXP: 0, onTap: () {}),
        reduceMotion: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('LV.7'), findsOneWidget);
    expect(find.byType(ArcadeBar), findsOneWidget);
    // No perpetual-animation exception under reduced motion.
    expect(tester.takeException(), isNull);
  });
}
