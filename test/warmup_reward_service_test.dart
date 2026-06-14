import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/gem_service.dart';
import 'package:workout_track/services/warmup_reward_service.dart';

// `warmedUp` is now observable: it means the session carries a logged warm-up
// set (not a self-reported flag). The helper maps it onto a real warm-up set.
WorkoutSession _session({
  required bool warmedUp,
  bool partial = false,
  bool abandoned = false,
  int reps = 5,
  String id = 's1',
  DateTime? date,
}) => WorkoutSession(
  id: id,
  date: date ?? DateTime(2026, 6, 13, 10),
  muscleGroup: 'Chest',
  targetDurationMinutes: 30,
  actualDurationSeconds: 1800,
  exercises: [
    ExerciseLog(
      exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
      exerciseName: 'Bench',
      sets: [SetEntry(weight: 60, reps: reps)],
      warmupSets: warmedUp
          ? const [SetEntry(weight: 20, reps: 10, isWarmup: true)]
          : const [],
    ),
  ],
  estimatedCalories: 100,
  isPartial: partial,
  isAbandoned: abandoned,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<int> grant(WorkoutSession s) =>
      WarmupRewardService().grantForSession(s);

  test('a warmed-up real session earns the gem bonus', () async {
    expect(await grant(_session(warmedUp: true)), WarmupRewardService.gemReward);
    expect(await GemService().balance(), WarmupRewardService.gemReward);
  });

  test('no warm-up → no bonus', () async {
    expect(await grant(_session(warmedUp: false)), 0);
    expect(await GemService().balance(), 0);
  });

  test('warmed up but no real set (reps 0) → no bonus (must be real training)', () async {
    expect(await grant(_session(warmedUp: true, reps: 0)), 0);
    expect(await GemService().balance(), 0);
  });

  test('partial and abandoned sessions never reward', () async {
    expect(await grant(_session(warmedUp: true, partial: true)), 0);
    expect(await grant(_session(warmedUp: true, abandoned: true)), 0);
    expect(await GemService().balance(), 0);
  });

  test('idempotent: re-granting the same session does not double-credit', () async {
    final s = _session(warmedUp: true);
    expect(await grant(s), WarmupRewardService.gemReward);
    expect(await grant(s), 0);
    expect(await GemService().balance(), WarmupRewardService.gemReward);
  });

  test('daily cap: a second warmed-up session the same day earns nothing more', () async {
    final morning = _session(warmedUp: true, id: 'a', date: DateTime(2026, 6, 13, 8));
    final evening = _session(warmedUp: true, id: 'b', date: DateTime(2026, 6, 13, 19));
    expect(await grant(morning), WarmupRewardService.gemReward);
    expect(await grant(evening), 0); // same calendar day → capped
    expect(await GemService().balance(), WarmupRewardService.gemReward);
  });

  test('a warmed-up session on a different day earns its own bonus', () async {
    final day1 = _session(warmedUp: true, id: 'a', date: DateTime(2026, 6, 13));
    final day2 = _session(warmedUp: true, id: 'b', date: DateTime(2026, 6, 14));
    expect(await grant(day1), WarmupRewardService.gemReward);
    expect(await grant(day2), WarmupRewardService.gemReward);
    expect(await GemService().balance(), 2 * WarmupRewardService.gemReward);
  });
}
