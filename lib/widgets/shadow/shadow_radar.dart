import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/shadow_models.dart';
import '../../theme/tokens.dart';

/// Dual-polygon contest radar for the Shadow detail view.
///
/// Challenge-relative scale: the Shadow polygon is the fixed reference ring
/// (every axis at the same radius — it IS the baseline), and the user's
/// polygon is drawn per-axis at `referenceRadius × ratio` (clamped), so being
/// behind/ahead is visible as the user's shape dipping inside / pushing past
/// the ring. Deliberately NOT the profile radar's rank-band scale — this view
/// answers "am I keeping pace with my past month", not "what rank am I".
/// Forming axes draw on the ring (neutral), never inside it.
class ShadowRadar extends StatelessWidget {
  const ShadowRadar({super.key, required this.axes, this.height = 188});

  final List<ShadowAxisRead> axes;
  final double height;

  static const _labelInset = 26.0;
  // Shadow reference ring fraction of the full radius; user ratio clamp keeps
  // a PR week from exploding the polygon past the labels.
  static const _referenceFraction = 0.62;
  static const _minRatio = 0.25;
  static const _maxRatio = 1.45;

  static const _labelOffsets = <Offset>[
    Offset(0, -12),
    Offset(13, 13),
    Offset(-13, 13),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final center = Offset(size.width / 2, size.height / 2);
          final radius = min(size.width, size.height) / 2 - _labelInset;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ShadowRadarPainter(
                    axes: axes,
                    center: center,
                    radius: radius,
                  ),
                ),
              ),
              for (var i = 0; i < axes.length && i < 3; i++)
                Positioned(
                  left: (_vertex(center, radius, i) + _labelOffsets[i]).dx,
                  top: (_vertex(center, radius, i) + _labelOffsets[i]).dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: Text(
                      axes[i].axis,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 7,
                        color: axes[i].state == ShadowAxisState.behind
                            ? kDanger
                            : kMutedText,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static Offset _vertex(Offset center, double radius, int i) {
    final angle = -pi / 2 + i * 2 * pi / 3;
    return Offset(
      center.dx + cos(angle) * radius,
      center.dy + sin(angle) * radius,
    );
  }
}

class _ShadowRadarPainter extends CustomPainter {
  const _ShadowRadarPainter({
    required this.axes,
    required this.center,
    required this.radius,
  });

  final List<ShadowAxisRead> axes;
  final Offset center;
  final double radius;

  Offset _vertex(double r, int i) {
    final angle = -pi / 2 + i * 2 * pi / 3;
    return Offset(center.dx + cos(angle) * r, center.dy + sin(angle) * r);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0 || axes.length < 3) return;

    final reference = radius * ShadowRadar._referenceFraction;
    final outer = [for (var i = 0; i < 3; i++) _vertex(radius, i)];

    // Background + outer border + spokes (matches the profile radar idiom).
    canvas.drawPath(
      _polygonPath(outer),
      Paint()
        ..color = kBg.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      _polygonPath(outer),
      Paint()
        ..color = kBorder
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    final spokePaint = Paint()
      ..color = kBorder.withValues(alpha: 0.32)
      ..strokeWidth = 1;
    for (final p in outer) {
      canvas.drawLine(center, p, spokePaint);
    }

    // The Shadow: dashed spectral reference ring.
    final shadowPoints = [for (var i = 0; i < 3; i++) _vertex(reference, i)];
    final shadowPaint = Paint()
      ..color = kCyan.withValues(alpha: 0.85)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    _drawDashedPolygon(canvas, shadowPoints, shadowPaint);
    canvas.drawPath(
      _polygonPath(shadowPoints),
      Paint()
        ..color = kCyan.withValues(alpha: 0.07)
        ..style = PaintingStyle.fill,
    );

    // You: solid neon polygon, per-axis ratio against the reference ring.
    final userPoints = <Offset>[];
    for (var i = 0; i < 3; i++) {
      final read = axes[i];
      final ratio = read.state == ShadowAxisState.forming
          ? 1.0
          : (read.ratio ?? 1.0).clamp(
              ShadowRadar._minRatio,
              ShadowRadar._maxRatio,
            );
      userPoints.add(_vertex(reference * ratio, i));
    }
    final userPath = _polygonPath(userPoints);
    canvas
      ..drawPath(
        userPath,
        Paint()
          ..color = kNeon.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      )
      ..drawPath(
        userPath,
        Paint()
          ..color = kNeon
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

    // Gap encoding: a danger tick along the spoke from your vertex to the
    // ring on axes the Shadow leads.
    final gapPaint = Paint()
      ..color = kDanger.withValues(alpha: 0.9)
      ..strokeWidth = 2;
    for (var i = 0; i < 3; i++) {
      if (axes[i].state != ShadowAxisState.behind) continue;
      canvas.drawLine(userPoints[i], shadowPoints[i], gapPaint);
    }

    final dotPaint = Paint()
      ..color = kNeon
      ..style = PaintingStyle.fill;
    for (final p in userPoints) {
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

  void _drawDashedPolygon(Canvas canvas, List<Offset> points, Paint paint) {
    for (var i = 0; i < points.length; i++) {
      final start = points[i];
      final end = points[(i + 1) % points.length];
      final delta = end - start;
      final distance = delta.distance;
      if (distance == 0) continue;
      final direction = delta / distance;
      const dash = 4.0;
      const gap = 4.0;
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
  }

  @override
  bool shouldRepaint(covariant _ShadowRadarPainter old) =>
      old.center != center || old.radius != radius || old.axes != axes;
}
