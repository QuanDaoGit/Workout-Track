import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_fonts.dart';
import '../theme/tokens.dart';

/// The center Train action — a pixel-stepped, cut-corner "keycap" with a
/// pressable bottom depth face (no round edges; the staircase corners keep it
/// coherent with the pixel theme). Idle shows the sword; while a session is live
/// it swaps to the mm:ss timer — restoring the always-visible elapsed time the
/// old dock used to show — wrapped in a marching segmented neon ring and a
/// breathing phosphor glow. All motion freezes under reduced motion.
class TrainNavButton extends StatefulWidget {
  const TrainNavButton({
    super.key,
    required this.live,
    required this.onTap,
    this.elapsedLabel,
  });

  final bool live;
  final VoidCallback onTap;

  /// mm:ss (or h:mm:ss) shown on the keycap while [live]; null when idle.
  final String? elapsedLabel;

  @override
  State<TrainNavButton> createState() => _TrainNavButtonState();
}

class _TrainNavButtonState extends State<TrainNavButton>
    with TickerProviderStateMixin {
  static const double _w = 48;
  static const double _faceH = 44;
  static const double _depth = 4;
  static const double _step = 4;

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _pressed = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _sync();
  }

  @override
  void didUpdateWidget(TrainNavButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live != widget.live) _sync();
  }

  void _sync() {
    if (widget.live && !_reduceMotion) {
      if (!_sweep.isAnimating) _sweep.repeat();
      if (!_breathe.isAnimating) _breathe.repeat(reverse: true);
    } else {
      _sweep.stop();
      _breathe.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = widget.live
        ? Text(
            widget.elapsedLabel ?? '0:00',
            style: AppFonts.shareTechMono(color: kNeon, fontSize: 9),
          )
        : const ImageIcon(
            AssetImage('assets/icons/control/icon_sword.png'),
            color: kBg,
            size: 22,
          );

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.translate(
            offset: const Offset(0, -10),
            child: SizedBox(
              width: _w,
              height: _faceH + _depth,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_sweep, _breathe]),
                      builder: (_, _) => CustomPaint(
                        painter: _KeycapPainter(
                          live: widget.live,
                          pressed: _pressed,
                          sweep: _sweep.value,
                          glow: _reduceMotion ? 0.5 : _breathe.value,
                          reduceMotion: _reduceMotion,
                          step: _step,
                          depth: _depth,
                          faceH: _faceH,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _pressed ? _depth : 0,
                    height: _faceH,
                    child: Center(child: content),
                  ),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -8),
            child: const Text(
              'TRAIN',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 7,
                color: kNeon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeycapPainter extends CustomPainter {
  _KeycapPainter({
    required this.live,
    required this.pressed,
    required this.sweep,
    required this.glow,
    required this.reduceMotion,
    required this.step,
    required this.depth,
    required this.faceH,
  });

  final bool live;
  final bool pressed;
  final double sweep;
  final double glow;
  final bool reduceMotion;
  final double step;
  final double depth;
  final double faceH;

  static const Color _idleDepth = Color(0xFF0A7A4D); // darker neon = keycap base
  static const Color _liveDepth = Color(0xFF052017);
  static const Color _liveFace = Color(0xFF0C1712);

  /// A square with 2-step pixel-staircase corners (no diagonal/round edges).
  Path _facePath(Rect r, double s) {
    final l = r.left, t = r.top, rr = r.right, b = r.bottom;
    final c = 2 * s;
    return Path()
      ..moveTo(l + c, t)
      ..lineTo(rr - c, t)
      ..lineTo(rr - s, t)
      ..lineTo(rr - s, t + s)
      ..lineTo(rr, t + s)
      ..lineTo(rr, t + c)
      ..lineTo(rr, b - c)
      ..lineTo(rr, b - s)
      ..lineTo(rr - s, b - s)
      ..lineTo(rr - s, b)
      ..lineTo(rr - c, b)
      ..lineTo(l + c, b)
      ..lineTo(l + s, b)
      ..lineTo(l + s, b - s)
      ..lineTo(l, b - s)
      ..lineTo(l, b - c)
      ..lineTo(l, t + c)
      ..lineTo(l, t + s)
      ..lineTo(l + s, t + s)
      ..lineTo(l + s, t)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final faceTop = pressed ? depth : 0.0;
    final mainPath = _facePath(Rect.fromLTWH(0, faceTop, w, faceH), step);

    // Pressable depth base — hidden once the keycap is pressed down onto it.
    if (!pressed) {
      final depthPaint = Paint()
        ..isAntiAlias = false
        ..color = live ? _liveDepth : _idleDepth;
      canvas.drawPath(
        _facePath(Rect.fromLTWH(0, depth, w, faceH), step),
        depthPaint,
      );
    }

    // Keycap face.
    canvas.drawPath(
      mainPath,
      Paint()
        ..isAntiAlias = false
        ..color = live ? _liveFace : kNeon,
    );

    if (!live) return;

    // Breathing phosphor halo (full outline, blurred, intensity breathes).
    canvas.drawPath(
      mainPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = kNeon.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 + glow * 5.0),
    );

    // Dim base ring so the keycap edge stays defined between segments.
    canvas.drawPath(
      mainPath,
      Paint()
        ..isAntiAlias = false
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = kNeon.withValues(alpha: 0.25),
    );

    // Marching segmented neon ring — discrete pixel ticks, swept by [sweep].
    final metric = mainPath.computeMetrics().first;
    final len = metric.length;
    const seg = 6.0, gap = 5.0, period = seg + gap;
    final phase = (reduceMotion ? 0.0 : sweep) * period;
    final segPaint = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt
      ..color = kNeon;
    for (double d = -phase; d < len; d += period) {
      final start = math.max(0.0, d);
      final end = math.min(len, d + seg);
      if (end > start) {
        canvas.drawPath(metric.extractPath(start, end), segPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_KeycapPainter old) =>
      old.live != live ||
      old.pressed != pressed ||
      old.sweep != sweep ||
      old.glow != glow ||
      old.reduceMotion != reduceMotion;
}
