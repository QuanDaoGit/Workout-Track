import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/rest_models.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/quest_service.dart';
import 'package:workout_track/services/rest_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('daily quests are fixed, automatic, and training-derived', () async {
    final service = QuestService();
    final now = DateTime(2026, 5, 13, 10);

    final initial = await service.getSummary(const [], now: now);
    expect(initial.dailyQuests.map((quest) => quest.id), [
      'show_up',
      'class_focus',
      'volume_floor',
    ]);
    expect(initial.dailyQuests.where((quest) => quest.isManual), isEmpty);
    expect(initial.dailyQuests.where((quest) => quest.completed), isEmpty);

    final completed = await service.getSummary([
      _session(date: now, setCount: 4),
    ], now: now);
    expect(completed.dailyQuests.every((quest) => quest.completed), isTrue);
    expect(completed.dailyQuests.map((quest) => quest.rewardXP), [5, 10, 15]);
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

  test('automatic daily rewards claim once after completion', () async {
    final service = QuestService();
    final now = DateTime(2026, 5, 13, 10);
    final empty = await service.getSummary(const [], now: now);
    final showUp = empty.dailyQuests.firstWhere(
      (quest) => quest.id == 'show_up',
    );

    expect(await service.claimReward(showUp.claimKey, const [], now: now), 0);

    final sessions = [_session(date: now)];
    final completed = await service.getSummary(sessions, now: now);
    final claimable = completed.dailyQuests.firstWhere(
      (quest) => quest.id == 'show_up',
    );
    final firstClaim = await service.claimReward(
      claimable.claimKey,
      sessions,
      now: now,
    );
    final secondClaim = await service.claimReward(
      claimable.claimKey,
      sessions,
      now: now,
    );

    expect(firstClaim, 5);
    expect(secondClaim, 0);
    expect((await service.getSummary(sessions, now: now)).claimedRewardXP, 5);
  });

  test('unclaimed daily rewards do not carry forward after midnight', () async {
    final service = QuestService();
    final dayOne = DateTime(2026, 5, 13, 10);
    final dayTwo = dayOne.add(const Duration(days: 1));
    final dayOneSessions = [_session(date: dayOne)];
    final dayOneSummary = await service.getSummary(dayOneSessions, now: dayOne);
    final dayOneShowUp = dayOneSummary.dailyQuests.firstWhere(
      (quest) => quest.id == 'show_up',
    );

    expect(dayOneShowUp.claimable, isTrue);
    expect(
      await service.claimReward(
        dayOneShowUp.claimKey,
        dayOneSessions,
        now: dayTwo,
      ),
      0,
    );
  });

  test('LCK multiplier applies when quest rewards are claimed', () async {
    final service = QuestService();
    final now = DateTime(2026, 5, 13, 10);
    final sessions = [
      for (var i = 24; i >= 0; i--)
        _session(date: DateTime(now.year, now.month, now.day - i, 10)),
    ];

    final summary = await service.getSummary(sessions, now: now);
    final classFocus = summary.dailyQuests.firstWhere(
      (quest) => quest.id == 'class_focus',
    );

    expect(classFocus.rewardXP, 15);
    expect(
      await service.claimReward(classFocus.claimKey, sessions, now: now),
      15,
    );
  });

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

  test(
    '300 completed lifetime minutes completes the time side quest',
    () async {
      final service = QuestService();
      final now = DateTime(2026, 5, 13, 10);
      final sessions = [_session(date: now, seconds: 18000)];

      final summary = await service.getSummary(sessions, now: now);
      final quest = summary.sideQuests.firstWhere(
        (quest) => quest.id == 'side_minutes_300',
      );

      expect(quest.title, 'Time Trial');
      expect(quest.rewardTitle, 'Time Keeper');
      expect(quest.completed, isTrue);
      expect(quest.progressLabel, '300 / 300 min');
    },
  );

  test('partial sessions do not count toward the time side quest', () async {
    final service = QuestService();
    final now = DateTime(2026, 5, 13, 10);
    final sessions = [
      _session(date: now, seconds: 18000, isPartial: true, isAbandoned: true),
      _session(
        date: now.add(const Duration(minutes: 1)),
        seconds: 18000,
        isPartial: true,
      ),
    ];

    final summary = await service.getSummary(sessions, now: now);
    final quest = summary.sideQuests.firstWhere(
      (quest) => quest.id == 'side_minutes_300',
    );

    expect(quest.completed, isFalse);
    expect(quest.progressLabel, '0 / 300 min');
  });

  test('legacy Oath Keeper claims migrate to Time Keeper', () async {
    final now = DateTime(2026, 5, 13, 10);
    SharedPreferences.setMockInitialValues({
      'quest_state_v1': jsonEncode({
        'dailyPeriodKey': '2026-05-13',
        'weeklyPeriodKey': '2026-05-11',
        'manualDoneKeys': <String>[],
        'selectedTitle': 'Oath Keeper',
        'claims': {
          'side:side_streak_3': {
            'xp': 123,
            'claimedAt': now.toIso8601String(),
            'title': 'Oath Keeper',
          },
        },
      }),
    });

    final summary = await QuestService().getSummary(const [], now: now);
    final quest = summary.sideQuests.firstWhere(
      (quest) => quest.id == 'side_minutes_300',
    );

    expect(summary.claimedRewardXP, 123);
    expect(summary.earnedTitles, contains('Time Keeper'));
    expect(summary.selectedTitle, 'Time Keeper');
    expect(quest.claimed, isTrue);
    expect(quest.rewardXP, 123);
  });

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

  test(
    'recovery XP scales quest rewards but does not complete quests',
    () async {
      final now = DateTime(2026, 5, 12);
      SharedPreferences.setMockInitialValues({
        RestService.stateKey: jsonEncode(
          RestState.defaults(currentWeekKey: RestService.weekKey(now))
              .copyWith(
                recoveryClaims: {
                  '2026-05-12': RestRecoveryClaim(xp: 500, claimedAt: now),
                },
              )
              .toJson(),
        ),
      });

      final summary = await QuestService().getSummary(const [], now: now);
      final firstWorkout = summary.weeklyQuests.firstWhere(
        (quest) => quest.id == 'weekly_workout_1',
      );
      final side = summary.sideQuests.firstWhere(
        (quest) => quest.id == 'side_first_workout',
      );

      expect(firstWorkout.completed, isFalse);
      expect(side.completed, isFalse);
      expect(side.rewardXP, 50);
    },
  );
}

WorkoutSession _session({
  required DateTime date,
  String muscleGroup = 'Chest',
  int setCount = 3,
  int seconds = 1800,
  bool isPartial = false,
  bool isAbandoned = false,
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
    isPartial: isPartial,
    isAbandoned: isAbandoned,
  );
}
