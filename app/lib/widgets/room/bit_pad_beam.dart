import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Pixel-art rising beam that tethers BIT to his emitter pad — a verbatim port
/// of the prototype's `bitpad-beam.js`. A point-source cone: a ~3-cell bright
/// focus at the emitter, fanning up and **fading to zero before it reaches
/// BIT** (the clean dark gap that keeps BIT the brightest thing — handoff
/// GUARDRAILS #2/#3). Travelling energy bands climb upward. Same Bayer-4×4
/// dither + cyan ramp as the floor pool, so pad and beam read as one emitter.
///
/// Quantised to ~14fps; reduced motion → a static lit frame.
class BitPadBeamPainter extends CustomPainter {
  BitPadBeamPainter({
    required this.time,
    required this.reduceMotion,
    this.scale = 1.0,
    this.topY01 = 0.0,
  }) : super(repaint: time);

  /// Shared room clock, in seconds.
  final ValueListenable<double> time;
  final bool reduceMotion;

  /// External brightness multiplier on the auto flicker (`bitpad-beam.js`'s
  /// `extScale`). 1 = normal; the send-off pushes it to ~1.15 so the beam
  /// brightens **in place** (it never extends past BIT — BIT rises above it).
  final double scale;

  /// Retract, 0→1: pulls the beam's fade-top **down toward the emitter apex** so
  /// it withdraws INTO the pad (`bitpad-beam.js`'s `topY01`). 0 = full (normal)
  /// height; 1 = fully retracted (no beam). The launch collapse and the
  /// homecoming deposit drive this up; collect drives it back to 0.
  final double topY01;

  // Config — verbatim from preview.html's BitPadBeam.init.
  static const int _cols = 20, _rows = 26;
  static const double _apexX = 10, _apexY = 22, _topY = 9;
  static const double _halfBase = 3.0, _spread = -0.05, _edgeFlat = 1.7;
  static const double _vfade = 1.1, _bandSpeed = 6, _period = 4;

  static const List<List<int>> _bayer = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
  ];

  // Canonical procedural-art BIT-turquoise ramp (not brand color) — matches the
  // pool, so pad and beam still read as one emitter.
  static const List<Color?> _tiers = [
    null,
    Color(0x3D1A968E),
    Color(0x7528CEC2),
    Color(0xB380F0E4),
    Color(0xE0D2FFFA),
  ];

  /// `curTopY` = the live fade-top, pulled down toward the apex by [topY01]
  /// (verbatim `bitpad-beam.js`: `round(topY + (apexY-topY)*topY01)`).
  double get _curTopY =>
      (_topY + (_apexY - _topY) * topY01.clamp(0.0, 1.0)).roundToDouble();

  double _field(int x, int y, double t, double curTopY) {
    final hh = _apexY - curTopY; // live beam height in rows
    if (y > _apexY || y < curTopY || hh <= 0) return 0;
    final rise = _apexY - y; // 0 at apex … hh at fade-top
    final half = _halfBase + _spread * rise;
    final dxa = (x - _apexX).abs();
    if (dxa > half) return 0;
    var hpart = 1 - dxa / half; // bright centre → soft edge
    hpart = math.min(1, hpart * _edgeFlat);
    final up = rise / hh; // 0 apex … 1 fade-top
    final vert = math.pow(1 - up, _vfade).toDouble(); // peaks at base, →0 before BIT
    var v = hpart * vert;
    // travelling energy — discrete bands climbing upward
    final p = (((rise - t * _bandSpeed) % _period) + _period) % _period;
    v *= (p < _period * 0.5) ? 1.28 : 0.70;
    return v < 0 ? 0 : v;
  }

  double _noise(double t) {
    final s = math.sin(t * 12.9898) * 43758.5453;
    return s - s.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (scale <= 0) return; // fully dimmed (collapse / deposit)
    final cw = size.width / _cols, ch = size.height / _rows;
    final curTopY = _curTopY;
    final double t, intensity;
    if (reduceMotion) {
      t = 0;
      intensity = 0.85 * scale;
    } else {
      t = (time.value * 14).floorToDouble() / 14; // chunky ~14fps
      final breath = 0.82 + 0.18 * math.sin(t * 1.6);
      final jitter = 0.95 + 0.05 * _noise(t * 1.9);
      final dip = _noise(t * 0.31 + 7) < 0.14
          ? (0.55 + 0.20 * _noise(t * 2.3 + 5))
          : 1.0;
      intensity = breath * jitter * dip * scale; // scale = brightness, in place
    }
    final paint = Paint()..isAntiAlias = false;
    for (var y = curTopY.toInt(); y <= _apexY.toInt(); y++) {
      for (var x = 0; x < _cols; x++) {
        final v = _field(x, y, t, curTopY) * intensity;
        if (v <= 0) continue;
        final th = (_bayer[y & 3][x & 3] + 0.5) / 16;
        final q = v * 4;
        var lvl = q.floor();
        if (q - lvl > th) lvl++;
        if (lvl <= 0) continue;
        if (lvl > 4) lvl = 4;
        final c = _tiers[lvl];
        if (c == null) continue;
        paint.color = c;
        canvas.drawRect(Rect.fromLTWH(x * cw, y * ch, cw, ch), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BitPadBeamPainter old) =>
      old.reduceMotion != reduceMotion ||
      old.scale != scale ||
      old.topY01 != topY01;
}
