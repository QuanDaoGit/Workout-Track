import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/loot_item.dart';
import 'package:workout_track/models/rest_models.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/gem_service.dart';
import 'package:workout_track/services/loot_service.dart';
import 'package:workout_track/services/quest_service.dart';
import 'package:workout_track/models/unit_models.dart';
import 'package:workout_track/services/rest_service.dart';
import 'package:workout_track/services/unit_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Units.weight = WeightUnit.kg;
  });

  test('daily quests rotate (3, anchored by Show Up), automatic, gem-only',
      () async {
    final service = QuestService();
    final now = DateTime(2026, 5, 13, 10);

    final initial = await service.getSummary(const [], now: now);
    // Three per day, deterministically picked, with Show Up always anchored first.
    expect(initial.dailyQuests.length, 3);
    expect(initial.dailyQuests.first.id, 'show_up');
    expect(initial.dailyQuests.every((quest) => !quest.isManual), isTrue);
    expect(initial.dailyQuests.every((quest) => quest.rewardGems == 5), isTrue);
    expect(initial.dailyQuests.where((quest) => quest.completed), isEmpty);

    // A workout today completes the Show Up anchor (auto-evaluated, gems only).
    final completed = await service.getSummary([
      _session(date: now, setCount: 4),
    ], now: now);
    final showUp =
        completed.dailyQuests.firstWhere((quest) => quest.id == 'show_up');
    expect(showUp.completed, isTrue);
    expect(showUp.rewardXP, 0);
    expect(showUp.rewardGems, 5);
  });

  test('weekly workout quests reset on the next Monday period', () async {
    final service = QuestService();
    final weekOne = DateTime(2026, 5, 13, 10);
    final weekTwo = weekOne.add(const Duration(days: 7));
    final sessions = [_session(date: weekOne)];

    final current = await service.getSummary(sessions, now: weekOne);
    expect(
      current.weeklyQuests
          .firstWhere((quest) => quest.id == 'opening_move')
          .completed,
      isTrue,
    );

    final next = await service.getSummary(sessions, now: weekTwo);
    expect(
      next.weeklyQuests
          .firstWhere((quest) => quest.id == 'opening_move')
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

    final emptyClaim = await service.claimReward(
      showUp.claimKey,
      const [],
      now: now,
    );
    expect(emptyClaim.gems, 0);
    expect(emptyClaim.xp, 0);

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

    expect(firstClaim.gems, 5);
    expect(firstClaim.xp, 0);
    expect(secondClaim.gems, 0);
    final updated = await service.getSummary(sessions, now: now);
    expect(updated.claimedRewardXP, 0);
    expect(updated.claimedRewardGems, 5);
    expect(await GemService().balance(), 5);
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
    final claim = await service.claimReward(
      dayOneShowUp.claimKey,
      dayOneSessions,
      now: dayTwo,
    );
    expect(claim.gems, 0);
    expect(claim.xp, 0);
  });

  test('LCK multiplier does not scale gem quest rewards', () async {
    final service = QuestService();
    final now = DateTime(2026, 5, 13, 10);
    final sessions = [
      for (var i = 24; i >= 0; i--)
        _session(date: DateTime(now.year, now.month, now.day - i, 10)),
    ];

    final summary = await service.getSummary(sessions, now: now);
    final showUp = summary.dailyQuests.firstWhere(
      (quest) => quest.id == 'show_up',
    );

    expect(showUp.rewardXP, 0);
    expect(showUp.rewardGems, 5);
    final claim = await service.claimReward(
      showUp.claimKey,
      sessions,
      now: now,
    );
    expect(claim.gems, 5);
    expect(claim.xp, 0);
    expect(await GemService().balance(), 5);
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
            .firstWhere((quest) => quest.id == 'opening_move')
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

      expect(quest.title, 'Time Keeper');
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

    // The legacy claim is re-keyed to side_minutes_300 (titles are now loot, so
    // the rename is no longer surfaced on the summary).
    expect(summary.claimedRewardXP, 123);
    expect(summary.claimedRewardGems, 0);
    expect(quest.claimed, isTrue);
    expect(quest.rewardXP, 123);
    expect(quest.rewardGems, 0);
  });

  test('claiming a side quest grants its title as loot and equips the first', () async {
    final service = QuestService();
    final loot = LootService();
    final now = DateTime(2026, 5, 13, 10);
    final sessions = [_session(date: now)];
    final summary = await service.getSummary(sessions, now: now);
    final side = summary.sideQuests.firstWhere(
      (quest) => quest.id == 'side_first_workout',
    );

    final reward = await service.claimReward(side.claimKey, sessions, now: now);

    expect(reward.gems, 100);
    expect(reward.xp, 0);
    final owned = await loot.getInventory();
    expect(owned.any((item) => item.id == 'title_iron_novice'), isTrue);
    final equipped = await loot.getEquippedItem(LootCategory.titleBadge);
    expect(equipped?.id, 'title_iron_novice');
  });

  test('claiming a title does not override an already-equipped title', () async {
    final service = QuestService();
    final loot = LootService();
    final now = DateTime(2026, 5, 13, 10);
    final sessions = [_session(date: now)];
    await loot.equipItem('title_recruit');

    final summary = await service.getSummary(sessions, now: now);
    final side = summary.sideQuests.firstWhere(
      (quest) => quest.id == 'side_first_workout',
    );
    await service.claimReward(side.claimKey, sessions, now: now);

    final owned = await loot.getInventory();
    expect(owned.any((item) => item.id == 'title_iron_novice'), isTrue);
    final equipped = await loot.getEquippedItem(LootCategory.titleBadge);
    expect(equipped?.id, 'title_recruit');
  });

  test('period key helpers use local day and Monday week start', () {
    expect(QuestService.dailyPeriodKey(DateTime(2026, 5, 13)), '2026-05-13');
    expect(QuestService.weeklyPeriodKey(DateTime(2026, 5, 13)), '2026-05-11');
  });

  test('recovery XP does not scale gem rewards or complete quests', () async {
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
      (quest) => quest.id == 'opening_move',
    );
    final side = summary.sideQuests.firstWhere(
      (quest) => quest.id == 'side_first_workout',
    );

    expect(firstWorkout.completed, isFalse);
    expect(side.completed, isFalse);
    expect(side.rewardXP, 0);
    expect(side.rewardGems, 100);
  });

  test('rotation is deterministic per day and rotates across days', () async {
    final service = QuestService();
    final picks = [
      for (var i = 0; i < 6; i++)
        (await service.getSummary(const [], now: DateTime(2026, 5, 13 + i, 10)))
            .dailyQuests
            .map((quest) => quest.id)
            .join(','),
    ];
    // Same period (same day, different hour) → identical picks.
    final again = (await service.getSummary(const [],
            now: DateTime(2026, 5, 13, 22)))
        .dailyQuests
        .map((quest) => quest.id)
        .join(',');
    expect(again, picks.first);
    // Show Up always anchored first; three per day; the board rotates across days.
    expect(picks.every((p) => p.startsWith('show_up')), isTrue);
    expect(picks.every((p) => p.split(',').length == 3), isTrue);
    expect(picks.toSet().length, greaterThan(1));
  });

  test('Limit Break is featured + personalized once a baseline exists, else absent',
      () async {
    final service = QuestService();
    final now = DateTime(2026, 5, 13, 10); // week of Mon 2026-05-11

    // No prior weeks → Limit Break is never offered.
    final cold = await service.getSummary(const [], now: now);
    expect(cold.weeklyQuests.any((q) => q.id == 'limit_break'), isFalse);

    // Three prior weeks of training (1,000 / 2,000 / 3,000 kg) → avg 2,000 kg.
    final sessions = [
      _session(date: DateTime(2026, 5, 5, 10), setCount: 4), // 4*250 = 1000
      _session(date: DateTime(2026, 4, 28, 10), setCount: 8), // 2000
      _session(date: DateTime(2026, 4, 21, 10), setCount: 12), // 3000
    ];
    final warm = await service.getSummary(sessions, now: now);
    final lb = warm.weeklyQuests.firstWhere((q) => q.id == 'limit_break');

    // avg 2000 * 1.15 = 2300 → a round hundred.
    expect(lb.description.replaceAll(',', ''), contains('2300'));
    expect(lb.completed, isFalse); // this week's volume is 0
  });

  test('Limit Break uses a gentler 1.10x stretch with under 3 weeks of history',
      () async {
    final service = QuestService();
    final now = DateTime(2026, 5, 13, 10);
    // A single noisy baseline week of 2,000 kg → gentler factor 1.10.
    final sessions = [_session(date: DateTime(2026, 5, 5, 10), setCount: 8)];
    final warm = await service.getSummary(sessions, now: now);
    final lb = warm.weeklyQuests.firstWhere((q) => q.id == 'limit_break');
    // 2000 * 1.10 = 2200 (a round hundred, inside the [x1.05, x1.30] safety clamp).
    expect(lb.description.replaceAll(',', ''), contains('2200'));
  });

  test('Limit Break rounds the target to a clean hundred in the display unit (lbs)',
      () async {
    Units.weight = WeightUnit.lbs;
    final service = QuestService();
    final now = DateTime(2026, 5, 13, 10);
    // avg 2000 kg * 1.15 = ~2300 kg ~= 5071 lbs → rounded IN LBS to 5,100.
    final sessions = [
      _session(date: DateTime(2026, 5, 5, 10), setCount: 4), // 1000 kg
      _session(date: DateTime(2026, 4, 28, 10), setCount: 8), // 2000 kg
      _session(date: DateTime(2026, 4, 21, 10), setCount: 12), // 3000 kg
    ];
    final warm = await service.getSummary(sessions, now: now);
    final lb = warm.weeklyQuests.firstWhere((q) => q.id == 'limit_break');
    expect(lb.description, contains('5100 lbs'));
  });
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
