import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum ArcadeRouteMotion { panel, flow, reveal, fade }

Route<T> arcadeRoute<T>(
  WidgetBuilder builder, {
  ArcadeRouteMotion motion = ArcadeRouteMotion.panel,
}) {
  final spec = _specFor(motion);
  return PageRouteBuilder<T>(
    transitionDuration: spec.forward,
    reverseTransitionDuration: spec.reverse,
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (reduceMotion) {
        return _fadeTransition(animation, child);
      }
      if (motion == ArcadeRouteMotion.fade) {
        return _phosphorDissolve(animation, child, spec);
      }
      return _crtSignalTransition(animation, child, spec);
    },
  );
}

_CrtRouteSpec _specFor(ArcadeRouteMotion motion) {
  return switch (motion) {
    ArcadeRouteMotion.panel => const _CrtRouteSpec(
      forward: Duration(milliseconds: 230),
      reverse: Duration(milliseconds: 170),
      accent: kNeon,
      bandCount: 16,
      tearCount: 3,
      sweepStrength: 0.24,
      edgeStrength: 0.18,
    ),
    ArcadeRouteMotion.flow => const _CrtRouteSpec(
      forward: Duration(milliseconds: 250),
      reverse: Duration(milliseconds: 180),
      accent: kCyan,
      bandCount: 18,
      tearCount: 3,
      sweepStrength: 0.26,
      edgeStrength: 0.20,
      driftPx: 8,
    ),
    ArcadeRouteMotion.reveal => const _CrtRouteSpec(
      forward: Duration(milliseconds: 320),
      reverse: Duration(milliseconds: 200),
      accent: kAmber,
      bandCount: 20,
      tearCount: 5,
      sweepStrength: 0.36,
      edgeStrength: 0.28,
      revealPulse: 1,
    ),
    ArcadeRouteMotion.fade => const _CrtRouteSpec(
      forward: Duration(milliseconds: 160),
      reverse: Duration(milliseconds: 160),
      accent: kNeon,
      bandCount: 0,
      tearCount: 0,
      sweepStrength: 0.08,
      edgeStrength: 0.08,
    ),
  };
}

Widget _crtSignalTransition(
  Animation<double> animation,
  Widget child,
  _CrtRouteSpec spec,
) {
  final curved = CurvedAnimation(parent: animation, curve: kMotionCurve);
  final opacity = Tween<double>(begin: 0.36, end: 1).animate(curved);
  return AnimatedBuilder(
    animation: curved,
    child: child,
    builder: (context, child) {
      final t = curved.value.clamp(0.0, 1.0).toDouble();
      final drift = spec.driftPx == 0 ? 0.0 : (1 - t) * spec.driftPx;
      return Stack(
        children: [
          Transform.translate(
            offset: Offset(drift, 0),
            child: FadeTransition(
              opacity: opacity,
              child: ClipPath(
                clipper: _SignalBandClipper(
                  progress: t,
                  bandCount: spec.bandCount,
                  centered: spec.driftPx == 0,
                ),
                child: child,
              ),
            ),
          ),
          _CrtSignalOverlay(animation: curved, spec: spec),
        ],
      );
    },
  );
}

Widget _phosphorDissolve(
  Animation<double> animation,
  Widget child,
  _CrtRouteSpec spec,
) {
  final curved = CurvedAnimation(parent: animation, curve: kMotionCurve);
  return Stack(
    children: [
      FadeTransition(opacity: curved, child: child),
      _CrtSignalOverlay(animation: curved, spec: spec),
    ],
  );
}

Widget _fadeTransition(Animation<double> animation, Widget child) {
  final curved = CurvedAnimation(parent: animation, curve: kMotionCurve);
  return FadeTransition(opacity: curved, child: child);
}

class _CrtSignalOverlay extends StatelessWidget {
  const _CrtSignalOverlay({required this.animation, required this.spec});

