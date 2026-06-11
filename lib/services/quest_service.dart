import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/class_definitions.dart';
import '../data/loot_registry.dart';
import '../models/character_class.dart';
import '../models/loot_item.dart';
import '../models/quest_models.dart';
import '../models/unit_models.dart';
import '../models/workout_models.dart';
import 'class_service.dart';
import 'loot_service.dart';
import 'unit_settings_service.dart';
import 'gem_service.dart';
import 'rest_service.dart';
import 'xp_boost_service.dart';
import 'xp_service.dart';

class QuestService {
  static const String _stateKey = 'quest_state_v1';
  static const String _oldTimeQuestClaimKey = 'side:side_streak_3';
  static const String _timeQuestClaimKey = 'side:side_minutes_300';
  static const String _oldTimeTitle = 'Oath Keeper';
  static const String _timeTitle = 'Time Keeper';

  Future<QuestSummary> getSummary(
    List<WorkoutSession> sessions, {
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    final state = await _loadState(currentTime);
    final currentClass = await ClassService().getCurrentClass();
    final stats = _QuestStats.fromSessions(sessions, currentTime, currentClass);
    final restService = RestService(nowProvider: () => currentTime);
    final currentRecoveryXP = await restService.effectiveRecoveryXP(
      sessions,
      now: currentTime,
    );
    final potionBonusXP = await XpBoostService().getTotalBonusXP();
    await restService.ensureAutomaticRecoveryForToday(
      sessions: sessions,
      baseXP:
          XpService.calculateTotalXP(sessions) +
          state.claimedXP +
          currentRecoveryXP +
          potionBonusXP,
      now: currentTime,
    );
    final daily = _buildDailyQuests(state, stats);
    final weekly = _buildWeeklyQuests(state, stats);
    final side = _buildSideQuests(state, stats);

    // Titles are now loot (see LootCategory.titleBadge). The active title is the
    // equipped loot badge, surfaced by LootService — not tracked here.
    return QuestSummary(
      dailyQuests: daily,
      weeklyQuests: weekly,
      sideQuests: side,
      claimedRewardXP: state.claimedXP,
      claimedRewardGems: state.claimedGems,
      todayClaimedXP: _claimedXPForDay(state, currentTime),
      todayClaimedGems: _claimedGemsForDay(state, currentTime),
    );
  }

  Future<int> claimedRewardXP() async {
    final state = await _loadState(DateTime.now());
    return state.claimedXP;
  }

  Future<int> todayClaimedXP({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    final state = await _loadState(currentTime);
    return _claimedXPForDay(state, currentTime);
  }

  Future<int> claimedRewardGems() async {
    final state = await _loadState(DateTime.now());
    return state.claimedGems;
  }

  Future<int> todayClaimedGems({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    final state = await _loadState(currentTime);
    return _claimedGemsForDay(state, currentTime);
  }

  Future<void> markManualDone(String claimKey, {DateTime? now}) async {
    final state = await _loadState(now ?? DateTime.now());
    final updated = {...state.manualDoneKeys, claimKey};
    await _saveState(state.copyWith(manualDoneKeys: updated));
  }

  Future<QuestClaimResult> claimReward(
    String claimKey,
    List<WorkoutSession> sessions, {
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    final summary = await getSummary(sessions, now: currentTime);
    QuestItem? quest;
    for (final item in [
      ...summary.dailyQuests,
      ...summary.weeklyQuests,
      ...summary.sideQuests,
    ]) {
      if (item.claimKey == claimKey) {
        quest = item;
        break;
      }
    }

    if (quest == null || !quest.claimable) {
      return const QuestClaimResult(xp: 0, gems: 0);
    }

    final state = await _loadState(currentTime);
    if (state.claims.containsKey(claimKey)) {
      return const QuestClaimResult(xp: 0, gems: 0);
    }

    final claims = Map<String, QuestClaim>.from(state.claims);
    claims[claimKey] = QuestClaim(
      xp: 0,
      gems: quest.rewardGems,
      claimedAt: currentTime,
      title: quest.rewardTitle,
    );
    final awardedGems = await GemService().awardQuestGems(
      claimKey: claimKey,
      amount: quest.rewardGems,
      label: quest.title,
      now: currentTime,
    );

    await _grantQuestTitle(quest.id);
    await _saveState(state.copyWith(claims: claims));
    return QuestClaimResult(xp: 0, gems: awardedGems, title: quest.rewardTitle);
  }

  /// Grants the loot title that a claimed side quest rewards. The very first
  /// title a user earns is auto-equipped (the onboarding delight beat). After
  /// that, titles are added to the collection but never override the user's
  /// current choice — including an explicit "None". Titles are owned forever
  /// and freely re-selectable from the Inventory.
  Future<void> _grantQuestTitle(String questId) async {
    final lootId = sideQuestTitleLootId[questId];
    if (lootId == null) return;
    final loot = LootService();
    final inventory = await loot.getInventory();
    final ownedTitlesBefore = inventory
        .where((i) => i.category == LootCategory.titleBadge && !i.isDefault)
        .length;
    await loot.grantItem(lootId);
    final equipped = await loot.getEquippedItem(LootCategory.titleBadge);
    if (equipped == null && ownedTitlesBefore == 0) {
      await loot.equipItem(lootId);
    }
  }

  static String dailyPeriodKey(DateTime date) => _dateKey(date);

  static String weeklyPeriodKey(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return _dateKey(day.subtract(Duration(days: day.weekday - 1)));
  }

  Future<QuestState> _loadState(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    final dailyKey = dailyPeriodKey(now);
    final weeklyKey = weeklyPeriodKey(now);
    final loaded = raw == null
        ? QuestState.empty(dailyPeriodKey: dailyKey, weeklyPeriodKey: weeklyKey)
        : QuestState.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    final normalized = _normalizePeriods(loaded, dailyKey, weeklyKey);
    if (normalized != loaded) await _saveState(normalized);
    return normalized;
  }

  QuestState _normalizePeriods(
    QuestState state,
    String dailyKey,
    String weeklyKey,
  ) {
    var manualDone = state.manualDoneKeys;
    var claims = Map<String, QuestClaim>.from(state.claims);
    var selectedTitle = state.selectedTitle;

    if (state.dailyPeriodKey != dailyKey) {
      manualDone = manualDone.where((key) => !key.startsWith('daily:')).toSet();
    }

    final oldTimeClaim = claims.remove(_oldTimeQuestClaimKey);
    if (oldTimeClaim != null && !claims.containsKey(_timeQuestClaimKey)) {
      claims[_timeQuestClaimKey] = QuestClaim(
        xp: oldTimeClaim.xp,
        gems: oldTimeClaim.gems,
        claimedAt: oldTimeClaim.claimedAt,
        title: _timeTitle,
      );
    }
    claims = claims.map((key, claim) {
      if (claim.title != _oldTimeTitle) return MapEntry(key, claim);
      return MapEntry(
        key,
        QuestClaim(
          xp: claim.xp,
          gems: claim.gems,
          claimedAt: claim.claimedAt,
          title: _timeTitle,
        ),
      );
    });
    if (selectedTitle == _oldTimeTitle) {
      selectedTitle = _timeTitle;
    }

    return state.copyWith(
      dailyPeriodKey: dailyKey,
      weeklyPeriodKey: weeklyKey,
      manualDoneKeys: manualDone,
      claims: claims,
      selectedTitle: selectedTitle,
    );
  }

  Future<void> _saveState(QuestState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, jsonEncode(state.toJson()));
  }

  List<QuestItem> _buildDailyQuests(QuestState state, _QuestStats stats) {
    const templates = [
      _DailyTemplate('show_up', 'Show Up', 'Complete any workout today.', 5),
      _DailyTemplate(
        'class_focus',
        'Class Focus',
        "Train one of your class's primary muscle groups.",
        5,
      ),
      _DailyTemplate(
        'volume_floor',
        'Volume Floor',
        'Log 1,000 kg total volume today.',
        5,
      ),
    ];

    return [
      for (final template in templates)
        _dailyQuestItem(template, state, stats, state.dailyPeriodKey),
    ];
  }

  QuestItem _dailyQuestItem(
    _DailyTemplate template,
    QuestState state,
    _QuestStats stats,
    String periodKey,
  ) {
    final claimKey = 'daily:$periodKey:${template.id}';
    final claim = state.claims[claimKey];
    final completed = _isDailyAutoComplete(template.id, stats);

    return QuestItem(
      id: template.id,
      claimKey: claimKey,
      category: QuestCategory.daily,
      title: template.title,
      description: _questDescription(template.id, template.description),
      rewardXP: claim?.xp ?? 0,
      rewardGems: claim?.gems ?? template.rewardGems,
      completed: completed,
      claimed: claim != null,
      isManual: false,
      progressLabel: _dailyProgress(template.id, stats),
    );
  }

  List<QuestItem> _buildWeeklyQuests(QuestState state, _QuestStats stats) {
    const templates = [
      _WeeklyTemplate(
        'weekly_workout_1',
        'First Quest',
        'Complete 1 workout',
        5,
      ),
      _WeeklyTemplate(
        'weekly_workout_2',
        'Second Quest',
        'Complete 2 workouts',
        5,
      ),
      _WeeklyTemplate('weekly_sets_10', 'Set Smith', 'Log 10 total sets', 10),
      _WeeklyTemplate(
        'weekly_muscles_2',
        'Balanced Path',
        'Train 2 muscle groups',
        10,
      ),
      _WeeklyTemplate(
        'weekly_minutes_60',
        'Hour Trial',
        'Train 60 total minutes',
        20,
      ),
    ];

    return [
      for (final template in templates)
        _weeklyQuestItem(template, state, stats),
    ];
  }

  QuestItem _weeklyQuestItem(
    _WeeklyTemplate template,
    QuestState state,
    _QuestStats stats,
  ) {
    final claimKey = 'weekly:${state.weeklyPeriodKey}:${template.id}';
    final claim = state.claims[claimKey];
    final completed = switch (template.id) {
      'weekly_workout_1' => stats.weekCompletedSessions >= 1,
      'weekly_workout_2' => stats.weekCompletedSessions >= 2,
      'weekly_sets_10' => stats.weekSetCount >= 10,
      'weekly_muscles_2' => stats.weekMuscleGroups >= 2,
      'weekly_minutes_60' => stats.weekDurationSeconds >= 3600,
      _ => false,
    };

    return QuestItem(
      id: template.id,
      claimKey: claimKey,
      category: QuestCategory.weekly,
      title: template.title,
      description: template.description,
      rewardXP: claim?.xp ?? 0,
      rewardGems: claim?.gems ?? template.rewardGems,
      completed: completed,
      claimed: claim != null,
      isManual: false,
      progressLabel: _weeklyProgress(template.id, stats),
    );
  }

  List<QuestItem> _buildSideQuests(QuestState state, _QuestStats stats) {
    const templates = [
      _SideTemplate(
        'side_first_workout',
        'First Forge',
        'Complete your first workout',
        'Iron Novice',
        100,
      ),
      _SideTemplate(
        'side_sets_25',
        'Set Smith',
        'Log 25 total sets',
        'Set Smith',
        100,
      ),
      _SideTemplate(
        'side_minutes_300',
        'Time Trial',
        'Train 300 total minutes',
        'Time Keeper',
        100,
      ),
      _SideTemplate(
        'side_all_muscles',
        'Four Guilds',
        'Train Chest, Back, Arms, and Legs',
        'Guild Walker',
        100,
      ),
      _SideTemplate(
        'side_volume_10000',
        'Iron Ledger',
        'Reach 10,000 kg total volume',
        'Volume Knight',
        100,
      ),
    ];

    return [
      for (final template in templates) _sideQuestItem(template, state, stats),
    ];
  }

  QuestItem _sideQuestItem(
    _SideTemplate template,
    QuestState state,
    _QuestStats stats,
  ) {
    final claimKey = 'side:${template.id}';
    final claim = state.claims[claimKey];
    final completed = switch (template.id) {
      'side_first_workout' => stats.lifetimeCompletedSessions >= 1,
      'side_sets_25' => stats.lifetimeSetCount >= 25,
      'side_minutes_300' => stats.lifetimeDurationSeconds >= 18000,
      'side_all_muscles' => stats.lifetimeMuscleGroups >= 4,
      'side_volume_10000' => stats.lifetimeVolume >= 10000,
      _ => false,
    };

    return QuestItem(
      id: template.id,
      claimKey: claimKey,
      category: QuestCategory.side,
      title: template.title,
      description: _questDescription(template.id, template.description),
      rewardXP: claim?.xp ?? 0,
      rewardGems: claim?.gems ?? template.rewardGems,
      completed: completed,
      claimed: claim != null,
      isManual: false,
      progressLabel: _sideProgress(template.id, stats),
      rewardTitle: template.rewardTitle,
    );
  }

  bool _isDailyAutoComplete(String id, _QuestStats stats) {
    return switch (id) {
      'show_up' => stats.todayCompletedSessions >= 1,
      'class_focus' => stats.todayClassFocusTrained,
      'volume_floor' => stats.todayVolume >= 1000,
      _ => false,
    };
  }

  /// Volume-quest descriptions render their kg threshold in the active unit so
  /// the copy matches the progress counter (e.g. "Log 2,205 lbs..." / "0 / 2205
  /// lbs"). Non-volume quests keep their static [fallback] text.
  String _questDescription(String id, String fallback) {
    switch (id) {
      case 'volume_floor':
        return 'Log ${formatWeight(1000, Units.weight, decimals: 0)} total volume today.';
      case 'side_volume_10000':
        return 'Reach ${formatWeight(10000, Units.weight, decimals: 0)} total volume';
      default:
        return fallback;
    }
  }

  String _dailyProgress(String id, _QuestStats stats) {
    return switch (id) {
      'show_up' => '${min(stats.todayCompletedSessions, 1)} / 1',
      'class_focus' => stats.todayClassFocusTrained ? 'DONE' : '0 / 1',
      'volume_floor' =>
        '${weightValue(min(stats.todayVolume, 1000.0), Units.weight, decimals: 0)}'
            ' / ${formatWeight(1000, Units.weight, decimals: 0)}',
      _ => '',
    };
  }

  String _weeklyProgress(String id, _QuestStats stats) {
    return switch (id) {
      'weekly_workout_1' => '${min(stats.weekCompletedSessions, 1)} / 1',
      'weekly_workout_2' => '${min(stats.weekCompletedSessions, 2)} / 2',
      'weekly_sets_10' => '${min(stats.weekSetCount, 10)} / 10 sets',
      'weekly_muscles_2' => '${min(stats.weekMuscleGroups, 2)} / 2 groups',
      'weekly_minutes_60' =>
        '${min(stats.weekDurationSeconds ~/ 60, 60)} / 60 min',
      _ => '',
    };
  }

  String _sideProgress(String id, _QuestStats stats) {
    return switch (id) {
      'side_first_workout' => '${min(stats.lifetimeCompletedSessions, 1)} / 1',
      'side_sets_25' => '${min(stats.lifetimeSetCount, 25)} / 25 sets',
      'side_minutes_300' =>
        '${min(stats.lifetimeDurationSeconds ~/ 60, 300)} / 300 min',
      'side_all_muscles' => '${min(stats.lifetimeMuscleGroups, 4)} / 4 groups',
      'side_volume_10000' =>
        '${weightValue(min(stats.lifetimeVolume, 10000.0), Units.weight, decimals: 0)}'
            ' / ${formatWeight(10000, Units.weight, decimals: 0)}',
      _ => '',
    };
  }

  int _claimedXPForDay(QuestState state, DateTime day) {
    final key = _dateKey(day);
    return state.claims.values
        .where((claim) => _dateKey(claim.claimedAt) == key)
        .fold(0, (sum, claim) => sum + claim.xp);
  }

  int _claimedGemsForDay(QuestState state, DateTime day) {
    final key = _dateKey(day);
    return state.claims.values
        .where((claim) => _dateKey(claim.claimedAt) == key)
        .fold(0, (sum, claim) => sum + claim.gems);
  }

  static String _dateKey(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }
}

class _QuestStats {
  const _QuestStats({
    required this.todayCompletedSessions,
    required this.todayMuscles,
    required this.todayVolume,
    required this.todayClassFocusTrained,
    required this.weekCompletedSessions,
    required this.weekSetCount,
    required this.weekMuscleGroups,
    required this.weekDurationSeconds,
    required this.lifetimeCompletedSessions,
    required this.lifetimeSetCount,
    required this.lifetimeMuscleGroups,
    required this.lifetimeDurationSeconds,
    required this.lifetimeVolume,
  });

  final int todayCompletedSessions;
  final Set<String> todayMuscles;
  final double todayVolume;
  final bool todayClassFocusTrained;
  final int weekCompletedSessions;
  final int weekSetCount;
  final int weekMuscleGroups;
  final int weekDurationSeconds;
  final int lifetimeCompletedSessions;
  final int lifetimeSetCount;
  final int lifetimeMuscleGroups;
  final int lifetimeDurationSeconds;
  final double lifetimeVolume;

  factory _QuestStats.fromSessions(
    List<WorkoutSession> sessions,
    DateTime now,
    CharacterClass currentClass,
  ) {
    final completed = sessions.where((session) => !session.isPartial).toList();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final sunday = monday.add(const Duration(days: 7));
    final todaySessions = completed
        .where((session) => _sameDay(session.date, today))
        .toList();
    final weekSessions = completed
        .where(
          (session) =>
              !session.date.isBefore(monday) && session.date.isBefore(sunday),
        )
        .toList();

    final weekSetCount = weekSessions.fold(
      0,
      (sum, session) =>
          sum +
          session.exercises.fold(0, (setSum, log) => setSum + log.sets.length),
    );
    final lifetimeSetCount = completed.fold(
      0,
      (sum, session) =>
          sum +
          session.exercises.fold(0, (setSum, log) => setSum + log.sets.length),
    );
    final lifetimeVolume = completed.fold(
      0.0,
      (sum, session) =>
          sum +
          session.exercises.fold(
            0.0,
            (logSum, log) => logSum + log.totalVolume,
          ),
    );
    final todayVolume = todaySessions.fold(
      0.0,
      (sum, session) =>
          sum +
          session.exercises.fold(
            0.0,
            (logSum, log) => logSum + log.totalVolume,
          ),
    );
    final classTargets = musclesForClass(currentClass);
    final todayClassFocusTrained = todaySessions.any(
      (session) => session.targetMuscleGroups.any(
        (target) => classTargets.contains(target),
      ),
    );
    final lifetimeDurationSeconds = completed.fold(
      0,
      (sum, session) => sum + session.actualDurationSeconds,
    );

    return _QuestStats(
      todayCompletedSessions: todaySessions.length,
      todayMuscles: todaySessions
          .expand((session) => session.targetMuscleGroups)
          .toSet(),
      todayVolume: todayVolume,
      todayClassFocusTrained: todayClassFocusTrained,
      weekCompletedSessions: weekSessions.length,
      weekSetCount: weekSetCount,
      weekMuscleGroups: weekSessions
          .expand((session) => session.targetMuscleGroups)
          .toSet()
          .length,
      weekDurationSeconds: weekSessions.fold(
        0,
        (sum, session) => sum + session.actualDurationSeconds,
      ),
      lifetimeCompletedSessions: completed.length,
      lifetimeSetCount: lifetimeSetCount,
      lifetimeMuscleGroups: completed
          .expand((session) => session.targetMuscleGroups)
          .toSet()
          .length,
      lifetimeDurationSeconds: lifetimeDurationSeconds,
      lifetimeVolume: lifetimeVolume,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DailyTemplate {
  const _DailyTemplate(this.id, this.title, this.description, this.rewardGems);

  final String id;
  final String title;
  final String description;
  final int rewardGems;
}

class _WeeklyTemplate {
  const _WeeklyTemplate(this.id, this.title, this.description, this.rewardGems);

  final String id;
  final String title;
  final String description;
  final int rewardGems;
}

class _SideTemplate {
  const _SideTemplate(
    this.id,
    this.title,
    this.description,
    this.rewardTitle,
    this.rewardGems,
  );

  final String id;
  final String title;
  final String description;
  final String rewardTitle;
  final int rewardGems;
}
