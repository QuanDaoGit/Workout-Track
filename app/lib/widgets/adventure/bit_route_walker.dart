import 'dart:math';

import 'package:flutter/material.dart';

import '../companion/bit_core_engine.dart'
    show addLampDot, bevelBlock, metal;

/// BIT — the side-view hover-glide traveller for the expedition routes.
///
/// A faithful Dart port of the handoff painter
/// `assets/handoff_BIT_expedition/handoff_bit_route_walk/engine/bit-walk.js`.
/// BIT has no legs — he *floats* — so "walking a route" is a **hover-glide**:
/// a forward-facing glowing screen, a trailing back-plate fin, top plate +
/// under-vent, a phase-lagged hover-bob, blink, a cyan thrust trail, and a
/// crisp route-tinted hover shimmer on the walk line. Hand-painted on a 40×32
/// native sprite; nearest-neighbour, integer-grid.
///
/// Layer-2 adaptations from the JS reference (recorded in the port plan):
/// - The JS canvas is native-res + CSS-upscaled; here we paint the native
///   40×32 grid and `Canvas.scale()` by the diorama's (fractional) `scale`,
///   `isAntiAlias:false`, so BIT shares the backdrop's pixel grid exactly.
/// - Blink and the thrust-trail jitter are **deterministic** functions of the
///   clock (not `Math.random()`) — required for golden tests + frame-rate
///   independence. Everything else is ported verbatim.
class BitRouteWalker extends StatelessWidget {
  const BitRouteWalker({
    super.key,
    required this.tMs,
    required this.accent,
    required this.speed,
    required this.scale,
    this.showShimmer = true,
  });

  /// Elapsed clock in milliseconds (drives bob/blink/trail). 0 freezes BIT on
  /// the static neutral pose (reduced motion).
  final double tMs;

  /// Active route accent — tints the hover shimmer ONLY, never BIT's body.
  final Color accent;

  /// Effective world-scroll speed (native px/s). The thrust trail emits only
  /// while the world is moving (`speed > 4`); pass 0 to idle BIT.
  final double speed;

  /// Diorama scale (`height / 270`); BIT scales in step with the backdrop.
  final double scale;

  /// Draw the route-tinted hover shimmer on the walk line (off for off-route
  /// thumbnails).
  final bool showShimmer;

  @override
  Widget build(BuildContext context) {
    final size = Size(_nativeW * scale, _nativeH * scale);
    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(
        size: size,
        painter: _BitWalkPainter(
          tMs: tMs,
          accent: accent,
          speed: speed,
          scale: scale,
          showShimmer: showShimmer,
        ),
      ),
    );
  }
}

const double _nativeW = 40;
const double _nativeH = 32;

/* ---- BIT's canonical metal palette, sourced from the shared engine so the
   body stays in lockstep with every other BIT surface. The two lamp tones are
   bit-walk.js's deliberate travel-cyan override (the front-view sprite's lamps
   are turquoise) — the one documented divergence, kept explicit here. ---- */
final Map<String, Color> _metal = {
  ...metal,
  'c': const Color(0xFF00BFFF),
  'C': const Color(0xFF5EE8FF),
};
const List<Color> _ramp = [
  Color(0xFF0A5E72),
  Color(0xFF11A6C4),
  Color(0xFF39D6F0),
  Color(0xFF7CF2FF),
]; // screen glow, edge → centre

// Core-local screen well (shared by the well-carve and the drawn screen).
const int _scrx = 5, _scry = 4, _scrw = 7, _scrh = 7;

/* ---- the bevel / lamp algorithms are the shared engine's (`bevelBlock` /
   `addLampDot`) — only the side-view grids below are bespoke to the walker.
   (The reference's black `outlinePass` was dropped engine-wide: it only ever
   filled the bevel-cut corner notches with pitch-black specks.) ---- */

/* ---- side core: square rounded body mostly filled by the glowing screen with
   a thin metal bezel. Screen pushed to the forward (right) face; the left metal
   reads as the "back of the head" so BIT faces the direction of travel. ---- */
