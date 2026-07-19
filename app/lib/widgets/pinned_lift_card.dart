import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../models/unit_models.dart';
import '../services/haptic_service.dart';
import '../services/strength_trend_service.dart';
import '../services/unit_settings_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import '../services/ui_sound.dart';
import 'lift_icon.dart';
import 'motion/hold_depress.dart';

/// A user-pinned "anchor lift" — the ONE rich surface in the strength roster.
/// Where the rows are stripped to a glyph + number, the pinned card keeps the
/// full read: the lift icon, the verdict **word** + signed delta, a neutral
/// "trained N× · last …" mastery line, the big est-max, and a sparkline with an
/// amber PR marker. Cyan accent (its own role, distinct from amber=reward /
/// neon=action). Tap → the detail chart; the pin icon unpins (also a custom
/// Semantics action so switch / screen-reader users can unpin without the icon).
class PinnedLiftCard extends StatelessWidget {
  const PinnedLiftCard({
    super.key,
    required this.trend,
    required this.onTap,
    required this.onUnpin,
  });

  final StrengthTrend trend;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  static (String, Color) _verdict(StrengthMomentum m) => switch (m) {
    StrengthMomentum.newBest => ('NEW BEST', kAmber),
    StrengthMomentum.rising => ('ON THE RISE', kNeon),
    StrengthMomentum.holding => ('HOLDING', kMutedText),
    StrengthMomentum.rebuilding => ('REBUILDING', kMutedText),
    StrengthMomentum.fresh => ('1 SESSION', kMutedText),
  };

  String get _estMax => weightValue(trend.lastE1rm, Units.weight);

  String? get _delta {
    if (trend.momentum == StrengthMomentum.fresh) return null;
    final d = trend.deltaVsPrevious;
    if (d.abs() < 0.05) return null;
    final mag = weightValue(d.abs(), Units.weight);
    return '${d > 0 ? '+' : '−'}$mag ${Units.weight.label} vs last';
  }

  @override
  Widget build(BuildContext context) {
    final (word, color) = _verdict(trend.momentum);
    final delta = _delta;
    final lastDate =
        '${trend.lastDate.year}-${trend.lastDate.month.toString().padLeft(2, '0')}-${trend.lastDate.day.toString().padLeft(2, '0')}';

    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          'Pinned: ${trend.exerciseName}, $word, estimated max $_estMax '
          '${Units.weight.label}${delta == null ? '' : ', $delta'}. '
          'Tap for history.',
      customSemanticsActions: {
        CustomSemanticsAction(label: 'Unpin ${trend.exerciseName}'): onUnpin,
      },
      // Long-press mirrors the roster row: hold a row to PIN, hold the card to
      // UNPIN (the pin icon is the explicit affordance; this keeps the gesture
      // symmetric so the pin gesture isn't a one-way street).
      child: GestureDetector(
        onLongPress: onUnpin,
        child: HoldDepress(
          onTap: onTap,
          haptic: HapticIntent.selection,
          sound: UiSound.tick,
          borderRadius: BorderRadius.circular(kCardRadius),
        child: Container(
          padding: const EdgeInsets.all(kSpace3),
          decoration: BoxDecoration(
            color: kCard,
            border: Border.all(
              color: kCyan.withValues(alpha: 0.55),
              width: 1.4,
            ),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kSurface3,
                      border: Border.all(color: kBorder),
                      borderRadius: BorderRadius.circular(kCardRadius),
                    ),
                    child: LiftIcon(exerciseName: trend.exerciseName, size: 40),
                  ),
                  const SizedBox(width: kSpace3),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'trained ${trend.sessionCount}× · last $lastDate',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.shareTechMono(
                            color: kDim,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              word,
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 8,
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
                      GestureDetector(
                        onTap: onUnpin,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.only(bottom: kSpace1, left: kSpace2),
                          child: Icon(
                            Icons.push_pin_sharp,
                            size: 18,
                            color: kCyan,
                          ),
                        ),
                      ),
                      Text(
                        _estMax,
                        style: AppFonts.shareTechMono(color: kText, fontSize: 24),
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
                ],
              ),
              if (trend.hasTrend) ...[
                const SizedBox(height: kSpace3),
                SizedBox(
                  height: 36,
                  child: _PinnedSpark(points: trend.e1rmPoints, color: color),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}

/// The pinned card's sparkline — like the row's, but it marks the **peak** point
/// with an amber PR dot (the rest of the line stays the verdict colour).
class _PinnedSpark extends StatelessWidget {
  const _PinnedSpark({required this.points, required this.color});

  final List<double> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxY = points.fold<double>(points.first, max);
    final minY = points.fold<double>(points.first, min);
    final range = max(1.0, maxY - minY);
    return LineChart(
      LineChartData(
        minY: minY - range * 0.18,
        maxY: maxY + range * 0.18,
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
            color: color,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, _) => spot.y >= maxY - 1e-6,
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: 3,
                color: kAmber,
                strokeWidth: 0,
                strokeColor: kAmber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
