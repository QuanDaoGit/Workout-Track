import 'dart:convert';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/curated_exercises.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';
import '../models/workout_models.dart';
import '../services/favorite_service.dart';
import '../services/quest_service.dart';
import '../services/workout_storage_service.dart';
import '../services/xp_service.dart';
import '../widgets/exercise_card.dart';
import 'calendar_page.dart';
import 'exercise_detail.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  WorkoutPageState createState() => WorkoutPageState();
}

class WorkoutPageState extends State<WorkoutPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _historyKey = GlobalKey<_HistoryTabState>();
  final _statsKey = GlobalKey<_StatsTabState>();

  void reload() {
    _historyKey.currentState?._load();
    _statsKey.currentState?._load();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
            Tab(text: 'HISTORY'),
            Tab(text: 'EXERCISES'),
            Tab(text: 'STATS'),
          ],
          labelStyle: const TextStyle(fontFamily: 'PressStart2P', fontSize: 9),
          indicatorColor: const Color(0xFF00FF9C),
          labelColor: const Color(0xFF00FF9C),
          unselectedLabelColor: const Color(0xFF6B6B8A),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _HistoryTab(key: _historyKey),
          const _ExercisesTab(),
          _StatsTab(key: _statsKey),
        ],
      ),
    );
  }
}

// ── History Tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({super.key});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  int _totalSessions = 0;
  int _thisMonth = 0;
  int _streak = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await WorkoutStorageService().getSessions();
    if (!mounted) return;
    final completed = all.where((s) => !s.isPartial).toList();
    final now = DateTime.now();
    final thisMonth = completed
        .where((s) => s.date.year == now.year && s.date.month == now.month)
        .length;
    setState(() {
      _totalSessions = completed.length;
      _thisMonth = thisMonth;
      _streak = _calcStreak(completed);
      _loading = false;
    });
  }

  int _calcStreak(List<WorkoutSession> completed) {
    final days = completed.map((s) => DateUtils.dateOnly(s.date)).toSet();
    int streak = 0;
    DateTime check = DateUtils.dateOnly(DateTime.now());
    while (days.contains(check)) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: PixelLoader());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HISTORY', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _StatRow(label: 'Total Sessions', value: '$_totalSessions'),
                  const Divider(height: 24, color: Color(0xFF2A2A4A)),
                  _StatRow(label: 'This Month', value: '$_thisMonth'),
                  const Divider(height: 24, color: Color(0xFF2A2A4A)),
                  _StatRow(
                    label: 'Streak',
                    value: '$_streak day${_streak == 1 ? '' : 's'}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          PixelButton(
            label: 'Open Calendar',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalendarPage()),
            ).then((_) => _load()),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF00FF9C),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ── Stats Tab ─────────────────────────────────────────────────────────────────

class _PBRecord {
  const _PBRecord(this.volume, this.weight, this.reps, this.date);
  final double volume;
  final double weight;
  final int reps;
  final DateTime date;
}

class _MuscleData {
  const _MuscleData(this.muscle, this.volume, this.lastTrained);
  final String muscle;
  final double volume;
  final DateTime? lastTrained;
}

class _StatsTab extends StatefulWidget {
  const _StatsTab({super.key});

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  List<WorkoutSession> _sessions = [];
  int _questXP = 0;
  bool _loading = true;
  bool _showRecords = false;

  static const Map<String, Color> _muscleColors = {
    'Chest': Color(0xFF00FF9C),
    'Back': Color(0xFFFFD700),
    'Arms': Color(0xFFFF2D55),
    'Legs': Color(0xFF00BFFF),
  };

  static const List<String> _muscles = ['Chest', 'Back', 'Arms', 'Legs'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await WorkoutStorageService().getSessions();
    final questXP = await QuestService().claimedRewardXP();
    if (!mounted) return;
    setState(() {
      _sessions = all;
      _questXP = questXP;
      _loading = false;
    });
  }

