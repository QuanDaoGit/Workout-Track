import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class WelcomeBenchPressScene extends StatefulWidget {
  const WelcomeBenchPressScene({
    super.key,
    this.width = 256,
    this.height = 192,
  });

  final double width;
  final double height;

  @override
  State<WelcomeBenchPressScene> createState() => _WelcomeBenchPressSceneState();
}

class _WelcomeBenchPressSceneState extends State<WelcomeBenchPressScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableMotion = MediaQuery.of(context).disableAnimations;
    if (disableMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _BenchPressPainter(
              progress: disableMotion ? 0 : _controller.value,
              reducedMotion: disableMotion,
            ),
          );
        },
      ),
    );
  }
}

class _BenchPressPainter extends CustomPainter {
  const _BenchPressPainter({
    required this.progress,
    required this.reducedMotion,
  });

  final double progress;
  final bool reducedMotion;

  static const _gridWidth = 64.0;
  static const _gridHeight = 48.0;
  static const _repSeconds = 1.4;
  static const _loopSeconds = 6.3;

  static const _body = Color(0xFF2A2A4A);
  static const _bar = Color(0xFF9090A8);
  static const _barShade = Color(0xFF5C5C72);
  static const _plateDark = Color(0xFF13132A);
  static const _benchTop = Color(0xFF3A3A5A);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / _gridWidth, size.height / _gridHeight);
    canvas
      ..save()
      ..translate(
        (size.width - _gridWidth * scale) / 2,
        (size.height - _gridHeight * scale) / 2,
      )
      ..scale(scale);

    final pose = reducedMotion ? _Pose.lockout : _poseForProgress(progress);
    final strain = reducedMotion ? 0.0 : _strainForProgress(progress);
    final flash = reducedMotion ? 0.0 : _barFlashForProgress(progress);
    final finishPulse = reducedMotion ? 0.0 : _finishPulseForProgress(progress);
    final payoff = reducedMotion ? 0.0 : _payoffForProgress(progress);
    final liftGlow = reducedMotion ? 0.0 : _liftGlowForProgress(progress);
    final glowPulse = 0.24 + liftGlow * 0.22 + finishPulse * 0.42;

    _drawGlow(canvas, glowPulse);
    _drawRack(canvas);
    _drawBench(canvas);
    _drawLifter(canvas, pose, strain);
    _drawArmAndBar(canvas, pose, flash, strain);
    if (strain > 0.1) _drawPressLines(canvas, strain);
    if (finishPulse > 0) _drawVictoryPixels(canvas, finishPulse);
    if (payoff > 0) _drawLevelPayoff(canvas, payoff);

    canvas.restore();
  }

  void _drawGlow(Canvas canvas, double opacity) {
    final paint = Paint()
      ..color = kNeon.withValues(alpha: opacity * 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(33, 24), width: 38, height: 24),
      paint,
    );
  }

  _Pose _poseForProgress(double progress) {
    final t = progress * _loopSeconds;
    if (t >= 5.6) return _Pose.lockout;

    final repT = t - math.min(3, (t / _repSeconds).floor()) * _repSeconds;
    if (repT < 0.10) return _Pose.lockout;
    if (repT < 0.41) return _Pose.mid;
    if (repT < 0.70) return _Pose.bottom;
    if (repT < 0.89) return _Pose.strain;
    if (repT < 1.01) return _Pose.mid;
    return _Pose.lockout;
  }

  double _strainForProgress(double progress) {
    final t = progress * _loopSeconds;
    if (t >= 5.6) return 0;
    final repT = t - math.min(3, (t / _repSeconds).floor()) * _repSeconds;
    if (repT < 0.48 || repT > 1.01) return 0;
    if (repT < 0.70) return ((repT - 0.48) / 0.22).clamp(0.0, 0.7).toDouble();
    if (repT < 0.89) return 1;
    return (1 - (repT - 0.89) / 0.12).clamp(0.0, 1.0).toDouble();
  }

  double _liftGlowForProgress(double progress) {
    final t = progress * _loopSeconds;
    if (t >= 5.6) return 0;
    final repT = t - math.min(3, (t / _repSeconds).floor()) * _repSeconds;
    if (repT < 0.70 || repT > 1.13) return 0;
    final local = ((repT - 0.70) / 0.43).clamp(0.0, 1.0).toDouble();
    return math.sin(local * math.pi).clamp(0.0, 1.0).toDouble();
  }

  double _barFlashForProgress(double progress) {
    final t = progress * _loopSeconds;
    if (t >= 5.6) return 0;
    final repIndex = math.min(3, (t / _repSeconds).floor());
    final repT = t - repIndex * _repSeconds;
    if (repIndex != 3 || repT < 1.13) return 0;

    final flashT = repT - 1.13;
    var pulse = 0.0;
    for (final phase in const [0.05, 0.15, 0.24]) {
      final distance = (flashT - phase).abs();
      if (distance < 0.04) pulse = math.max(pulse, 1 - distance / 0.04);
    }
    return pulse * 0.5;
  }

  double _finishPulseForProgress(double progress) {
    final t = progress * _loopSeconds;
    if (t < 5.6 || t > 5.9) return 0;
    final local = (t - 5.6) / 0.3;
    return math.sin(local * math.pi).clamp(0.0, 1.0).toDouble();
  }

  double _payoffForProgress(double progress) {
    final t = progress * _loopSeconds;
    if (t < 5.6 || t > 5.9) return 0;
    final local = (t - 5.6) / 0.3;
    if (local < 0.22) return (local / 0.22).clamp(0.0, 1.0).toDouble();
    return (1 - (local - 0.22) / 0.78).clamp(0.0, 1.0).toDouble();
  }

  void _rect(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
  }

  void _line(
    Canvas canvas,
    double x1,
    double y1,
    double x2,
    double y2,
    Color color,
  ) {
    final steps = math.max((x2 - x1).abs(), (y2 - y1).abs()).round();
    for (var i = 0; i <= steps; i++) {
      final t = steps == 0 ? 0.0 : i / steps;
      final x = (x1 + (x2 - x1) * t).roundToDouble();
      final y = (y1 + (y2 - y1) * t).roundToDouble();
      _rect(canvas, x, y, 2, 1, color);
    }
  }

  void _drawRack(Canvas canvas) {
    _rect(canvas, 58, 4, 2, 28, _body);
    _rect(canvas, 54, 4, 4, 2, _body);
  }

  void _drawBench(Canvas canvas) {
    _rect(canvas, 8, 30, 44, 2, _body);
    _rect(canvas, 8, 30, 44, 1, _benchTop);
    _rect(canvas, 12, 32, 2, 12, _body);
    _rect(canvas, 46, 32, 2, 12, _body);
    _rect(canvas, 10, 43, 6, 1, _body);
    _rect(canvas, 44, 43, 6, 1, _body);
  }

  void _drawLifter(Canvas canvas, _Pose pose, double strain) {
    final compression = pose == _Pose.bottom || pose == _Pose.strain
        ? strain
        : 0.0;
    final headY = 26 + compression;
    final torsoY = 28 + compression * 0.5;

    _rect(canvas, 10, 34, 6, 2, _body);
    _rect(canvas, 10, 36, 2, 6, _body);
    _rect(canvas, 8, 42, 6, 2, _body);
    _rect(canvas, 8, 41, 1, 1, kNeon);
    _rect(canvas, 8, 42, 1, 2, kNeon);

    _rect(canvas, 16, 30 + compression * 0.3, 12, 2, _body);
    _rect(canvas, 16, 32 + compression * 0.3, 4, 1, _body);
    _rect(canvas, 16, 29 + compression * 0.3, 12, 1, kNeon);

    _rect(canvas, 28, torsoY, 12, 4, _body);
    _rect(canvas, 28, torsoY - 1, 12, 1, kNeon);
    _rect(canvas, 28, torsoY + 4, 12, 1, _body);

    _rect(canvas, 40, 30 + compression * 0.5, 2, 2, _body);
    _rect(canvas, 40, headY, 6, 5, _body);
    _rect(canvas, 40, headY - 1, 6, 1, kNeon);
    _rect(canvas, 46, headY, 1, 5, kNeon);
    _rect(canvas, 44, headY + 1, 1, 1, kText);
    _rect(canvas, 44, headY + 3, 1, 1, const Color(0xFF111118));
  }

  void _drawArmAndBar(Canvas canvas, _Pose pose, double flash, double strain) {
    final bar = switch (pose) {
      _Pose.lockout => (y: 8.0, centerX: 34.0),
      _Pose.mid => (y: 16.0, centerX: 34.0),
      _Pose.bottom => (y: 24.0, centerX: 34.0),
      _Pose.strain => (y: 25.0, centerX: 34.0),
      _Pose.racked => (y: 8.0, centerX: 54.0),
    };

    final gripX = bar.centerX;
    const shoulderX = 32.0;
    const shoulderY = 28.0;

    switch (pose) {
      case _Pose.lockout:
        _line(canvas, gripX, bar.y + 2, shoulderX, shoulderY, _body);
        _rect(
          canvas,
          gripX - 1,
          bar.y + 2,
          1,
          shoulderY - (bar.y + 2) + 1,
          kNeon,
        );
      case _Pose.mid:
        _line(canvas, shoulderX, shoulderY, 33, 23, _body);
        _line(canvas, 33, 23, gripX, bar.y + 2, _body);
      case _Pose.bottom:
        _line(canvas, shoulderX, shoulderY, 33, 26, _body);
        _line(canvas, 33, 26, gripX, bar.y + 2, _body);
      case _Pose.strain:
        _line(canvas, shoulderX, shoulderY, 32, 27, _body);
        _line(canvas, 32, 27, gripX, bar.y + 2, _body);
        _rect(canvas, 31, 27, 2, 1, kNeon.withValues(alpha: 0.7));
      case _Pose.racked:
        _rect(canvas, 34, 26, 2, 4, _body);
        _rect(canvas, 33, 26, 1, 4, kNeon);
    }

    _drawSideBarbell(canvas, gripX, bar.y, flash, strain);
  }

  void _drawSideBarbell(
    Canvas canvas,
    double gripX,
    double barY,
    double flash,
    double strain,
  ) {
    final edge = flash > 0.5 ? const Color(0xFFB8FFD8) : kNeon;
    final strainDrop = strain > 0.55 ? 1.0 : 0.0;
    final plateX = gripX - 4;
    final plateY = barY - 3 + strainDrop;

    _rect(canvas, gripX - 1, barY + 1 + strainDrop, 3, 2, _bar);
    _rect(canvas, gripX - 1, barY + 3 + strainDrop, 3, 1, _barShade);

    _rect(canvas, plateX + 2, plateY - 1, 7, 8, _plateDark);
    _strokeRect(canvas, plateX + 2, plateY - 1, 7, 8, _barShade);

    _rect(canvas, plateX, plateY, 7, 8, _plateDark);
    _strokeRect(canvas, plateX, plateY, 7, 8, edge);
    _rect(canvas, plateX + 2, plateY + 2, 3, 4, _body);
    _strokeRect(canvas, plateX + 2, plateY + 2, 3, 4, edge);
  }

  void _strokeRect(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = false;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
  }

  void _drawPressLines(Canvas canvas, double opacity) {
    final color = kNeon.withValues(alpha: (opacity * 0.6).clamp(0.0, 0.6));
    _rect(canvas, 18, 16 - opacity * 2, 1, 4, color);
    _rect(canvas, 21, 14 - opacity * 2, 1, 3, color);
  }

  void _drawVictoryPixels(Canvas canvas, double pulse) {
    final particles = const [
      (x: 20.0, y: 11.0, dx: -3.0, dy: -2.0),
      (x: 26.0, y: 9.0, dx: -1.0, dy: -3.0),
      (x: 32.0, y: 8.0, dx: 0.0, dy: -4.0),
      (x: 39.0, y: 9.0, dx: 2.0, dy: -3.0),
      (x: 45.0, y: 12.0, dx: 4.0, dy: -1.0),
      (x: 27.0, y: 15.0, dx: -2.0, dy: 2.0),
      (x: 37.0, y: 15.0, dx: 2.0, dy: 2.0),
    ];
    final travel = 1 - pulse;
    final opacity = (pulse * 0.7).clamp(0.0, 0.7).toDouble();
    for (final p in particles) {
      _rect(
        canvas,
        p.x + p.dx * travel,
        p.y + p.dy * travel,
        1,
        1,
        kNeon.withValues(alpha: opacity),
      );
    }
  }

  void _drawLevelPayoff(Canvas canvas, double opacity) {
    final painter = TextPainter(
      text: TextSpan(
        text: '+1 LV',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 4.5,
          height: 1,
          color: kAmber.withValues(alpha: opacity),
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(42, 10 - (1 - opacity) * 2));
  }

  @override
  bool shouldRepaint(covariant _BenchPressPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        reducedMotion != oldDelegate.reducedMotion;
  }
}

enum _Pose { lockout, mid, bottom, strain, racked }
