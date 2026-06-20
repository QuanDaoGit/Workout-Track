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
import 'json_safe.dart';
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
    final decoded = safeDecodeMap(raw, debugLabel: _stateKey);
    final loaded = decoded == null
        ? QuestState.empty(dailyPeriodKey: dailyKey, weeklyPeriodKey: weeklyKey)
        : _questStateOrEmpty(decoded, dailyKey, weeklyKey);

    final normalized = _normalizePeriods(loaded, dailyKey, weeklyKey);
    if (normalized != loaded) await _saveState(normalized);
    return normalized;
  }

  /// A decoded-but-possibly-schema-drifted map → a [QuestState], falling back to
  /// an empty period state if `fromJson` throws on an unexpected shape.
  QuestState _questStateOrEmpty(
    Map<String, dynamic> json,
    String dailyKey,
    String weeklyKey,
  ) {
    try {
      return QuestState.fromJson(json);
    } on Object {
      return QuestState.empty(dailyPeriodKey: dailyKey, weeklyPeriodKey: weeklyKey);
    }
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
    // Side-quest reward titles renamed 2026-06 (loot ids kept stable; migrate the
    // user's selected-title NAME so an equipped pick still resolves).
    const renamedTitles = {
      'Iron Novice': 'A New Dawn',
      'Guild Walker': 'Juggler',
      'Volume Knight': 'Elephant Lifter',
    };
    final renamed = renamedTitles[selectedTitle];
    if (renamed != null) selectedTitle = renamed;

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

  // ── quest pools + deterministic rotation ─────────────────────────────────
  // Each template carries its own auto-eval + progress closures, so the pool
  // extends without per-id switches. Daily/weekly surface a deterministic subset
  // per period (anchored by one guaranteed reliable win); side = the full ladder.

  static String _descVol(num kg) =>
      formatWeight(kg.toDouble(), Units.weight, decimals: 0);
  static String _progVol(double have, num cap) =>
      '${weightValue(min(have, cap.toDouble()), Units.weight, decimals: 0)}'
      ' / ${formatWeight(cap.toDouble(), Units.weight, decimals: 0)}';
  static bool _hasGroup(_QuestStats s, String g) => s.todayMuscles.contains(g);

  static final List<_QuestTemplate> _dailyPool = [
    _QuestTemplate(
      id: 'show_up', title: 'Show Up', gems: 5,
      done: (s) => s.todayCompletedSessions >= 1,
      describe: (s) => 'Complete any workout today.',
      progress: (s) => '${min(s.todayCompletedSessions, 1)} / 1',
    ),
    _QuestTemplate(
      id: 'class_focus', title: 'Class Focus', gems: 5,
      done: (s) => s.todayClassFocusTrained,
      describe: (s) => "Train one of your class's primary muscle groups.",
      progress: (s) => s.todayClassFocusTrained ? 'DONE' : '0 / 1',
    ),
    _QuestTemplate(
      id: 'volume_floor', title: 'Volume Floor', gems: 5,
      done: (s) => s.todayVolume >= 1000,
      describe: (s) => 'Log ${_descVol(1000)} total volume today.',
      progress: (s) => _progVol(s.todayVolume, 1000),
    ),
    _QuestTemplate(
      id: 'two_fronts', title: 'Two Fronts', gems: 5,
      done: (s) => s.todayMuscles.length >= 2,
      describe: (s) => 'Train 2 muscle groups today.',
      progress: (s) => '${min(s.todayMuscles.length, 2)} / 2 groups',
    ),
    _QuestTemplate(
      id: 'rack_work', title: 'Rack Work', gems: 5,
      done: (s) => s.todaySets >= 12,
      describe: (s) => 'Log 12 sets today.',
      progress: (s) => '${min(s.todaySets, 12)} / 12 sets',
    ),
    _QuestTemplate(
      id: 'time_in', title: 'Time In', gems: 5,
      done: (s) => s.todayDurationSeconds >= 25 * 60,
      describe: (s) => 'Train 25 minutes today.',
      progress: (s) => '${min(s.todayDurationSeconds ~/ 60, 25)} / 25 min',
    ),
    _QuestTemplate(
      id: 'warm_first', title: 'Warm First', gems: 5,
      done: (s) => s.todayWarmedUp,
      describe: (s) => 'Log a warm-up set today.',
      progress: (s) => s.todayWarmedUp ? 'DONE' : '0 / 1',
    ),
    _QuestTemplate(
      id: 'leg_day', title: 'Leg Day', gems: 5,
      done: (s) => _hasGroup(s, 'Legs'),
      describe: (s) => 'Train Legs today.',
      progress: (s) => _hasGroup(s, 'Legs') ? 'DONE' : '0 / 1',
    ),
    _QuestTemplate(
      id: 'push_day', title: 'Push Day', gems: 5,
      done: (s) => _hasGroup(s, 'Chest') || _hasGroup(s, 'Shoulders'),
      describe: (s) => 'Train Chest or Shoulders today.',
      progress: (s) =>
          (_hasGroup(s, 'Chest') || _hasGroup(s, 'Shoulders')) ? 'DONE' : '0 / 1',
    ),
    _QuestTemplate(
      id: 'pull_day', title: 'Pull Day', gems: 5,
      done: (s) => _hasGroup(s, 'Back'),
      describe: (s) => 'Train Back today.',
      progress: (s) => _hasGroup(s, 'Back') ? 'DONE' : '0 / 1',
    ),
    _QuestTemplate(
      id: 'the_core', title: 'The Core', gems: 5,
      done: (s) => _hasGroup(s, 'Core'),
      describe: (s) => 'Train Core today.',
      progress: (s) => _hasGroup(s, 'Core') ? 'DONE' : '0 / 1',
    ),
  ];

  // A stable (portable) FNV-1a hash of the period key seeds the pick, so the same
  // period always surfaces the same quests and a new period rotates — no
  // persistence. (Dart's String.hashCode is not stable across runs.)
  static int _seed(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  // Anchors first (guaranteed reliable wins / a featured quest), then a
  // deterministic subset of the rest (optionally excluding e.g. Limit Break when
  // it has no baseline yet).
  List<_QuestTemplate> _rotate(
    List<_QuestTemplate> pool,
    List<String> anchorIds,
    int count,
    String seedKey, {
    bool Function(_QuestTemplate)? exclude,
  }) {
    final anchors = [
      for (final id in anchorIds) pool.firstWhere((t) => t.id == id),
    ];
    final rest = pool
        .where((t) =>
            !anchorIds.contains(t.id) && (exclude == null || !exclude(t)))
        .toList()
      ..shuffle(Random(_seed(seedKey)));
    return [...anchors, ...rest.take(count - anchors.length)];
  }

  QuestItem _questItem(
    _QuestTemplate t,
    QuestCategory category,
    String claimKey,
    QuestState state,
    _QuestStats stats,
  ) {
    final claim = state.claims[claimKey];
    return QuestItem(
      id: t.id,
      claimKey: claimKey,
      category: category,
      title: t.title,
      description: t.describe(stats),
      rewardXP: claim?.xp ?? 0,
      rewardGems: claim?.gems ?? t.gems,
      completed: t.done(stats),
      claimed: claim != null,
      isManual: false,
      progressLabel: t.progress(stats),
      rewardTitle: t.rewardTitle,
    );
  }

  List<QuestItem> _buildDailyQuests(QuestState state, _QuestStats stats) {
    final key = 'daily:${state.dailyPeriodKey}';
    return [
      for (final t in _rotate(_dailyPool, const ['show_up'], 3, key))
        _questItem(t, QuestCategory.daily,
            'daily:${state.dailyPeriodKey}:${t.id}', state, stats),
    ];
  }

  static final List<_QuestTemplate> _weeklyPool = [
    _QuestTemplate(
      id: 'opening_move', title: 'Opening Move', gems: 5,
      done: (s) => s.weekCompletedSessions >= 1,
      describe: (s) => 'Complete 1 workout this week.',
      progress: (s) => '${min(s.weekCompletedSessions, 1)} / 1',
    ),
    _QuestTemplate(
      id: 'double_up', title: 'Double Up', gems: 5,
      done: (s) => s.weekCompletedSessions >= 2,
      describe: (s) => 'Complete 2 workouts this week.',
      progress: (s) => '${min(s.weekCompletedSessions, 2)} / 2',
    ),
    _QuestTemplate(
      id: 'triple_threat', title: 'Triple Threat', gems: 10,
      done: (s) => s.weekCompletedSessions >= 3,
      describe: (s) => 'Complete 3 workouts this week.',
      progress: (s) => '${min(s.weekCompletedSessions, 3)} / 3',
    ),
    _QuestTemplate(
      id: 'steady_cadence', title: 'Steady Cadence', gems: 10,
      done: (s) => s.weekDays >= 3,
      describe: (s) => 'Train on 3 different days this week.',
      progress: (s) => '${min(s.weekDays, 3)} / 3 days',
    ),
    _QuestTemplate(
      id: 'set_chaser', title: 'Set Chaser', gems: 10,
      done: (s) => s.weekSetCount >= 30,
      describe: (s) => 'Log 30 sets this week.',
      progress: (s) => '${min(s.weekSetCount, 30)} / 30 sets',
    ),
    _QuestTemplate(
      id: 'balance', title: 'Balance', gems: 10,
      done: (s) => s.weekMuscleGroups >= 3,
      describe: (s) => 'Train 3 muscle groups this week.',
      progress: (s) => '${min(s.weekMuscleGroups, 3)} / 3 groups',
    ),
    _QuestTemplate(
      id: 'full_sweep', title: 'Full Sweep', gems: 15,
      done: (s) => s.weekMuscleGroups >= 5,
      describe: (s) => 'Train 5 muscle groups this week.',
      progress: (s) => '${min(s.weekMuscleGroups, 5)} / 5 groups',
    ),
    _QuestTemplate(
      id: 'hour_trial', title: 'Hour Trial', gems: 15,
      done: (s) => s.weekDurationSeconds >= 90 * 60,
      describe: (s) => 'Train 90 minutes this week.',
      progress: (s) => '${min(s.weekDurationSeconds ~/ 60, 90)} / 90 min',
    ),
    _QuestTemplate(
      id: 'limit_break', title: 'Limit Break', gems: 20,
      done: (s) => s.limitBreakAvailable && s.weekVolume >= s.limitBreakTarget,
      describe: (s) => 'Move ${_descVol(s.limitBreakTarget)} this week.',
      progress: (s) => _progVol(s.weekVolume, s.limitBreakTarget),
    ),
    _QuestTemplate(
      id: 'warm_discipline', title: 'Warm Discipline', gems: 10,
      done: (s) => s.weekWarmupSessions >= 3,
      describe: (s) => 'Warm up in 3 sessions this week.',
      progress: (s) => '${min(s.weekWarmupSessions, 3)} / 3',
    ),
    _QuestTemplate(
      id: 'class_dedication', title: 'Class Dedication', gems: 15,
      done: (s) => s.weekClassFocusCount >= 3,
      describe: (s) => 'Hit your class focus 3 times this week.',
      progress: (s) => '${min(s.weekClassFocusCount, 3)} / 3',
    ),
  ];

  List<QuestItem> _buildWeeklyQuests(QuestState state, _QuestStats stats) {
    final key = 'weekly:${state.weeklyPeriodKey}';
    // Limit Break is a FEATURED (anchored) quest when the user has a baseline
    // week to personalize its target; otherwise it is excluded entirely.
    final anchors = stats.limitBreakAvailable
        ? const ['opening_move', 'limit_break']
        : const ['opening_move'];
    final picks = _rotate(
      _weeklyPool,
      anchors,
      5,
      key,
      exclude: (t) => t.id == 'limit_break' && !stats.limitBreakAvailable,
    );
    return [
      for (final t in picks)
        _questItem(t, QuestCategory.weekly,
            'weekly:${state.weeklyPeriodKey}:${t.id}', state, stats),
    ];
  }

  static final List<_QuestTemplate> _sidePool = [
    _QuestTemplate(
      id: 'side_first_workout', title: 'A New Dawn', gems: 100,
      rewardTitle: 'A New Dawn',
      done: (s) => s.lifetimeCompletedSessions >= 1,
      describe: (s) => 'Complete your first workout.',
      progress: (s) => '${min(s.lifetimeCompletedSessions, 1)} / 1',
    ),
    _QuestTemplate(
      id: 'side_sets_25', title: 'Set Smith', gems: 100, rewardTitle: 'Set Smith',
      done: (s) => s.lifetimeSetCount >= 25,
      describe: (s) => 'Log 25 total sets.',
      progress: (s) => '${min(s.lifetimeSetCount, 25)} / 25 sets',
    ),
    _QuestTemplate(
      id: 'side_minutes_300', title: 'Time Keeper', gems: 100,
      rewardTitle: 'Time Keeper',
      done: (s) => s.lifetimeDurationSeconds >= 300 * 60,
      describe: (s) => 'Train 300 total minutes.',
      progress: (s) => '${min(s.lifetimeDurationSeconds ~/ 60, 300)} / 300 min',
    ),
    _QuestTemplate(
      id: 'side_all_muscles', title: 'All-Rounded', gems: 100,
      rewardTitle: 'Juggler',
      done: (s) => s.lifetimeMuscleGroups >= 4,
      describe: (s) => 'Train Chest, Back, Arms, and Legs.',
      progress: (s) => '${min(s.lifetimeMuscleGroups, 4)} / 4 groups',
    ),
    _QuestTemplate(
      id: 'side_volume_10000', title: 'Elephant Lifter', gems: 100,
      rewardTitle: 'Elephant Lifter',
      done: (s) => s.lifetimeVolume >= 10000,
      describe: (s) => 'Reach ${_descVol(10000)} total volume.',
      progress: (s) => _progVol(s.lifetimeVolume, 10000),
    ),
    _QuestTemplate(
      id: 'side_workouts_100', title: 'Centurion', gems: 100,
      rewardTitle: 'Centurion',
      done: (s) => s.lifetimeCompletedSessions >= 100,
      describe: (s) => 'Complete 100 total workouts.',
      progress: (s) => '${min(s.lifetimeCompletedSessions, 100)} / 100',
    ),
    _QuestTemplate(
      id: 'side_minutes_3000', title: 'Not There Yet?', gems: 100,
      rewardTitle: 'Long Live',
      done: (s) => s.lifetimeDurationSeconds >= 3000 * 60,
      describe: (s) => 'Train 3,000 total minutes.',
      progress: (s) => '${min(s.lifetimeDurationSeconds ~/ 60, 3000)} / 3000 min',
    ),
    _QuestTemplate(
      id: 'side_volume_50000', title: 'Whale Lifter', gems: 100,
      rewardTitle: 'Whale Lifter',
      done: (s) => s.lifetimeVolume >= 50000,
      describe: (s) => 'Reach ${_descVol(50000)} total volume.',
      progress: (s) => _progVol(s.lifetimeVolume, 50000),
    ),
    _QuestTemplate(
      id: 'side_all_seven', title: 'All Seven', gems: 100,
      rewardTitle: 'Guildmaster',
      done: (s) => s.lifetimeMuscleGroups >= 7,
      describe: (s) => 'Train all 7 muscle groups.',
      progress: (s) => '${min(s.lifetimeMuscleGroups, 7)} / 7 groups',
    ),
    _QuestTemplate(
      id: 'side_sets_1000', title: 'Apex 1000', gems: 100,
      rewardTitle: 'Apex 1000',
      done: (s) => s.lifetimeSetCount >= 1000,
      describe: (s) => 'Log 1,000 total sets.',
      progress: (s) => '${min(s.lifetimeSetCount, 1000)} / 1000 sets',
    ),
  ];

  List<QuestItem> _buildSideQuests(QuestState state, _QuestStats stats) {
    return [
      for (final t in _sidePool)
        _questItem(t, QuestCategory.side, 'side:${t.id}', state, stats),
    ];
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
    required this.todaySets,
    required this.todayDurationSeconds,
    required this.todayWarmedUp,
    required this.todayClassFocusTrained,
    required this.weekCompletedSessions,
    required this.weekSetCount,
    required this.weekMuscleGroups,
    required this.weekDurationSeconds,
    required this.weekVolume,
    required this.weekDays,
    required this.weekWarmupSessions,
    required this.weekClassFocusCount,
    required this.lifetimeCompletedSessions,
    required this.lifetimeSetCount,
    required this.lifetimeMuscleGroups,
    required this.lifetimeDurationSeconds,
    required this.lifetimeVolume,
    required this.limitBreakTarget,
    required this.limitBreakAvailable,
  });

  final int todayCompletedSessions;
  final Set<String> todayMuscles;
  final double todayVolume;
  final int todaySets;
  final int todayDurationSeconds;
  final bool todayWarmedUp;
  final bool todayClassFocusTrained;
  final int weekCompletedSessions;
  final int weekSetCount;
  final int weekMuscleGroups;
  final int weekDurationSeconds;
  final double weekVolume;
  final int weekDays;
  final int weekWarmupSessions;
  final int weekClassFocusCount;
  final int lifetimeCompletedSessions;
  final int lifetimeSetCount;
  final int lifetimeMuscleGroups;
  final int lifetimeDurationSeconds;
  final double lifetimeVolume;

  /// Personalized "Limit Break" weekly-volume target (canonical kg): the avg of
  /// the last <=4 completed prior weeks (weeks-with-training only) x 1.15 (x1.10
  /// when <3 weeks of history), clamped to [x1.05, x1.30] so it stays a doable
  /// stretch and never a danger-zone spike. Rounded to the nearest 100 in the
  /// user's DISPLAY unit (so a lbs target reads as a clean hundred too), then
  /// stored as the kg threshold that formats back to it. 0 + [limitBreakAvailable]
  /// false when there is no prior training week (the quest is then excluded).
  final double limitBreakTarget;
  final bool limitBreakAvailable;

  static double _vol(Iterable<WorkoutSession> s) => s.fold(
        0.0,
        (sum, session) =>
            sum +
            session.exercises
                .fold(0.0, (logSum, log) => logSum + log.totalVolume),
      );
  static int _sets(Iterable<WorkoutSession> s) => s.fold(
        0,
        (sum, session) =>
            sum +
            session.exercises.fold(0, (setSum, log) => setSum + log.sets.length),
      );
  static int _secs(Iterable<WorkoutSession> s) =>
      s.fold(0, (sum, session) => sum + session.actualDurationSeconds);

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
    final classTargets = musclesForClass(currentClass);
    bool hitsClassFocus(WorkoutSession s) =>
        s.targetMuscleGroups.any((t) => classTargets.contains(t));

    // Limit Break baseline: avg volume over the last up-to-4 completed prior
    // weeks (the ACWR "chronic" window); only weeks that had training count.
    final priorWeekVolumes = <double>[];
    for (var w = 1; w <= 4; w++) {
      final wkMonday = monday.subtract(Duration(days: 7 * w));
      final wkSunday = wkMonday.add(const Duration(days: 7));
      final vol = _vol(completed.where(
        (s) => !s.date.isBefore(wkMonday) && s.date.isBefore(wkSunday),
      ));
      if (vol > 0) priorWeekVolumes.add(vol);
    }
    var limitBreakTarget = 0.0;
    final limitBreakAvailable = priorWeekVolumes.isNotEmpty;
    if (limitBreakAvailable) {
      final avg =
          priorWeekVolumes.reduce((a, b) => a + b) / priorWeekVolumes.length;
      final factor = priorWeekVolumes.length >= 3 ? 1.15 : 1.10;
      final clampedKg = (avg * factor).clamp(avg * 1.05, avg * 1.30);
      // Round to the nearest 100 in the user's DISPLAY unit so the shown target
      // reads as a clean hundred (lbs or kg), then store the kg threshold that
      // formats back to it.
      final hundreds =
          (kgToDisplay(clampedKg, Units.weight) / 100).round() * 100;
      final display = hundreds < 100 ? 100 : hundreds;
      limitBreakTarget = displayToKg(display.toDouble(), Units.weight);
    }

    return _QuestStats(
      todayCompletedSessions: todaySessions.length,
      todayMuscles: todaySessions
          .expand((session) => session.targetMuscleGroups)
          .toSet(),
      todayVolume: _vol(todaySessions),
      todaySets: _sets(todaySessions),
      todayDurationSeconds: _secs(todaySessions),
      todayWarmedUp: todaySessions.any((s) => s.warmedUp),
      todayClassFocusTrained: todaySessions.any(hitsClassFocus),
      weekCompletedSessions: weekSessions.length,
      weekSetCount: _sets(weekSessions),
      weekMuscleGroups: weekSessions
          .expand((session) => session.targetMuscleGroups)
          .toSet()
          .length,
      weekDurationSeconds: _secs(weekSessions),
      weekVolume: _vol(weekSessions),
      weekDays: weekSessions
          .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
          .toSet()
          .length,
      weekWarmupSessions: weekSessions.where((s) => s.warmedUp).length,
      weekClassFocusCount: weekSessions.where(hitsClassFocus).length,
      lifetimeCompletedSessions: completed.length,
      lifetimeSetCount: _sets(completed),
      lifetimeMuscleGroups: completed
          .expand((session) => session.targetMuscleGroups)
          .toSet()
          .length,
      lifetimeDurationSeconds: _secs(completed),
      lifetimeVolume: _vol(completed),
      limitBreakTarget: limitBreakTarget,
      limitBreakAvailable: limitBreakAvailable,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// A pooled quest. Each carries its own auto-eval ([done]), [describe], and
/// [progress] closures (evaluated against the computed `_QuestStats`), so the
/// rotation pools extend without per-id switches. [rewardTitle] is the loot
/// title-badge name a side quest grants (null for daily/weekly).
class _QuestTemplate {
  _QuestTemplate({
    required this.id,
    required this.title,
    required this.gems,
    required this.done,
    required this.describe,
    required this.progress,
    this.rewardTitle,
  });

  final String id;
  final String title;
  final int gems;
  final String? rewardTitle;
  final bool Function(_QuestStats stats) done;
  final String Function(_QuestStats stats) describe;
  final String Function(_QuestStats stats) progress;
}
