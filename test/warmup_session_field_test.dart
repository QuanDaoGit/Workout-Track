import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/workout_models.dart';

ExerciseLog _log({
  List<SetEntry> sets = const [SetEntry(weight: 60, reps: 5)],
  List<SetEntry> warmupSets = const [],
}) => ExerciseLog(
  exerciseId: 'bench',
  exerciseName: 'Bench Press',
  sets: sets,
  warmupSets: warmupSets,
);

WorkoutSession _session({List<ExerciseLog>? exercises}) => WorkoutSession(
  id: 's1',
  date: DateTime(2026, 6, 13),
  muscleGroup: 'Chest',
  targetDurationMinutes: 30,
  actualDurationSeconds: 1800,
  exercises: exercises ?? [_log()],
  estimatedCalories: 100,
);

void main() {
  group('SetEntry.isWarmup', () {
    test('round-trips through JSON; omitted when false', () {
      expect(const SetEntry(weight: 40, reps: 8).toJson().containsKey('warmup'), isFalse);
      final j = const SetEntry(weight: 40, reps: 8, isWarmup: true).toJson();
      expect(j['warmup'], true);
      expect(SetEntry.fromJson(j).isWarmup, isTrue);
    });

    test('legacy set (no warmup key) decodes to false', () {
      expect(SetEntry.fromJson({'weight': 40, 'reps': 8}).isWarmup, isFalse);
    });
  });

  group('ExerciseLog.warmupSets', () {
    test('round-trips and stays out of totalVolume', () {
      final log = _log(
        sets: const [SetEntry(weight: 100, reps: 5)],
        warmupSets: const [SetEntry(weight: 40, reps: 10, isWarmup: true)],
      );
      // 100*5 only — the 40*10 warm-up set is excluded.
      expect(log.totalVolume, 500);
      expect(log.hasWarmupSet, isTrue);

      final restored = ExerciseLog.fromJson(log.toJson());
      expect(restored.warmupSets, hasLength(1));
      expect(restored.warmupSets.first.isWarmup, isTrue);
      expect(restored.totalVolume, 500);
    });

    test('legacy log (no warmupSets key) decodes to empty — no cliff', () {
      final legacy = {
        'exerciseId': 'bench',
        'exerciseName': 'Bench Press',
        'sets': [
          {'weight': 100, 'reps': 5},
        ],
      };
      final log = ExerciseLog.fromJson(legacy);
      expect(log.warmupSets, isEmpty);
      expect(log.hasWarmupSet, isFalse);
    });
  });

  group('WorkoutSession.warmedUp (derived)', () {
    test('false when no exercise carries a warm-up set', () {
      expect(_session().warmedUp, isFalse);
    });

    test('true when any exercise carries a warm-up set', () {
      final s = _session(
        exercises: [
          _log(warmupSets: const [SetEntry(weight: 40, reps: 10, isWarmup: true)]),
        ],
      );
      expect(s.warmedUp, isTrue);
    });

    test('not persisted as a stored field — derived from the exercises only', () {
      final s = _session(
        exercises: [
          _log(warmupSets: const [SetEntry(weight: 40, reps: 10, isWarmup: true)]),
        ],
      );
      // No top-level warmedUp key; round-trips back to true via warmupSets.
      expect(s.toJson().containsKey('warmedUp'), isFalse);
      expect(WorkoutSession.fromJson(s.toJson()).warmedUp, isTrue);
    });

    test('survives copyWith (warm-up sets ride on the exercises)', () {
      final s = _session(
        exercises: [
          _log(warmupSets: const [SetEntry(weight: 40, reps: 10, isWarmup: true)]),
        ],
      ).copyWith(statDelta: {'STR': 2});
      expect(s.warmedUp, isTrue);
    });
  });
}
