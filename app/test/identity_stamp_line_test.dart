import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/identity_stamp_line.dart';

/// The profile competence stamp line: rank is the colour-laddered headline,
/// level the muted detail, on one line, with a single screen-reader
/// announcement and no overflow across the support matrix.
void main() {
  Widget host(Widget child, {double width = 360, double textScale = 1.0}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('rank is the headline colour, level recedes to muted', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const IdentityStampLine(level: 22, rank: 'Champion')),
    );

    // Rank word is uppercased and carries the rank-ladder colour (red).
    final rankText = tester.widget<Text>(find.text('CHAMPION'));
    expect(rankText.style?.color, kDanger, reason: 'Champion is the red headline');

    // Level is present and muted — never a second accent competing with rank.
    final lvText = tester.widget<Text>(find.text('LV. 22'));
    expect(lvText.style?.color, kMutedText, reason: 'level recedes to metadata');
  });

  testWidgets('glyph + word give a non-colour role cue', (tester) async {
    await tester.pumpWidget(
      host(const IdentityStampLine(level: 7, rank: 'Knight')),
    );
    expect(find.byIcon(Icons.shield_sharp), findsOneWidget);
    expect(find.byIcon(Icons.bolt_sharp), findsOneWidget);
    // Amber rank still reads via the word + glyph, not colour alone.
    expect(find.text('KNIGHT'), findsOneWidget);
  });

  testWidgets('announces once, with the true (un-uppercased) values', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const IdentityStampLine(level: 22, rank: 'Champion')),
    );
    expect(
      find.bySemanticsLabel('Rank Champion, level 22'),
      findsOneWidget,
      reason: 'excludeSemantics collapses the inner nodes into one label',
    );
  });

  testWidgets('lays out without overflow across the width x text-scale matrix', (
    tester,
  ) async {
    for (final width in <double>[320, 360, 411]) {
      for (final scale in <double>[1.0, 1.3]) {
        await tester.pumpWidget(
          host(
            const IdentityStampLine(level: 22, rank: 'Champion'),
            width: width,
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'no overflow at ${width}dp x $scale',
        );
      }
    }
  });
}
