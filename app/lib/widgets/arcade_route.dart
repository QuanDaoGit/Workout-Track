import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum ArcadeRouteMotion { panel, flow, reveal, fade, powerOn, dolly }

/// The dolly route's timings — exported because the Home room's camera dolly
/// and its cover-reset must stay in lockstep with the route transition.
const int kDollyForwardMs = 280;
const int kDollyReverseMs = 190;

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
      if (motion == ArcadeRouteMotion.powerOn) {
        return _powerOnTransition(animation, child);
      }
      if (motion == ArcadeRouteMotion.dolly) {
        return _dollyReveal(animation, child, spec);
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
    // The Start Gate "powers on" from black: a dot expands to a horizontal beam,
    // then blooms vertically to the full screen. Deliberately SHORT — it's the
    // quick resolve after the longer power-off collapse on the outgoing screen
    // (Charge Ritual ignition). Starts from black so the collapse→route seam is
    // dark-to-dark (no flash).
    ArcadeRouteMotion.powerOn => const _CrtRouteSpec(
      forward: Duration(milliseconds: 380),
      reverse: Duration(milliseconds: 200),
      accent: kNeon,
      bandCount: 0,
      tearCount: 0,
      sweepStrength: 0,
      edgeStrength: 0,
    ),
    // The quest-board camera dolly's receive: the incoming page holds fully
    // back through the travel beat (the Home room visibly dollies alone under
    // a transparent route), then the CRT-signal bands sweep it in over the
    // zoomed room. On the reverse the page clears out early, so the room's
    // pull-back settle owns the tail of the pop.
    ArcadeRouteMotion.dolly => const _CrtRouteSpec(
      forward: Duration(milliseconds: kDollyForwardMs),
      reverse: Duration(milliseconds: kDollyReverseMs),
      accent: kCyan,
      bandCount: 18,
      tearCount: 3,
      sweepStrength: 0.26,
      edgeStrength: 0.20,
      revealGate: 0.42,
    ),
  };
}

/// The dolly receive: opacity 0 through the travel beat (`revealGate`), then
/// the standard CRT-signal composition runs on the remapped remainder.
Widget _dollyReveal(
  Animation<double> animation,
  Widget child,
  _CrtRouteSpec spec,
) {
  final gated = CurvedAnimation(
    parent: animation,
    curve: Interval(spec.revealGate, 1.0),
  );
  return FadeTransition(
    opacity: Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: animation,
        // A hard gate, then a fast ramp: invisible until the gate, fully
        // present shortly after (the bands carry the texture of the reveal).
        curve: Interval(spec.revealGate, spec.revealGate + 0.18),
      ),
    ),
    child: _crtSignalTransition(gated, child, spec),
  );
}

/// CRT power-on: from black, a dot → horizontal beam (the tube firing) → a
/// vertical bloom that opens the incoming page from its centre line. Paired with
/// the Charge Ritual's power-off collapse; both meet at near-black.
Widget _powerOnTransition(Animation<double> animation, Widget child) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
  return AnimatedBuilder(
    animation: curved,
    child: child,
    builder: (context, child) {
      final t = curved.value.clamp(0.0, 1.0).toDouble();
      // The picture blooms open (a horizontal band growing to full height) after
      // the beam has drawn its line.
      final open = ((t - 0.15) / 0.85).clamp(0.0, 1.0).toDouble();
      return ColoredBox(
        color: kBg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipPath(clipper: _VBandClipper(open), child: child!),
            if (t < 0.55)
              IgnorePointer(
                child: CustomPaint(
                  painter: _PowerOnBeamPainter(t),
                  size: Size.infinite,
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Clips to a centred horizontal band of height `open * h` (full width) — the
/// vertical bloom from a line to the full frame.
class _VBandClipper extends CustomClipper<Path> {
  const _VBandClipper(this.open);
  final double open;

  @override
  Path getClip(Size size) {
    if (open >= 0.999) return Path()..addRect(Offset.zero & size);
    final bandH = (size.height * open).clamp(2.0, size.height);
    final top = (size.height - bandH) / 2;
    return Path()..addRect(Rect.fromLTWH(0, top, size.width, bandH));
  }

  @override
  bool shouldReclip(covariant _VBandClipper old) => old.open != open;
}

/// The power-on beam: a bright centre line that first expands horizontally
/// (dot → full width) then fades as the picture blooms.
class _PowerOnBeamPainter extends CustomPainter {
  const _PowerOnBeamPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = (1 - (t / 0.5)).clamp(0.0, 1.0);
    if (alpha <= 0) return;
    final beamW = (t / 0.18).clamp(0.0, 1.0) * size.width;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: beamW,
      height: 3,
    );
    canvas.drawRect(rect, Paint()..color = kText.withValues(alpha: alpha));
    canvas.drawRect(
      rect,
      Paint()
        ..color = kNeon.withValues(alpha: alpha * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  @override
  bool shouldRepaint(covariant _PowerOnBeamPainter old) => old.t != t;
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
    this.revealGate = 0,
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

  /// Fraction of the transition the incoming page stays fully invisible
  /// (the dolly's travel beat). 0 = no gate (every other motion).
  final double revealGate;
}
