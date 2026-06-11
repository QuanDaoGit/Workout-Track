import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Animated LCK / streak icon: an amber 4-point star that twinkles, orbited by
/// a violet comet sweeping a tilted ellipse over a breathing violet bloom.
///
/// A faithful Flutter port of the reference canvas animation — a pixel-art
/// raster redrawn every frame. Self-animating: it owns a long, repeating
/// controller and reads its elapsed time as a continuous clock (matching the
/// reference `performance.now()` model). Honors reduced motion by painting a
/// single settled frame and never ticking.
class StreakOrbitIcon extends StatefulWidget {
  const StreakOrbitIcon({super.key, required this.size});

  /// Square edge length, in logical pixels (reference canvas is 280).
  final double size;

  @override
  State<StreakOrbitIcon> createState() => _StreakOrbitIconState();
}

class _StreakOrbitIconState extends State<StreakOrbitIcon>
    with SingleTickerProviderStateMixin {
  // A monotonic clock; long enough never to wrap during onboarding.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1000),
  );

  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce == _reducedMotion && (reduce || _clock.isAnimating)) return;
    _reducedMotion = reduce;
    if (_reducedMotion) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _StreakOrbitPainter(
          clock: _clock,
          size: widget.size,
          reducedMotion: _reducedMotion,
        ),
      ),
    );
  }
}

/// One tilted-ellipse comet orbit. Matches the reference's default (single,
/// "ON") orbit.
class _Orbit {
  const _Orbit({
    required this.a,
    required this.b,
    required this.phi,
    required this.tail,
    required this.speed,
    required this.base,
    required this.rim,
    required this.head,
    required this.glow,
  });

  final double a; // ellipse semi-major (icon-space units)
  final double b; // ellipse semi-minor
  final double phi; // tilt (radians)
  final double tail; // tail length factor
  final double speed; // angular speed factor
  final Color base;
  final Color rim;
  final Color head;
  final Color glow;
}

const _orbit = _Orbit(
  a: 13.4,
  b: 4.9,
  phi: -11 * math.pi / 180,
  tail: 4.9,
  speed: 1.0,
  base: Color(0xFF4A2480),
  rim: Color(0xFFB14DFF),
  head: Color(0xFFF0D8FF),
  glow: Color(0x8CB14DFF), // rgba(177,77,255,0.55)
);

// Star palette.
const _starInterior = Color(0xFFC8901A);
const _starEdge = Color(0xFFFFE34D);

const _g = 30; // pixel grid resolution (icon-space units)

/// 4-point amber sparkle, built once into a [_g]×[_g] mask.
final Uint8List _starMask = _buildStarMask();

Uint8List _buildStarMask() {
  final mask = Uint8List(_g * _g);
  double cell(double x, double y) {
    const lv = 7.4, hwv = 2.4, lh = 5.8, hwh = 2.1, p = 1.8;
    final ax = x.abs(), ay = y.abs();
    if (ay <= lv && ax <= hwv * math.pow(1 - ay / lv, p)) return 1;
    if (ax <= lh && ay <= hwh * math.pow(1 - ax / lh, p)) return 1;
    return 0;
  }

  for (var iy = 0; iy < _g; iy++) {
    for (var ix = 0; ix < _g; ix++) {
      mask[iy * _g + ix] = cell((ix + 0.5) - _g / 2, (iy + 0.5) - _g / 2)
          .toInt();
    }
  }
  return mask;
}

class _StreakOrbitPainter extends CustomPainter {
  _StreakOrbitPainter({
    required this.clock,
    required this.size,
    required this.reducedMotion,
  }) : super(repaint: reducedMotion ? null : clock);

  final AnimationController clock;
  final double size;
  final bool reducedMotion;

  // Geometry (mirrors the reference: CSSPX 280, BOX 196).
  double get _box => size * 196 / 280;
  double get _e => _box / _g;
  double get _ox => (size - _box) / 2;
  double get _oy => (size - _box) / 2;
  double get _s => size / 280; // pixel-space scale vs. the reference canvas

  double get _el => reducedMotion
      ? 2.6
      : clock.lastElapsedDuration == null
      ? 0.0
      : clock.lastElapsedDuration!.inMicroseconds / 1e6;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final el = _el;
    final cx = size / 2, cy = size / 2;

    // Entrance / idle envelopes.
    final ignite = ((el - 0.2) / 1.1).clamp(0.0, 1.0);
    final starPop = ((el - 0.05) / 0.5).clamp(0.0, 1.0);
    final popEase = 1 - math.pow(1 - starPop, 3).toDouble();
    final twk = 0.5 + 0.5 * math.sin(el * 1.7);
    final breath = 0.5 + 0.5 * math.sin(el * 0.9 + 1);