List<List<String>> _buildSideCore() {
  final g = bevelBlock(15, 15, 3);
  for (var y = _scry - 1; y <= _scry + _scrh; y++) {
    for (var x = _scrx - 1; x <= _scrx + _scrw; x++) {
      if (y >= 0 && y < g.length && x >= 0 && x < g[y].length && g[y][x] != '.') {
        final inner =
            x >= _scrx && x < _scrx + _scrw && y >= _scry && y < _scry + _scrh;
        if (inner) {
          g[y][x] = 'q';
        } else {
          g[y][x] = (x < _scrx || y < _scry) ? 'd' : 'k'; // recessed bezel ring
        }
      }
    }
  }
  // back-of-head vents
  g[5][1] = 'k';
  g[6][1] = 'd';
  g[7][1] = 'd';
  g[8][1] = 'd';
  g[9][1] = 'k';
  g[7][2] = 'l';
  return g;
}

final List<List<String>> _core = _buildSideCore();
final List<List<String>> _topPlate = () {
  final g = bevelBlock(13, 4, 2);
  addLampDot(g, 3, 1);
  addLampDot(g, 9, 1);
  return g;
}();
final List<List<String>> _backPlate = () {
  final g = bevelBlock(5, 11, 2);
  addLampDot(g, 2, 2);
  addLampDot(g, 2, 8);
  return g;
}();
final List<List<String>> _underVent = () {
  final g = bevelBlock(10, 3, 1);
  addLampDot(g, 2, 1);
  addLampDot(g, 7, 1);
  return g;
}();

class _BitWalkPainter extends CustomPainter {
  _BitWalkPainter({
    required this.tMs,
    required this.accent,
    required this.speed,
    required this.scale,
    required this.showShimmer,
  });

  final double tMs;
  final Color accent;
  final double speed;
  final double scale;
  final bool showShimmer;

  static const double _amp = 1.5; // hover amplitude (px)
  static const double _per = 300; // hover period (ms)
  static const int _cx = 13, _cy = 8; // core top-left (native)

  // JS `Math.round` (ties toward +∞) — NOT Dart's `.round()` (ties away from
  // zero); they differ on negative half-integers, which the bob trough / sway
  // land on exactly. Porting the reference faithfully requires JS semantics.
  static int _jsRound(double x) => (x + 0.5).floor();

  int _bob(double t, double lag) => _jsRound(_amp * sin((t - lag) / _per));

  // Deterministic blink: a 110ms closure on a ~3.5s cadence (the JS uses a
  // random 2.6–6.6s gap; determinism is an app requirement).
  bool get _blink => tMs % 3500 < 110;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    canvas.save();
    canvas.scale(scale);
    final t = tMs;
    final cb = _bob(t, 0);

    // ground contact — crisp, route-tinted hover shimmer (no soft blur).
    if (showShimmer) {
      const cxn = _cx + 6; // 19
      const gy = 29;
      final pulse = 0.55 + 0.45 * sin(t / 300);
      p.color = const Color(0xFF05050C).withValues(alpha: 0.26); // faint contact
      canvas.drawRect(Rect.fromLTWH((cxn - 5).toDouble(), gy.toDouble(), 11, 1), p);
      const dashes = <(int, double)>[
        (-5, 0.10),
        (-3, 0.18),
        (-1, 0.50),
        (1, 0.50),
        (3, 0.18),
        (5, 0.10),
      ];
      for (final (dx, a) in dashes) {
        p.color = accent.withValues(alpha: (a * pulse).clamp(0.0, 1.0));
        canvas.drawRect(Rect.fromLTWH((cxn + dx).toDouble(), gy.toDouble(), 1, 1), p);
      }
    }

    // thrust motes (cyan — BIT's engine identity), drawn behind the body
    if (speed > 4) _paintMotes(canvas, p, t);

    // back plate (trailing fin) floats furthest behind + sways; then top plate,
    // under-vent — each lags the core's bob.
    final backX = _cx - 7 - _jsRound(sin((t - 200) / _per));
    _drawGrid(canvas, p, _backPlate, backX.toDouble(), (_cy + 2 + _bob(t, 200)).toDouble());
    _drawGrid(canvas, p, _topPlate, (_cx + 1).toDouble(), (_cy - 4 + _bob(t, 140)).toDouble());
    _drawGrid(canvas, p, _underVent, (_cx + 3).toDouble(), (_cy + 14 + _bob(t, 90)).toDouble());

    // core + glowing forward face
    _drawGrid(canvas, p, _core, _cx.toDouble(), (_cy + cb).toDouble());
    _drawScreen(canvas, p, (_cx + _scrx).toDouble(), (_cy + _scry + cb).toDouble());

