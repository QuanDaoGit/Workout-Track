import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Pixel-art floor-pool light under BIT's emitter pad — a verbatim port of the
/// prototype's `bitpad-light.js`. A chunky **Bayer-4×4 ordered-dithered** cyan
/// radial rendered on a low-res cell grid and scaled up nearest-neighbour, so
/// the light reads as authentic pixel art, never a smooth gradient
/// (handoff GUARDRAILS #1).
///
/// The field pools **wide** horizontally (`_rx`) and **downward** on the floor
/// (`_ryUp` tighter than `_ry` keeps the halo from climbing the pad's pillars).
/// Slow breathing fade + occasional pixel-dropout flicker, quantised to ~14fps
/// (chunky on purpose). Reduced motion → a static lit frame at 0.85.
///
/// The cyan ramp below is canonical procedural-art (a light ramp), not brand
/// color — same status as `bit_boot.dart`'s `_metal` map.
class BitPadLightPainter extends CustomPainter {
  BitPadLightPainter({
    required this.time,
    required this.reduceMotion,
    this.tint = 0.0,
  }) : super(repaint: time);

  /// Shared room clock, in seconds.
  final ValueListenable<double> time;
  final bool reduceMotion;

  /// Underglow hue, 0→1: 0 = BIT's turquoise (home), 1 = magenta (a haul on the
  /// pad). The homecoming tints to magenta on deposit; collect reverses it. Each
  /// dither tier lerps turquoise→magenta keeping its tier alpha.
  final double tint;

  // Config — verbatim from preview.html's BitPadLight.init.
  static const int _cols = 68, _rows = 60;
  static const double _cx = 34, _cy = 40, _rx = 30, _ry = 22, _ryUp = 10;

  static const List<List<int>> _bayer = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
  ];

  // BIT turquoise ramp: deep → bright → near-white core (color carries the tier
  // alpha). Recoloured off recovery-cyan so BIT's machine light owns its own hue.
  static const List<Color?> _tiers = [
    null,
    Color(0x3D1A968E),
    Color(0x7528CEC2),
    Color(0xB380F0E4),
    Color(0xE0D2FFFA),
  ];

  // Magenta haul ramp (sampled from gem.png: deep facet → mid → core →
  // highlight) at the same per-tier alphas, so a haul recolours the same dither
  // without changing its shape. Canonical procedural-art palette, not brand.
  static const List<Color?> _magentaTiers = [
    null,
    Color(0x3D961C8C),
    Color(0x75E028A0),
    Color(0xB3FF4DCD),
    Color(0xE0FF96E6),
  ];

  double _field(int x, int y) {
    final dx = (x - _cx) / _rx;
    final dy = (y < _cy) ? (y - _cy) / _ryUp : (y - _cy) / _ry;
    var v = 1 - math.sqrt(dx * dx + dy * dy);
    if (v < 0.10) v = 0; // trim stray far specks
    return v < 0 ? 0 : v;
  }

  // Deterministic 0..1 hash noise (golden-stable; no per-frame RNG state).
  double _noise(double t) {
    final s = math.sin(t * 12.9898) * 43758.5453;
    return s - s.floorToDouble();
  }

  double _intensity() {
    if (reduceMotion) return 0.85;
    final t = time.value;
    final tq = (t * 14).floorToDouble() / 14; // chunky ~14fps
    final breath = 0.80 + 0.20 * math.sin(tq * 1.6);
    final jitter = 0.94 + 0.06 * _noise(tq * 1.7);
    final dip = _noise(tq * 0.37 + 11) < 0.16
        ? (0.5 + 0.22 * _noise(tq * 2.1 + 3))
        : 1.0;
    return breath * jitter * dip;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / _cols, ch = size.height / _rows;
    final intensity = _intensity();
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < _rows; y++) {
      for (var x = 0; x < _cols; x++) {
        final v = _field(x, y) * intensity;
        if (v <= 0) continue;
        final th = (_bayer[y & 3][x & 3] + 0.5) / 16;
        final q = v * 4;
        var lvl = q.floor();
        if (q - lvl > th) lvl++;
        if (lvl <= 0) continue;
        if (lvl > 4) lvl = 4;
        var c = _tiers[lvl];
        if (c == null) continue;
        if (tint > 0) c = Color.lerp(c, _magentaTiers[lvl], tint)!;
        paint.color = c;
        canvas.drawRect(Rect.fromLTWH(x * cw, y * ch, cw, ch), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BitPadLightPainter old) =>
      old.reduceMotion != reduceMotion || old.tint != tint;
}
