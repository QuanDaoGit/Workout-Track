import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/quest_models.dart';
import '../models/workout_models.dart';
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
    final stats = _QuestStats.fromSessions(sessions, currentTime);
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
        XpService.calculateTotalXP(sessions) + state.claimedXP + recoveryXP + potionBonusXP;

    final daily = _buildDailyQuests(state, stats, baseXP, currentTime);
    final weekly = _buildWeeklyQuests(state, stats, baseXP, currentTime);
    final side = _buildSideQuests(state, stats, baseXP);
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
    int baseXP,
    DateTime now,
  ) {
    final selected = _dailyPoolFor(now);
    const percents = [2, 3, 4];

    return [
      for (int i = 0; i < selected.length; i++)
        _dailyQuestItem(
          selected[i],
          state,
          stats,
          baseXP,
          state.dailyPeriodKey,
          percents[i],
        ),
    ];
  }

  QuestItem _dailyQuestItem(
    _DailyTemplate template,
    QuestState state,
    _QuestStats stats,
    int baseXP,
    String periodKey,
    int percent,
  ) {
    final claimKey = 'daily:$periodKey:${template.id}';
    final claim = state.claims[claimKey];
    final completed = template.isManual
        ? state.manualDoneKeys.contains(claimKey)
        : _isDailyAutoComplete(template.id, stats);

    return QuestItem(
      id: template.id,
      claimKey: claimKey,
      category: QuestCategory.daily,
      title: template.title,
      description: _dailyDescription(template, stats),
      rewardXP: claim?.xp ?? _rewardXP(baseXP, percent, 75),
      completed: completed,
      claimed: claim != null,
      isManual: template.isManual,
      progressLabel: completed ? 'DONE' : template.progressLabel,
    );
  }

  List<QuestItem> _buildWeeklyQuests(
    QuestState state,
    _QuestStats stats,
    int baseXP,
    DateTime now,
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
        _weeklyQuestItem(template, state, stats, baseXP),
    ];
  }

  QuestItem _weeklyQuestItem(
    _WeeklyTemplate template,
    QuestState state,
    _QuestStats stats,
    int baseXP,
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
      rewardXP: claim?.xp ?? _rewardXP(baseXP, template.percent, 400),
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
        _sideQuestItem(template, state, stats, baseXP),
    ];
  }

  QuestItem _sideQuestItem(
    _SideTemplate template,
    QuestState state,
    _QuestStats stats,
    int baseXP,
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
      rewardXP: claim?.xp ?? _rewardXP(baseXP, template.percent, 500),
      completed: completed,
      claimed: claim != null,
      isManual: false,
      progressLabel: _sideProgress(template.id, stats),
      rewardTitle: template.rewardTitle,
    );
  }

  bool _isDailyAutoComplete(String id, _QuestStats stats) {
    return switch (id) {
      'complete_workout' => stats.todayCompletedSessions >= 1,
      'suggested_muscle' =>
        stats.suggestedMuscle != null &&
            stats.todayMuscles.contains(stats.suggestedMuscle),
      _ => false,
    };
  }

  String _dailyDescription(_DailyTemplate template, _QuestStats stats) {
    if (template.id == 'suggested_muscle') {
      final muscle = stats.suggestedMuscle;
      return muscle == null
          ? 'Build history to unlock a target muscle.'
          : 'Train $muscle today.';
    }
    return template.description;
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

  static String _dateKey(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  List<_DailyTemplate> _dailyPoolFor(DateTime now) {
    const pool = [
      _DailyTemplate(
        'stretch',
        'Stretch 5 min',
        'Mark done after a short stretch.',
        true,
        'MANUAL',
      ),
      _DailyTemplate(
        'protein',
        'Protein snack',
        'Have a protein bar or meal.',
        true,
        'MANUAL',
      ),
      _DailyTemplate(
        'hydrate',
        'Hydrate',
        'Drink water before or after training.',
        true,
        'MANUAL',
      ),
      _DailyTemplate(
        'warm_up',
        'Warm up',
        'Do a short warm-up before lifting.',
        true,
        'MANUAL',
      ),
      _DailyTemplate(
        'walk_10',
        'Walk 10 min',
        'Take a short walk today.',
        true,
        'MANUAL',
      ),
      _DailyTemplate(
        'sleep_check',
        'Sleep check',
        'Note that you protected recovery.',
        true,
        'MANUAL',
      ),
      _DailyTemplate(
        'complete_workout',
        'Complete workout',
        'Finish one workout today.',
        false,
        'AUTO',
      ),
      _DailyTemplate(
        'suggested_muscle',
        'Train target',
        'Train your suggested muscle.',
        false,
        'AUTO',
      ),
    ];

    final seed = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(2020)).inDays;
    return [for (int i = 0; i < 3; i++) pool[(seed + i) % pool.length]];
  }
}