    canvas.restore();
  }

  void _drawGrid(
    Canvas canvas,
    Paint p,
    List<List<String>> grid,
    double ox,
    double oy,
  ) {
    final rx = ox.roundToDouble();
    final ry = oy.roundToDouble();
    for (var y = 0; y < grid.length; y++) {
      final row = grid[y];
      for (var x = 0; x < row.length; x++) {
        final ch = row[x];
        if (ch == '.') continue;
        final c = _metal[ch];
        if (c == null) continue;
        p.color = c;
        canvas.drawRect(Rect.fromLTWH(rx + x, ry + y, 1, 1), p);
      }
    }
  }

  // screen: fills the face; radial ramp glow + forward-looking eyes + mouth glint.
  void _drawScreen(Canvas canvas, Paint p, double ox, double oy) {
    final rx = ox.roundToDouble();
    final ry = oy.roundToDouble();
    const cx = 3.0, cy = 3.0; // (SCRW-1)/2, (SCRH-1)/2
    for (var y = 0; y < _scrh; y++) {
      for (var x = 0; x < _scrw; x++) {
        final d = sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
        final idx = d < 1.2
            ? 3
            : d < 2.4
                ? 2
                : d < 3.4
                    ? 1
                    : 0;
        p.color = _ramp[idx];
        canvas.drawRect(Rect.fromLTWH(rx + x, ry + y, 1, 1), p);
      }
    }
    p.color = const Color(0xFFFFFFFF); // eyes, shifted to the forward (right) half
    if (_blink) {
      canvas.drawRect(Rect.fromLTWH(rx + 3, ry + 3, 1, 1), p);
      canvas.drawRect(Rect.fromLTWH(rx + 5, ry + 3, 1, 1), p);
    } else {
      canvas.drawRect(Rect.fromLTWH(rx + 3, ry + 2, 1, 1), p);
      canvas.drawRect(Rect.fromLTWH(rx + 5, ry + 2, 1, 1), p);
      canvas.drawRect(Rect.fromLTWH(rx + 3, ry + 3, 1, 1), p);
      canvas.drawRect(Rect.fromLTWH(rx + 5, ry + 3, 1, 1), p);
    }
    p.color = const Color(0xFF7CF2FF); // mouth glint
    canvas.drawRect(Rect.fromLTWH(rx + 4, ry + 5, 1, 1), p);
  }

  // Deterministic thrust trail — the visible motes at time `t` are those emitted
  // every 70ms within the last 520ms (their lifespan). Ported from `emit()`:
  // spawn x7 y(24+bob(90)+jitter), vx=-(0.05+speed·0.0009), vy=0.012,
  // life 1→0 over 520ms; cyan hot (#5EE8FF, 2px) → cool (#00BFFF, 1px).
  void _paintMotes(Canvas canvas, Paint p, double t) {
    final vx = -(0.05 + speed * 0.0009);
    const vy = 0.012;
    const period = 70.0;
    const life = 520.0;
    final kEnd = (t / period).floor();
    final kStart = max(0, ((t - life) / period).ceil());
    for (var k = kStart; k <= kEnd; k++) {
      final te = k * period;
      final age = t - te;
      if (age < 0 || age >= life) continue;
      final lifeFrac = 1 - age / life;
      if (lifeFrac <= 0) continue;
      final x = 7 + vx * age;
      if (x <= -1) continue; // matches the `m.x > -1` filter
      final jitter = _hash(k) * 2 - 1; // [-1, 1)
      final y = 24 + _bob(te, 90) + jitter + vy * age;
      final a = lifeFrac.clamp(0.0, 1.0);
      final hot = a > 0.55;
      p.color = (hot ? const Color(0xFF5EE8FF) : const Color(0xFF00BFFF))
          .withValues(alpha: a);
      final sz = hot ? 2.0 : 1.0;
      canvas.drawRect(
        Rect.fromLTWH(_jsRound(x).toDouble(), _jsRound(y).toDouble(), sz, sz),
        p,
      );
    }
  }

  // Deterministic [0,1) hash of the emission index (replaces Math.random()).
  double _hash(int k) {
    final v = sin(k * 12.9898) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _BitWalkPainter old) =>
      old.tMs != tMs ||
      old.accent != accent ||
      old.speed != speed ||
      old.scale != scale ||
      old.showShimmer != showShimmer;
}
