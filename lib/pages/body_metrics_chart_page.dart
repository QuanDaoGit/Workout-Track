import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../models/body_goal_models.dart';
import '../models/body_metrics_models.dart';
import '../services/body_goal_service.dart';
import '../services/body_metrics_service.dart';
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
              child: Text(
                'NO ENTRIES YET',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final first = _entries.first.loggedAt;
    final last = _entries.last.loggedAt;
    final weekSpan = last.difference(first).inDays ~/ 7;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        // Chart
        SizedBox(height: 240, child: _buildChart()),
        const SizedBox(height: 24),

        // Stats
        _StatRow(label: 'TOTAL ENTRIES', value: '${_entries.length}'),
        const SizedBox(height: 6),
        _StatRow(label: 'TIME SPAN', value: '$weekSpan WEEKS'),
        if (_goalState != null) ...[
          const SizedBox(height: 6),
          _StatRow(
            label: 'CURRENT GOAL',
            value:
                '${_goalState!.goalLabel} \u2192 ${_goalState!.futureClassName}',
          ),
        ],
        const SizedBox(height: 24),
        PixelButton(
          label: 'VIEW LOG',
          onPressed: () async {
            await Navigator.push(
              context,
              arcadeRoute((_) => const BodyMetricsHistoryPage()),
            );
            _load();
          },
        ),
      ],
    );
  }

  Widget _buildChart() {
    if (_entries.length < 2) {
      return Center(
        child: Text(
          'LOG AT LEAST 2 ENTRIES\nTO SEE A CHART',
          textAlign: TextAlign.center,
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
        ),
      );
    }

    final minWeight =
        _entries.map((e) => e.weightKg).reduce((a, b) => a < b ? a : b) - 2;
    final maxWeight =
        _entries.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b) + 2;
    final origin = _entries.first.loggedAt;

    final spots = _entries.map((e) {
      final x = e.loggedAt.difference(origin).inDays.toDouble();
      return FlSpot(x, e.weightKg);
    }).toList();

    return LineChart(
      LineChartData(
        minY: minWeight,
        maxY: maxWeight,
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: kBorder, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 2,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
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
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: kNeon,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) =>
                  FlDotCirclePainter(radius: 3, color: kNeon, strokeWidth: 0),
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (_goalState?.targetWeight != null)
              HorizontalLine(
                y: _goalState!.targetWeight!,
                color: kMutedText,
                strokeWidth: 1,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: AppFonts.shareTechMono(color: kMutedText, fontSize: 9),
                  labelResolver: (_) => 'TARGET (NO DATE)',
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
