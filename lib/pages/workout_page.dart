import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../data/curated_exercises.dart';
import '../data/muscle_groups.dart';
import '../models/rest_models.dart';
import '../models/unit_models.dart';
import '../models/workout_models.dart';
import '../services/exercise_catalog_service.dart';
import '../services/favorite_service.dart';
import '../services/progressive_overload_service.dart';
import '../services/quest_service.dart';
import '../services/rest_service.dart';
import '../services/unit_settings_service.dart';
import '../services/weekly_goal_service.dart';
import '../services/workout_metric_service.dart';
import '../services/workout_storage_service.dart';
import '../services/xp_boost_service.dart';
import '../services/xp_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_chip.dart';
import '../widgets/arcade_bar.dart';
import '../widgets/arcade_route.dart';
import '../widgets/calendar_day_marker.dart';
import '../widgets/exercise_card.dart';
import '../widgets/motion/arcade_text_field.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/motion/phosphor_tap.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';
import 'Workout session/session_detail.dart';
import 'Workout session/start_workout.dart';
import 'calendar_page.dart';
import 'create_exercise_page.dart';
import 'exercise_detail.dart';
import 'exercise_history_page.dart';
import 'programs_library_page.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  WorkoutPageState createState() => WorkoutPageState();
}

class WorkoutPageState extends State<WorkoutPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _reloadToken = 0;

  void reload() {
    if (!mounted) return;
    setState(() => _reloadToken++);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'LOGS'),
            Tab(text: 'LIBRARY'),
          ],
          labelStyle: const TextStyle(fontFamily: 'PressStart2P', fontSize: 9),
          indicatorColor: kNeon,
          labelColor: kNeon,
          unselectedLabelColor: kMutedText,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _LogsTab(reloadToken: _reloadToken),
                _LibraryTab(reloadToken: _reloadToken),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Focused **LOGS** view (workout history / calendar / analytics) — the old
/// Workout tab's LOGS half, re-homed under Home in the area restructure. Pushed
/// as its own page so Home surfaces only the log, never the library.
class WorkoutLogsPage extends StatelessWidget {
  const WorkoutLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logs')),
      body: const _LogsTab(reloadToken: 0),
    );
  }
}

/// Focused **LIBRARY** view (Programs ⇄ Exercises) — the old Workout tab's
/// LIBRARY half, re-homed under Labs.
class WorkoutLibraryPage extends StatelessWidget {
  const WorkoutLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: const _LibraryTab(reloadToken: 0),
    );
  }
}

// ── Logs Tab — single scroll ─────────────────────────────────────────────────
// One surface, no sub-tabs: streak hero + week strip → stat trio → XP card →
// session list (PR badges) → analytics. Replaces the old HISTORY/TRENDS split
// so nothing the user logged hides behind a toggle.

class _LogsTab extends StatefulWidget {
  const _LogsTab({required this.reloadToken});

  final int reloadToken;

