import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/body_map_regions.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/muscle_coverage_service.dart';

/// `averagedContributors` normalizes the window to a weekly AVERAGE so a
/// multi-week window can be read against the weekly MEV/MAV bands. The
/// load-bearing guard (Codex F1): the divisor is capped to the user's real
/// history, so a new user's hard week is never divided by empty pre-history.
void main() {
  final now = DateTime(2026, 6, 26, 12);

  Exercise ex(String id, String primary, [List<String> sec = const []]) =>
      Exercise(
        id: id,
        name: id,
        level: 'beginner',
        images: const [],
        primaryMuscle: primary,
        secondaryMuscles: sec,
      );

  ExerciseLog log(String exId, String name, int sets) => ExerciseLog(
    exerciseId: exId,
    exerciseName: name,
    sets: List.generate(sets, (_) => const SetEntry(weight: 50, reps: 8)),
  );

  WorkoutSession session(List<ExerciseLog> logs, {required int daysAgo}) =>
      WorkoutSession(
        id: 's$daysAgo',
        date: now.subtract(Duration(days: daysAgo)),
        muscleGroup: 'Chest',
        targetDurationMinutes: 30,
        actualDurationSeconds: 1800,
        exercises: logs,
        estimatedCalories: 0,
      );

  final byId = {'Bench': ex('Bench', 'chest')};

  AveragedCoverage avg(List<WorkoutSession> s, CoverageWindow w) =>
      MuscleCoverageService.averagedContributors(
        sessions: s,
        exercisesById: byId,
        now: now,
        window: w.window,
      );

  double chestSets(AveragedCoverage c) =>
      (c.contributors['chest'] ?? const []).fold<double>(0, (a, x) => a + x.sets);

  test('week window returns the raw count, no division', () {
    final c = avg([
      session([log('Bench', 'Bench', 4)], daysAgo: 2),
    ], CoverageWindow.week);
    expect(chestSets(c), 4.0);
    expect(c.effectiveWeeks, 1.0);
  });

  test('4-wk window, established history → divides by the full 4 weeks', () {
    final c = avg([
      session([log('Bench', 'Bench', 4)], daysAgo: 60), // long history, out of window
      session([log('Bench', 'Bench', 4)], daysAgo: 10), // in window
      session([log('Bench', 'Bench', 4)], daysAgo: 3), // in window
    ], CoverageWindow.fourWeek);
    // In-window credit = 8 sets; firstSessionEver 60d ago → cap at 28d = 4 wk.
    expect(c.effectiveWeeks, 4.0);
    expect(chestSets(c), 2.0); // 8 / 4
  });

  test('F1: 4-wk window, history shorter than window → divisor caps to history', () {
    final c = avg([
      session([log('Bench', 'Bench', 4)], daysAgo: 14), // first ever, 2 wk ago
      session([log('Bench', 'Bench', 4)], daysAgo: 3),
    ], CoverageWindow.fourWeek);
    // 8 sets over a real 2-week span → 4.0/wk, NOT 8/4=2.0 (that would read low).
    expect(c.effectiveWeeks, 2.0);
    expect(chestSets(c), 4.0);
  });

  test('F1: 12-wk window, only this week trained → no dilution (weeks floored to 1)', () {
    final c = avg([
      session([log('Bench', 'Bench', 5)], daysAgo: 0),
    ], CoverageWindow.twelveWeek);
    expect(c.effectiveWeeks, 1.0);
    expect(chestSets(c), 5.0); // raw, not 5/12
  });

  test('12-wk window, long history → divides by the full 12 weeks', () {
    final c = avg([
      session([log('Bench', 'Bench', 4)], daysAgo: 200), // anchors >12wk history
      for (final d in [5, 20, 40, 60, 75, 80])
        session([log('Bench', 'Bench', 4)], daysAgo: d), // 6×4 = 24 in window
    ], CoverageWindow.twelveWeek);
    expect(c.effectiveWeeks, 12.0);
    expect(chestSets(c), 2.0); // 24 / 12
  });

  test('averaging preserves the meter↔drill sum==total invariant', () {
    final multi = {
      'Bench': ex('Bench', 'chest', const ['triceps']),
    };
    final c = MuscleCoverageService.averagedContributors(
      sessions: [
        session([log('Bench', 'Bench', 4)], daysAgo: 90),
        session([log('Bench', 'Bench', 4)], daysAgo: 5),
      ],
      exercisesById: multi,
      now: now,
      window: CoverageWindow.fourWeek.window,
    );
    final bd = muscleBreakdown(c.contributors);
    for (final m in bd.values) {
      expect(
        m.total,
        closeTo(m.contributors.fold<double>(0, (a, x) => a + x.sets), 1e-9),
      );
    }
    // chest credited 4 (in-window) / 4 wk = 1.0; triceps 0.5×4 / 4 = 0.5.
    expect(bd['chest']!.total, closeTo(1.0, 1e-9));
    expect(bd['triceps']!.total, closeTo(0.5, 1e-9));
  });

  test('no sessions → empty coverage', () {
    final c = avg(const [], CoverageWindow.fourWeek);
    expect(c.contributors, isEmpty);
  });

  test('CoverageWindow presets map to the right rolling durations + labels', () {
    expect(CoverageWindow.week.window, const Duration(days: 7));
    expect(CoverageWindow.fourWeek.window, const Duration(days: 28));
    expect(CoverageWindow.twelveWeek.window, const Duration(days: 84));
    expect(CoverageWindow.week.isAverage, isFalse);
    expect(CoverageWindow.fourWeek.isAverage, isTrue);
    expect(CoverageWindow.twelveWeek.chipLabel, '12-WK AVG');
  });
}
