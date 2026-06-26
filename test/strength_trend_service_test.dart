import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/body_map_regions.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/strength_trend_service.dart';

/// The browsable strength index's brain: best Epley e1RM per session, the SAME
/// estimate the detail chart plots, most-recently-trained first.
void main() {
  final now = DateTime(2026, 6, 26, 12);

  SetEntry set(double w, int r) => SetEntry(weight: w, reps: r);

  Exercise ex(String id, String primary, [List<String> sec = const []]) =>
      Exercise(
        id: id,
        name: id,
        level: 'beginner',
        images: const [],
        primaryMuscle: primary,
        secondaryMuscles: sec,
      );

  ExerciseLog log(String id, String name, List<SetEntry> sets) =>
      ExerciseLog(exerciseId: id, exerciseName: name, sets: sets);

  WorkoutSession session(
    List<ExerciseLog> logs, {
    required int daysAgo,
    bool partial = false,
  }) => WorkoutSession(
    id: 's$daysAgo',
    date: now.subtract(Duration(days: daysAgo)),
    muscleGroup: 'Chest',
    targetDurationMinutes: 30,
    actualDurationSeconds: partial ? 0 : 1800,
    exercises: logs,
    estimatedCalories: 0,
    isPartial: partial,
  );

  // Epley: weight * (1 + reps/30).
  double e1(double w, int r) => w * (1 + r / 30);

  StrengthTrend byId(List<StrengthTrend> ts, String id) =>
      ts.firstWhere((t) => t.exerciseId == id);

  test('best e1RM per session, oldest→newest, recency-sorted across exercises', () {
    final trends = StrengthTrendService.trendsFor([
      session([log('Bench', 'Bench Press', [set(100, 5)])], daysAgo: 10),
      session([log('Squat', 'Back Squat', [set(140, 5)])], daysAgo: 5),
      session([log('Bench', 'Bench Press', [set(105, 5)])], daysAgo: 2),
    ]);

    // Bench last trained 2d ago, Squat 5d ago → Bench first.
    expect(trends.map((t) => t.exerciseId), ['Bench', 'Squat']);

    final bench = byId(trends, 'Bench');
    expect(bench.sessionCount, 2);
    expect(bench.hasTrend, isTrue);
    expect(bench.e1rmPoints, [closeTo(e1(100, 5), 1e-9), closeTo(e1(105, 5), 1e-9)]);
    expect(bench.lastE1rm, closeTo(e1(105, 5), 1e-9));
    expect(bench.exerciseName, 'Bench Press');

    final squat = byId(trends, 'Squat');
    expect(squat.sessionCount, 1);
    expect(squat.hasTrend, isFalse); // single session → locked row
  });

  test('takes the best e1RM across the session’s sets', () {
    final trends = StrengthTrendService.trendsFor([
      session([
        log('Bench', 'Bench', [set(100, 5), set(110, 3)]),
      ], daysAgo: 1),
    ]);
    // max(100×1.1667, 110×1.10) = 121.0
    expect(byId(trends, 'Bench').lastE1rm, closeTo(e1(110, 3), 1e-9));
  });

  test('bodyweight-only logs (no positive weight) contribute no e1RM', () {
    final trends = StrengthTrendService.trendsFor([
      session([
        log('PullUp', 'Pull Up', [set(0, 10), set(0, 8)]),
        log('Bench', 'Bench', [set(80, 5)]),
      ], daysAgo: 1),
    ]);
    expect(trends.map((t) => t.exerciseId), ['Bench']);
  });

  test('minSessions filters out single-session lifts when asked', () {
    final all = StrengthTrendService.trendsFor([
      session([log('Bench', 'Bench', [set(100, 5)])], daysAgo: 5),
      session([log('Bench', 'Bench', [set(102, 5)])], daysAgo: 2),
      session([log('Curl', 'Curl', [set(20, 8)])], daysAgo: 1),
    ], minSessions: 2);
    expect(all.map((t) => t.exerciseId), ['Bench']); // Curl (1 session) dropped
  });

  test('partial sessions are skipped', () {
    final trends = StrengthTrendService.trendsFor([
      session([log('Bench', 'Bench', [set(100, 5)])], daysAgo: 3, partial: true),
      session([log('Bench', 'Bench', [set(100, 5)])], daysAgo: 1),
    ]);
    expect(byId(trends, 'Bench').sessionCount, 1); // only the non-partial counts
  });

  test('sparkline caps to the most recent 12 sessions; count stays full', () {
    final sessions = [
      for (var i = 0; i < 14; i++)
        session([
          log('Bench', 'Bench', [set(100 + i.toDouble(), 5)]),
        ], daysAgo: 20 - i),
    ];
    final bench = byId(StrengthTrendService.trendsFor(sessions), 'Bench');
    expect(bench.sessionCount, 14);
    expect(bench.e1rmPoints.length, 12); // capped
    // The last point is the most recent (highest weight = 113).
    expect(bench.e1rmPoints.last, closeTo(e1(113, 5), 1e-9));
  });

  test('no weighted sessions → empty index', () {
    expect(StrengthTrendService.trendsFor(const []), isEmpty);
    expect(
      StrengthTrendService.trendsFor([
        session([log('PullUp', 'Pull Up', [set(0, 10)])], daysAgo: 1),
      ]),
      isEmpty,
    );
  });

  // One lift across sessions of the given weights (fixed reps → e1RM ∝ weight,
  // so the ordering that drives momentum is preserved).
  StrengthTrend only(List<double> weights) {
    final s = [
      for (var i = 0; i < weights.length; i++)
        session([
          log('Bench', 'Bench', [set(weights[i], 5)]),
        ], daysAgo: weights.length - i),
    ];
    return StrengthTrendService.trendsFor(s).single;
  }

  test('momentum: NEW BEST when the latest session is an all-time high', () {
    expect(only([80, 85, 90]).momentum, StrengthMomentum.newBest);
  });

  test('momentum: ON THE RISE — up vs baseline but below an earlier peak', () {
    expect(only([78, 95, 88, 92]).momentum, StrengthMomentum.rising);
  });

  test('momentum: HOLDING within a stable band', () {
    expect(only([90, 90, 90, 90]).momentum, StrengthMomentum.holding);
  });

  test('momentum: REBUILDING on a real recent drop (honest, not hidden)', () {
    expect(only([100, 95, 90]).momentum, StrengthMomentum.rebuilding);
  });

  test('momentum: fresh for a single session', () {
    expect(only([100]).momentum, StrengthMomentum.fresh);
  });

  test('deltas: vs previous + since start (signed, in kg)', () {
    final t = only([80, 85, 90]);
    const k = 1 + 5 / 30; // Epley factor at 5 reps
    expect(t.deltaVsPrevious, closeTo((90 - 85) * k, 1e-9));
    expect(t.deltaSinceStart, closeTo((90 - 80) * k, 1e-9));
  });

  test('strengthByMuscle files a lift under its PRIMARY muscle only', () {
    final byId = {
      'Bench': ex('Bench', 'chest', const ['triceps']),
      'Pushdown': ex('Pushdown', 'triceps'),
    };
    final trends = StrengthTrendService.trendsFor([
      session([
        log('Bench', 'Bench Press', [set(80, 5)]),
        log('Pushdown', 'Triceps Pushdown', [set(30, 10)]),
      ], daysAgo: 5),
      session([
        log('Bench', 'Bench Press', [set(85, 5)]),
        log('Pushdown', 'Triceps Pushdown', [set(32, 10)]),
      ], daysAgo: 1),
    ]);
    final grouped = strengthByMuscle(trends, byId);
    // Bench → chest (its primary), NOT triceps (a secondary). Pushdown → triceps.
    expect(grouped['chest']!.map((t) => t.exerciseId), contains('Bench'));
    expect(grouped['triceps']!.map((t) => t.exerciseId), contains('Pushdown'));
    expect(grouped['triceps']!.map((t) => t.exerciseId), isNot(contains('Bench')));
  });
}
