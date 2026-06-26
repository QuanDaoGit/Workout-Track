import 'dart:math';

import '../models/workout_models.dart';
import 'progressive_overload_service.dart';

/// A plain, body-neutral verdict on where a lift's estimated strength is headed.
/// `fresh` = one session (no trend yet). `rebuilding` is the **honest** down
/// state — a real recent drop (detrain/deload) named kindly, never punished (no
/// alarm colour, no "stalled"): direction stays truthful, tone stays neutral.
enum StrengthMomentum { newBest, rising, holding, rebuilding, fresh }

/// One exercise's estimated-1RM progression: the best Epley e1RM per session it
/// was logged with a weighted set, plus the headline read the strength surfaces
/// show. Display only — feeds no XP/stat/overload path.
class StrengthTrend {
  const StrengthTrend({
    required this.exerciseId,
    required this.exerciseName,
    required this.e1rmPoints,
    required this.sessionCount,
    required this.firstE1rm,
    required this.bestE1rm,
    required this.lastE1rm,
    required this.lastDate,
  });

  final String exerciseId;

  /// The **logged** name (so a since-renamed/deleted exercise still reads).
  final String exerciseName;

  /// Best e1RM per weighted session, oldest → newest, capped to the most recent
  /// [StrengthTrendService._maxPoints] (the sparkline teaser). A single point
  /// (one session) has no real trend — rendered as a calm locked row.
  final List<double> e1rmPoints;

  /// Number of sessions with ≥1 weighted set (the eligibility + "needs one more"
  /// signal). Counts the full history, not just the capped window.
  final int sessionCount;

  /// All-time first / best / last e1RM (uncapped) — drive the deltas + verdict.
  final double firstE1rm;
  final double bestE1rm;
  final double lastE1rm;
  final DateTime lastDate;

  bool get hasTrend => sessionCount >= 2;

  /// Estimated-max gain since the first logged weighted session (signed).
  double get deltaSinceStart => lastE1rm - firstE1rm;

  /// Change in estimated max from the previous weighted session (signed) — the
  /// recent step, matching the [momentum] verdict's timeframe. 0 when no trend.
  double get deltaVsPrevious => e1rmPoints.length < 2
      ? 0
      : lastE1rm - e1rmPoints[e1rmPoints.length - 2];

  /// The body-neutral, **direction-truthful** verdict. A ±2.5% band around a
  /// recent baseline (≈3 sessions back) counts as `holding`; an all-time high
  /// reached in the latest session is `newBest`; a real recent drop is the
  /// kind `rebuilding`, never hidden as holding (Codex F3).
  StrengthMomentum get momentum {
    if (sessionCount < 2 || e1rmPoints.length < 2) return StrengthMomentum.fresh;
    final baseline = e1rmPoints[max(0, e1rmPoints.length - 4)];
    final prev = e1rmPoints[e1rmPoints.length - 2];
    final isAllTimeHigh = lastE1rm >= bestE1rm - 1e-6;
    final roseLast = lastE1rm > prev + 1e-6;
    if (isAllTimeHigh && roseLast) return StrengthMomentum.newBest;
    if (baseline <= 0) return StrengthMomentum.holding;
    final ratio = lastE1rm / baseline;
    if (ratio >= 1.025) return StrengthMomentum.rising;
    if (ratio <= 0.975) return StrengthMomentum.rebuilding;
    return StrengthMomentum.holding;
  }
}

/// Pure analyzer behind the browsable **strength index**: rolls logged sessions
/// into per-exercise e1RM progression, using the *same* Epley estimate as
/// [ExerciseHistoryPage]'s chart (`ProgressiveOverloadService.epley1RM`) so the
/// index row and the detail chart can't disagree on the metric. Stateless and
/// session-driven → trivially unit-testable with fixtures.
class StrengthTrendService {
  const StrengthTrendService._();

  /// Sparkline cap — the most recent N weighted sessions (a teaser, not the full
  /// chart, which lives on the detail page).
  static const int _maxPoints = 12;

  /// Per-exercise [StrengthTrend], sorted **most-recently-trained first** (the
  /// "what am I working on" default). Includes every exercise with ≥[minSessions]
  /// weighted-set sessions; bodyweight-only logs (no positive weight) contribute
  /// no e1RM and are excluded. Warm-ups are excluded by construction
  /// ([ExerciseLog.sets] holds working sets only); partial sessions are skipped.
  static List<StrengthTrend> trendsFor(
    List<WorkoutSession> sessions, {
    int minSessions = 1,
  }) {
    // exerciseId -> chronological (date, bestE1rm) per qualifying session.
    final byExercise = <String, List<({DateTime date, double e1rm})>>{};
    final names = <String, String>{};

    for (final session in sessions) {
      if (session.isPartial) continue;
      for (final log in session.exercises) {
        var best = 0.0;
        for (final set in log.sets) {
          if (set.weight <= 0) continue;
          best = max(
            best,
            ProgressiveOverloadService.epley1RM(set.weight, set.reps, false),
          );
        }
        if (best <= 0) continue; // no weighted set this session → no e1RM
        byExercise
            .putIfAbsent(log.exerciseId, () => [])
            .add((date: session.date, e1rm: best));
        names[log.exerciseId] = log.exerciseName;
      }
    }

    final trends = <StrengthTrend>[];
    for (final entry in byExercise.entries) {
      if (entry.value.length < minSessions) continue;
      final points = entry.value.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      final recent = points.length > _maxPoints
          ? points.sublist(points.length - _maxPoints)
          : points;
      var best = 0.0;
      for (final p in points) {
        best = max(best, p.e1rm);
      }
      trends.add(
        StrengthTrend(
          exerciseId: entry.key,
          exerciseName: names[entry.key] ?? entry.key,
          e1rmPoints: [for (final p in recent) p.e1rm],
          sessionCount: points.length,
          firstE1rm: points.first.e1rm,
          bestE1rm: best,
          lastE1rm: points.last.e1rm,
          lastDate: points.last.date,
        ),
      );
    }

    trends.sort((a, b) => b.lastDate.compareTo(a.lastDate));
    return trends;
  }
}
