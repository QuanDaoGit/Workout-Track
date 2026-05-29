import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/stat_card.dart';
import 'package:workout_track/widgets/stat_radar.dart';

void main() {
  testWidgets('StatRadar zero state shows the STR/AGI/END triangle only', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatRadar(
            stats: {
              'STR': 0,
              'END': 0,
              'DEF': 0,
              'VIT': 0,
              'AGI': 0,
              'LCK': 100,
            },
          ),
        ),
      ),
    );

    expect(find.text('Train to shape your build'), findsOneWidget);
    expect(find.text('STR'), findsOneWidget);
    expect(find.text('AGI'), findsOneWidget);
    expect(find.text('END'), findsOneWidget);
    // DEF and VIT are off the radar now; LCK never was.
    expect(find.text('DEF'), findsNothing);
    expect(find.text('VIT'), findsNothing);
    expect(find.text('LCK'), findsNothing);
  });

  testWidgets(
    'StatCard shows VIT bar, no LCK row, and expands STR/AGI/END detail',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 620,
              child: StatCard(
                stats: {
                  'STR': 10,
                  'END': 10,
                  'DEF': 10,
                  'VIT': 10,
                  'AGI': 10,
                  'LCK': 50,
                },
              ),
            ),
          ),
        ),
      );

      // New ladder: lowest visible stat (10) targets C at 100.
      expect(find.text('NEXT: STR -> [C] AT 100'), findsOneWidget);
      expect(find.text('Train to shape your build'), findsNothing);
      // LCK is no longer a stat row here (it's a buff badge by the XP bar).
      expect(find.text('LCK'), findsNothing);
      expect(find.text('◆◆◇◇'), findsNothing);
      // VIT bar is always visible below the radar.
      expect(find.text('VIT'), findsOneWidget);
      expect(find.text('[ SHOW DETAIL ]'), findsOneWidget);

      await tester.tap(find.text('[ SHOW DETAIL ]'));
      await tester.pumpAndSettle();

      expect(find.text('[ HIDE DETAIL ]'), findsOneWidget);
      // Detail rows: STR/AGI/END (3) + the always-on VIT bar = 4 [D] grades.
      expect(find.text('[D]'), findsNWidgets(4));
      // DEF never renders.
      expect(find.text('DEF'), findsNothing);
    },
  );

  testWidgets('StatCard next milestone targets the lowest visible stat', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 620,
            child: StatCard(
              stats: {'STR': 300, 'DEF': 50, 'VIT': 120, 'AGI': 0, 'LCK': 0},
            ),
          ),
        ),
      ),
    );

    // AGI is lowest among visible STR/AGI/END/VIT (DEF excluded) → C at 100.
    expect(find.text('NEXT: AGI -> [C] AT 100'), findsOneWidget);
  });

  testWidgets('StatCard can show one-time END history note', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 620,
            child: StatCard(
              showEndBackfillNotice: true,
              stats: {
                'STR': 20,
                'END': 30,
                'DEF': 10,
                'VIT': 15,
                'AGI': 5,
                'LCK': 0,
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('+END FROM HISTORY'), findsOneWidget);
  });

  testWidgets('StatCard info button explains the stat board', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 620,
            child: StatCard(
              stats: {
                'STR': 900,
                'END': 900,
                'DEF': 900,
                'VIT': 900,
                'AGI': 900,
                'LCK': 0,
              },
            ),
          ),
        ),
      ),
    );

    // All visible stats at S (>=900) → HOLD.
    expect(find.text('NEXT: HOLD [S]'), findsOneWidget);

    expect(find.text('?'), findsOneWidget);

    await tester.tap(find.text('?'));
    await tester.pumpAndSettle();

    expect(find.text('STAT BOARD'), findsOneWidget);
    expect(
      find.text(
        'STR / AGI / VIT grow from logged workout volume. END grows from logged reps.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'LCK is a buff beside your XP bar — your streak multiplies XP.',
      ),
      findsOneWidget,
    );
  });
}
