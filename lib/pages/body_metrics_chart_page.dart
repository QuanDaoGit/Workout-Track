import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../models/body_goal_models.dart';
import '../models/body_metrics_models.dart';
import '../models/unit_models.dart';
import '../models/weight_trend.dart';
import '../services/body_goal_service.dart';
import '../services/body_metrics_service.dart';
import '../services/unit_settings_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';
import 'body_metrics_history_page.dart';

class BodyMetricsChartPage extends StatefulWidget {
  const BodyMetricsChartPage({super.key});

  @override
  State<BodyMetricsChartPage> createState() => _BodyMetricsChartPageState();
}

class _BodyMetricsChartPageState extends State<BodyMetricsChartPage> {
  List<WeightEntry> _entries = [];
  BodyGoalState? _goalState;
  bool _loading = true;
  bool _showVelocity = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await BodyMetricsService().getEntries();
    final goal = await BodyGoalService().getGoalState();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _goalState = goal;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BODY METRICS')),
      body: _loading
          ? const Center(child: PixelLoader())
          : _entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'NO CHECK-INS YET\n\nlog your weight to start your trend.',
                  textAlign: TextAlign.center,
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final first = _entries.first.loggedAt;
    final last = _entries.last.loggedAt;
    final weekSpan = last.difference(first).inDays ~/ 7;
    final ready = trendIsReady(_entries);
    final velocityKg = trendVelocityPerWeek(_entries);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        // Chart
        SizedBox(height: 240, child: _buildChart(ready)),
        if (!ready) ...[
          const SizedBox(height: 10),
          Center(
            child: Text(
              'trend builds as you log',
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
            ),
          ),
        ],
        const SizedBox(height: 24),

        // Stats
        _StatRow(label: 'CHECK-INS', value: '${_entries.length}'),
        const SizedBox(height: 6),
        _StatRow(label: 'TIME SPAN', value: '$weekSpan WEEKS'),
        if (_goalState != null) ...[
          const SizedBox(height: 6),
          _StatRow(label: 'GOAL', value: _goalState!.goalLabel),
        ],
        if (ready && velocityKg != null) ...[
          const SizedBox(height: 6),
          // Velocity is muted and tap-to-reveal: the rate is data, never a
          // headline, and never coloured good/bad (body-neutral).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _showVelocity = !_showVelocity),
            child: _StatRow(
              label: 'TREND',
              value: _showVelocity ? _velocityLabel(velocityKg) : 'tap to show',
            ),
          ),
        ],
        const SizedBox(height: 24),
        PixelButton(
          label: 'VIEW LOG',
          onPressed: () async {
            await Navigator.push(
              context,
              arcadeRoute(
                (_) => const BodyMetricsHistoryPage(),
                motion: ArcadeRouteMotion.fade,
              ),
            );
            _load();
          },
        ),
      ],
    );
  }

  String _velocityLabel(double velocityKg) {
    final v = kgToDisplay(velocityKg, Units.weight);
    return '${v.toStringAsFixed(1)} ${Units.weight.label}/wk';
  }

  Widget _buildChart(bool ready) {
    if (_entries.length < 2) {
      return Center(
        child: Text(
          'LOG A FEW MORE CHECK-INS\nTO SEE YOUR TREND',
          textAlign: TextAlign.center,
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
        ),
      );
    }

    // Plot in the active unit; storage stays kg.
    final unit = Units.weight;
    final interval = unit == WeightUnit.kg ? 2.0 : 5.0;
    double conv(double kg) => kgToDisplay(kg, unit);

    final origin = _entries.first.loggedAt;
    double dx(DateTime t) => t.difference(origin).inMinutes / 1440.0;

    final rawSpots = [
      for (final e in _entries) FlSpot(dx(e.loggedAt), conv(e.weightKg)),
    ];
    final trendSpots = [
      for (final p in computeTrend(_entries)) FlSpot(dx(p.at), conv(p.trendKg)),
    ];

    final ys = <double>[
      for (final s in rawSpots) s.y,
      if (ready) for (final s in trendSpots) s.y,
    ];
    final minWeight = ys.reduce((a, b) => a < b ? a : b) - interval;
    final maxWeight = ys.reduce((a, b) => a > b ? a : b) + interval;

    final spanDays = dx(_entries.last.loggedAt);
    // ~3 date ticks across the span, regardless of how many entries.
    final bottomInterval = spanDays <= 0 ? 1.0 : (spanDays / 3).ceilToDouble();
    final dotColor = ready ? kMutedText : kNeon;

    return LineChart(
      LineChartData(
        minY: minWeight,
        maxY: maxWeight,
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: kBorder, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: bottomInterval,
              getTitlesWidget: (value, _) {
                final date = origin.add(Duration(days: value.round()));
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${date.month}/${date.day}',
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 9,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // Raw weigh-ins: faint dots. The connecting line is hidden once the
          // smoothed trend takes over as the hero (barWidth 0).
          LineChartBarData(
            spots: rawSpots,
            isCurved: false,
            color: dotColor,
            barWidth: ready ? 0.0 : 2.0,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: ready ? 2.0 : 3.0,
                color: dotColor,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(show: false),
          ),
          // Smoothed trend line (the hero) — only once there is enough data.
          if (ready)
            LineChartBarData(
              spots: trendSpots,
              isCurved: true,
              color: kNeon,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (_goalState?.targetWeight != null)
              HorizontalLine(
                y: conv(_goalState!.targetWeight!),
                color: kMutedText,
                strokeWidth: 1,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: AppFonts.shareTechMono(color: kMutedText, fontSize: 9),
                  labelResolver: (_) =>
                      'TARGET · ${formatWeight(_goalState!.targetWeight!, unit)}',
                ),
              ),
          ],
        ),
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
        Text(
          label,
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
        ),
        Text(
          value,
          style: AppFonts.shareTechMono(
            color: kText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
