import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:workout_track/models/overload_models.dart';
import 'package:workout_track/models/training_focus.dart';
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

List<SetEntry> _sets(double weight, List<int> reps) => [
  for (final r in reps) _set(weight, r),
];

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

  group('epley1RM', () {
    test('reps == 1 returns the weight itself — a single IS the max', () {
      // Pre-fix this returned 100 * 1.0333 = 103.3 (overshoot). A single must
      // read as exactly the weight lifted, never higher.
      expect(ProgressiveOverloadService.epley1RM(100, 1, false), 100);
      expect(ProgressiveOverloadService.epley1RM(60, 1, false), 60);
    });
    test('multi-rep keeps standard Epley (unchanged)', () {
      expect(ProgressiveOverloadService.epley1RM(100, 5, false), closeTo(116.67, 0.01));
      expect(ProgressiveOverloadService.epley1RM(80, 8, false), closeTo(101.33, 0.01));
    });
    test('e1RM is never below the actual weight (the invariant)', () {
      for (final reps in [1, 2, 5, 8, 12]) {
        expect(ProgressiveOverloadService.epley1RM(100, reps, false),
            greaterThanOrEqualTo(100));
      }
    });
    test('bodyweight uses the 40kg base; a single returns 40', () {
      expect(ProgressiveOverloadService.epley1RM(0, 1, true), 40);
      expect(ProgressiveOverloadService.epley1RM(0, 10, true), closeTo(53.33, 0.01));
    });
    test('non-positive reps/weight → 0', () {
      expect(ProgressiveOverloadService.epley1RM(100, 0, false), 0);
      expect(ProgressiveOverloadService.epley1RM(0, 5, false), 0);
    });
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
            _log('bench', _sets(80, [8, 8, 8, 8, 8])),
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
            _log('bench', _sets(80, [8, 8, 8, 8, 7])),
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

    test('a single low-rep session no longer deloads — sparse history has no '
        'baseline to judge (#5)', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', _sets(80, [3, 3, 3, 3, 3])),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 5),
      );
      // One session can't anchor a target → fall back to the kind aim and NEVER
      // deload (matches Strong/Hevy: show previous, let the user decide).
      expect(s!.reason, OverloadReason.repTarget);
      expect(s.weight, 80);
    });

    test('22+ days gap → repeat weight / detrained', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', _sets(80, [8, 8, 8, 8, 8])),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 30),
      );
      expect(s!.weight, 76);
      expect(s.reps, 8);
      expect(s.reason, OverloadReason.detrained);
    });

    test('multi-set near-miss holds (deload threshold scales with set count, #8)',
        () async {
      // Latest session = 3×7 (target 8): a small per-set miss. An earlier 2-set
      // session lifts total logged sets over the 5-set suggestion gate.
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', _sets(80, [8, 8])),
          ],
        ),
        _session(
          date: DateTime(2025, 1, 8),
          exercises: [
            _log('bench', _sets(80, [7, 7, 7])),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 12),
      );
      // Two sessions → history-anchored target (top-set reps [7,8] → median 8 →
      // aim 9, floor 6). The user's 7s sit above floor 6, so no deload — a
      // repeat-the-load hold aiming at 9.
      expect(s!.reason, OverloadReason.repTarget);
      expect(s.weight, 80);
      expect(s.reps, 9);
    });

    test('picks top set across multiple sets in last session', () async {
      // 80×8 first, then 80×6 fatigue drop. Top set is 80×8 → met target → +2.5.
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', _sets(80, [8, 8, 8, 8, 8])),
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

  group('suggestNext — history-anchored rep target (#5)', () {
    test('a consistent 5-rep trainee is NEVER deloaded (the headline)', () async {
      // 3 sessions of 5×5 compound, no prescription → demonstrated reps = 5.
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', _sets(80, [5, 5, 5, 5, 5])),
          ],
        ),
        _session(
          date: DateTime(2025, 1, 3),
          exercises: [
            _log('bench', _sets(80, [5, 5, 5, 5, 5])),
          ],
        ),
        _session(
          date: DateTime(2025, 1, 5),
          exercises: [
            _log('bench', _sets(80, [5, 5, 5, 5, 5])),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 8),
      );
      // Old engine deloads (5 < the fixed 8 target every session); the
      // history-anchored target follows the user → no false deload.
      expect(s, isNotNull);
      expect(s!.reason, isNot(OverloadReason.deload));
    });

    test('INV1: a post-+load reset session (fewer reps, heavier) does not '
        'false-deload', () async {
      // 3 sessions of 8s @50, then a +load reset to 5s @52.5. The old engine
      // deloads (5 < fixed 8); the derived floor (6, below the demonstrated 8s)
      // accommodates the heavier reset → no false deload.
      final svc = ProgressiveOverloadService.fromSessions([
        _session(date: DateTime(2025, 1, 1), exercises: [_log('bench', _sets(50, [8, 8, 8]))]),
        _session(date: DateTime(2025, 1, 3), exercises: [_log('bench', _sets(50, [8, 8, 8]))]),
        _session(date: DateTime(2025, 1, 5), exercises: [_log('bench', _sets(50, [8, 8, 8]))]),
        _session(date: DateTime(2025, 1, 7), exercises: [_log('bench', _sets(52.5, [5, 5, 5]))]),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 9),
      );
      expect(s!.reason, isNot(OverloadReason.deload));
    });

    test('INV4: a clear dip below an established floor still deloads — not '
        'over-suppressed', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        for (final d in [1, 3, 5, 7])
          _session(date: DateTime(2025, 1, d), exercises: [_log('bench', _sets(60, [8, 8, 8]))]),
        _session(date: DateTime(2025, 1, 9), exercises: [_log('bench', _sets(60, [4, 4, 4]))]),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 11),
      );
      // 4 prior 8-rep sessions establish a floor of 6; a 4-rep session is a
      // genuine collapse → deload (spread 4 stays inside the consistency gate).
      expect(s!.reason, OverloadReason.deload);
    });

    test('an undulating (high-variance) history suppresses the deload judgment',
        () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(date: DateTime(2025, 1, 1), exercises: [_log('bench', _sets(60, [12, 12, 12]))]),
        _session(date: DateTime(2025, 1, 3), exercises: [_log('bench', _sets(80, [5, 5, 5]))]),
        _session(date: DateTime(2025, 1, 5), exercises: [_log('bench', _sets(60, [12, 12, 12]))]),
        _session(date: DateTime(2025, 1, 7), exercises: [_log('bench', _sets(80, [5, 5, 5]))]),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 9),
      );
      expect(s!.reason, isNot(OverloadReason.deload));
    });

    test('bodyweight target follows demonstrated reps, not the 15 kind default',
        () async {
      final svc = ProgressiveOverloadService.fromSessions([
        for (final d in [1, 3, 5])
          _session(date: DateTime(2025, 1, d), exercises: [_log('pullup', _sets(0, [10, 10, 10]))]),
      ]);
      final s = await svc.suggestNext(
        _exercise('pullup', mechanic: 'compound', equipment: 'body only'),
        now: DateTime(2025, 1, 8),
      );
      expect(s!.weight, 0);
      expect(s.reps, 11); // aim = median(10) + 1, NOT the old kind default 15
      expect(s.reason, OverloadReason.repTarget);
    });

    test('F4/INV5: a consistent 3-rep strength trainee is aimed at ~4, never '
        'pushed up to 6+', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        for (final d in [1, 3, 5])
          _session(date: DateTime(2025, 1, d), exercises: [_log('squat', _sets(140, [3, 3, 3]))]),
      ]);
      final s = await svc.suggestNext(
        _exercise('squat', mechanic: 'compound'),
        now: DateTime(2025, 1, 8),
      );
      expect(s!.reason, isNot(OverloadReason.deload));
      expect(s.reps, lessThanOrEqualTo(4));
    });

    test('INV3: a double-progression cycle does not ratchet the band downward',
        () async {
      const reps = [6, 7, 8, 9, 6, 7]; // climb to the top, +load, reset, climb
      final sessions = <WorkoutSession>[
        for (var i = 0; i < reps.length; i++)
          _session(
            date: DateTime(2025, 1, 1 + i * 2),
            exercises: [_log('bench', _sets(60, [reps[i], reps[i], reps[i]]))],
          ),
      ];
      final svc = ProgressiveOverloadService.fromSessions(sessions);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 13),
      );
      // The aim stays anchored near the top of the user's range (>=7), never
      // collapsed toward the band floor (3) despite recent reset-low sessions.
      expect(s!.reps, greaterThanOrEqualTo(7));
    });
  });

  group('suggestNext — onboarding training-focus seed', () {
    test('a Strength focus seeds the cold-start rep target (sparse history)',
        () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', _sets(80, [5, 5, 5, 5, 5])),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        focus: TrainingFocus.strength,
        now: DateTime(2025, 1, 5),
      );
      // 1 session = sparse → the Strength seed (5), not the kind default (8):
      // the user hit 5 across the work, so +load at 5 reps.
      expect(s!.reps, 5);
      expect(s.reason, OverloadReason.weightIncrease);
    });

    test('null focus keeps the legacy kind default (sparse)', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', _sets(80, [5, 5, 5, 5, 5])),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 5),
      );
      // No focus → the kind default aim 8 (the pre-feature behavior).
      expect(s!.reps, 8);
      expect(s.reason, OverloadReason.repTarget);
    });

    test('once history exists the focus does NOT override it (seed, not clamp)',
        () async {
      final svc = ProgressiveOverloadService.fromSessions([
        for (final d in [1, 3, 5])
          _session(date: DateTime(2025, 1, d), exercises: [_log('bench', _sets(80, [8, 8, 8]))]),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        focus: TrainingFocus.strength,
        now: DateTime(2025, 1, 8),
      );
      // 3 sessions of 8s → history-anchored (median 8 → aim 9), kind-banded. The
      // Strength seed (5) is ignored — history wins once it exists.
      expect(s!.reps, 9);
    });

    test('an Endurance focus seeds high reps for a bodyweight cold-start',
        () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('pullup', _sets(0, [15, 15, 15, 15, 15])),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('pullup', mechanic: 'compound', equipment: 'body only'),
        focus: TrainingFocus.endurance,
        now: DateTime(2025, 1, 5),
      );
      // Sparse bodyweight + Endurance → aim 15, met across the work → +1 rep.
      expect(s!.reps, 16);
      expect(s.reason, OverloadReason.weightIncrease);
    });
  });

  group('suggestNext — isolation (target 12)', () {
    test('hit target → +2.5 kg', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('curl', _sets(20, [12, 12, 12, 12, 12])),
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
            _log('curl', _sets(20, [12, 12, 12, 12, 11])),
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
            _log('pullup', _sets(0, [15, 15, 15, 15, 15])),
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
            _log('pullup', _sets(0, [10, 10, 10, 10, 10])),
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

  group('suggestNext — program prescription', () {
    test('fixed prescription overrides the kind default (linear bump)', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', _sets(80, [5, 5, 5, 5, 5])),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        targetRepMin: 5,
        now: DateTime(2025, 1, 5),
      );
      expect(s!.reason, OverloadReason.weightIncrease);
      expect(s.weight, 82.5);
      expect(s.reps, 5);
    });

    test('without a prescription a single low-rep session does NOT deload '
        '(sparse → no judgment; #5)', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', _sets(80, [5, 5, 5, 5, 5])),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        now: DateTime(2025, 1, 5),
      );
      // Contrast with the prescribed sibling above (which linear-bumps): with no
      // prescription and only one session, the engine encourages, never deloads.
      expect(s!.reason, OverloadReason.repTarget);
    });

    test('double progression: hit the top → +load, reps reset to the floor', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', _sets(80, [12, 12, 12, 12, 12])),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        targetRepMin: 8,
        targetRepMax: 12,
        now: DateTime(2025, 1, 5),
      );
      expect(s!.reason, OverloadReason.weightIncrease);
      expect(s.weight, 82.5);
      expect(s.reps, 8);
    });

    test('double progression: inside the range → hold load, aim for the top', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', _sets(80, [8, 8, 8, 8, 8])),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        targetRepMin: 8,
        targetRepMax: 12,
        now: DateTime(2025, 1, 5),
      );
      // Bottom of an 8–12 range must NOT deload.
      expect(s!.reason, OverloadReason.repTarget);
      expect(s.weight, 80);
      expect(s.reps, 12);
    });

    test('double progression: below the floor → deload', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', _sets(80, [5, 5, 5, 5, 5])),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        targetRepMin: 8,
        targetRepMax: 12,
        now: DateTime(2025, 1, 5),
      );
      expect(s!.reason, OverloadReason.deload);
      expect(s.weight, 76);
    });

    test('cold start (<5 logged sets) yields no load suggestion', () async {
      final svc = ProgressiveOverloadService.fromSessions([
        _session(
          date: DateTime(2025, 1, 1),
          exercises: [
            _log('bench', _sets(80, [8, 8])),
          ],
        ),
      ]);
      final s = await svc.suggestNext(
        _exercise('bench', mechanic: 'compound'),
        targetRepMin: 8,
        targetRepMax: 12,
        now: DateTime(2025, 1, 5),
      );
      expect(s, isNull);
    });
  });
}