  final Animation<double> animation;
  final _CrtRouteSpec spec;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value.clamp(0.0, 1.0).toDouble();
          if (t <= 0 || t >= 1) return const SizedBox.shrink();
          return CustomPaint(
            painter: _CrtSignalPainter(progress: t, spec: spec),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _CrtSignalPainter extends CustomPainter {
  const _CrtSignalPainter({required this.progress, required this.spec});

  final double progress;
  final _CrtRouteSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final q = _quantized(progress);
    _drawEdgeBloom(canvas, size, q);
    _drawSweep(canvas, size, q);
    _drawSignalTears(canvas, size, q);
    if (spec.revealPulse > 0) {
      _drawRevealPulse(canvas, size, progress);
    }
  }

  void _drawEdgeBloom(Canvas canvas, Size size, double q) {
    final alpha = (math.sin(q * math.pi) * spec.edgeStrength).clamp(0.0, 1.0);
    if (alpha <= 0) return;

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = spec.accent.withValues(alpha: alpha);
    canvas.drawRect(Offset.zero & size, edgePaint);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = spec.accent.withValues(alpha: alpha * 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRect(Offset.zero & size, glowPaint);
  }

  void _drawSweep(Canvas canvas, Size size, double q) {
    final y = size.height * q;
    final strength = math.sin(q * math.pi).clamp(0.0, 1.0) * spec.sweepStrength;
    if (strength <= 0) return;

    final rect = Rect.fromLTWH(0, y - 28, size.width, 56);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          spec.accent.withValues(alpha: strength * 0.15),
          kNeon.withValues(alpha: strength),
          spec.accent.withValues(alpha: strength * 0.15),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    final linePaint = Paint()
      ..color = kNeon.withValues(alpha: strength * 0.72)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
  }

  void _drawSignalTears(Canvas canvas, Size size, double q) {
    if (spec.tearCount == 0) return;
    final window = math.sin(q * math.pi).clamp(0.0, 1.0);
    final paint = Paint();

    for (var i = 0; i < spec.tearCount; i++) {
      final seed = i + 1;
      final y = ((q * 1.35 + seed * 0.23) % 1.0) * size.height;
      final h = 2.0 + (seed % 3) * 2.0;
      final left = ((seed * 37) % 100) / 100 * size.width * 0.55;
      final width = size.width * (0.20 + (seed % 4) * 0.08);
      final alpha = window * (0.08 + seed * 0.018);
      final color = seed.isEven ? kCyan : kNeon;
      paint.color = color.withValues(alpha: alpha);
      canvas.drawRect(Rect.fromLTWH(left, y, width, h), paint);

      final offset = seed.isEven ? 8.0 : -6.0;
      paint.color = spec.accent.withValues(alpha: alpha * 0.55);
      canvas.drawRect(
        Rect.fromLTWH(left + offset, y + h + 2, width * 0.42, 1),
        paint,
      );
    }
  }

  void _drawRevealPulse(Canvas canvas, Size size, double t) {
    final pulse = (1 - ((t - 0.55).abs() / 0.22)).clamp(0.0, 1.0).toDouble();
    if (pulse <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final offsets = <Offset>[
      const Offset(-42, -18),
      const Offset(-24, 20),
      const Offset(8, -34),
      const Offset(30, 16),
      const Offset(48, -8),
      const Offset(-10, 42),
      const Offset(18, 36),
      const Offset(-54, 8),
    ];
    final paint = Paint()..color = kAmber.withValues(alpha: pulse * 0.48);
    for (var i = 0; i < offsets.length; i++) {
      final offset = offsets[i] * (0.7 + pulse * 0.55);
      final sizePx = i.isEven ? 3.0 : 2.0;
      canvas.drawRect(
        Rect.fromCenter(center: center + offset, width: sizePx, height: sizePx),
        paint,
      );
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = kAmber.withValues(alpha: pulse * 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, 54 + pulse * 18, glowPaint);
  }

  double _quantized(double t) {
    const frames = 12.0;
    return (t * frames).floorToDouble() / frames;
  }

  @override
  bool shouldRepaint(covariant _CrtSignalPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.spec != spec;
}

class _SignalBandClipper extends CustomClipper<Path> {
  const _SignalBandClipper({
    required this.progress,
    required this.bandCount,
    required this.centered,
  });

  final double progress;
  final int bandCount;
  final bool centered;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (progress >= 0.985 || bandCount <= 0) {
      path.addRect(Offset.zero & size);
      return path;
    }

    final bandHeight = size.height / bandCount;
    for (var i = 0; i < bandCount; i++) {
      final stagger = ((i % 4) * 0.035) + (i / bandCount) * 0.055;
      final bandT = ((progress - stagger) / (1 - stagger))
          .clamp(0.0, 1.0)
          .toDouble();
      if (bandT <= 0) continue;

      final width = size.width * bandT;
      final top = i * bandHeight;
      final height = bandHeight + 1;
      final left = centered ? (size.width - width) / 2 : 0.0;
      path.addRect(Rect.fromLTWH(left, top, width, height));
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _SignalBandClipper oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.bandCount != bandCount ||
      oldClipper.centered != centered;
}

class _CrtRouteSpec {
  const _CrtRouteSpec({
    required this.forward,
    required this.reverse,
    required this.accent,
    required this.bandCount,
    required this.tearCount,
    required this.sweepStrength,
    required this.edgeStrength,
    this.driftPx = 0,
    this.revealPulse = 0,
  });

  final Duration forward;
  final Duration reverse;
  final Color accent;
  final int bandCount;
  final int tearCount;
  final double sweepStrength;
  final double edgeStrength;
  final double driftPx;
  final double revealPulse;
}
