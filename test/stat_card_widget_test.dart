import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/stat_card.dart';
import 'package:workout_track/widgets/stat_radar.dart';

void main() {
  testWidgets('StatRadar zero state omits LCK axis and shows training hint', (
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
    expect(find.text('END'), findsOneWidget);
    expect(find.text('DEF'), findsOneWidget);
    expect(find.text('VIT'), findsOneWidget);
    expect(find.text('AGI'), findsOneWidget);
    expect(find.text('LCK'), findsNothing);
  });

  testWidgets(
    'StatCard shows compact view by default and expands detail rows',
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

      expect(find.text('NEXT: STR -> [C] AT 200'), findsOneWidget);
      expect(find.text('Train to shape your build'), findsNothing);
      expect(find.text('\u25C6\u25C6\u25C7\u25C7'), findsOneWidget);
      expect(find.text('[D]'), findsNothing);
      expect(find.text('[ SHOW DETAIL ]'), findsOneWidget);

      await tester.tap(find.text('[ SHOW DETAIL ]'));
      await tester.pumpAndSettle();

      expect(find.text('[ HIDE DETAIL ]'), findsOneWidget);
      expect(find.text('[D]'), findsNWidgets(5));
      expect(find.text('10'), findsNWidgets(5));
    },
  );

  testWidgets('StatCard next milestone targets the lowest training stat', (
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

    expect(find.text('NEXT: AGI -> [C] AT 200'), findsOneWidget);
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
                'STR': 800,
                'END': 800,
                'DEF': 800,
                'VIT': 800,
                'AGI': 800,
                'LCK': 0,
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('NEXT: HOLD [S]'), findsOneWidget);

    expect(find.text('?'), findsOneWidget);

    await tester.tap(find.text('?'));
    await tester.pumpAndSettle();

    expect(find.text('STAT BOARD'), findsOneWidget);
    expect(
      find.text(
        'STR / DEF / VIT / AGI grow from logged workout volume. END grows from logged reps.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('LCK comes from your current streak and multiplies XP.'),
      findsOneWidget,
    );
  });
}
