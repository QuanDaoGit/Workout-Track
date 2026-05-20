import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/class_definitions.dart';
import '../models/character_class.dart';
import '../models/quest_models.dart';
import '../models/workout_models.dart';
import 'class_service.dart';
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
    final lckMultiplier = XpService.lckXpMultiplier(
      XpService.lckForSessions(sessions, now: currentTime),
    );
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
    final recoveryXP = await restService.effectiveRecoveryXP(
      sessions,
      now: currentTime,
    );
    final baseXP =
        XpService.calculateTotalXP(sessions) +
        state.claimedXP +
        recoveryXP +
        potionBonusXP;

    final daily = _buildDailyQuests(state, stats, lckMultiplier);
    final weekly = _buildWeeklyQuests(state, stats, baseXP, lckMultiplier);
    final side = _buildSideQuests(state, stats, baseXP, lckMultiplier);
    final earnedTitles = [
      for (final quest in side)
        if (quest.claimed && quest.rewardTitle != null) quest.rewardTitle!,
    ];
    final selectedTitle = earnedTitles.contains(state.selectedTitle)
        ? state.selectedTitle
        : null;

    if (selectedTitle != state.selectedTitle) {
      await _saveState(state.copyWith(clearSelectedTitle: true));
    }

    return QuestSummary(
      dailyQuests: daily,
      weeklyQuests: weekly,
      sideQuests: side,
      claimedRewardXP: state.claimedXP,
      todayClaimedXP: _claimedXPForDay(state, currentTime),
      earnedTitles: earnedTitles,
      selectedTitle: selectedTitle,
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

  Future<String?> selectedTitle() async {
    final state = await _loadState(DateTime.now());
    return state.selectedTitle;
  }

  Future<void> markManualDone(String claimKey, {DateTime? now}) async {
    final state = await _loadState(now ?? DateTime.now());
    final updated = {...state.manualDoneKeys, claimKey};
    await _saveState(state.copyWith(manualDoneKeys: updated));
  }

  Future<int> claimReward(
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

    if (quest == null || !quest.claimable) return 0;

    final state = await _loadState(currentTime);
    if (state.claims.containsKey(claimKey)) return 0;

    final claims = Map<String, QuestClaim>.from(state.claims);
    claims[claimKey] = QuestClaim(
      xp: quest.rewardXP,
      claimedAt: currentTime,
      title: quest.rewardTitle,
    );

    final selectedTitle = state.selectedTitle ?? quest.rewardTitle;
    await _saveState(
      state.copyWith(claims: claims, selectedTitle: selectedTitle),
    );
    return quest.rewardXP;
  }

  Future<void> selectTitle(String title) async {
    final state = await _loadState(DateTime.now());
    final earned = state.claims.values
        .map((claim) => claim.title)
        .whereType<String>()
        .toSet();
    if (!earned.contains(title)) return;
    await _saveState(state.copyWith(selectedTitle: title));
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
        claimedAt: oldTimeClaim.claimedAt,
        title: _timeTitle,
      );
    }
    claims = claims.map((key, claim) {
      if (claim.title != _oldTimeTitle) return MapEntry(key, claim);
      return MapEntry(
        key,
        QuestClaim(xp: claim.xp, claimedAt: claim.claimedAt, title: _timeTitle),
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

  List<QuestItem> _buildDailyQuests(
    QuestState state,
    _QuestStats stats,
    double lckMultiplier,
  ) {
    const templates = [
      _DailyTemplate('show_up', 'Show Up', 'Complete any workout today.', 5),
      _DailyTemplate(
        'class_focus',
        'Class Focus',
        "Train one of your class's primary muscle groups.",
        10,
      ),
      _DailyTemplate(
        'volume_floor',
        'Volume Floor',
        'Log 1,000 kg total volume today.',
        15,
      ),
    ];

    return [
      for (final template in templates)
        _dailyQuestItem(
          template,
          state,
          stats,
          state.dailyPeriodKey,
          lckMultiplier,
        ),
    ];
  }

  QuestItem _dailyQuestItem(
    _DailyTemplate template,
    QuestState state,
    _QuestStats stats,
    String periodKey,
    double lckMultiplier,
  ) {
    final claimKey = 'daily:$periodKey:${template.id}';
    final claim = state.claims[claimKey];
    final completed = _isDailyAutoComplete(template.id, stats);

    return QuestItem(
      id: template.id,
      claimKey: claimKey,
      category: QuestCategory.daily,
      title: template.title,
      description: template.description,
      rewardXP:
          claim?.xp ?? _applyMultiplier(template.baseRewardXP, lckMultiplier),
      completed: completed,
      claimed: claim != null,
      isManual: false,
      progressLabel: _dailyProgress(template.id, stats),
    );
  }

  List<QuestItem> _buildWeeklyQuests(
    QuestState state,
    _QuestStats stats,
    int baseXP,
    double lckMultiplier,
  ) {
    const templates = [
      _WeeklyTemplate(
        'weekly_workout_1',
        'First Quest',
        'Complete 1 workout',
        2,
      ),
      _WeeklyTemplate(
        'weekly_workout_2',
        'Second Quest',
        'Complete 2 workouts',
        4,
      ),
      _WeeklyTemplate('weekly_sets_10', 'Set Smith', 'Log 10 total sets', 8),
      _WeeklyTemplate(
        'weekly_muscles_2',
        'Balanced Path',
        'Train 2 muscle groups',
        12,
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
        _weeklyQuestItem(template, state, stats, baseXP, lckMultiplier),
    ];
  }

  QuestItem _weeklyQuestItem(
    _WeeklyTemplate template,
    QuestState state,
    _QuestStats stats,
    int baseXP,
    double lckMultiplier,
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
      rewardXP:
          claim?.xp ??
          _applyMultiplier(
            _rewardXP(baseXP, template.percent, 400),
            lckMultiplier,
          ),
      completed: completed,
      claimed: claim != null,
      isManual: false,
      progressLabel: _weeklyProgress(template.id, stats),
    );
  }

  List<QuestItem> _buildSideQuests(
    QuestState state,
    _QuestStats stats,
    int baseXP,
    double lckMultiplier,
  ) {
    const templates = [
      _SideTemplate(
        'side_first_workout',
        'First Forge',
        'Complete your first workout',
        'Iron Novice',
        5,
      ),
      _SideTemplate(
        'side_sets_25',
        'Set Smith',
        'Log 25 total sets',
        'Set Smith',
        8,
      ),
      _SideTemplate(
        'side_minutes_300',
        'Time Trial',
        'Train 300 total minutes',
        'Time Keeper',
        10,
      ),
      _SideTemplate(
        'side_all_muscles',
        'Four Guilds',
        'Train Chest, Back, Arms, and Legs',
        'Guild Walker',
        12,
      ),
      _SideTemplate(
        'side_volume_10000',
        'Iron Ledger',
        'Reach 10,000 kg total volume',
        'Volume Knight',
        15,
      ),
    ];

    return [
      for (final template in templates)
        _sideQuestItem(template, state, stats, baseXP, lckMultiplier),
    ];
  }

  QuestItem _sideQuestItem(
    _SideTemplate template,
    QuestState state,
    _QuestStats stats,
    int baseXP,
    double lckMultiplier,
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
      description: template.description,
      rewardXP:
          claim?.xp ??
          _applyMultiplier(
            _rewardXP(baseXP, template.percent, 500),
            lckMultiplier,
          ),
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

  String _dailyProgress(String id, _QuestStats stats) {
    return switch (id) {
      'show_up' => '${min(stats.todayCompletedSessions, 1)} / 1',
      'class_focus' => stats.todayClassFocusTrained ? 'DONE' : '0 / 1',
      'volume_floor' => '${min(stats.todayVolume.round(), 1000)} / 1000 kg',
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
        '${min(stats.lifetimeVolume.round(), 10000)} / 10000 kg',
      _ => '',
    };
  }

  int _claimedXPForDay(QuestState state, DateTime day) {
    final key = _dateKey(day);
    return state.claims.values
        .where((claim) => _dateKey(claim.claimedAt) == key)
        .fold(0, (sum, claim) => sum + claim.xp);
  }

  int _rewardXP(int baseXP, int percent, int cap) {
    final level = XpService.getLevel(baseXP);
    final span =
        XpService.xpForNextLevel(level) - XpService.xpForCurrentLevel(level);
    final scaled = (max(1, span) * percent / 100).round();
    return min(cap, max(1, scaled));
  }

  int _applyMultiplier(int baseXP, double multiplier) =>
      (baseXP * multiplier).round();

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
  const _DailyTemplate(
    this.id,
    this.title,
    this.description,
    this.baseRewardXP,
  );

  final String id;
  final String title;
  final String description;
  final int baseRewardXP;
}

class _WeeklyTemplate {
  const _WeeklyTemplate(this.id, this.title, this.description, this.percent);

  final String id;
  final String title;
  final String description;
  final int percent;
}

class _SideTemplate {
  const _SideTemplate(
    this.id,
    this.title,
    this.description,
    this.rewardTitle,
    this.percent,
  );

  final String id;
  final String title;
  final String description;
  final String rewardTitle;
  final int percent;
}
