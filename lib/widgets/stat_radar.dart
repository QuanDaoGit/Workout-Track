import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_fonts.dart';
import '../theme/tokens.dart';

class StatRadar extends StatelessWidget {
  const StatRadar({super.key, required this.stats});

  final Map<String, int> stats;

  static const _labels = ['STR', 'END', 'DEF', 'VIT', 'AGI'];
  static const _maxStatValue = 1000.0;
  static const _activationThreshold = 10;

  @override
  Widget build(BuildContext context) {
    final hasShape = _labels.any(
      (label) => (stats[label] ?? 0) >= _activationThreshold,
    );
    if (!hasShape) {
      return const _EmptyStatRadar();
    }

    final entries = [
      for (final label in _labels)
        RadarEntry(value: (stats[label] ?? 0).clamp(0, 1000).toDouble()),
    ];

    return SizedBox(
      height: 168,
      width: double.infinity,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          radarBackgroundColor: kBg.withValues(alpha: 0.35),
          radarBorderData: BorderSide(color: kBorder, width: 1),
          gridBorderData: BorderSide(color: kBorder.withValues(alpha: 0.7)),
          tickBorderData: BorderSide(color: kBorder.withValues(alpha: 0.35)),
          ticksTextStyle: const TextStyle(
            color: Colors.transparent,
            fontSize: 0,
          ),
          titleTextStyle: const TextStyle(
            fontFamily: 'PressStart2P',
            color: kMutedText,
            fontSize: 7,
          ),
          titlePositionPercentageOffset: 0.15,
          getTitle: (index, angle) => RadarChartTitle(
            text: _labels[index],
            angle: angle,
            positionPercentageOffset: 0.18,
          ),
          radarTouchData: RadarTouchData(enabled: false),
          dataSets: [
            RadarDataSet(
              dataEntries: const [
                RadarEntry(value: _maxStatValue),
                RadarEntry(value: _maxStatValue),
                RadarEntry(value: _maxStatValue),
                RadarEntry(value: _maxStatValue),
                RadarEntry(value: _maxStatValue),
              ],
              fillColor: Colors.transparent,
              borderColor: Colors.transparent,
              borderWidth: 0,
              entryRadius: 0,
            ),
            RadarDataSet(
              dataEntries: entries,
              fillColor: kNeon.withValues(alpha: 0.18),
              borderColor: kNeon,
              borderWidth: 2,
              entryRadius: 2.5,
            ),
          ],
        ),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

class _EmptyStatRadar extends StatelessWidget {
  const _EmptyStatRadar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      width: double.infinity,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _EmptyRadarPainter()),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _RadarAxisLabel('STR'),
          ),
          const Positioned(right: 40, top: 42, child: _RadarAxisLabel('END')),
          const Positioned(
            right: 50,
            bottom: 18,
            child: _RadarAxisLabel('DEF'),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _RadarAxisLabel('VIT'),
          ),
          const Positioned(left: 50, bottom: 18, child: _RadarAxisLabel('AGI')),
          Center(
            child: Text(
              'Train to shape your build',
              textAlign: TextAlign.center,
              style: AppFonts.shareTechMono(
                color: kMutedText,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarAxisLabel extends StatelessWidget {
  const _RadarAxisLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'PressStart2P',
        color: kMutedText,
        fontSize: 7,
      ),
    );
  }
}

class _EmptyRadarPainter extends CustomPainter {
  const _EmptyRadarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide * 0.34).clamp(42.0, 58.0);
    final points = List.generate(5, (index) {
      final angle = -pi / 2 + index * 2 * pi / 5;
      return Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
    });
    final paint = Paint()
      ..color = kBorder.withValues(alpha: 0.72)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var ring = 1; ring <= 4; ring++) {
      final t = ring / 4;
      final ringPoints = [
        for (final point in points) Offset.lerp(center, point, t) ?? center,
      ];
      _drawDottedPolygon(canvas, ringPoints, paint);
    }

    final axisPaint = Paint()
      ..color = kBorder.withValues(alpha: 0.32)
      ..strokeWidth = 1;
    for (final point in points) {
      canvas.drawLine(center, point, axisPaint);
    }
  }

  void _drawDottedPolygon(Canvas canvas, List<Offset> points, Paint paint) {
    for (var i = 0; i < points.length; i++) {
      final start = points[i];
      final end = points[(i + 1) % points.length];
      _drawDottedLine(canvas, start, end, paint);
    }
  }

  void _drawDottedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final distance = delta.distance;
    if (distance == 0) return;
    final direction = delta / distance;
    const dash = 3.0;
    const gap = 5.0;
    var progress = 0.0;
    while (progress < distance) {
      final segmentEnd = (progress + dash).clamp(0.0, distance);
      canvas.drawLine(
        start + direction * progress,
        start + direction * segmentEnd,
        paint,
      );
      progress += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _EmptyRadarPainter oldDelegate) => false;
}
