import 'dart:math' as math;

import 'body_metrics_models.dart';

/// One smoothed point on the body-weight trend line.
class TrendPoint {
  const TrendPoint(this.at, this.trendKg);

  final DateTime at;

  /// Canonical kg. Convert to display units at the edge via `kgToDisplay`.
  final double trendKg;
}

/// Time-aware exponentially-weighted moving average of body weight — the
/// "trend weight" the serious trackers (Hacker's Diet, MacroFactor, Happy
/// Scale) use to filter daily water/glycogen noise out of the scale number.
///
/// The weight of each new reading scales with the elapsed time since the last
/// one, so the curve behaves correctly whether logs are daily or sparse:
///   factor = 1 - (1 - alphaDaily)^deltaDays
///   trend  = prevTrend + factor * (reading - prevTrend)
/// A 1-day gap blends at `alphaDaily` (≈0.1 ≈ a 20-day average); a long gap
/// pushes `factor → 1` so the trend catches up to reality; a same-day re-log
/// (deltaDays ≈ 0) barely moves it. Days with no reading are never fabricated —
/// the trend is only ever evaluated at real entries.
List<TrendPoint> computeTrend(
  List<WeightEntry> entries, {
  double alphaDaily = 0.1,
}) {
  if (entries.isEmpty) return const [];
  final sorted = [...entries]..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

  var trend = sorted.first.weightKg;
  final points = <TrendPoint>[TrendPoint(sorted.first.loggedAt, trend)];
  for (var i = 1; i < sorted.length; i++) {
    final deltaDays = math.max(
      0.0,
      sorted[i].loggedAt.difference(sorted[i - 1].loggedAt).inMinutes / 1440.0,
    );
    final factor = 1 - math.pow(1 - alphaDaily, deltaDays).toDouble();
    trend += factor * (sorted[i].weightKg - trend);
    points.add(TrendPoint(sorted[i].loggedAt, trend));
  }
  return points;
}

/// Whether there is enough data for the smoothed trend (and any velocity) to be
/// honest rather than noise dressed up as a precise readout. Below this, callers
/// show raw points with a "trend builds as you log" message instead.
bool trendIsReady(List<WeightEntry> entries) {
  if (entries.length < 4) return false;
  final sorted = [...entries]..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  return sorted.last.loggedAt.difference(sorted.first.loggedAt).inDays >= 14;
}

/// Muted trend velocity in canonical kg per week over the trailing
/// [windowDays], or null when [trendIsReady] is false. Body-neutral: the sign
/// is data, not judgment — callers render it without good/bad colour.
double? trendVelocityPerWeek(
  List<WeightEntry> entries, {
  int windowDays = 30,
}) {
  if (!trendIsReady(entries)) return null;
  final points = computeTrend(entries);
  if (points.length < 2) return null;

  final last = points.last;
  final cutoff = last.at.subtract(Duration(days: windowDays));
  // First trend point inside the trailing window (falls back to the earliest).
  var start = points.first;
  for (final p in points) {
    if (!p.at.isBefore(cutoff)) {
      start = p;
      break;
    }
  }
  final days = last.at.difference(start.at).inMinutes / 1440.0;
  if (days <= 0) return null;
  return (last.trendKg - start.trendKg) / days * 7.0;
}
