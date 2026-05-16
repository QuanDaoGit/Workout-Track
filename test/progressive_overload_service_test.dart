import 'package:flutter_test/flutter_test.dart';

import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/progressive_overload_service.dart';

WorkoutSession _session({
  required DateTime date,
  required List<ExerciseLog> exercises,
}) {
  return WorkoutSession(
    id: date.toIso8601String(),
    date: date,
    exercises: exercises,
    targetDurationMinutes: 60,
    actualDurationSeconds: 3600,
    estimatedCalories: 300,
    muscleGroup: 'Chest',
  );
}

ExerciseLog _log(String exerciseId, List<SetEntry> sets) {
  return ExerciseLog(
    exerciseId: exerciseId,
    exerciseName: exerciseId,
    sets: sets,
  );
}

SetEntry _set(double weight, int reps) => SetEntry(weight: weight, reps: reps);

void main() {
  group('getLastSessionSets', () {
    test('returns most recent session sets', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [_log('bench', [_set(60, 10)])],
        ),
        _session(
          date: DateTime(2025, 1, 3),
          exercises: [_log('bench', [_set(80, 8)])],
        ),
      ]);
      final sets = svc.getLastSessionSets('bench');
      expect(sets, isNotNull);
      expect(sets!.length, 1);
      expect(sets[0].weight, 80);
      expect(sets[0].reps, 8);
    });

    test('returns null when no history', () {
      final svc = ProgressiveOverloadService.fromSessions([]);
      expect(svc.getLastSessionSets('bench'), isNull);
    });

    test('returns null for unknown exercise', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [_log('squat', [_set(100, 5)])],
        ),
      ]);
      expect(svc.getLastSessionSets('bench'), isNull);
    });
  });

  group('getSuggestion', () {
    test('+5% weight rounded to nearest 2.5 kg', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [_log('bench', [_set(80, 8)])],
        ),
      ]);
      final s = svc.getSuggestion('bench', 0, false);
      expect(s, isNotNull);
      // 80 * 1.05 = 84, / 2.5 = 33.6, round = 34, * 2.5 = 85
      expect(s!.weight, 85.0);
      expect(s.reps, 8);
    });

    test('+1 rep for bodyweight', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [_log('pullup', [_set(0, 10)])],
        ),
      ]);
      final s = svc.getSuggestion('pullup', 0, true);
      expect(s, isNotNull);
      expect(s!.weight, 0);
      expect(s.reps, 11);
    });

    test('same weight when reps dropped mid-session', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', [_set(80, 8), _set(80, 6)]),
          ],
        ),
      ]);
      final s = svc.getSuggestion('bench', 1, false);
      expect(s, isNotNull);
      expect(s!.weight, 80);
      expect(s.reps, 6);
    });

    test('null when no history for exercise', () {
      final svc = ProgressiveOverloadService.fromSessions([]);
      expect(svc.getSuggestion('bench', 0, false), isNull);
    });

    test('null when setIndex out of range', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [_log('bench', [_set(80, 8)])],
        ),
      ]);
      expect(svc.getSuggestion('bench', 5, false), isNull);
    });
  });

  group('getPersonalBest', () {
    test('max 1RM across sessions', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [_log('bench', [_set(80, 8)])],
        ),
        _session(
          date: DateTime(2025, 1, 3),
          exercises: [_log('bench', [_set(100, 5)])],
        ),
      ]);
      // 80*(1+8/30) = 101.33, 100*(1+5/30) = 116.67
      final best = svc.getPersonalBest('bench');
      expect(best, closeTo(116.67, 0.01));
    });

    test('uses 40.0 base for bodyweight', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [_log('pullup', [_set(0, 10)])],
        ),
      ]);
      // 40*(1+10/30) = 53.33
      expect(svc.getPersonalBest('pullup'), closeTo(53.33, 0.01));
    });

    test('returns 0 when no history', () {
      final svc = ProgressiveOverloadService.fromSessions([]);
      expect(svc.getPersonalBest('bench'), 0.0);
    });
  });

  group('checkPR', () {
    test('true when beats history', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [_log('bench', [_set(80, 8)])],
        ),
      ]);
      // 80*(1+8/30) = 101.33; 90*(1+8/30) = 114
      expect(svc.checkPR('bench', 90, 8, false), isTrue);
    });

    test('false when does not beat history', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [_log('bench', [_set(80, 8)])],
        ),
      ]);
      expect(svc.checkPR('bench', 70, 8, false), isFalse);
    });

    test('true for first-ever set', () {
      final svc = ProgressiveOverloadService.fromSessions([]);
      expect(svc.checkPR('bench', 80, 8, false), isTrue);
    });

    test('false when reps is 0', () {
      final svc = ProgressiveOverloadService.fromSessions([]);
      expect(svc.checkPR('bench', 80, 0, false), isFalse);
    });

    test('bodyweight PR uses 40.0 base', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [_log('pullup', [_set(0, 10)])],
        ),
      ]);
      // stored best: 40*(1+10/30) = 53.33
      // new: 40*(1+12/30) = 56.0 > 53.33
      expect(svc.checkPR('pullup', 0, 12, true), isTrue);
    });
  });

  group('getDelta', () {
    test('positive diff', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [_log('bench', [_set(80, 8)])],
        ),
      ]);
      final d = svc.getDelta('bench', 0, 85, 10);
      expect(d, isNotNull);
      expect(d!.weightDiff, 5.0);
      expect(d.repsDiff, 2);
    });

    test('negative diff', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [_log('bench', [_set(80, 8)])],
        ),
      ]);
      final d = svc.getDelta('bench', 0, 75, 6);
      expect(d, isNotNull);
      expect(d!.weightDiff, -5.0);
      expect(d.repsDiff, -2);
    });

    test('null when no history', () {
      final svc = ProgressiveOverloadService.fromSessions([]);
      expect(svc.getDelta('bench', 0, 80, 8), isNull);
    });

    test('null when setIndex out of range', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [_log('bench', [_set(80, 8)])],
        ),
      ]);
      expect(svc.getDelta('bench', 5, 80, 8), isNull);
    });
  });

  group('epley1RM', () {
    test('weighted calculation', () {
      // 100 * (1 + 5/30) = 116.67
      expect(
        ProgressiveOverloadService.epley1RM(100, 5, false),
        closeTo(116.67, 0.01),
      );
    });

    test('bodyweight uses 40.0', () {
      // 40 * (1 + 10/30) = 53.33
      expect(
        ProgressiveOverloadService.epley1RM(0, 10, true),
        closeTo(53.33, 0.01),
      );
    });

    test('returns 0 when reps <= 0', () {
      expect(ProgressiveOverloadService.epley1RM(100, 0, false), 0.0);
      expect(ProgressiveOverloadService.epley1RM(100, -1, false), 0.0);
    });

    test('returns 0 when weight <= 0 and not bodyweight', () {
      expect(ProgressiveOverloadService.epley1RM(0, 10, false), 0.0);
    });
  });
}
