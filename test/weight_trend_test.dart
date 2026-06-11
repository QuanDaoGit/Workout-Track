import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/body_metrics_models.dart';
import 'package:workout_track/models/weight_trend.dart';

WeightEntry _e(double kg, DateTime at) => WeightEntry(weightKg: kg, loggedAt: at);

void main() {
  final origin = DateTime(2026, 1, 1, 7);

  group('computeTrend', () {
    test('empty input yields no points', () {
      expect(computeTrend(const []), isEmpty);
    });

    test('single entry: trend equals the reading', () {
      final pts = computeTrend([_e(80, origin)]);
      expect(pts, hasLength(1));
      expect(pts.first.trendKg, 80);
    });

    test('initial trend is the first reading', () {
      final pts = computeTrend([
        _e(80, origin),
        _e(90, origin.add(const Duration(days: 1))),
      ]);
      expect(pts.first.trendKg, 80);
    });

    test('a 1-day gap blends at alphaDaily (0.1)', () {
      final pts = computeTrend([
        _e(80, origin),
        _e(90, origin.add(const Duration(days: 1))),
      ]);
      // 80 + 0.1 * (90 - 80) = 81.0
      expect(pts.last.trendKg, closeTo(81.0, 1e-9));
    });

    test('a long gap lets the trend catch up to reality', () {
      final pts = computeTrend([
        _e(80, origin),
        _e(90, origin.add(const Duration(days: 100))),
      ]);
      // factor = 1 - 0.9^100 ≈ 1, so the trend nearly reaches the new reading.
      expect(pts.last.trendKg, greaterThan(89.9));
    });

    test('a same-day re-log barely moves the trend (delta ≈ 0)', () {
      final pts = computeTrend([
        _e(80, origin),
        _e(90, origin), // identical timestamp → factor 0
      ]);
      expect(pts.last.trendKg, 80);
    });

    test('unsorted input is sorted by time before smoothing', () {
      final later = origin.add(const Duration(days: 1));
      final a = computeTrend([_e(90, later), _e(80, origin)]);
      final b = computeTrend([_e(80, origin), _e(90, later)]);
      expect(a.first.trendKg, b.first.trendKg);
      expect(a.last.trendKg, closeTo(b.last.trendKg, 1e-9));
      expect(a.first.trendKg, 80);
    });
  });

  group('trendIsReady', () {
    test('false below 4 entries', () {
      expect(
        trendIsReady([
          _e(80, origin),
          _e(80, origin.add(const Duration(days: 7))),
          _e(80, origin.add(const Duration(days: 14))),
        ]),
        isFalse,
      );
    });

    test('false when span under 14 days even with 4 entries', () {
      expect(
        trendIsReady([
          _e(80, origin),
          _e(80, origin.add(const Duration(days: 3))),
          _e(80, origin.add(const Duration(days: 6))),
          _e(80, origin.add(const Duration(days: 10))),
        ]),
        isFalse,
      );
    });

    test('true with 4+ entries spanning at least 14 days', () {
      expect(
        trendIsReady([
          _e(80, origin),
          _e(80, origin.add(const Duration(days: 5))),
          _e(80, origin.add(const Duration(days: 10))),
          _e(80, origin.add(const Duration(days: 15))),
        ]),
        isTrue,
      );
    });
  });

  group('trendVelocityPerWeek', () {
    test('null when not enough data', () {
      expect(trendVelocityPerWeek([_e(80, origin)]), isNull);
    });

    test('negative for a steadily declining trend', () {
      final entries = [
        for (var d = 0; d <= 28; d++)
          _e(80 - d * 0.1, origin.add(Duration(days: d))),
      ];
      final v = trendVelocityPerWeek(entries);
      expect(v, isNotNull);
      expect(v!, lessThan(0));
    });

    test('positive for a steadily rising trend', () {
      final entries = [
        for (var d = 0; d <= 28; d++)
          _e(80 + d * 0.1, origin.add(Duration(days: d))),
      ];
      final v = trendVelocityPerWeek(entries);
      expect(v, isNotNull);
      expect(v!, greaterThan(0));
    });
  });
}
