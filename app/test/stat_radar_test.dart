import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/stat_radar_read.dart';
import 'package:workout_track/services/stat_engine.dart';
import 'package:workout_track/widgets/stat_radar.dart';

void main() {
  group('rankBandFraction', () {
    test('a corner lands on a ring at each rank promotion threshold', () {
      expect(StatRadarRead.rankBandFraction(0), 0.0);
      expect(StatRadarRead.rankBandFraction(1000), closeTo(0.2, 1e-9));
      expect(StatRadarRead.rankBandFraction(3000), closeTo(0.4, 1e-9));
      expect(StatRadarRead.rankBandFraction(6000), closeTo(0.6, 1e-9));
      expect(StatRadarRead.rankBandFraction(9000), closeTo(0.8, 1e-9));
      expect(StatRadarRead.rankBandFraction(10000), closeTo(1.0, 1e-9));
    });

    test('interpolates within a band and clamps out-of-range', () {
      expect(
        StatRadarRead.rankBandFraction(500),
        closeTo(0.1, 1e-9),
      ); // mid-D band
      expect(StatRadarRead.rankBandFraction(-20), 0.0);
      // Post-S values (up to StatEngine.statCap) read as a full pentagon.
      expect(StatRadarRead.rankBandFraction(15000), 1.0);
    });

    test('is non-decreasing across the whole range', () {
      var prev = -1.0;
      for (var v = 0; v <= 10000; v += 50) {
        final f = StatRadarRead.rankBandFraction(v);
        expect(f, greaterThanOrEqualTo(prev));
        prev = f;
      }
    });
  });

  test(
    'rank-band edges mirror the StatEngine rank thresholds (drift guard)',
    () {
      // The radar's rings must sit exactly where ranks promote.
      expect(
        StatRadarRead.rankBandFraction(StatEngine.rankThresholdC),
        closeTo(0.2, 1e-9),
      );
      expect(
        StatRadarRead.rankBandFraction(StatEngine.rankThresholdB),
        closeTo(0.4, 1e-9),
      );
      expect(
        StatRadarRead.rankBandFraction(StatEngine.rankThresholdA),
        closeTo(0.6, 1e-9),
      );
      expect(
        StatRadarRead.rankBandFraction(StatEngine.rankThresholdS),
        closeTo(0.8, 1e-9),
      );
    },
  );

  group('StatRadar widget', () {
    testWidgets(
      'renders the three axis labels and highlights the dominant one',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatRadar(stats: {'STR': 6000, 'AGI': 1200, 'END': 3000}),
            ),
          ),
        );

        expect(find.text('STR'), findsOneWidget);
        expect(find.text('AGI'), findsOneWidget);
        expect(find.text('END'), findsOneWidget);
        // STR leads by >= 400, so it's the dominant (highlighted) axis.
        expect(
          find.byKey(const ValueKey('stat_radar_axis_STR_dominant')),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows the hint when every stat is below activation', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatRadar(stats: {'STR': 5, 'AGI': 5, 'END': 5}),
          ),
        ),
      );

      expect(find.text('Train to shape your build'), findsOneWidget);
    });
  });
}