  String _fmtVol(double v) {
    final rounded = v.round();
    if (rounded >= 1000) {
      final s = rounded.toString();
      final buf = StringBuffer();
      final start = s.length % 3;
      if (start > 0) buf.write(s.substring(0, start));
      for (int i = start; i < s.length; i += 3) {
        if (buf.isNotEmpty) buf.write(',');
        buf.write(s.substring(i, i + 3));
      }
      return buf.toString();
    }
    return rounded.toString();
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

  // Returns list of (totalVolume, dominantColor) for Mon–Sun of current week
  List<(double, Color)> _buildWeekData() {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final volumes = List<double>.filled(7, 0);
    // per day: track muscle → volume so we can pick dominant
    final muscleVols = List<Map<String, double>>.generate(7, (_) => {});

    for (final s in _sessions.where((s) => !s.isPartial)) {
      final day = DateTime(s.date.year, s.date.month, s.date.day);
      final idx = day.difference(monday).inDays;
      if (idx < 0 || idx > 6) continue;
      final vol = s.exercises.fold(0.0, (sum, e) => sum + e.totalVolume);
      volumes[idx] += vol;
      muscleVols[idx][s.muscleGroup] =
          (muscleVols[idx][s.muscleGroup] ?? 0) + vol;
    }

    return List.generate(7, (i) {
      if (volumes[i] == 0) return (0.0, Colors.transparent);
      final dominant = muscleVols[i].entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      return (volumes[i], _muscleColors[dominant] ?? const Color(0xFF00FF9C));
    });
  }

  // Returns (sessions count, total volume) for a date range
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
      for (final s in _sessions.where(
        (s) => !s.isPartial && s.muscleGroup == muscle,
      )) {
        if (s.date.isAfter(cutoff)) {
          vol += s.exercises.fold(0.0, (sum, e) => sum + e.totalVolume);
        }
        if (lastTrained == null || s.date.isAfter(lastTrained)) {
          lastTrained = s.date;
        }
      }
      return _MuscleData(muscle, vol, lastTrained);
    }).toList();
  }

  int _suggestedIdx(List<_MuscleData> data) {
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

  List<MapEntry<String, _PBRecord>> _buildPersonalBests() {
    final Map<String, _PBRecord> bests = {};
    for (final s in _sessions.where((s) => !s.isPartial)) {
      for (final e in s.exercises) {
        for (final set in e.sets) {
          final vol = set.weight * set.reps;
          if (!bests.containsKey(e.exerciseName) ||
              vol > bests[e.exerciseName]!.volume) {
            bests[e.exerciseName] = _PBRecord(
              vol,
              set.weight,
              set.reps,
              s.date,
            );
          }
        }
      }
    }
    final sorted = bests.entries.toList()
      ..sort((a, b) => b.value.volume.compareTo(a.value.volume));
    return sorted.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: PixelLoader());
    }

    final completed = _sessions.where((s) => !s.isPartial).toList();

    if (completed.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ImageIcon(
              AssetImage('assets/icons/control/icon_sword.png'),
              size: 48,
              color: Color(0xFF2A2A4A),
            ),
            const SizedBox(height: 16),
            Text(
              'NO DATA YET',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first quest\nto unlock your stats.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // ── Computed values ──────────────────────────────────────────────────────
    final totalXP = XpService.calculateTotalXP(_sessions) + _questXP;
    final level = XpService.getLevel(totalXP);
    final rank = XpService.getRank(level);
    final xpBase = XpService.xpForCurrentLevel(level);
    final xpNext = XpService.xpForNextLevel(level);
    final streak = XpService.calculateStreak(_sessions);
    final questCount = completed.length;
    final totalVolume = completed.fold(
      0.0,
      (sum, s) => sum + s.exercises.fold(0.0, (s2, e) => s2 + e.totalVolume),
    );

    final xpFraction = xpNext > xpBase
        ? ((totalXP - xpBase) / (xpNext - xpBase)).clamp(0.0, 1.0)
        : 1.0;
    // Week data
    final weekData = _buildWeekData();
    final now = DateTime.now();
    final thisMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final (thisWeekCount, thisWeekVol) = _rangeStats(
      thisMonday,
      now.add(const Duration(days: 1)),
    );
    final (lastWeekCount, lastWeekVol) = _rangeStats(lastMonday, thisMonday);
    final pct = lastWeekVol > 0
        ? ((thisWeekVol - lastWeekVol) / lastWeekVol * 100).round()
        : (thisWeekVol > 0 ? 100 : 0);

    // Muscle balance
    final muscleData = _buildMuscleBalance();
    final maxVol = muscleData.fold(0.0, (m, d) => max(m, d.volume));
    final suggestedIdx = _suggestedIdx(muscleData);

    // Personal bests
    final pbs = _buildPersonalBests();

    // Max bar height for chart
    final maxBarY = weekData.fold(0.0, (m, d) => max(m, d.$1));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section 1: Character Card ──────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rank + Level row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RankBadge(rank: rank),
                      Text(
                        'LV. $level',
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 11,
                          color: Color(0xFFE8E8FF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: xpFraction,
                      minHeight: 8,
                      backgroundColor: const Color(0xFF2A2A4A),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF00FF9C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$totalXP / $xpNext XP',
                    style: const TextStyle(
                      color: Color(0xFF6B6B8A),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats trio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatPip(
                        iconPath: 'assets/icons/control/icon_star.png',
                        label: 'STREAK',
                        value: '$streak days',
                      ),
                      _StatPip(
                        iconPath: 'assets/icons/control/icon_trophy.png',
                        label: 'QUESTS',
                        value: '$questCount',
                      ),
                      _StatPip(
                        iconPath: 'assets/icons/control/icon_sword.png',
                        label: 'DAMAGE',
                        value: '${_fmtVol(totalVolume)} kg',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFF2A2A4A)),
          const SizedBox(height: 16),

          // ── Section 2: This Week ───────────────────────────────────────
          Text('THIS WEEK', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
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
                      barRods: [
                        BarChartRodData(
                          toY: weekData[i].$1,
                          color: weekData[i].$1 > 0
                              ? weekData[i].$2
                              : Colors.transparent,
                          width: 20,
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
                          style: const TextStyle(
                            color: Color(0xFF6B6B8A),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Week comparison
          Text(
            'This week: $thisWeekCount sessions · ${_fmtVol(thisWeekVol)} kg',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Last week: $lastWeekCount sessions · ${_fmtVol(lastWeekVol)} kg',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              Text(
                pct > 0
                    ? '+$pct% ↑'
                    : pct < 0
                    ? '$pct% ↓'
                    : '→',
                style: TextStyle(
                  fontSize: 11,
                  color: pct > 0
                      ? const Color(0xFF00FF9C)
                      : pct < 0
                      ? const Color(0xFFFF2D55)
                      : const Color(0xFF6B6B8A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFF2A2A4A)),
          const SizedBox(height: 16),

          // ── Section 3: Muscle Balance ──────────────────────────────────
          Text(
            'MUSCLE BALANCE',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Last 30 days',
            style: const TextStyle(color: Color(0xFF6B6B8A), fontSize: 12),
          ),
          const SizedBox(height: 16),

          for (int i = 0; i < muscleData.length; i++) ...[
            _MuscleBalanceRow(
              data: muscleData[i],
              color:
                  _muscleColors[muscleData[i].muscle] ??
                  const Color(0xFF00FF9C),
              maxVol: maxVol,
              fmtVol: _fmtVol,
            ),
            if (i == suggestedIdx)
              Padding(
                padding: const EdgeInsets.only(left: 64, bottom: 4),
                child: Text(
                  'Suggested next',
                  style: const TextStyle(
                    color: Color(0xFF6B6B8A),
                    fontSize: 10,
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2A2A4A)),
          const SizedBox(height: 16),

          // ── Section 4: Personal Bests ──────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() => _showRecords = !_showRecords),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _showRecords ? '[ HIDE RECORDS ]' : '[ SHOW RECORDS ]',
                      style: GoogleFonts.shareTechMono(
                        color: const Color(0xFF00FF9C),
                        fontSize: 13,
                      ),
                    ),
                    AnimatedRotation(
                      turns: _showRecords ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(
                        Icons.keyboard_arrow_down_sharp,
                        color: Color(0xFF00FF9C),
                      ),
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
                          const SizedBox(height: 16),
                          if (pbs.isEmpty)
                            Text(
                              'Complete your first quest to see records here',
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          else
                            for (final entry in pbs)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
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
                                          color: Color(0xFFFFD700),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
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
                                                '${entry.value.weight}kg × ${entry.value.reps} reps',
                                                style: const TextStyle(
                                                  color: Color(0xFF6B6B8A),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _fmtDate(entry.value.date),
                                          style: const TextStyle(
                                            color: Color(0xFF6B6B8A),
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
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final String rank;

  Color _borderColor() {
    switch (rank) {
      case 'Legend':
        return const Color(0xFFFF2D55);
      case 'Champion':
        return const Color(0xFFFF2D55);
      case 'Knight':
        return const Color(0xFFFFD700);
      case 'Squire':
        return const Color(0xFF00FF9C);
      default:
        return const Color(0xFF6B6B8A);
    }
  }

  Color? _bgColor() {
    if (rank == 'Legend') {
      return const Color(0xFFFF2D55).withValues(alpha: 0.15);
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
          color: const Color(0xFF00FF9C),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: Color(0xFF00FF9C),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF6B6B8A), fontSize: 9),
        ),
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
    final filled = maxVol > 0
        ? (data.volume / maxVol * 10).floor().clamp(0, 10)
        : 0;

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            data.muscle,
            style: const TextStyle(color: Color(0xFF6B6B8A), fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final blockWidth = (constraints.maxWidth - 9 * 4) / 10;
              return Row(
                children: [
                  for (int i = 0; i < 10; i++) ...[
                    Container(
                      width: blockWidth,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i < filled ? color : const Color(0xFF2A2A4A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    if (i < 9) const SizedBox(width: 4),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            '${fmtVol(data.volume)} kg',
            style: const TextStyle(color: Color(0xFF6B6B8A), fontSize: 12),
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
  static const _groups = ['All', 'Chest', 'Back', 'Arms', 'Legs'];

  String _selectedGroup = 'All';
  List<Exercise> _catalog = [];
  Set<String> _favoriteIds = {};
  bool _loading = true;

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
    super.dispose();
  }

  Future<void> _load() async {
    final jsonStr = await rootBundle.loadString('assets/exercises.json');
    final data = jsonDecode(jsonStr) as List<dynamic>;
    final catalog = [
      for (final e in data) Exercise.fromJson(e as Map<String, dynamic>),
    ];
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
    return _catalog.where((e) => allowedIds.contains(e.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter chips
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _groups.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final group = _groups[i];
              final selected = group == _selectedGroup;
              return ChoiceChip(
                label: Text(group),
                selected: selected,
                labelStyle: TextStyle(
                  color: selected
                      ? const Color(0xFF0D0D1A)
                      : const Color(0xFF6B6B8A),
                  fontSize: 11,
                ),
                onSelected: (_) => setState(() => _selectedGroup = group),
              );
            },
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
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                )
              : _filtered.isEmpty
              ? Center(
                  child: Text(
                    'No exercises found',
                    style: Theme.of(context).textTheme.bodySmall,
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
                      showFavorite: true,
                      showArrow: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseDetailPage(exercise: ex),
                        ),
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
