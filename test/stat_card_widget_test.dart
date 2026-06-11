import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/radar_stat_icon.dart';
import 'package:workout_track/widgets/segmented_progress_bar.dart';
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

  testWidgets('StatRadar highlights the dominant readable axis', (
    tester,
  ) async {
    const cases = [
      (dominant: 'STR', stats: {'STR': 564, 'AGI': 346, 'END': 297}),
      (dominant: 'AGI', stats: {'STR': 336, 'AGI': 512, 'END': 332}),
      (dominant: 'END', stats: {'STR': 353, 'AGI': 319, 'END': 452}),
    ];

    for (final entry in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StatRadar(stats: entry.stats)),
        ),
      );

      expect(
        find.byKey(ValueKey('stat_radar_axis_${entry.dominant}_dominant')),
        findsOneWidget,
      );
      for (final label in ['STR', 'AGI', 'END']) {
        if (label == entry.dominant) continue;
        expect(
          find.byKey(ValueKey('stat_radar_axis_${label}_normal')),
          findsOneWidget,
        );
      }
    }
  });

  testWidgets('StatRadar does not highlight noisy ties', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatRadar(stats: {'STR': 10, 'AGI': 10, 'END': 10}),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('stat_radar_axis_STR_dominant')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('stat_radar_axis_AGI_dominant')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('stat_radar_axis_END_dominant')),
      findsNothing,
    );
  });

  testWidgets('StatCard gives a neutral five-second status read', (
    tester,
  ) async {
    const cases = [
      (read: 'POWER', stats: {'STR': 564, 'AGI': 346, 'END': 297}),
      (read: 'CONTROL', stats: {'STR': 336, 'AGI': 512, 'END': 332}),
      (read: 'STAMINA', stats: {'STR': 353, 'AGI': 319, 'END': 452}),
      (read: 'BALANCED', stats: {'STR': 300, 'AGI': 300, 'END': 300}),
    ];

    for (final entry in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 620, child: StatCard(stats: entry.stats)),
          ),
        ),
      );

      expect(
        find.textContaining('STATUS: ${entry.read} - LOW VITALITY'),
        findsOneWidget,
      );
      expect(find.text('ASSASSIN'), findsNothing);
      expect(find.text('BRUISER'), findsNothing);
      expect(find.text('TANK'), findsNothing);
    }
  });

  testWidgets('StatCard status read reflects vitality buckets', (tester) async {
    const cases = [
      (vit: 39, label: 'LOW VITALITY'),
      (vit: 40, label: 'RECOVERING'),
      (vit: 70, label: 'READY'),
      (vit: 100, label: 'FULL VITALITY'),
    ];

    for (final entry in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 620,
              child: StatCard(
                stats: {
                  'STR': 10,
                  'AGI': 10,
                  'END': 10,
                  'VIT': entry.vit,
                  'LCK': 0,
                },
              ),
            ),
          ),
        ),
      );

      expect(
        find.textContaining('STATUS: BALANCED - ${entry.label}'),
        findsOneWidget,
      );
    }
  });

  testWidgets(
    'StatCard shows VIT recovery meter + LCK diamonds, expands STR/AGI/END',
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
                  'LCK': 4,
                },
              ),
            ),
          ),
        ),
      );

      // Hidden state keeps progression math out of the quick-read panel.
      expect(find.text('NEXT: STR -> [C] AT 100'), findsNothing);
      expect(find.text('Train to shape your build'), findsNothing);
      expect(
        find.textContaining('STATUS: BALANCED - LOW VITALITY'),
        findsOneWidget,
      );
      expect(find.textContaining('STR POWER'), findsNothing);
      expect(find.textContaining('AGI CONTROL'), findsNothing);
      expect(find.textContaining('END STAMINA'), findsNothing);
      // VIT recovery meter (a 'REC' gauge, not a graded stat).
      expect(find.text('VIT'), findsOneWidget);
      expect(find.text('REC'), findsOneWidget);
      final headerIcon = tester.widget<Image>(
        find.byKey(const ValueKey('stat_card_header_icon')),
      );
      expect(headerIcon.image, isA<AssetImage>());
      expect(
        (headerIcon.image as AssetImage).assetName,
        RadarStatIcons.statsBuild,
      );
      _expectImageAsset(
        tester,
        const ValueKey('stat_card_vit_icon'),
        RadarStatIcons.vitalityEmpty,
      );
      expect(find.byKey(const ValueKey('stat_card_lck_icon')), findsNothing);
      // LCK consistency row is back: 4 diamonds, 2 filled at 4 clean weeks.
      expect(find.text('LCK'), findsOneWidget);
      expect(find.text('◆◆◇◇'), findsOneWidget);
      expect(find.text('[ SHOW DETAIL ]'), findsOneWidget);

      await tester.tap(find.text('[ SHOW DETAIL ]'));
      await tester.pumpAndSettle();

      expect(find.text('[ HIDE DETAIL ]'), findsOneWidget);
      expect(find.textContaining('STR POWER'), findsOneWidget);
      expect(find.textContaining('AGI CONTROL'), findsOneWidget);
      expect(find.textContaining('END STAMINA'), findsOneWidget);
      expect(find.text('NEXT: STR -> [C] AT 100'), findsOneWidget);
      // Detail rows are the capability trio STR/AGI/END → 3 [D] grades.
      // VIT (recovery meter) and LCK (diamonds) carry no letter grade.
      expect(find.text('[D]'), findsNWidgets(3));
      // DEF never renders.
      expect(find.text('DEF'), findsNothing);
    },
  );

  testWidgets('StatCard keeps recovery neutral and rank color chip-only', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 620,
            child: StatCard(
              stats: {
                'STR': 420,
                'END': 130,
                'DEF': 10,
                'VIT': 11,
                'AGI': 310,
                'LCK': 25,
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('[ SHOW DETAIL ]'));
    await tester.pumpAndSettle();

    final vitValue = tester.widget<Text>(
      find.byKey(const ValueKey('stat_card_vit_value')),
    );
    final vitRec = tester.widget<Text>(
      find.byKey(const ValueKey('stat_card_vit_rec')),
    );
    final lckValue = tester.widget<Text>(
      find.byKey(const ValueKey('stat_card_lck_value')),
    );
    final strValue = tester.widget<Text>(
      find.byKey(const ValueKey('stat_card_STR_value')),
    );
    final strRank = tester.widget<Text>(
      find.byKey(const ValueKey('stat_card_STR_rank')),
    );

    expect(vitValue.style?.color, kText);
    expect(vitRec.style?.color, kMutedText);
    expect(lckValue.style?.color, kAmber);
    expect(strValue.style?.color, kText);
    expect(strRank.style?.color, isNot(kText));
  });

  testWidgets('StatCard maps VIT values to heart assets', (tester) async {
    const cases = [
      (value: 10, asset: RadarStatIcons.vitalityEmpty),
      (value: 20, asset: RadarStatIcons.vitality20),
      (value: 40, asset: RadarStatIcons.vitality40),
      (value: 60, asset: RadarStatIcons.vitality60),
      (value: 80, asset: RadarStatIcons.vitality80),
      (value: 100, asset: RadarStatIcons.vitalityFull),
    ];

    for (final entry in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 620,
              child: StatCard(
                stats: {
                  'STR': 10,
                  'END': 10,
                  'DEF': 10,
                  'VIT': entry.value,
                  'AGI': 10,
                  'LCK': 0,
                },
              ),
            ),
          ),
        ),
      );

      _expectImageAsset(
        tester,
        const ValueKey('stat_card_vit_icon'),
        entry.asset,
      );
    }
  });

  testWidgets('StatCard VIT bar fills red-deepening with the value', (
    tester,
  ) async {
    Future<({Color color, double widthFactor, double fillHeight})> fillFor(
      int value,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 620,
              child: StatCard(
                stats: {
                  'STR': 10,
                  'END': 10,
                  'DEF': 10,
                  'VIT': value,
                  'AGI': 10,
                  'LCK': 0,
                },
              ),
            ),
          ),
        ),
      );
      final fillKey = const ValueKey('stat_card_vit_fill');
      final box = tester.widget<ColoredBox>(find.byKey(fillKey));
      final fill = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('stat_card_vit_fill_fraction')),
      );
      return (
        color: box.color,
        widthFactor: fill.widthFactor ?? 0,
        fillHeight: tester.getSize(find.byKey(fillKey)).height,
      );
    }

    final low = await fillFor(10);
    final high = await fillFor(100);

    // Width scales with the value.
    expect(low.widthFactor, 0.1);
    expect(high.widthFactor, 1.0);

    // Regression: the fill paints with real height (it previously collapsed to
    // zero, rendering the bar empty regardless of value).
    expect(low.fillHeight, greaterThan(0));
    expect(high.fillHeight, greaterThan(0));

    // Red-deepening: a full meter is red-ward (red channel dominant) and more
    // opaque than a near-empty one.
    expect(high.color.r, greaterThan(high.color.g));
    expect(high.color.r, greaterThan(high.color.b));
    expect(low.color.a, lessThan(high.color.a));
    // Not the avoided accent colors.
    expect(high.color, isNot(kAmber));
    expect(high.color, isNot(kCyan));
  });

  test('RadarStatIcons maps LCK values to streak assets', () {
    // Weekly ladder: none at 0 diamonds, active at 1-3 (1/3/6 weeks), hot at 4
    // (10+ weeks).
    const cases = [
      (value: 0, asset: RadarStatIcons.lckNone),
      (value: 1, asset: RadarStatIcons.lckActive),
      (value: 5, asset: RadarStatIcons.lckActive),
      (value: 9, asset: RadarStatIcons.lckActive),
      (value: 10, asset: RadarStatIcons.lckHot),
      (value: 100, asset: RadarStatIcons.lckHot),
    ];

    for (final entry in cases) {
      expect(RadarStatIcons.lckForValue(entry.value), entry.asset);
    }
  });

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

    // AGI is lowest among visible STR/AGI/END (DEF/VIT excluded) → C at 100.
    expect(find.text('NEXT: AGI -> [C] AT 100'), findsNothing);

    await tester.tap(find.text('[ SHOW DETAIL ]'));
    await tester.pumpAndSettle();

    expect(find.text('NEXT: AGI -> [C] AT 100'), findsOneWidget);
  });

  testWidgets('StatCard info button explains the stat board', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          // Scrollable like the real profile page — the expanded card at the
          // taller radar height exceeds a bare 600px test surface otherwise.
          body: SingleChildScrollView(
            child: SizedBox(
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
      ),
    );

    // All visible stats at S (>=900) → HOLD.
    expect(find.text('NEXT: HOLD [S]'), findsNothing);

    await tester.tap(find.text('[ SHOW DETAIL ]'));
    await tester.pumpAndSettle();

    expect(find.text('NEXT: HOLD [S]'), findsOneWidget);

    expect(find.text('?'), findsOneWidget);

    await tester.tap(find.text('?'));
    await tester.pumpAndSettle();

    expect(find.text('STAT BOARD'), findsOneWidget);
    // Three categories explained.
    expect(
      find.textContaining('STR is power, AGI is control, END is stamina'),
      findsOneWidget,
    );
    expect(find.textContaining('VIT is recovery'), findsOneWidget);
    expect(find.textContaining('LCK is consistency'), findsOneWidget);
    expect(find.textContaining('XP-multiplier tier'), findsOneWidget);
  });

  testWidgets('StatCard detail bars fill on the rank-band scale', (
    tester,
  ) async {
    Future<List<int>> litCellsFor(int value) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 620,
                child: StatCard(
                  key: ValueKey(value),
                  stats: {
                    'STR': value,
                    'AGI': value,
                    'END': value,
                    'VIT': 10,
                    'LCK': 0,
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('[ SHOW DETAIL ]'));
      await tester.pumpAndSettle();
      return tester
          .widgetList<SegmentedProgressBar>(find.byType(SegmentedProgressBar))
          .map((bar) => bar.litCells)
          .toList();
    }

    // Each rank D/C/B/A/S = 2 of 10 cells; promotions at 100/300/600/900. These
    // differ from the old linear value/100 (e.g. 300→3, 900→9), so they pin the
    // rank-band scale.
    expect(
      await litCellsFor(50),
      everyElement(1),
    ); // mid-D — early progress shows
    expect(await litCellsFor(100), everyElement(2)); // just promoted to C
    expect(await litCellsFor(300), everyElement(4)); // just promoted to B
    expect(await litCellsFor(900), everyElement(8)); // S
    expect(await litCellsFor(1000), everyElement(10)); // cap
  });
}

void _expectImageAsset(WidgetTester tester, Key key, String expectedAsset) {
  final image = tester.widget<Image>(
    find.descendant(of: find.byKey(key), matching: find.byType(Image)),
  );
  final provider = image.image;
  expect(provider, isA<AssetImage>());
  expect((provider as AssetImage).assetName, expectedAsset);
}
