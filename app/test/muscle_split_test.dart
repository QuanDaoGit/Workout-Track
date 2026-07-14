import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/muscle_splits.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/muscle_coverage_service.dart';

/// Detailed per-muscle analyzer + the curated shoulders/abdominals split layer.
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

  ExerciseLog log(String exId, int sets, {int warmups = 0}) => ExerciseLog(
    exerciseId: exId,
    exerciseName: exId,
    sets: List.generate(sets, (_) => const SetEntry(weight: 50, reps: 8)),
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
  ) => MuscleCoverageService.weeklySetsByMuscle(
    sessions: sessions,
    exercisesById: byId,
    now: now,
  );

  group('splitDetailedMuscle resolver', () {
    test('curated shoulders → front/rear delt', () {
      expect(
        splitDetailedMuscle('Dumbbell_Bench_Press', 'shoulders'),
        [muscleFrontDelt],
      );
      expect(splitDetailedMuscle('Face_Pull', 'shoulders'), [muscleRearDelt]);
    });

    test('curated abdominals → rectus / obliques', () {
      expect(
        splitDetailedMuscle('Crunches', 'abdominals'),
        [muscleRectusAbdominis],
      );
      expect(
        splitDetailedMuscle('Russian_Twist', 'abdominals'),
        [muscleObliques, muscleRectusAbdominis],
      );
    });

    test('un-curated splittable token stays coarse (never guessed)', () {
      expect(splitDetailedMuscle('Some_Unknown_Press', 'shoulders'), [
        'shoulders',
      ]);
      expect(splitDetailedMuscle('Some_Unknown_Twist', 'abdominals'), [
        'abdominals',
      ]);
    });

    test('non-splittable token passes through unchanged', () {
      expect(splitDetailedMuscle('Dumbbell_Bench_Press', 'biceps'), ['biceps']);
      expect(splitDetailedMuscle('anything', 'quadriceps'), ['quadriceps']);
    });
  });

  group('weeklySetsByMuscle', () {
    test('biceps and triceps are distinct (the free split)', () {
      final cov = cover(
        [
          session('s', now.subtract(const Duration(days: 1)), [
            log('curl', 3),
            log('pushdown', 2),
          ]),
        ],
        {'curl': ex('curl', 'biceps'), 'pushdown': ex('pushdown', 'triceps')},
      );
      expect(cov['biceps'], 3.0);
      expect(cov['triceps'], 2.0);
    });

    test('chest press: shoulders secondary resolves to front_delt, not generic',
        () {
      final cov = cover(
        [
          session('s', now.subtract(const Duration(days: 1)), [
            log('Dumbbell_Bench_Press', 4),
          ]),
        ],
        {
          'Dumbbell_Bench_Press': ex(
            'Dumbbell_Bench_Press',
            'chest',
            const ['shoulders', 'triceps'],
          ),
        },
      );
      expect(cov['chest'], 4.0); // direct
      expect(cov[muscleFrontDelt], 2.0); // 0.5 × 4
      expect(cov['triceps'], 2.0);
      expect(cov.containsKey('shoulders'), isFalse); // resolved away
      expect(cov.containsKey(muscleRearDelt), isFalse);
    });

    test('un-curated shoulder primary stays coarse generic', () {
      final cov = cover(
        [
          session('s', now.subtract(const Duration(days: 1)), [
            log('Mystery_Press', 3),
          ]),
        ],
        {'Mystery_Press': ex('Mystery_Press', 'shoulders')},
      );
      expect(cov['shoulders'], 3.0);
      expect(cov.containsKey(muscleFrontDelt), isFalse);
    });

    test('multi-region split: dominant region full, assist half (Codex F2)', () {
      // Russian_Twist abdominals → [obliques, rectus_abdominis] (obliques first).
      final cov = cover(
        [
          session('s', now.subtract(const Duration(days: 1)), [
            log('Russian_Twist', 4),
          ]),
        ],
        {'Russian_Twist': ex('Russian_Twist', 'abdominals')},
      );
      expect(cov[muscleObliques], 4.0); // dominant → full
      expect(cov[muscleRectusAbdominis], 2.0); // assist → half, NOT 4.0
      expect(cov.containsKey('abdominals'), isFalse);
    });

    test('row: shoulders secondary resolves to rear_delt', () {
      final cov = cover(
        [
          session('s', now.subtract(const Duration(days: 1)), [
            log('Bent_Over_Barbell_Row', 4),
          ]),
        ],
        {
          'Bent_Over_Barbell_Row': ex(
            'Bent_Over_Barbell_Row',
            'lats',
            const ['shoulders', 'biceps'],
          ),
        },
      );
      expect(cov['lats'], 4.0);
      expect(cov[muscleRearDelt], 2.0); // 0.5 × 4
      expect(cov['biceps'], 2.0);
    });

    test('primary wins when a secondary resolves to the same key', () {
      final cov = cover(
        [
          session('s', now.subtract(const Duration(days: 1)), [log('x', 2)]),
        ],
        {
          'x': ex('x', 'biceps', const ['biceps']),
        },
      );
      expect(cov['biceps'], 2.0); // 1.0 × 2, NOT 1.0 + 0.5
    });

    test('warm-ups excluded, partial skipped, unknown skipped', () {
      expect(
        cover(
          [
            session('s', now.subtract(const Duration(days: 1)), [
              log('curl', 0, warmups: 3),
            ]),
          ],
          {'curl': ex('curl', 'biceps')},
        ),
        isEmpty,
      );
      expect(
        cover(
          [
            session('s', now.subtract(const Duration(days: 1)), [
              log('curl', 3),
            ], partial: true),
          ],
          {'curl': ex('curl', 'biceps')},
        ),
        isEmpty,
      );
      expect(
        cover(
          [
            session('s', now.subtract(const Duration(days: 1)), [
              log('ghost', 3),
            ]),
          ],
          const {},
        ),
        isEmpty,
      );
    });
  });

  group('curated split data integrity (validated against the real catalog)', () {
    test('every override id exists and its split token is really on it', () {
      final raw = File('assets/exercises.json').readAsStringSync();
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final musclesById = <String, Set<String>>{
        for (final e in list)
          e['id'] as String: {
            ...((e['primaryMuscles'] as List?)?.cast<String>() ?? const []),
            ...((e['secondaryMuscles'] as List?)?.cast<String>() ?? const []),
          },
      };

      curatedMuscleSplits.forEach((id, tokenMap) {
        final muscles = musclesById[id];
        expect(muscles, isNotNull, reason: '$id not in catalog');
        tokenMap.forEach((token, subs) {
          expect(
            kSplittableTokens.contains(token),
            isTrue,
            reason: '$id: $token is not a splittable token',
          );
          expect(
            muscles!.contains(token),
            isTrue,
            reason: '$id has no "$token" in its primary/secondary muscles',
          );
          expect(subs, isNotEmpty, reason: '$id/$token empty split');
          for (final sub in subs) {
            expect(
              kSplitSubMuscles.contains(sub),
              isTrue,
              reason: '$id/$token: "$sub" is not a valid sub-region',
            );
          }
        });
      });
    });
  });
}
