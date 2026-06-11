import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/unit_models.dart';
import '../models/workout_models.dart';
import '../services/progressive_overload_service.dart';
import '../services/unit_settings_service.dart';
import '../services/workout_storage_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/pixel_loader.dart';
import 'Workout session/session_detail.dart';
import 'calendar_page.dart';

/// One entry per session in which the exercise was logged.
class _HistoryEntry {
  const _HistoryEntry({
    required this.session,
    required this.sets,
    required this.best1RM,
  });

  final WorkoutSession session;
  final List<SetEntry> sets;

  /// Best estimated 1RM across the session's sets (0 for bodyweight-only).
  final double best1RM;
}

/// Full progression history for a single exercise: an e1RM trend chart over
/// every session it appears in, plus the chronological set log. The
/// competence-feedback surface — "am I actually getting stronger at this?"
class ExerciseHistoryPage extends StatefulWidget {
  const ExerciseHistoryPage({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
  });

  final String exerciseId;
  final String exerciseName;

  @override
  State<ExerciseHistoryPage> createState() => _ExerciseHistoryPageState();
}

class _ExerciseHistoryPageState extends State<ExerciseHistoryPage> {
  List<_HistoryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await WorkoutStorageService().getSessions();
    if (!mounted) return;
    final entries = <_HistoryEntry>[];
    for (final session in sessions) {
      if (session.isPartial) continue;
      for (final log in session.exercises) {
        if (log.exerciseId != widget.exerciseId || log.sets.isEmpty) continue;
        var best = 0.0;
        for (final set in log.sets) {
          if (set.weight <= 0) continue;
          best = max(
            best,
            ProgressiveOverloadService.epley1RM(set.weight, set.reps, false),
          );
        }
        entries.add(
          _HistoryEntry(session: session, sets: log.sets, best1RM: best),
        );
      }
    }
    entries.sort((a, b) => b.session.date.compareTo(a.session.date));
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exerciseName.toUpperCase())),
      body: _loading
          ? const Center(child: PixelLoader())
          : _entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(kSpace5),
                child: Text(
                  'No logged sets yet.\nThis page fills in as you train.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(kSpace5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryRow(context),
                  const SizedBox(height: kSpace4),
                  ..._buildChartSection(context),
                  Text(
                    'HISTORY',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: kSpace3),
                  for (final entry in _entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: kSpace2),
                      child: _HistoryEntryCard(entry: entry, onOpen: _open),
                    ),
                  const SizedBox(height: kSpace5),
                ],
              ),
            ),
    );
  }

  void _open(WorkoutSession session) {
    Navigator.push(
      context,
      arcadeRoute((_) => SessionDetailPage(session: session)),
    ).then((_) => _load());
  }

  Widget _buildSummaryRow(BuildContext context) {
    final best = _entries.fold(0.0, (m, e) => max(m, e.best1RM));
    final totalSets = _entries.fold(0, (sum, e) => sum + e.sets.length);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(kCardPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryPip(label: 'SESSIONS', value: '${_entries.length}'),
            _SummaryPip(label: 'SETS', value: '$totalSets'),
            _SummaryPip(
              label: 'BEST e1RM',
              value: best > 0
                  ? '${weightValue(best, Units.weight)} ${Units.weight.label}'
                  : '—',
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChartSection(BuildContext context) {
    // Oldest → newest for the x axis; weighted sessions only.
    final points = _entries.reversed
        .where((entry) => entry.best1RM > 0)
        .toList();
    if (points.length < 2) {
      return [
        Text(
          'Log this exercise in one more session to unlock the trend chart.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: kSpace4),
      ];
    }
    final maxY = points.fold(0.0, (m, e) => max(m, e.best1RM));
    final minY = points.fold(maxY, (m, e) => min(m, e.best1RM));
    final range = max(1.0, maxY - minY);
    return [
      Text('e1RM TREND', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: kSpace3),
      Container(
        padding: const EdgeInsets.all(kSpace3),
        decoration: BoxDecoration(
          color: kSurface2,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        child: SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              minY: minY - range * 0.1,
              maxY: maxY + range * 0.1,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) => Text(
                      weightValue(value, Units.weight),
                      style: AppFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < points.length; i++)
                      FlSpot(i.toDouble(), points[i].best1RM),
                  ],
                  isCurved: false,
                  barWidth: 2,
                  color: kNeon,
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: kSpace2),
      Text(
        '${points.length} weighted sessions · estimated 1RM per session',
        style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
      ),
      const SizedBox(height: kSpace4),
    ];
  }
}

class _SummaryPip extends StatelessWidget {
  const _SummaryPip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: kNeon,
          ),
        ),
        const SizedBox(height: kSpace1),
        Text(
          label,
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
        ),
      ],
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({required this.entry, required this.onOpen});

  final _HistoryEntry entry;
  final ValueChanged<WorkoutSession> onOpen;

  @override
  Widget build(BuildContext context) {
    return HoldDepress(
      onTap: () => onOpen(entry.session),
      borderRadius: BorderRadius.circular(kCardRadius),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(kSpace3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fmtDayDate(entry.session.date),
                      style: AppFonts.shareTechMono(
                        color: kText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (entry.best1RM > 0)
                    Text(
                      'e1RM ${weightValue(entry.best1RM, Units.weight)} ${Units.weight.label}',
                      style: AppFonts.shareTechMono(
                        color: kNeon,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: kSpace2),
              Wrap(
                spacing: kSpace3,
                runSpacing: kSpace1,
                children: [
                  for (final set in entry.sets)
                    Text(
                      set.weight > 0
                          ? '${weightValue(set.weight, Units.weight)}${Units.weight.label} × ${set.reps}'
                          : 'BW × ${set.reps}',
                      style: AppFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