  @override
  State<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<_LogsTab> {
  // ── Loaded data ──
  List<WorkoutSession> _sessions = [];
  RestState _restState = RestState.defaults();
  Map<String, String> _primaryBucketByExerciseId = {};
  int _questXP = 0;
  int _recoveryXP = 0;
  int _potionBonusXP = 0;
  int _goalDays = WeeklyGoalService.defaultGoalDays;
  bool _loading = true;

  // ── UI state ──
  bool _showAllSessions = false;
  bool _showRecords = false;
  DateTime? _selectedStripDay;

  // ── Analytics, memoized once per load (never derived in build) ──
  List<WorkoutSession> _browsable = [];
  Map<DateTime, List<WorkoutSession>> _sessionsByDay = {};
  DateTime? _firstActivityDay;
  int _completedCount = 0;
  double _totalVolume = 0;
  int _streak = 0;
  int _trainingDays = 0;
  List<(double, Color)> _weekData = const [];
  List<double> _lastWeekVolumes = const [];
  int _thisWeekCount = 0;
  double _thisWeekVol = 0;
  int _lastWeekCount = 0;
  double _lastWeekVol = 0;
  List<_MuscleData> _muscleData = const [];
  int _suggestedIdx = 0;
  List<MapEntry<String, _PBRecord>> _pbs = const [];
  int _recordCount = 0;
  List<_ExerciseTrend> _trends = const [];
  Map<String, int> _prCounts = const {};
  XpProgress _xpProgress = XpService.progressForTotalXP(0);
  String _rank = 'Recruit';

  static const List<String> _muscles = [
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Legs',
    'Core',
    'Full Body',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _LogsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    final all = await WorkoutStorageService().getSessions();
    final restState = await RestService().loadState();
    final catalog = await ExerciseCatalogService().getFullCatalog();
    final questXP = await QuestService().claimedRewardXP();
    final potionBonusXP = await XpBoostService().getTotalBonusXP();
    // Pure read: today's automatic recovery grant is ensured on the Home tab
    // load and inside QuestService.getSummary — never from a log view.
    final recoveryXP = await RestService().effectiveRecoveryXP(all);
    final goalDays = await WeeklyGoalService().getGoalDays();
    if (!mounted) return;
    setState(() {
      _sessions = all;
      _restState = restState;
      _primaryBucketByExerciseId = {
        for (final exercise in catalog)
          if (exercise.primaryMuscle != null)
            exercise.id: muscleGroupForDetailed(exercise.primaryMuscle!) ?? '',
      }..removeWhere((_, bucket) => bucket.isEmpty);
      _questXP = questXP;
      _recoveryXP = recoveryXP;
      _potionBonusXP = potionBonusXP;
      _goalDays = goalDays;
      _recomputeAnalytics();
      _loading = false;
    });
  }

  // ── Analytics computation ──────────────────────────────────────────────────

  void _recomputeAnalytics() {
    final completed = _sessions.where((s) => !s.isPartial).toList();
    _browsable = _sessions.where((s) => !s.isOngoing).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    _completedCount = completed.length;
    _totalVolume = completed.fold(
      0.0,
      (sum, s) => sum + s.exercises.fold(0.0, (s2, e) => s2 + e.totalVolume),
    );
    // LCK reframed: a weekly consistency streak (consecutive 7-day blocks held
    // without an unscheduled recovery), not a raw consecutive-day count.
    _streak = RestService().consistencyWeeks(
      sessions: _sessions,
      state: _restState,
    );
    _trainingDays = WorkoutMetricService.trainingDaysThisWeek(_sessions);
    _prCounts = WorkoutMetricService.prCountsBySession(_sessions);

    final byDay = <DateTime, List<WorkoutSession>>{};
    DateTime? first;
    for (final session in _browsable) {
      final day = DateUtils.dateOnly(session.date);
      byDay.putIfAbsent(day, () => []).add(session);
      if (first == null || day.isBefore(first)) first = day;
    }
    _sessionsByDay = byDay;
    _firstActivityDay = first;

    final now = DateTime.now();
    final thisMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    _weekData = _buildWeekData(thisMonday);
    _lastWeekVolumes = _volumesForWeek(lastMonday);
    final (thisWeekCount, thisWeekVol) = _rangeStats(
      thisMonday,
      now.add(const Duration(days: 1)),
    );
    final (lastWeekCount, lastWeekVol) = _rangeStats(lastMonday, thisMonday);
    _thisWeekCount = thisWeekCount;
    _thisWeekVol = thisWeekVol;
    _lastWeekCount = lastWeekCount;
    _lastWeekVol = lastWeekVol;

    _muscleData = _buildMuscleBalance();
    _suggestedIdx = _suggestedMuscleIdx(_muscleData);

    final bests = _buildBests();
    _recordCount = bests.length;
    final sortedBests = bests.entries.toList()
      ..sort((a, b) => b.value.oneRM.compareTo(a.value.oneRM));
    _pbs = sortedBests.take(5).toList();

    _trends = _buildExerciseTrends();

    final totalXP =
        XpService.calculateTotalXP(_sessions) +
        _questXP +
        _recoveryXP +
        _potionBonusXP;
    _xpProgress = XpService.progressForTotalXP(totalXP);
    _rank = XpService.getRank(_xpProgress.level);
  }

  Map<String, double> _sessionVolumeByMuscle(WorkoutSession session) {
    final volumes = <String, double>{};
    final targets = session.targetMuscleGroups;
    for (final log in session.exercises) {
      final bucket = _primaryBucketByExerciseId[log.exerciseId];
      if (bucket != null) {
        volumes[bucket] = (volumes[bucket] ?? 0) + log.totalVolume;
      } else if (targets.isNotEmpty) {
        final share = log.totalVolume / targets.length;
        for (final target in targets) {
          volumes[target] = (volumes[target] ?? 0) + share;
        }
      }
    }
    return volumes;
  }

  // Returns (totalVolume, dominantColor) for Mon–Sun of the week at [monday].
  List<(double, Color)> _buildWeekData(DateTime monday) {
    final volumes = List<double>.filled(7, 0);
    final muscleVols = List<Map<String, double>>.generate(7, (_) => {});

    for (final s in _sessions.where((s) => !s.isPartial)) {
      final day = DateTime(s.date.year, s.date.month, s.date.day);
      final idx = day.difference(monday).inDays;
      if (idx < 0 || idx > 6) continue;
      final vol = s.exercises.fold(0.0, (sum, e) => sum + e.totalVolume);
      volumes[idx] += vol;
      for (final entry in _sessionVolumeByMuscle(s).entries) {
        muscleVols[idx][entry.key] =
            (muscleVols[idx][entry.key] ?? 0) + entry.value;
      }
    }

    return List.generate(7, (i) {
      if (volumes[i] == 0) return (0.0, Colors.transparent);
      final dominant = muscleVols[i].entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      return (volumes[i], kMuscleGroupColors[dominant] ?? kNeon);
    });
  }

  List<double> _volumesForWeek(DateTime monday) {
    final volumes = List<double>.filled(7, 0);
    for (final s in _sessions.where((s) => !s.isPartial)) {
      final day = DateTime(s.date.year, s.date.month, s.date.day);
      final idx = day.difference(monday).inDays;
      if (idx < 0 || idx > 6) continue;
      volumes[idx] += s.exercises.fold(0.0, (sum, e) => sum + e.totalVolume);
    }
    return volumes;
  }

  // Returns (sessions count, total volume) for a date range.
  (int, double) _rangeStats(DateTime from, DateTime to) {
    int count = 0;
    double vol = 0;
    for (final s in _sessions.where((s) => !s.isPartial)) {
      if (!s.date.isBefore(from) && s.date.isBefore(to)) {
        count++;
        vol += s.exercises.fold(0.0, (sum, e) => sum + e.totalVolume);
      }
    }
    return (count, vol);
  }

  List<_MuscleData> _buildMuscleBalance() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return _muscles.map((muscle) {
      double vol = 0;
      DateTime? lastTrained;
      for (final s in _sessions.where((s) => !s.isPartial)) {
        final muscleVolumes = _sessionVolumeByMuscle(s);
        final muscleVolume = muscleVolumes[muscle] ?? 0;
        if (muscleVolume <= 0 && !s.targetMuscleGroups.contains(muscle)) {
          continue;
        }
        if (s.date.isAfter(cutoff)) {
          vol += muscleVolume;
        }
        if (lastTrained == null || s.date.isAfter(lastTrained)) {
          lastTrained = s.date;
        }
      }
      return _MuscleData(muscle, vol, lastTrained);
    }).toList();
  }

