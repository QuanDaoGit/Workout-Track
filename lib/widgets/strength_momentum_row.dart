import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/unit_models.dart';
import '../services/strength_trend_service.dart';
import '../services/unit_settings_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'motion/hold_depress.dart';

/// One lift's strength momentum — the shared row for the muscle dossier and the
/// "all lifts" roster, so the two surfaces can never drift. Leads with a **plain
/// verdict** (no "e1RM" jargon) + a recent signed delta; the estimated max is
/// labelled an estimate, never a "best"/record. Body-neutral: the down state
/// (`REBUILDING`) is named kindly and never coloured as danger. Tap → the full
/// [ExerciseHistoryPage] trend (caller owns the push).
class StrengthMomentumRow extends StatelessWidget {
  const StrengthMomentumRow({
    super.key,
    required this.trend,
    required this.onTap,
  });

  final StrengthTrend trend;
  final VoidCallback onTap;

  static (String, Color) _verdict(StrengthMomentum m) => switch (m) {
    StrengthMomentum.newBest => ('NEW BEST', kAmber),
    StrengthMomentum.rising => ('ON THE RISE', kNeon),
    StrengthMomentum.holding => ('HOLDING', kMutedText),
    StrengthMomentum.rebuilding => ('REBUILDING', kMutedText),
    StrengthMomentum.fresh => ('', kMutedText),
  };

  String get _estMax =>
      '${weightValue(trend.lastE1rm, Units.weight)} ${Units.weight.label}';

  String? get _deltaLabel {
    final d = trend.deltaVsPrevious;
    if (d.abs() < 0.05) return null;
    final mag = weightValue(d.abs(), Units.weight);
    return '${d > 0 ? '+' : '−'}$mag ${Units.weight.label} vs last';
  }

  @override
  Widget build(BuildContext context) {
    final fresh = trend.momentum == StrengthMomentum.fresh;
    final (word, color) = _verdict(trend.momentum);
    final delta = _deltaLabel;

    final semantics = fresh
        ? '${trend.exerciseName}, one session, save once more for a trend'
        : '${trend.exerciseName}, $word, estimated max $_estMax'
              '${delta == null ? '' : ', $delta'}';

    return Semantics(
      label: semantics,
      button: true,
      excludeSemantics: true,
      child: HoldDepress(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace3,
            vertical: kSpace3,
          ),
          decoration: BoxDecoration(
            color: kSurface2,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trend.exerciseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.shareTechMono(
                        color: kText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (fresh)
                      Text(
                        '1 session · save once more for a trend',
                        style: AppFonts.shareTechMono(
                          color: kMutedText,
                          fontSize: 11,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Text(
                            word,
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 8,
                              letterSpacing: 0.5,
                              color: color,
                            ),
                          ),
                          if (delta != null) ...[
                            const SizedBox(width: kSpace2),
                            Flexible(
                              child: Text(
                                delta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.shareTechMono(
                                  color: kMutedText,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: kSpace2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _estMax,
                    style: AppFonts.shareTechMono(color: kText, fontSize: 13),
                  ),
                  Text(
                    'est. max',
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              if (trend.hasTrend) ...[
                const SizedBox(width: kSpace2),
                SizedBox(
                  width: 56,
                  height: 28,
                  child: _Spark(points: trend.e1rmPoints, color: color),
                ),
              ],
              const Icon(Icons.chevron_right_sharp, size: 16, color: kMutedText),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal verdict-coloured sparkline — no axes/dots; "is the line moving".
class _Spark extends StatelessWidget {
  const _Spark({required this.points, required this.color});
  final List<double> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxY = points.fold<double>(0, max);
    final minY = points.fold<double>(maxY, min);
    final range = max(1.0, maxY - minY);
    return LineChart(
      LineChartData(
        minY: minY - range * 0.15,
        maxY: maxY + range * 0.15,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i]),
            ],
            isCurved: false,
            barWidth: 2,
            color: color == kMutedText ? kMutedText : color,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
