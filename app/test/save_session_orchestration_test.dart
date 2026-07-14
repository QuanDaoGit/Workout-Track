import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/adventure_service.dart';
import 'package:workout_track/services/gem_service.dart';
import 'package:workout_track/services/warmup_reward_service.dart';
import 'package:workout_track/services/workout_storage_service.dart';

/// Cross-store atomicity: one `saveSession` must leave EVERY downstream store
/// consistent (workout_sessions + gem ledger + adventure charges + mission
/// marker), and a re-save must not double-award. The per-service reward tests
/// exercise `grantForSession` / `grantChargeForSession` in isolation — they do
/// NOT prove `saveSession` actually wires them. A regression that dropped the
/// `WarmupRewardService().grantForSession(session)` line (or the adventure /
/// mission calls) would pass every existing test; this is the guard for it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  WorkoutSession warmedSession({String id = 'w1'}) => WorkoutSession(
    id: id,
    date: DateTime(2026, 6, 13, 10),
    muscleGroup: 'Chest',
    targetMuscleGroups: const ['Chest'],
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    estimatedCalories: 100,
    exercises: const [
      ExerciseLog(
        exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
        exerciseName: 'Bench',
        sets: [SetEntry(weight: 60, reps: 8)],
        warmupSets: [SetEntry(weight: 20, reps: 10, isWarmup: true)],
      ),
    ],
  );

  test('one save fans out consistently to every downstream store', () async {
    final storage = WorkoutStorageService();
    await storage.saveSession(warmedSession());

    // (a) the session is persisted as a completed (non-ongoing) row.
    final sessions = await storage.getSessions();
    expect(sessions.where((s) => s.id == 'w1'), hasLength(1));
    expect(sessions.single.isOngoing, isFalse);

    // (b) the warm-up gem bonus was wired through (not just available in isolation).
    expect(await GemService().balance(), WarmupRewardService.gemReward);

    // (c) the adventure charge was granted by the save.
    expect((await AdventureService().loadState()).charges, 1);

    // (d) today's mission is marked completed.
    expect(
      await WorkoutStorageService.missionFinishStateToday(
        now: DateTime(2026, 6, 13, 12),
      ),
      MissionFinishState.completed,
    );
  });

  test('re-running the reward fan-out never double-awards (idempotent path)', () async {
    // saveSession dedupes only the ongoing→completed checkpoint row (covered in
    // workout_session_lifecycle); it is otherwise an append, so re-saving a
    // *completed* session is not a real path. The cross-store guarantee that DOES
    // hold is reward idempotency: the warm-up bonus is once/day and the adventure
    // charge is once/day, so a second qualifying save the same day pays nothing
    // more — even though XP-bearing history would accumulate.
    final storage = WorkoutStorageService();
    await storage.saveSession(warmedSession(id: 'w1'));
    await storage.saveSession(warmedSession(id: 'w2')); // distinct id, same day

    expect(await GemService().balance(), WarmupRewardService.gemReward);
    expect((await AdventureService().loadState()).charges, 1);
  });

  test('an abandoned save writes the row but awards nothing', () async {
    final storage = WorkoutStorageService();
    final abandoned = WorkoutSession(
      id: 'a1',
      date: DateTime(2026, 6, 13, 10),
      muscleGroup: 'Chest',
      targetMuscleGroups: const ['Chest'],
      targetDurationMinutes: 30,
      actualDurationSeconds: 600,
      estimatedCalories: 50,
      isPartial: true,
      isAbandoned: true,
      exercises: const [
        ExerciseLog(
          exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
          exerciseName: 'Bench',
          sets: [SetEntry(weight: 60, reps: 8)],
          warmupSets: [SetEntry(weight: 20, reps: 10, isWarmup: true)],
        ),
      ],
    );
    await storage.saveSession(abandoned);

    expect((await storage.getSessions()).where((s) => s.id == 'a1'), hasLength(1));
    // Abandoned sessions are gated out of every reward path.
    expect(await GemService().balance(), 0);
    expect((await AdventureService().loadState()).charges, 0);
  });
}
