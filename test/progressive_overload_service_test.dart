import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:workout_track/models/overload_models.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/exercise_kind_cache.dart';
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

Exercise _exercise(String id, {String? mechanic, String? equipment}) {
  return Exercise(
    id: id,
    name: id,
    level: 'beginner',
    images: const [],
    mechanic: mechanic,
    equipment: equipment,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExerciseKindCache.instance.resetForTest();
  });

  group('getLastSessionSets', () {
    test('returns most recent session sets', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', [_set(60, 10)]),
          ],
        ),
        _session(
          date: DateTime(2025, 1, 3),
          exercises: [
            _log('bench', [_set(80, 8)]),
          ],
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
          exercises: [
            _log('squat', [_set(100, 5)]),
          ],
        ),
      ]);
      expect(svc.getLastSessionSets('bench'), isNull);
    });
  });

  group('suggestNext — compound (target 8)', () {
    test('hit target → +2.5 kg / weightIncrease', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', [_set(80, 8)]),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 5),
      );
      expect(s, isNotNull);
      expect(s!.weight, 82.5);
      expect(s.reps, 8);
      expect(s.reason, OverloadReason.weightIncrease);
    });

    test('missed by 1 → repeat weight at target / repTarget', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', [_set(80, 7)]),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 5),
      );
      expect(s!.weight, 80);
      expect(s.reps, 8);
      expect(s.reason, OverloadReason.repTarget);
    });

    test('missed by 4+ → −2.5 kg / deload', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', [_set(80, 3)]),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 5),
      );
      expect(s!.weight, 77.5);
      expect(s.reps, 8);
      expect(s.reason, OverloadReason.deload);
    });

    test('22+ days gap → repeat weight / detrained', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', [_set(80, 8)]),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 30),
      );
      expect(s!.weight, 80);
      expect(s.reps, 8);
      expect(s.reason, OverloadReason.detrained);
    });

    test('picks top set across multiple sets in last session', () async {
      // 80×8 first, then 80×6 fatigue drop. Top set is 80×8 → met target → +2.5.
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', [_set(80, 8), _set(80, 6)]),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 5),
      );
      expect(s!.weight, 82.5);
      expect(s.reason, OverloadReason.weightIncrease);
    });
  });

  group('suggestNext — isolation (target 12)', () {
    test('hit target → +2.5 kg', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('curl', [_set(20, 12)]),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('curl', mechanic: 'isolation'),
        now: DateTime(2025, 1, 5),
      );
      expect(s!.weight, 22.5);
      expect(s.reps, 12);
      expect(s.reason, OverloadReason.weightIncrease);
    });

    test('missed by 1 → repeat weight at 12-rep target', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('curl', [_set(20, 11)]),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('curl', mechanic: 'isolation'),
        now: DateTime(2025, 1, 5),
      );
      expect(s!.weight, 20);
      expect(s.reps, 12);
      expect(s.reason, OverloadReason.repTarget);
    });
  });

  group('suggestNext — bodyweight (target 15)', () {
    test('hit target → +1 rep, no weight increase', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('pullup', [_set(0, 15)]),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('pullup', mechanic: 'compound', equipment: 'body only'),
        now: DateTime(2025, 1, 5),
      );
      expect(s!.weight, 0);
      expect(s.reps, 16);
      expect(s.reason, OverloadReason.weightIncrease);
    });

    test('missed target → repeat reps target', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('pullup', [_set(0, 10)]),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('pullup', mechanic: 'compound', equipment: 'body only'),
        now: DateTime(2025, 1, 5),
      );
      expect(s!.weight, 0);
      expect(s.reps, 15);
      expect(s.reason, OverloadReason.repTarget);
    });
  });

  test('no history → null', () async {
    final svc = ProgressiveOverloadService.fromSessions([]);
    final s = await svc.suggestNext(_exercise('bench', mechanic: 'compound'));
    expect(s, isNull);
  });

  group('getPersonalBest', () {
    test('max 1RM across sessions', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', [_set(80, 8)]),
          ],
        ),
        _session(
          date: DateTime(2025, 1, 3),
          exercises: [
            _log('bench', [_set(100, 5)]),
          ],
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
          exercises: [
            _log('pullup', [_set(0, 10)]),
          ],
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
          exercises: [
            _log('bench', [_set(80, 8)]),
          ],
        ),
      ]);
      expect(svc.checkPR('bench', 90, 8, false), isTrue);
    });

    test('false when does not beat history', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', [_set(80, 8)]),
          ],
        ),
      ]);
      expect(svc.checkPR('bench', 70, 8, false), isFalse);
    });

    test('false when no previous record exists', () {
      final svc = ProgressiveOverloadService.fromSessions([]);
      expect(svc.checkPR('bench', 80, 8, false), isFalse);
    });

    test('false when reps is 0', () {
      final svc = ProgressiveOverloadService.fromSessions([]);
      expect(svc.checkPR('bench', 80, 0, false), isFalse);
    });

    test('bodyweight PR uses 40.0 base', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('pullup', [_set(0, 10)]),
          ],
        ),
      ]);
      expect(svc.checkPR('pullup', 0, 12, true), isTrue);
    });
  });

  group('getDelta', () {
    test('positive diff', () {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', [_set(80, 8)]),
          ],
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
          exercises: [
            _log('bench', [_set(80, 8)]),
          ],
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
          exercises: [
            _log('bench', [_set(80, 8)]),
          ],
        ),
      ]);
      expect(svc.getDelta('bench', 5, 80, 8), isNull);
    });
  });

  group('epley1RM', () {
    test('weighted calculation', () {
      expect(
        ProgressiveOverloadService.epley1RM(100, 5, false),
        closeTo(116.67, 0.01),
      );
    });

    test('bodyweight uses 40.0', () {
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
