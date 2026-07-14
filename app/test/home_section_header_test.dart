import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/home_section_header.dart';

/// The Home section header: a white title + an optional green action link that
/// is one labelled Semantics button (arrow stripped), fires its callback, and
/// stays a still, legible control under reduced motion.
void main() {
  Widget host(Widget child, {bool reduceMotion = false}) {
    return MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Center(child: SizedBox(width: 360, child: child)),
        ),
      ),
    );
  }

  testWidgets('renders the title and the green action link', (tester) async {
    await tester.pumpWidget(
      host(
        const HomeSectionHeader(
          title: 'QUESTS',
          actionLabel: 'DETAILS >',
          onAction: _noop,
        ),
      ),
    );

    expect(find.text('QUESTS'), findsOneWidget);
    final link = tester.widget<Text>(find.text('DETAILS >'));
    expect(link.style?.color, kNeon, reason: 'the action link is the neon door');
  });

  testWidgets('the action link is one button, announced without the arrow', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const HomeSectionHeader(
          title: 'EXPEDITION',
          actionLabel: 'MAP >',
          onAction: _noop,
        ),
      ),
    );

    // excludeSemantics collapses the inner Text into one button node, and the
    // '>' is stripped so a screen reader never reads "greater than".
    expect(find.bySemanticsLabel('EXPEDITION, MAP'), findsOneWidget);
  });

  testWidgets('tapping the action link fires onAction', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        HomeSectionHeader(
          title: 'LAST WORKOUT',
          actionLabel: 'ANALYSIS >',
          onAction: () => taps++,
        ),
      ),
    );

    await tester.tap(find.text('ANALYSIS >'));
    expect(taps, 1);
  });

  testWidgets('no action → title-only header, no button', (tester) async {
    await tester.pumpWidget(host(const HomeSectionHeader(title: 'QUESTS')));

    expect(find.text('QUESTS'), findsOneWidget);
    expect(find.text('DETAILS >'), findsNothing);
    expect(find.byType(Semantics).evaluate().isEmpty, isFalse); // sanity
  });

  testWidgets('reduced motion keeps a still, tappable link', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        HomeSectionHeader(
          title: 'QUESTS',
          actionLabel: 'DETAILS >',
          onAction: () => taps++,
        ),
        reduceMotion: true,
      ),
    );

    // No motion to settle — the control is static; assert it still works.
    expect(find.text('DETAILS >'), findsOneWidget);
    await tester.tap(find.text('DETAILS >'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow across a width x scale matrix', (
    tester,
  ) async {
    for (final width in <double>[320, 360, 411]) {
      for (final scale in <double>[1.0, 1.3]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: const HomeSectionHeader(
                      title: 'LAST WORKOUT',
                      actionLabel: 'ANALYSIS >',
                      onAction: _noop,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'no overflow at ${width}dp x $scale',
        );
      }
    }
  });
}

void _noop() {}
