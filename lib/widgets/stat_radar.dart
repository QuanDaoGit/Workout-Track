import 'dart:math';

import 'package:flutter/material.dart';

import '../models/stat_radar_read.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';

/// Character-stats radar: a hand-drawn triangle for STR / AGI / END.
///
/// Drawn entirely in code (one [CustomPainter]) — no chart library and no image
/// assets. Grid, data polygon, and axis labels share one geometry so the labels
/// always anchor to the real vertices, and the data shape is scaled by the
/// rank-band curve ([rankBandFraction]) rather than a chart library's relative
/// min/max normalization.
class StatRadar extends StatelessWidget {
  const StatRadar({super.key, required this.stats, this.height = 188});

  final Map<String, int> stats;
  final double height;

  // Triangle: STR / AGI / END only. DEF retired from visible UI; VIT renders as
  // a separate horizontal bar in the stat card.
  static const _labels = StatRadarRead.visibleStats;
  static const _activationThreshold = 10;

  // Radius headroom reserved for the axis labels.
  static const double _labelInset = 26;

  // Per-axis label offset from each vertex (x → right, y → down). STR lifts
  // straight up; the two bottom labels push diagonally down-and-out so they
  // clear the triangle's base instead of sliding sideways.
  static const _labelOffsets = <Offset>[
    Offset(0, -12), // STR (top)
    Offset(13, 13), // AGI (bottom-right) — 45° down-right
    Offset(-13, 13), // END (bottom-left) — 45° down-left
  ];

  static Offset _vertex(Offset center, double radius, int i) {
    final angle = -pi / 2 + i * 2 * pi / 3;
    return Offset(
      center.dx + cos(angle) * radius,
      center.dy + sin(angle) * radius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasShape = _labels.any(
      (label) => (stats[label] ?? 0) >= _activationThreshold,
    );
    final dominant = StatRadarRead.dominantAxis(stats);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final center = Offset(size.width / 2, size.height / 2);
          final radius = min(size.width, size.height) / 2 - _labelInset;
          final labelPoints = [
            for (var i = 0; i < _labels.length; i++)
              _vertex(center, radius, i) + _labelOffsets[i],
          ];

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RadarPainter(
                    stats: stats,
                    center: center,
                    radius: radius,
                    hasShape: hasShape,
                  ),
                ),
              ),
              if (!hasShape)
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
              for (var i = 0; i < _labels.length; i++)
                Positioned(
                  left: labelPoints[i].dx,
                  top: labelPoints[i].dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: _RadarAxisLabel(
                      _labels[i],
                      highlighted: dominant == _labels[i],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.stats,
    required this.center,
    required this.radius,
    required this.hasShape,
  });

  final Map<String, int> stats;
  final Offset center;
  final double radius;
  final bool hasShape;

  static const _labels = StatRadarRead.visibleStats;

  Offset _vertex(double r, int i) {
    final angle = -pi / 2 + i * 2 * pi / 3;
    return Offset(center.dx + cos(angle) * r, center.dy + sin(angle) * r);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;

    final outer = [for (var i = 0; i < 3; i++) _vertex(radius, i)];

    // Translucent background polygon.
    canvas.drawPath(
      _polygonPath(outer),
      Paint()
        ..color = kBg.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill,
    );

    // Dotted rank rings at 1/5 .. 4/5 of the radius (the D/C, C/B, B/A, A/S
    // promotion boundaries).
    final ringPaint = Paint()
      ..color = kBorder.withValues(alpha: 0.72)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var ring = 1; ring <= 4; ring++) {
      final t = ring / 5;
      final pts = [for (var i = 0; i < 3; i++) _vertex(radius * t, i)];
      _drawDottedPolygon(canvas, pts, ringPaint);
    }

    // Outer border ring (solid, slightly stronger).
    canvas.drawPath(
      _polygonPath(outer),
      Paint()
        ..color = kBorder
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // Axis spokes.
    final spokePaint = Paint()
      ..color = kBorder.withValues(alpha: 0.32)
      ..strokeWidth = 1;
    for (final p in outer) {
      canvas.drawLine(center, p, spokePaint);
    }

    if (!hasShape) return;

    // Data polygon, scaled by the rank-band curve.
    final dataPoints = [
      for (var i = 0; i < 3; i++)
        _vertex(
          radius * StatRadarRead.rankBandFraction(stats[_labels[i]] ?? 0),
          i,
        ),
    ];
    final path = _polygonPath(dataPoints);
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = kNeon.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      )
      ..drawPath(
        path,
        Paint()
          ..color = kNeon
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

    final dotPaint = Paint()
      ..color = kNeon
      ..style = PaintingStyle.fill;
    for (final p in dataPoints) {
      canvas.drawCircle(p, 2.5, dotPaint);
    }
  }

  Path _polygonPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  void _drawDottedPolygon(Canvas canvas, List<Offset> points, Paint paint) {
    for (var i = 0; i < points.length; i++) {
      _drawDottedLine(
        canvas,
        points[i],
        points[(i + 1) % points.length],
        paint,
      );
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
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.hasShape != hasShape ||
      old.center != center ||
      old.radius != radius ||
      !_sameStats(old.stats);

  bool _sameStats(Map<String, int> other) {
    for (final label in _labels) {
      if ((other[label] ?? 0) != (stats[label] ?? 0)) return false;
    }
    return true;
  }
}

class _RadarAxisLabel extends StatelessWidget {
  const _RadarAxisLabel(this.label, {this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? kNeon : kMutedText;
    return Semantics(
      label: highlighted ? '$label dominant stat axis' : '$label stat axis',
      child: Text(
        key: ValueKey(
          highlighted
              ? 'stat_radar_axis_${label}_dominant'
              : 'stat_radar_axis_${label}_normal',
        ),
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'PressStart2P',
          color: color,
          fontSize: highlighted ? 8 : 7,
        ),
      ),
    );
  }
}