  int _suggestedMuscleIdx(List<_MuscleData> data) {
    int idx = 0;
    for (int i = 1; i < data.length; i++) {
      final curr = data[idx];
      final cand = data[i];
      if (cand.volume < curr.volume) {
        idx = i;
      } else if (cand.volume == curr.volume) {
        // Least recently trained wins
        final currDate = curr.lastTrained;
        final candDate = cand.lastTrained;
        if (currDate == null && candDate == null) {
          // both never trained → alphabetical
          if (cand.muscle.compareTo(curr.muscle) < 0) idx = i;
        } else if (currDate == null) {
          // curr never trained → keep curr (null = older)
        } else if (candDate == null) {
          // cand never trained → pick cand
          idx = i;
        } else if (candDate.isBefore(currDate)) {
          idx = i;
        } else if (candDate.isAtSameMomentAs(currDate)) {
          if (cand.muscle.compareTo(curr.muscle) < 0) idx = i;
        }
      }
    }
    return idx;
  }

  /// Per-exercise records: heaviest set by estimated 1RM (weighted sets only).
  Map<String, _PBRecord> _buildBests() {
    final bests = <String, _PBRecord>{};
    for (final s in _sessions.where((s) => !s.isPartial)) {
      for (final e in s.exercises) {
        for (final set in e.sets) {
          if (set.weight <= 0) continue;
          final rm = ProgressiveOverloadService.epley1RM(
            set.weight,
            set.reps,
            false,
          );
          final current = bests[e.exerciseName];
          final better =
              current == null ||
              rm > current.oneRM ||
              (rm == current.oneRM && set.weight > current.weight);
          if (better) {
            bests[e.exerciseName] = _PBRecord(set.weight, set.reps, rm, s.date);
          }
        }
      }
    }
    return bests;
  }

  List<_ExerciseTrend> _buildExerciseTrends() {
    final byExercise = <String, List<({DateTime date, double load})>>{};
    final names = <String, String>{};
    for (final session in _sessions.where((s) => !s.isPartial)) {
      for (final log in session.exercises) {
        final weightedSets = log.sets.where((set) => set.weight > 0).toList();
        if (weightedSets.isEmpty) continue;
        final topLoad = weightedSets.fold<double>(
          0,
          (best, set) => max(best, set.weight),
        );
        byExercise.putIfAbsent(log.exerciseId, () => []).add((
          date: session.date,
          load: topLoad,
        ));
        names[log.exerciseId] = log.exerciseName;
      }
    }

    final trends = <_ExerciseTrend>[];
    for (final entry in byExercise.entries) {
      if (entry.value.length < 5) continue;
      final points = entry.value.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      final recent = points.length > 3
          ? points.sublist(points.length - 3)
          : points;
      final plateau =
          recent.length >= 3 &&
          recent.every((point) => point.load == recent.first.load);
      trends.add(
        _ExerciseTrend(
          id: entry.key,
          name: names[entry.key] ?? entry.key,
          loads: [for (final point in points.take(10)) point.load],
          plateau: plateau,
        ),
      );
    }
    trends.sort((a, b) => b.loads.length.compareTo(a.loads.length));
    return trends.take(3).toList();
  }

  String _fmtDate(DateTime d) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  // ── Interactions ──────────────────────────────────────────────────────────

