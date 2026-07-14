import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/body_map_regions.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/muscle_coverage_service.dart';

/// The drill data: per-muscle contributing exercises must come from the SAME
/// crediting as the meter total (Codex F1/F2), so the sheet can't disagree with
/// the bar.
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

  WorkoutSession session(List<ExerciseLog> logs) => WorkoutSession(
    id: 's',
    date: now.subtract(const Duration(days: 1)),
    muscleGroup: 'Chest',
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    exercises: logs,
    estimatedCalories: 0,
  );

  Map<String, List<MuscleContributor>> contrib(
    List<WorkoutSession> s,
    Map<String, Exercise> byId,
  ) => MuscleCoverageService.weeklyContributors(
    sessions: s,
    exercisesById: byId,
    now: now,
  );

  Map<String, double> totals(
    List<WorkoutSession> s,
    Map<String, Exercise> byId,
  ) => MuscleCoverageService.weeklySetsByMuscle(
    sessions: s,
    exercisesById: byId,
    now: now,
  );

  double setsOf(List<MuscleContributor>? cs, String exId) =>
      cs?.firstWhere((c) => c.exerciseId == exId).sets ?? 0;

  test('contributors credit each muscle + carry the logged name', () {
    final byId = {
      'Dumbbell_Bench_Press': ex('Dumbbell_Bench_Press', 'chest', const [
        'shoulders',
        'triceps',
      ]),
    };
    final s = [session([log('Dumbbell_Bench_Press', 'Bench Press', 4)])];
    final c = contrib(s, byId);
    expect(setsOf(c['chest'], 'Dumbbell_Bench_Press'), 4.0); // primary
    expect(setsOf(c['front_delt'], 'Dumbbell_Bench_Press'), 2.0); // shoulders→front, 0.5×4
    expect(setsOf(c['triceps'], 'Dumbbell_Bench_Press'), 2.0);
    expect(c['chest']!.first.exerciseName, 'Bench Press');
  });

  test('F1: per key, contributor sets sum to weeklySetsByMuscle (no drift)', () {
    final byId = {
      'Dumbbell_Bench_Press': ex('Dumbbell_Bench_Press', 'chest', const [
        'shoulders',
        'triceps',
      ]),
      'Triceps_Pushdown': ex('Triceps_Pushdown', 'triceps'),
    };
    final s = [
      session([
        log('Dumbbell_Bench_Press', 'Bench', 3),
        log('Triceps_Pushdown', 'Pushdown', 4),
      ]),
    ];
    final c = contrib(s, byId);
    final t = totals(s, byId);
    for (final key in t.keys) {
      final sum = (c[key] ?? const []).fold<double>(0, (a, x) => a + x.sets);
      expect(sum, closeTo(t[key]!, 1e-9), reason: 'key $key drifted');
    }
  });

  test('F2: muscleBreakdown total == sum of its contributors', () {
    final byId = {
      'Dumbbell_Bench_Press': ex('Dumbbell_Bench_Press', 'chest', const [
        'shoulders',
      ]),
    };
    final bd = muscleBreakdown(
      contrib([session([log('Dumbbell_Bench_Press', 'Bench', 4)])], byId),
    );
    final chest = bd['chest']!;
    expect(chest.total, chest.contributors.fold<double>(0, (a, c) => a + c.sets));
    expect(chest.total, 4.0);
  });

  test('F2: an un-curated shoulder exercise drills into FRONT DELT only', () {
    final byId = {'Mystery_Press': ex('Mystery_Press', 'shoulders')};
    final bd = muscleBreakdown(
      contrib([session([log('Mystery_Press', 'Mystery Press', 5)])], byId),
    );
    expect(
      bd['front_delt']!.contributors.map((c) => c.exerciseId),
      contains('Mystery_Press'),
    );
    expect(bd['front_delt']!.total, 5.0);
    expect(bd['rear_delt']!.contributors, isEmpty); // never guessed onto rear
    expect(bd['rear_delt']!.total, 0.0);
  });

  test('multi-region (Russian twist) drills into BOTH with split credit', () {
    final byId = {'Russian_Twist': ex('Russian_Twist', 'abdominals')};
    final bd = muscleBreakdown(
      contrib([session([log('Russian_Twist', 'Russian Twist', 4)])], byId),
    );
    expect(bd['obliques']!.total, 4.0); // dominant region, full
    expect(bd['rectus']!.total, 2.0); // assist, half
    expect(
      bd['obliques']!.contributors.single.exerciseName,
      'Russian Twist',
    );
    expect(bd['rectus']!.contributors.single.exerciseName, 'Russian Twist');
  });

  test('F4: a deleted exercise is skipped by BOTH (totals stay reconciled)', () {
    // 'Ghost' logged but not in the catalog → uncreditable.
    final byId = {'Barbell_Curl': ex('Barbell_Curl', 'biceps')};
    final s = [
      session([log('Ghost', 'Ghost', 3), log('Barbell_Curl', 'Curl', 2)]),
    ];
    final c = contrib(s, byId);
    final t = totals(s, byId);
    expect(c['biceps']!.single.exerciseId, 'Barbell_Curl');
    expect(t['biceps'], 2.0);
    expect(c.values.expand((l) => l).any((x) => x.exerciseId == 'Ghost'), isFalse);
  });
}
