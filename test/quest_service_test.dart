import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/quest_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('daily manual completion resets with a new local day', () async {
    final service = QuestService();
    final dayOne = DateTime(2026, 5, 13, 10);
    final dayTwo = dayOne.add(const Duration(days: 1));

    final initial = await service.getSummary(const [], now: dayOne);
    final manual = initial.dailyQuests.firstWhere((quest) => quest.isManual);

    await service.markManualDone(manual.claimKey, now: dayOne);
    final completed = await service.getSummary(const [], now: dayOne);
    expect(
      completed.dailyQuests
          .firstWhere((quest) => quest.claimKey == manual.claimKey)
          .completed,
      isTrue,
    );

    final reset = await service.getSummary(const [], now: dayTwo);
    expect(
      reset.dailyQuests.where((quest) => quest.isManual && quest.completed),
      isEmpty,
    );
  });

  test('weekly workout quests reset on the next Monday period', () async {
    final service = QuestService();
    final weekOne = DateTime(2026, 5, 13, 10);
    final weekTwo = weekOne.add(const Duration(days: 7));
    final sessions = [_session(date: weekOne)];

    final current = await service.getSummary(sessions, now: weekOne);
    expect(
      current.weeklyQuests
          .firstWhere((quest) => quest.id == 'weekly_workout_1')
          .completed,
      isTrue,
    );

    final next = await service.getSummary(sessions, now: weekTwo);
    expect(
      next.weeklyQuests
          .firstWhere((quest) => quest.id == 'weekly_workout_1')
          .completed,
      isFalse,
    );
  });

  test(
    'manual quests require done before claiming and only claim once',
    () async {
      final service = QuestService();
      final now = DateTime(2026, 5, 13, 10);
      final initial = await service.getSummary(const [], now: now);
      final manual = initial.dailyQuests.firstWhere((quest) => quest.isManual);

      expect(await service.claimReward(manual.claimKey, const [], now: now), 0);

      await service.markManualDone(manual.claimKey, now: now);
      final firstClaim = await service.claimReward(
        manual.claimKey,
        const [],
        now: now,
      );
      final secondClaim = await service.claimReward(
        manual.claimKey,
        const [],
        now: now,
      );

      expect(firstClaim, greaterThan(0));
      expect(secondClaim, 0);
      expect(
        (await service.getSummary(const [], now: now)).claimedRewardXP,
        firstClaim,
      );
    },
  );

  test(
    'saved workout history completes retroactive weekly and side quests',
    () async {
      final service = QuestService();
      final now = DateTime(2026, 5, 13, 10);
      final sessions = [_session(date: now, setCount: 10)];

      final summary = await service.getSummary(sessions, now: now);

      expect(
        summary.weeklyQuests
            .firstWhere((quest) => quest.id == 'weekly_workout_1')
            .completed,
        isTrue,
      );
      expect(
        summary.weeklyQuests
            .firstWhere((quest) => quest.id == 'weekly_sets_10')
            .completed,
        isTrue,
      );
      expect(
        summary.sideQuests
            .firstWhere((quest) => quest.id == 'side_first_workout')
            .completed,
        isTrue,
      );
    },
  );

  test('claimed side quest titles can be selected and persist', () async {
    final service = QuestService();
    final now = DateTime(2026, 5, 13, 10);
    final sessions = [_session(date: now)];
    final summary = await service.getSummary(sessions, now: now);
    final side = summary.sideQuests.firstWhere(
      (quest) => quest.id == 'side_first_workout',
    );

    final reward = await service.claimReward(side.claimKey, sessions, now: now);
    await service.selectTitle('Iron Novice');
    final updated = await service.getSummary(sessions, now: now);

    expect(reward, greaterThan(0));
    expect(updated.earnedTitles, contains('Iron Novice'));
    expect(updated.selectedTitle, 'Iron Novice');
  });

  test('period key helpers use local day and Monday week start', () {
    expect(QuestService.dailyPeriodKey(DateTime(2026, 5, 13)), '2026-05-13');
    expect(QuestService.weeklyPeriodKey(DateTime(2026, 5, 13)), '2026-05-11');
  });
}

WorkoutSession _session({
  required DateTime date,
  String muscleGroup = 'Chest',
  int setCount = 3,
  int seconds = 1800,
}) {
  return WorkoutSession(
    id: date.microsecondsSinceEpoch.toString(),
    date: date,
    muscleGroup: muscleGroup,
    targetDurationMinutes: 30,
    actualDurationSeconds: seconds,
    exercises: [
      ExerciseLog(
        exerciseId: 'bench',
        exerciseName: 'Bench Press',
        sets: [
          for (int i = 0; i < setCount; i++)
            const SetEntry(weight: 50, reps: 5),
        ],
      ),
    ],
    estimatedCalories: 100,
  );
}