  Future<void> _editGoal() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'WEEKLY GOAL',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: kNeon,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Days you aim to train each week.',
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
            ),
            const SizedBox(height: kSpace3),
            Wrap(
              spacing: kSpace2,
              runSpacing: kSpace2,
              children: [
                for (
                  var d = WeeklyGoalService.minGoalDays;
                  d <= WeeklyGoalService.maxGoalDays;
                  d++
                )
                  HoldDepress(
                    onTap: () => Navigator.of(ctx).pop(d),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: d == _goalDays
                            ? kNeon.withValues(alpha: 0.18)
                            : null,
                        border: Border.all(
                          color: d == _goalDays ? kNeon : kBorder,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$d',
                        style: AppFonts.shareTechMono(
                          color: d == _goalDays ? kNeon : kText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (picked == null || picked == _goalDays) return;
    await WeeklyGoalService().setGoalDays(picked);
    if (!mounted) return;
    setState(() => _goalDays = picked);
  }

  void _openSession(WorkoutSession session) {
    Navigator.push(
      context,
      arcadeRoute((_) => SessionDetailPage(session: session)),
    ).then((_) => _load());
  }

  void _openFullMonth() {
    Navigator.push(
      context,
      arcadeRoute((_) => const CalendarPage()),
    ).then((_) => _load());
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: PixelLoader());
    }

    // Empty state: no zeros, no analytics — just the invitation to train.
    if (_browsable.isEmpty) {
      return _EmptyState(
        icon: 'assets/icons/control/icon_sword.png',
        title: 'READY TO LIFT?',
        body:
            'Your first workout starts here —\n'
            'log a session and your stats begin to climb.',
        ctaLabel: 'NEW WORKOUT',
        onCta: () => _openStartWorkout(context, onReturn: _load),
      );
    }

    final bottomPadding = 120 + MediaQuery.of(context).padding.bottom;
    final visibleSessions = _showAllSessions
        ? _browsable
        : _browsable.take(10).toList();
    final maxBarY = max(
      _weekData.fold(0.0, (m, d) => max(m, d.$1)),
      _lastWeekVolumes.fold(0.0, max),
    );
    final maxMuscleVol = _muscleData.fold(0.0, (m, d) => max(m, d.volume));
    final pct = _lastWeekVol > 0
        ? ((_thisWeekVol - _lastWeekVol) / _lastWeekVol * 100).round()
        : (_thisWeekVol > 0 ? 100 : 0);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Streak hero + week strip ───────────────────────────────────
          _buildStreakHero(context),
          if (_selectedStripDay != null) ...[
            const SizedBox(height: kSpace2),
            ..._buildSelectedDay(context),
          ],
          const SizedBox(height: kSpace4),

          // ── Stat trio ──────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatPip(
                    iconPath:
                        'assets/icons/control/ui/icon_nav_sessions_active.png',
                    label: 'SESSIONS',
                    value: '$_completedCount',
                  ),
                  _StatPip(
                    iconPath: 'assets/icons/control/icon_sword.png',
                    label: 'VOLUME',
                    value:
                        '${fmtVol(kgToDisplay(_totalVolume, Units.weight))} ${Units.weight.label}',
                  ),
                  _StatPip(
                    iconPath: 'assets/icons/control/icon_trophy.png',
                    label: 'RECORDS',
                    value: '$_recordCount',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: kSpace4),

          // ── Level / XP ─────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RankBadge(rank: _rank),
                      Text(
                        'LV. ${_xpProgress.level}',
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 11,
                          color: kText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace3),
                  ArcadeBar(value: _xpProgress.fraction),
                  const SizedBox(height: 6),
                  Text(
                    _xpProgress.label,
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: kSpace5),

          // ── Sessions ───────────────────────────────────────────────────
          Text('SESSIONS', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: kSpace3),
          for (final session in visibleSessions)
            Padding(
              padding: const EdgeInsets.only(bottom: kSpace2),
              child: _SessionListTile(
                session: session,
                volume: session.exercises.fold<double>(
                  0.0,
                  (sum, e) => sum + e.totalVolume,
                ),
                prCount: _prCounts[session.id] ?? 0,
                onTap: () => _openSession(session),
              ),
            ),
          if (_browsable.length > 10)
            PhosphorTap(
              onTap: () =>
                  setState(() => _showAllSessions = !_showAllSessions),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: kSpace2),
                child: Text(
                  _showAllSessions
                      ? '[ SHOW RECENT ]'
                      : '[ SHOW ALL ${_browsable.length} ]',
                  style: AppFonts.shareTechMono(color: kNeon, fontSize: 13),
                ),
              ),
            ),

          const SizedBox(height: kSpace4),
          const Divider(color: kBorder),
          const SizedBox(height: kSpace4),

          // ── This week vs last week ─────────────────────────────────────
          Text('THIS WEEK', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: kSpace4),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                backgroundColor: Colors.transparent,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                maxY: maxBarY > 0 ? maxBarY * 1.2 : 10,
                barGroups: [
                  for (int i = 0; i < 7; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 2,
                      barRods: [
                        BarChartRodData(
                          toY: _lastWeekVolumes.length > i
                              ? _lastWeekVolumes[i]
                              : 0,
                          color: kMutedText.withValues(alpha: 0.28),
                          width: 7,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(2),
                            topRight: Radius.circular(2),
                          ),
                        ),
                        BarChartRodData(
                          toY: _weekData[i].$1,
                          color: _weekData[i].$1 > 0
                              ? _weekData[i].$2
                              : Colors.transparent,
                          width: 12,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        return Text(
                          days[value.toInt()],
                          style: AppFonts.shareTechMono(
                            color: kMutedText,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: kSpace3),
          Text(
            'This week: $_thisWeekCount sessions · ${fmtVol(kgToDisplay(_thisWeekVol, Units.weight))} ${Units.weight.label}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: kSpace1),
          Row(
            children: [
              Text(
                'Last week: $_lastWeekCount sessions · ${fmtVol(kgToDisplay(_lastWeekVol, Units.weight))} ${Units.weight.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: kSpace2),
              Text(
                pct > 0
                    ? '+$pct% ↑'
                    : pct < 0
                    ? '$pct% ↓'
                    : '→',
                style: AppFonts.shareTechMono(
                  fontSize: 11,
                  color: pct > 0
                      ? kNeon
                      : pct < 0
                      ? kDanger
                      : kMutedText,
                ),
              ),
            ],
          ),

          const SizedBox(height: kSpace5),
          const Divider(color: kBorder),
          const SizedBox(height: kSpace4),

          // ── Muscle balance ─────────────────────────────────────────────
          Text(
            'MUSCLE BALANCE',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: kSpace1),
          Text(
            'Last 30 days',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
          const SizedBox(height: kSpace4),
          for (int i = 0; i < _muscleData.length; i++) ...[
            _MuscleBalanceRow(
              data: _muscleData[i],
              color: kMuscleGroupColors[_muscleData[i].muscle] ?? kNeon,
              maxVol: maxMuscleVol,
              fmtVol: fmtVol,
            ),
            if (i == _suggestedIdx)
              Padding(
                padding: const EdgeInsets.only(left: 88, bottom: kSpace1),
                child: Text(
                  'Suggested next',
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 11,
                  ),
                ),
              ),
            const SizedBox(height: kSpace2),
          ],

          const SizedBox(height: kSpace4),
          const Divider(color: kBorder),
          const SizedBox(height: kSpace4),

          // ── Load trends ────────────────────────────────────────────────
          Text('LOAD TRENDS', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: kSpace3),
          if (_trends.isEmpty)
            Text(
              'Log 5 weighted sets on an exercise to unlock load trends.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final trend in _trends)
              Padding(
                padding: const EdgeInsets.only(bottom: kSpace3),
                child: _ExerciseTrendCard(
                  trend: trend,
                  onTap: () => Navigator.push(
                    context,
                    arcadeRoute(
                      (_) => ExerciseHistoryPage(
                        exerciseId: trend.id,
                        exerciseName: trend.name,
                      ),
                    ),
                  ).then((_) => _load()),
                ),
              ),

          const SizedBox(height: kSpace4),

          // ── Records ────────────────────────────────────────────────────
          PhosphorTap(
            onTap: () => setState(() => _showRecords = !_showRecords),
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showRecords ? '[ HIDE RECORDS ]' : '[ SHOW RECORDS ]',
                  style: AppFonts.shareTechMono(color: kNeon, fontSize: 13),
                ),
                AnimatedRotation(
                  turns: _showRecords ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.keyboard_arrow_down_sharp,
                      color: kNeon),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: _showRecords
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: kSpace4),
                      if (_pbs.isEmpty)
                        Text(
                          'Log weighted sets to set records.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else
                        for (final entry in _pbs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: kSpace2),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    const ImageIcon(
                                      AssetImage(
                                        'assets/icons/control/icon_trophy.png',
                                      ),
                                      color: kAmber,
                                      size: 20,
                                    ),
                                    const SizedBox(width: kSpace3),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.key,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                          Text(
                                            '${weightValue(entry.value.weight, Units.weight)}${Units.weight.label} × ${entry.value.reps} · e1RM ${weightValue(entry.value.oneRM, Units.weight)}${Units.weight.label}',
                                            style: AppFonts.shareTechMono(
                                              color: kMutedText,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _fmtDate(entry.value.date),
                                      style: AppFonts.shareTechMono(
                                        color: kMutedText,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: kSpace5),
        ],
      ),
    );
  }

  Widget _buildStreakHero(BuildContext context) {
    final goalMet = _trainingDays >= _goalDays;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _streak > 0
                        ? '$_streak WEEK STREAK'
                        : 'START YOUR STREAK',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 11,
                      color: _streak > 0 ? kNeon : kMutedText,
                    ),
                  ),
                ),
                PhosphorTap(
                  onTap: _editGoal,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: goalMet ? kNeon.withValues(alpha: 0.12) : null,
                      border: Border.all(color: goalMet ? kNeon : kBorder),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$_trainingDays / $_goalDays DAYS',
                      style: AppFonts.shareTechMono(
                        color: goalMet ? kNeon : kMutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpace3),
            _WeekStrip(
              sessionsByDay: _sessionsByDay,
              restState: _restState,
              selectedDay: _selectedStripDay,
              firstActivityDay: _firstActivityDay,
              onSelectDay: (day) => setState(
                () => _selectedStripDay = _selectedStripDay == day
                    ? null
                    : day,
              ),
            ),
            const SizedBox(height: kSpace3),
            Row(
              children: [
                const Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        CalendarLegendMarker(
                          kind: CalendarMarkerKind.workout,
                          label: 'Workout',
                        ),
                        SizedBox(width: 14),
                        CalendarLegendMarker(
                          kind: CalendarMarkerKind.protected,
                          label: 'Protected',
                        ),
                        SizedBox(width: 14),
                        CalendarLegendMarker(
                          kind: CalendarMarkerKind.missed,
                          label: 'Missed',
                        ),
                      ],
                    ),
                  ),
                ),
                PhosphorTap(
                  onTap: _openFullMonth,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      'FULL MONTH →',
                      style: AppFonts.shareTechMono(
                        color: kCyan,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSelectedDay(BuildContext context) {
    final day = DateUtils.dateOnly(_selectedStripDay!);
    final sessions = _sessionsByDay[day] ?? const <WorkoutSession>[];
    final restInfo = RestService().dayInfoForState(
      day: day,
      sessions: sessions,
      state: _restState,
    );
    return [
      CalendarDayStatusCard(
        dateLabel: fmtDayDate(day),
        restInfo: restInfo,
        hasWorkout: sessions.isNotEmpty,
        abandonedOnly:
            sessions.isNotEmpty &&
            sessions.every((session) => session.isAbandoned),
        workoutColor: sessions.isNotEmpty
            ? kMuscleGroupColors[sessions.first.muscleGroup] ?? kNeon
            : null,
      ),
      const SizedBox(height: kSpace2),
      for (final session in sessions)
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace2),
          child: _SessionListTile(
            session: session,
            volume: session.exercises.fold<double>(
              0.0,
              (sum, e) => sum + e.totalVolume,
            ),
            prCount: _prCounts[session.id] ?? 0,
            onTap: () => _openSession(session),
          ),
        ),
    ];
  }
}

/// Mon–Sun strip for the current week: weekday letter, day number, and the
/// same status markers as the full calendar. Tapping a day toggles its
/// detail card under the hero.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.sessionsByDay,
    required this.restState,
    required this.selectedDay,
    required this.onSelectDay,
    this.firstActivityDay,
  });

  final Map<DateTime, List<WorkoutSession>> sessionsByDay;
  final RestState restState;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelectDay;
  final DateTime? firstActivityDay;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _cell(
              context,
              monday.add(Duration(days: i)),
              _letters[i],
              today,
            ),
          ),
      ],
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime day,
    String letter,
    DateTime today,
  ) {
    final sessions = sessionsByDay[day] ?? const <WorkoutSession>[];
    final hasWorkout = sessions.isNotEmpty;
    final abandonedOnly =
        hasWorkout && sessions.every((session) => session.isAbandoned);
    final restInfo = RestService().dayInfoForState(
      day: day,
      sessions: sessions,
      state: restState,
    );
    final isToday = day == today;
    final isSelected =
        selectedDay != null && day == DateUtils.dateOnly(selectedDay!);
    final markerKind = calendarMarkerKindFor(
      restInfo: restInfo,
      hasWorkout: hasWorkout,
      abandonedOnly: abandonedOnly,
      isToday: isToday,
      isSelected: isSelected,
      suppressMissed:
          firstActivityDay == null || day.isBefore(firstActivityDay!),
    );
    final workoutColor = hasWorkout
        ? kMuscleGroupColors[sessions.first.muscleGroup] ?? kNeon
        : null;
    final isFuture = day.isAfter(today);

    return HoldDepress(
      onTap: () => onSelectDay(day),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? kNeon.withValues(alpha: 0.18) : null,
          border: isSelected
              ? Border.all(color: kNeon, width: 1.5)
              : isToday
              ? Border.all(color: kNeon, width: 1)
              : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              letter,
              style: AppFonts.shareTechMono(
                color: kMutedText,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? kNeon
                    : isFuture
                    ? kMutedText
                    : kText,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 10,
              child: markerKind == null
                  ? null
                  : CalendarDayMarker(
                      kind: markerKind,
                      color: calendarMarkerColor(
                        markerKind,
                        workoutColor: workoutColor,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact amber "N PR" badge for session tiles.
class _PrBadge extends StatelessWidget {
  const _PrBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: kAmber.withValues(alpha: 0.12),
        border: Border.all(color: kAmber),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ImageIcon(
            AssetImage('assets/icons/control/icon_trophy.png'),
            size: 10,
            color: kAmber,
          ),
          const SizedBox(width: 3),
          Text(
            '$count PR',
            style: AppFonts.shareTechMono(
              color: kAmber,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Library Tab (Programs ⇄ Exercises) ───────────────────────────────────────

class _LibraryTab extends StatefulWidget {
  const _LibraryTab({required this.reloadToken});

  final int reloadToken;

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

enum _LibraryView { programs, exercises }

class _LibraryTabState extends State<_LibraryTab> {
  _LibraryView _view = _LibraryView.programs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: _SubTabToggle(
            labels: const ['PROGRAMS', 'EXERCISES'],
            selectedIndex: _view == _LibraryView.programs ? 0 : 1,
            onChanged: (i) => setState(
              () => _view = i == 0
                  ? _LibraryView.programs
                  : _LibraryView.exercises,
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _view == _LibraryView.programs ? 0 : 1,
            children: [
              ProgramsLibraryBody(
                embedded: true,
                reloadToken: widget.reloadToken,
              ),
              const _ExercisesTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared helpers ───────────────────────────────────────────────────────────

void _openStartWorkout(BuildContext context, {VoidCallback? onReturn}) {
  Navigator.push(
    context,
    arcadeRoute(
      (_) => const StartWorkoutPage(),
      motion: ArcadeRouteMotion.flow,
    ),
  ).then((_) {
    if (onReturn != null) onReturn();
  });
}

/// Consistent empty-state block: pixel icon, verb-first headline, one-line body,
/// and an optional primary CTA. Used across Workout sub-tabs.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.onCta,
  });

  final String icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImageIcon(AssetImage(icon), size: 48, color: kBorder),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 20),
              PixelButton(label: ctaLabel!, fullWidth: false, onPressed: onCta),
            ],
          ],
        ),
      ),
    );
  }
}

/// Generic 2+-segment pill toggle (LIBRARY: Programs/Exercises). Animated
/// sliding indicator over labelled segments.
class _SubTabToggle extends StatelessWidget {
  const _SubTabToggle({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: selectedIndex * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kNeon.withValues(alpha: 0.18),
                    border: Border.all(color: kNeon),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  for (int i = 0; i < labels.length; i++)
                    _SubTabSegment(
                      label: labels[i],
                      selected: selectedIndex == i,
                      onTap: () => onChanged(i),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SubTabSegment extends StatelessWidget {
  const _SubTabSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PhosphorTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: selected ? kNeon : kMutedText,
              fontFamily: 'PressStart2P',
              fontSize: 8,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _SessionListTile extends StatelessWidget {
  const _SessionListTile({
    required this.session,
    required this.onTap,
    this.volume,
    this.prCount = 0,
  });

  final WorkoutSession session;
  final VoidCallback onTap;

  /// Session total volume (kg); shown under the duration when provided.
  final double? volume;

  /// Exercises that set a new e1RM record in this session.
  final int prCount;

  @override
  Widget build(BuildContext context) {
    final mins = session.actualDurationSeconds ~/ 60;
    final sessionVolume = volume;
    return HoldDepress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                color: session.isAbandoned ? kDanger : kNeon,
              ),
              Expanded(
                child: ListTile(
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          session.isAbandoned
                              ? '${session.targetMuscleLabel} - ENDED EARLY'
                              : session.targetMuscleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (prCount > 0) ...[
                        const SizedBox(width: 6),
                        _PrBadge(count: prCount),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${fmtDayDate(session.date)} · '
                    '${session.isAbandoned ? 'Time XP only' : '${session.exercises.length} exercises'}',
                    style: const TextStyle(color: kMutedText),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$mins min'),
                      if (sessionVolume != null && sessionVolume > 0)
                        Text(
                          '${fmtVol(kgToDisplay(sessionVolume, Units.weight))} ${Units.weight.label}',
                          style: AppFonts.shareTechMono(
                            color: kMutedText,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stats Tab ─────────────────────────────────────────────────────────────────

/// Per-exercise record: the heaviest set by estimated 1RM, plus the raw
/// weight × reps it came from.
class _PBRecord {
  const _PBRecord(this.weight, this.reps, this.oneRM, this.date);
  final double weight;
  final int reps;
  final double oneRM;
  final DateTime date;
}

class _MuscleData {
  const _MuscleData(this.muscle, this.volume, this.lastTrained);
  final String muscle;
  final double volume;
  final DateTime? lastTrained;
}

class _ExerciseTrend {
  const _ExerciseTrend({
    required this.id,
    required this.name,
    required this.loads,
    required this.plateau,
  });

  final String id;
  final String name;
  final List<double> loads;
  final bool plateau;
}

class _ExerciseTrendCard extends StatelessWidget {
  const _ExerciseTrendCard({required this.trend, this.onTap});

  final _ExerciseTrend trend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final maxLoad = trend.loads.fold<double>(0, max);
    final minLoad = trend.loads.fold<double>(maxLoad, min);
    final range = max(1.0, maxLoad - minLoad);
    final card = Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kSurface2,
        border: Border.all(color: trend.plateau ? kAmber : kBorder),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trend.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.shareTechMono(
                    color: kText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trend.plateau)
                Text(
                  'PLATEAU',
                  style: AppFonts.shareTechMono(color: kAmber, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: kSpace2),
          SizedBox(
            height: 80,
            child: LineChart(
              LineChartData(
                minY: minLoad - range * 0.1,
                maxY: maxLoad + range * 0.1,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < trend.loads.length; i++)
                        FlSpot(i.toDouble(), trend.loads[i]),
                    ],
                    isCurved: false,
                    barWidth: 2,
                    color: trend.plateau ? kAmber : kNeon,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return HoldDepress(
      onTap: onTap!,
      borderRadius: BorderRadius.circular(kCardRadius),
      child: card,
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final String rank;

  Color _borderColor() {
    switch (rank) {
      case 'Legend':
        return kDanger;
      case 'Champion':
        return kDanger;
      case 'Knight':
        return kAmber;
      case 'Squire':
        return kNeon;
      default:
        return kMutedText;
    }
  }

  Color? _bgColor() {
    if (rank == 'Legend') {
      return kDanger.withValues(alpha: 0.15);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor(),
        border: Border.all(color: _borderColor()),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        rank.toUpperCase(),
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 9,
          color: _borderColor(),
        ),
      ),
    );
  }
}

class _StatPip extends StatelessWidget {
  const _StatPip({
    required this.iconPath,
    required this.label,
    required this.value,
  });
  final String iconPath;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ImageIcon(
          AssetImage(iconPath),
          size: 16,
          color: kNeon,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: kNeon,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: kMutedText, fontSize: 9)),
      ],
    );
  }
}

class _MuscleBalanceRow extends StatelessWidget {
  const _MuscleBalanceRow({
    required this.data,
    required this.color,
    required this.maxVol,
    required this.fmtVol,
  });
  final _MuscleData data;
  final Color color;
  final double maxVol;
  final String Function(double) fmtVol;

  @override
  Widget build(BuildContext context) {
    final progress = maxVol > 0
        ? (data.volume / maxVol).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            data.muscle,
            maxLines: 1,
            style: const TextStyle(color: kMutedText, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ArcadeBar(
            value: progress,
            height: 8,
            accent: color,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            '${fmtVol(kgToDisplay(data.volume, Units.weight))} ${Units.weight.label}',
            style: const TextStyle(color: kMutedText, fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ── Exercises Tab ─────────────────────────────────────────────────────────────

class _ExercisesTab extends StatefulWidget {
  const _ExercisesTab();

  @override
  State<_ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends State<_ExercisesTab>
    with SingleTickerProviderStateMixin {
  static const _groups = ['All', ...canonicalMuscleGroups];

  String _selectedGroup = 'All';
  bool _favOnly = false;
  String _query = '';
  List<Exercise> _catalog = [];
  Set<String> _favoriteIds = {};
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  late final AnimationController _shimmerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  late final Animation<double> _shimmerOpacity =
      Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
      );

  @override
  void initState() {
    super.initState();
    _shimmerController.repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final catalog = await ExerciseCatalogService().getFullCatalog();
    final favs = await FavoriteService().getFavoriteExerciseIds();
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _favoriteIds = favs;
      _loading = false;
    });
  }

  Future<void> _toggleFavorite(String id) async {
    final isNowFav = await FavoriteService().toggleFavoriteExercise(id);
    if (isNowFav) {
      setState(() => _favoriteIds.add(id));
    } else {
      setState(() => _favoriteIds.remove(id));
    }
  }

  List<Exercise> get _filtered {
    final allowedIds = _selectedGroup == 'All'
        ? curatedExerciseIdsByMuscleGroup.values.expand((ids) => ids).toSet()
        : curatedExerciseIdsByMuscleGroup[_selectedGroup]?.toSet() ?? {};

    return _catalog.where((e) {
      final matchesQuery =
          _query.isEmpty || e.name.toLowerCase().contains(_query.toLowerCase());
      final matchesFav = !_favOnly || _favoriteIds.contains(e.id);
      if (!matchesQuery || !matchesFav) return false;

      if (e.isCustom) {
        if (_selectedGroup == 'All') return true;
        final group = e.muscleGroup;
        return group != null && hasTargetMuscle([group], _selectedGroup);
      }
      return allowedIds.contains(e.id);
    }).toList()..sort((a, b) {
      // Custom exercises first, then alphabetical
      if (a.isCustom != b.isCustom) return a.isCustom ? -1 : 1;
      return a.name.compareTo(b.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: ArcadeTextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            style: AppFonts.shareTechMono(
              color: kText,
              fontSize: 14,
            ),
            hintText: 'Search exercises',
            hintStyle: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
            prefixIcon: const Icon(Icons.search_sharp, color: kMutedText),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_sharp, color: kMutedText),
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        // Filter chips
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _groups.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i == _groups.length) {
                return _FavChip(
                  selected: _favOnly,
                  onSelected: () => setState(() => _favOnly = !_favOnly),
                );
              }
              final group = _groups[i];
              final selected = group == _selectedGroup;
              return ArcadeChip(
                label: group,
                selected: selected,
                onTap: () => setState(() => _selectedGroup = group),
              );
            },
          ),
        ),

        // Create button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            height: 36,
            child: FilledButton.icon(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  arcadeRoute((_) => const CreateExercisePage()),
                );
                if (created == true) _load();
              },
              icon: const Icon(Icons.add_sharp, size: 16),
              label: const Text(
                'CREATE',
                style: TextStyle(fontFamily: 'PressStart2P', fontSize: 9),
              ),
            ),
          ),
        ),

        // Exercise list
        Expanded(
          child: _loading
              ? AnimatedBuilder(
                  animation: _shimmerOpacity,
                  builder: (context, _) => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: 6,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) => Opacity(
                      opacity: _shimmerOpacity.value,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                )
              : _filtered.isEmpty
              ? Center(
                  child: Text(
                    _favOnly ? 'NO FAVORITES YET' : 'No exercises found',
                    style: _favOnly
                        ? AppFonts.shareTechMono(
                            color: kMutedText,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          )
                        : Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final ex = _filtered[i];
                    return ExerciseCard(
                      exercise: ex,
                      isFavorite: _favoriteIds.contains(ex.id),
                      isCustom: ex.isCustom,
                      showFavorite: true,
                      showArrow: true,
                      onTap: () => Navigator.push(
                        context,
                        arcadeRoute((_) => ExerciseDetailPage(exercise: ex)),
                      ),
                      onFavoriteToggle: () => _toggleFavorite(ex.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FavChip extends StatelessWidget {
  const _FavChip({required this.selected, required this.onSelected});

  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    const red = kDanger;
    const dark = kBg;
    final fg = selected ? dark : red;
    return HoldDepress(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? red : Colors.transparent,
          border: Border.all(color: red),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImageIcon(
              const AssetImage('assets/icons/control/icon_heart.png'),
              size: 14,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text('Fav', style: TextStyle(color: fg, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