class _QuestStats {
  const _QuestStats({
    required this.todayCompletedSessions,
    required this.todayMuscles,
    required this.weekCompletedSessions,
    required this.weekSetCount,
    required this.weekMuscleGroups,
    required this.weekDurationSeconds,
    required this.lifetimeCompletedSessions,
    required this.lifetimeSetCount,
    required this.lifetimeMuscleGroups,
    required this.lifetimeDurationSeconds,
    required this.lifetimeVolume,
    required this.suggestedMuscle,
  });

  final int todayCompletedSessions;
  final Set<String> todayMuscles;
  final int weekCompletedSessions;
  final int weekSetCount;
  final int weekMuscleGroups;
  final int weekDurationSeconds;
  final int lifetimeCompletedSessions;
  final int lifetimeSetCount;
  final int lifetimeMuscleGroups;
  final int lifetimeDurationSeconds;
  final double lifetimeVolume;
  final String? suggestedMuscle;

  factory _QuestStats.fromSessions(
    List<WorkoutSession> sessions,
    DateTime now,
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
    final lifetimeDurationSeconds = completed.fold(
      0,
      (sum, session) => sum + session.actualDurationSeconds,
    );

    return _QuestStats(
      todayCompletedSessions: todaySessions.length,
      todayMuscles: todaySessions.map((session) => session.muscleGroup).toSet(),
      weekCompletedSessions: weekSessions.length,
      weekSetCount: weekSetCount,
      weekMuscleGroups: weekSessions
          .map((session) => session.muscleGroup)
          .toSet()
          .length,
      weekDurationSeconds: weekSessions.fold(
        0,
        (sum, session) => sum + session.actualDurationSeconds,
      ),
      lifetimeCompletedSessions: completed.length,
      lifetimeSetCount: lifetimeSetCount,
      lifetimeMuscleGroups: completed
          .map((session) => session.muscleGroup)
          .toSet()
          .length,
      lifetimeDurationSeconds: lifetimeDurationSeconds,
      lifetimeVolume: lifetimeVolume,
      suggestedMuscle: _suggestedMuscle(completed, now),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String? _suggestedMuscle(
    List<WorkoutSession> completed,
    DateTime now,
  ) {
    if (completed.isEmpty) return null;
    final cutoff = now.subtract(const Duration(days: 30));
    const muscles = ['Chest', 'Back', 'Arms', 'Legs'];
    final volumes = {for (final muscle in muscles) muscle: 0.0};
    final lastDate = <String, DateTime>{};

    for (final session in completed) {
      if (session.date.isAfter(cutoff)) {
        volumes[session.muscleGroup] =
            (volumes[session.muscleGroup] ?? 0) +
            session.exercises.fold(0.0, (sum, log) => sum + log.totalVolume);
      }
      final previous = lastDate[session.muscleGroup];
      if (previous == null || session.date.isAfter(previous)) {
        lastDate[session.muscleGroup] = session.date;
      }
    }

    return muscles.reduce((a, b) {
      final aVolume = volumes[a]!;
      final bVolume = volumes[b]!;
      if (aVolume != bVolume) return aVolume < bVolume ? a : b;
      final aDate = lastDate[a];
      final bDate = lastDate[b];
      if (aDate == null && bDate == null) return a.compareTo(b) <= 0 ? a : b;
      if (aDate == null) return a;
      if (bDate == null) return b;
      return aDate.isBefore(bDate) ? a : b;
    });
  }
}

class _DailyTemplate {
  const _DailyTemplate(
    this.id,
    this.title,
    this.description,
    this.isManual,
    this.progressLabel,
  );

  final String id;
  final String title;
  final String description;
  final bool isManual;
  final String progressLabel;
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