    // ---- ambient violet bloom behind everything ----
    final bloomR = (86 + 10 * breath) * (0.4 + 0.6 * ignite) * _s;
    final bloomPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.fromRGBO(150, 70, 235, 0.10 * ignite),
          Color.fromRGBO(120, 55, 210, 0.07 * ignite),
          const Color.fromRGBO(90, 40, 170, 0),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: bloomR));
    canvas.drawCircle(Offset(cx, cy), bloomR, bloomPaint);

    // ---- comet grids (back arc behind the star, front arc in front) ----
    final back = Uint8List(_g * _g);
    final front = Uint8List(_g * _g);
    final th = el * _orbit.speed * 1.9;
    _stampComet(back, front, _orbit, th, ignite);

    final orbitSigma = 9 * 0.5 * _s;
    _drawGrid(canvas, back, _orbit, orbitSigma);

    // ---- star: twinkle scale + amber glow ----
    canvas.save();
    final sScale = popEase * (0.97 + 0.06 * twk);
    canvas.translate(cx, cy);
    canvas.scale(sScale, sScale);
    canvas.translate(-cx, -cy);
    final starSigma = (10 + 8 * twk) * 0.5 * _s;
    _drawMask(
      canvas,
      _starMask,
      base: _starInterior,
      rim: _starEdge,
      head: _starEdge,
      glow: const Color(0x80FFD700), // rgba(255,215,0,0.5)
      sigma: starSigma,
    );
    canvas.restore();

    _drawGrid(canvas, front, _orbit, orbitSigma);
  }

  void _stampDisc(Uint8List grid, double ux, double uy, double r, int val) {
    final gx = ux + _g / 2 - 0.5, gy = uy + _g / 2 - 0.5;
    final x0 = math.max(0, (gx - r).floor());
    final x1 = math.min(_g - 1, (gx + r).ceil());
    final y0 = math.max(0, (gy - r).floor());
    final y1 = math.min(_g - 1, (gy + r).ceil());
    final r2 = r * r;
    for (var iy = y0; iy <= y1; iy++) {
      for (var ix = x0; ix <= x1; ix++) {
        final dx = ix - gx, dy = iy - gy;
        if (dx * dx + dy * dy <= r2) {
          final i = iy * _g + ix;
          if (val > grid[i]) grid[i] = val;
        }
      }
    }
  }

  void _stampComet(
    Uint8List back,
    Uint8List front,
    _Orbit cfg,
    double headTh,
    double len,
  ) {
    final cosP = math.cos(cfg.phi), sinP = math.sin(cfg.phi);
    const m = 96;
    for (var i = 0; i <= m; i++) {
      final t = i / m; // 0 tail .. 1 head
      final th = headTh - (1 - t) * cfg.tail * len;
      final bx = cfg.a * math.cos(th), by = cfg.b * math.sin(th);
      final ux = bx * cosP - by * sinP, uy = bx * sinP + by * cosP;
      final r = (0.3 + 1.45 * t) * (0.55 + 0.45 * len);
      final val = t > 0.9 ? 2 : 1;
      _stampDisc(uy >= 0 ? front : back, ux, uy, r, val);
    }
    // bright head blob
    final bx = cfg.a * math.cos(headTh), by = cfg.b * math.sin(headTh);
    final ux = bx * cosP - by * sinP, uy = bx * sinP + by * cosP;
    _stampDisc(uy >= 0 ? front : back, ux, uy, 2.1 * (0.6 + 0.4 * len), 2);
  }

  bool _isEdge(Uint8List grid, int ix, int iy) {
    if (grid[iy * _g + ix] == 0) return false;
    if (ix == 0 || iy == 0 || ix == _g - 1 || iy == _g - 1) return true;
    return grid[iy * _g + (ix - 1)] == 0 ||
        grid[iy * _g + (ix + 1)] == 0 ||
        grid[(iy - 1) * _g + ix] == 0 ||
        grid[(iy + 1) * _g + ix] == 0;
  }

  void _drawGrid(Canvas canvas, Uint8List grid, _Orbit o, double sigma) {
    _drawMask(
      canvas,
      grid,
      base: o.base,
      rim: o.rim,
      head: o.head,
      glow: o.glow,
      sigma: sigma,
    );
  }

  /// Two passes: a blurred glow halo (one accumulated path), then crisp cells
  /// (head → [head], edge → [rim], interior → [base]).
  void _drawMask(
    Canvas canvas,
    Uint8List grid, {
    required Color base,
    required Color rim,
    required Color head,
    required Color glow,
    required double sigma,
  }) {
    final overlap = _e + 0.6;
    // bloom pass — accumulate every lit cell, draw once, blurred.
    final bloom = Path();
    var any = false;
    for (var iy = 0; iy < _g; iy++) {
      for (var ix = 0; ix < _g; ix++) {
        if (grid[iy * _g + ix] == 0) continue;
        any = true;
        bloom.addRect(
          Rect.fromLTWH(_ox + ix * _e, _oy + iy * _e, overlap, overlap),
        );
      }
    }
    if (!any) return;
    if (sigma > 0) {
      canvas.drawPath(
        bloom,
        Paint()
          ..color = glow
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
    }
    // crisp pass
    final cell = Paint()..isAntiAlias = false;
    for (var iy = 0; iy < _g; iy++) {
      for (var ix = 0; ix < _g; ix++) {
        final v = grid[iy * _g + ix];
        if (v == 0) continue;
        cell.color = v == 2 ? head : (_isEdge(grid, ix, iy) ? rim : base);
        canvas.drawRect(
          Rect.fromLTWH(_ox + ix * _e, _oy + iy * _e, overlap, overlap),
          cell,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StreakOrbitPainter oldDelegate) =>
      oldDelegate.size != size || oldDelegate.reducedMotion != reducedMotion;
}
