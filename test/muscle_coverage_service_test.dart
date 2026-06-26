import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/muscle_coverage_service.dart';

/// Pure analyzer: weekly working-set credit per canonical muscle bucket.
/// Direct (primary) sets = 1.0; indirect (secondary) sets = 0.5; per-exercise
/// bucket-collapse dedupe with primary winning. No UI, no persistence.
void main() {
  final now = DateTime(2026, 6, 25, 12);

  Exercise ex(
    String id,
    String primary, [
    List<String> secondary = const [],
  ]) => Exercise(
    id: id,
    name: id,
    level: 'beginner',
    images: const [],
    primaryMuscle: primary,
    secondaryMuscles: secondary,
  );

  ExerciseLog log(String exId, int workingSets, {int warmups = 0}) =>
      ExerciseLog(
        exerciseId: exId,
        exerciseName: exId,
        sets: List.generate(
          workingSets,
          (_) => const SetEntry(weight: 50, reps: 8),
        ),
        warmupSets: List.generate(
          warmups,
          (_) => const SetEntry(weight: 20, reps: 10, isWarmup: true),
        ),
      );

  WorkoutSession session(
    String id,
    DateTime date,
    List<ExerciseLog> logs, {
    bool partial = false,
  }) => WorkoutSession(
    id: id,
    date: date,
    muscleGroup: 'Chest',
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    exercises: logs,
    estimatedCalories: 0,
    isPartial: partial,
  );

  Map<String, double> cover(
    List<WorkoutSession> sessions,
    Map<String, Exercise> byId,
  ) => MuscleCoverageService.weeklySetsByBucket(
    sessions: sessions,
    exercisesById: byId,
    now: now,
  );

  group('Exercise.secondaryMuscles', () {
    test('parses secondaryMuscles from JSON', () {
      final e = Exercise.fromJson({
        'id': 'a',
        'name': 'A',
        'level': 'beginner',
        'images': <String>[],
        'primaryMuscles': ['chest'],
        'secondaryMuscles': ['triceps', 'shoulders'],
      });
      expect(e.primaryMuscle, 'chest');
      expect(e.secondaryMuscles, ['triceps', 'shoulders']);
    });

    test('round-trips through toJson', () {
      final e = ex('bench', 'chest', const ['triceps']);
      expect(Exercise.fromJson(e.toJson()).secondaryMuscles, ['triceps']);
    });

    test('legacy JSON with no key → empty', () {
      final e = Exercise.fromJson({
        'id': 'a',
        'name': 'A',
        'level': 'beginner',
        'images': <String>[],
      });
      expect(e.secondaryMuscles, isEmpty);
    });
  });

  group('MuscleCoverageService.weeklySetsByBucket', () {
    test('direct sets credit 1.0 to the primary bucket only', () {
      final cov = cover(
        [
          session('s', now.subtract(const Duration(days: 1)), [log('bench', 3)]),
        ],
        {'bench': ex('bench', 'chest')},
      );
      expect(cov['Chest'], 3.0);
      expect(cov.containsKey('Arms'), isFalse);
    });

    test('secondary muscles credit 0.5 per set into their buckets', () {
      final cov = cover(
        [
          session('s', now.subtract(const Duration(days: 1)), [log('bench', 3)]),
        ],
        {
          'bench': ex('bench', 'chest', const ['triceps', 'shoulders']),
        },
      );
      expect(cov['Chest'], 3.0); // 3 direct
      expect(cov['Arms'], 1.5); // triceps → Arms, 0.5 × 3
      expect(cov['Shoulders'], 1.5); // shoulders → Shoulders, 0.5 × 3
    });

    test('primary bucket absorbs same-bucket secondaries (no over-credit)', () {
      // Squat: quads (Legs) primary; glutes + hamstrings both → Legs.
      final cov = cover(
        [
          session('s', now.subtract(const Duration(days: 1)), [log('squat', 2)]),
        ],
        {
          'squat': ex('squat', 'quadriceps', const ['glutes', 'hamstrings']),
        },
      );
      expect(cov['Legs'], 2.0); // 2 direct, NOT 2 + 0.5 + 0.5
      expect(cov.length, 1);
    });

    test('two secondaries in one bucket count once (deduped)', () {
      // Primary chest; lats + traps both → Back → one 0.5 credit per set.
      final cov = cover(
        [
          session('s', now.subtract(const Duration(days: 1)), [log('x', 2)]),
        ],
        {
          'x': ex('x', 'chest', const ['lats', 'traps']),
        },
      );
      expect(cov['Chest'], 2.0);
      expect(cov['Back'], 1.0); // 0.5 × 2, deduped — NOT 2.0
    });

    test('rolling 7-day window excludes older sessions', () {
      final cov = cover(
        [
          session('old', now.subtract(const Duration(days: 8)), [log('bench', 5)]),
          session('new', now.subtract(const Duration(days: 6)), [log('bench', 2)]),
        ],
        {'bench': ex('bench', 'chest')},
      );
      expect(cov['Chest'], 2.0); // only the 6-day-old session
    });

    test('warm-up sets are not counted', () {
      final cov = cover(
        [
          session('s', now.subtract(const Duration(days: 1)), [
            log('bench', 2, warmups: 3),
          ]),
        ],
        {'bench': ex('bench', 'chest')},
      );
      expect(cov['Chest'], 2.0); // warm-ups ignored
    });

    test('partial sessions are excluded', () {
      final cov = cover(
        [
          session(
            's',
            now.subtract(const Duration(days: 1)),
            [log('bench', 3)],
            partial: true,
          ),
        ],
        {'bench': ex('bench', 'chest')},
      );
      expect(cov, isEmpty);
    });

    test('unknown exercise id is skipped, no throw', () {
      final cov = cover(
        [
          session('s', now.subtract(const Duration(days: 1)), [log('ghost', 3)]),
        ],
        const {},
      );
      expect(cov, isEmpty);
    });

    test('empty input → empty map', () {
      expect(cover(const [], const {}), isEmpty);
    });
  });
}
