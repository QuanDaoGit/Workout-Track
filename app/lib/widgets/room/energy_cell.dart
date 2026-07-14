import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../theme/tokens.dart';

/// BIT's **expedition energy cell** — a faithful port of the `energy-cell`
/// handoff (`assets/handoff_BIT_expedition/energy-cell/Energy Cell.html`,
/// `paintCell`). A code-painted **18×26** pixel sprite: a pad-metal frame with
/// cyan-vent caps + side rails, a recessed **cyan glass core** carrying the
/// charge level, and a captured **lightning bolt** glyph (the one signature
/// hook). Cyan = BIT's energy family — never the magenta haul currency.
///
/// Only the two states this app needs are ported: **FULL** (`lvl: 1`) for a
/// charged cell and **DEPLETED** (`dead: true`) for a spent one — dead grey
/// glass + ghost bolt + no bloom, which reads as "needs recharge", never
/// failure (body-neutral). The handoff's LOW (continuous level) and the
/// RECHARGING fill-front sweep are out of scope for the integer 0–3 charge
/// model and are deliberately not ported (the `lvl`/`fillTop` params are kept
/// for parity but only `lvl: 1` is used).
///
/// The palette below is **canonical procedural sprite-art** (same status as
/// `bit_companion.dart`'s `_metal`), carried as int ARGB so the `_shade` helper
/// can darken a channel with **JS `Math.round` semantics** (`(v·f + 0.5).floor`,
/// matching the source's `shade()`), not Dart's round-half-away-from-zero.

// ── palette (verbatim from the handoff `C` + glass ramps) ────────────────────
const int _kOut = 0xFF0A0B14;
const int _kD2 = 0xFF14162A;
const int _kD1 = 0xFF222540;
const int _kM = 0xFF2E3150;
const int _kL1 = 0xFF3D4262;
const int _kL2 = 0xFF525879;
const int _kL3 = 0xFF6B72A0;
const int _kVmd = 0xFF2BB8DC;
const int _kVhi = 0xFF7FE8FF;
const int _kVbr = 0xFFD6FBFF;
const int _kBolt = 0xFFEAFDFF;
const int _kBoltEdge = 0xFF9BEEFF;

const List<int> _glassFull = [
  0xFF0A3A4A, 0xFF0E6F88, 0xFF19A8C8, 0xFF45D8F0, 0xFF8AF0FF,
];
const int _glassCore = 0xFFCDF6FF;
const List<int> _glassDead = [
  0xFF10131F, 0xFF191C2E, 0xFF22253B, 0xFF2B2E47, 0xFF343858,
];
const int _deadCore = 0xFF3A3F5C;

// ── geometry (verbatim) ──────────────────────────────────────────────────────
const int _nw = 18, _nh = 26;
const int _wx = 5, _wy = 6, _ww = 8, _wh = 14;
const double _wcx = _wx + (_ww - 1) / 2; // 8.5
const double _wcy = _wy + (_wh - 1) / 2; // 12.5

/// Lightning bolt glyph — absolute cells, centred in the glass (verbatim).
const List<List<int>> _bolt = [
  [9, 7], [10, 7],
  [8, 8], [9, 8],
  [7, 9], [8, 9], [9, 9],
  [6, 10], [7, 10], [8, 10],
  [6, 11], [7, 11], [8, 11], [9, 11], [10, 11],
  [7, 12], [8, 12], [9, 12], [10, 12],
  [8, 13], [9, 13], [10, 13],
  [9, 14], [10, 14],
  [8, 15], [9, 15],
  [8, 16],
];
const List<List<int>> _boltHot = [[8, 11], [9, 11], [8, 12]];

const List<List<int>> _specks = [
  [6, 8], [11, 9], [7, 17], [10, 16], [6, 14], [11, 13],
];

/// Darken [argb] toward black by [f] (0..1; 1 = unchanged), with the handoff's
/// `Math.round` rounding (ties → +∞). For the factors used (≥0 inputs) this
/// equals Dart's round, but the explicit floor keeps it provably faithful.
int _shade(int argb, double f) {
  final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  int k(int v) => (v * f + 0.5).floor().clamp(0, 255);
  return 0xFF000000 | (k(r) << 16) | (k(g) << 8) | k(b);
}

class _Pen {
  _Pen(this.canvas, this.s) : _p = Paint();
  final Canvas canvas;
  final double s;
  final Paint _p;

  void px(int x, int y, int argb) {
    _p.color = Color(argb);
    canvas.drawRect(Rect.fromLTWH(x * s, y * s, s, s), _p);
  }

  void rect(num x, num y, num w, num h, int argb) {
    _p.color = Color(argb);
    canvas.drawRect(Rect.fromLTWH(x * s, y * s, w * s, h * s), _p);
  }

  void hline(int x, int y, int w, int argb) => rect(x, y, w, 1, argb);
  void vline(int x, int y, int h, int argb) => rect(x, y, 1, h, argb);
}

/// Beveled metal block: outline + fill, top/left lit, bottom/right shadowed
/// (verbatim `bevelBox`; [top] defaults to [lit]).
void _bevelBox(
  _Pen p, int x, int y, int w, int h, int fill, int lit, int shade, [int? top]) {
  p.rect(x, y, w, h, _kOut);
  p.rect(x + 1, y + 1, w - 2, h - 2, fill);
  p.hline(x + 1, y + 1, w - 2, top ?? lit);
  p.vline(x + 1, y + 1, h - 2, lit);
  p.hline(x + 1, y + h - 2, w - 2, shade);
  p.vline(x + w - 2, y + 1, h - 2, shade);
}

/// Paint the glass interior (verbatim `paintGlass`). [fillTop] is the topmost
/// charged row (recharge sweep) — defaults to [_wy] (fully charged).
void _paintGlass(_Pen p, double lvl, bool dead, int fillTop) {
  for (var y = _wy; y < _wy + _wh; y++) {
    for (var x = _wx; x < _wx + _ww; x++) {
      final charged = y >= fillTop;
      final ramp = charged ? (dead ? _glassDead : _glassFull) : _glassDead;
      final co = charged ? (dead ? _deadCore : _glassCore) : _deadCore;
      final dx = x - _wcx, dy = y - _wcy;
      final d = math.sqrt(dx * dx + dy * dy);
      final idx = d < 1.4
          ? -1
          : d < 2.6
              ? 4
              : d < 3.8
                  ? 3
                  : d < 5.0
                      ? 2
                      : d < 6.4
                          ? 1
                          : 0;
      var c = idx < 0 ? co : ramp[idx];
      if (((y - _wy) & 1) == 0 && idx > 0) c = _shade(c, 0.82);
      if (charged && lvl < 1) c = _shade(c, 0.5 + 0.5 * lvl);
      p.px(x, y, c);
    }
  }
  for (final s in _specks) {
    if (s[1] >= fillTop) p.px(s[0], s[1], dead ? 0xFF2F3350 : 0xFFBDF2FF);
  }
  if (fillTop > _wy && fillTop < _wy + _wh) {
    for (var x = _wx; x < _wx + _ww; x++) {
      p.px(x, fillTop, 0xFFD8FBFF);
    }
  }
}

/// Paint the whole cell into an 18×26 grid scaled by [s] (verbatim `paintCell`).
void paintEnergyCell(
  Canvas canvas,
  double s, {
  double lvl = 1,
  bool dead = false,
  int? fillTop,
}) {
  final p = _Pen(canvas, s);
  final ft = fillTop ?? _wy;

  // side rails (caps overlap them)
  _bevelBox(p, 2, 4, 3, 18, _kD1, _kL1, _kD2, _kL1);
  _bevelBox(p, 13, 4, 3, 18, _kD1, _kL1, _kD2, _kL1);
  final tip = dead ? _kD2 : _kVmd, tipHi = dead ? _kD1 : _kVhi;
  p.px(4, 6, tip); p.px(4, 7, tipHi); p.px(4, 18, tipHi); p.px(4, 19, tip);
  p.px(13, 6, tip); p.px(13, 7, tipHi); p.px(13, 18, tipHi); p.px(13, 19, tip);

  // glass core (recessed socket behind it)
  p.rect(_wx - 1, _wy - 1, _ww + 2, _wh + 2, _kOut);
  _paintGlass(p, lvl, dead, ft);

  // top cap
  _bevelBox(p, 1, 1, 16, 5, _kM, _kL2, _kD1, _kL3);
  p.hline(2, 5, 14, _kD2);
  p.rect(6, 2, 6, 2, _kOut);
  final vt = dead ? _kD1 : _kVhi, vtb = dead ? _kL1 : _kVbr;
  p.hline(7, 3, 4, vt); p.px(8, 3, vtb); p.px(9, 3, vtb);
  p.px(1, 3, _kL1); p.px(16, 3, _kL1);

  // bottom cap
  _bevelBox(p, 1, 20, 16, 5, _kM, _kL2, _kD1, _kL3);
  p.hline(2, 20, 14, _kL3);
  p.rect(6, 22, 6, 2, _kOut);
  p.hline(7, 22, 4, vt); p.px(8, 22, vtb); p.px(9, 22, vtb);
  p.px(1, 22, _kL1); p.px(16, 22, _kL1);

  // the bolt
  final bc = dead ? 0xFF454A68 : _kBolt;
  final bce = dead ? 0xFF363A55 : _kBoltEdge;
  final bhot = dead ? 0xFF4E5474 : 0xFFFFFFFF;
  for (final b in _bolt) {
    p.px(b[0], b[1], bc);
  }
  if (!dead) {
    p.px(6, 12, bce); p.px(10, 10, bce); p.px(10, 11, bce); p.px(7, 13, bce);
  }
  for (final b in _boltHot) {
    p.px(b[0], b[1], bhot);
  }
}

/// CustomPainter wrapper — renders one cell at the given integer [scale] with
/// crisp nearest-neighbour edges.
class EnergyCellPainter extends CustomPainter {
  const EnergyCellPainter({this.dead = false});

  final bool dead;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _nw;
    paintEnergyCell(canvas, s, dead: dead);
  }

  @override
  bool shouldRepaint(covariant EnergyCellPainter old) => old.dead != dead;
}

/// BIT's energy cell as a widget: an 18×26 sprite blitted at an **integer
/// [scale]** (FilterQuality.none equivalent — `CustomPaint` draws crisp), with
/// a subtle breathing **cyan bloom** behind a charged cell. The bloom is the
/// "not noisy, not static" idle (one small, slow, low-contrast element — the
/// app's ambient-motion dial) and is **killed on [dead]** and under reduced
/// motion (a still, lit cell — the handoff's static fallback).
class EnergyCell extends StatefulWidget {
  const EnergyCell({
    super.key,
    this.scale = 1,
    this.dead = false,
    this.glow = true,
  });

  /// Whole-number blit scale; the cell is `18·scale × 26·scale` logical px.
  final int scale;
  final bool dead;

  /// Whether the breathing bloom may show (charged only; off when [dead]).
  final bool glow;

  @override
  State<EnergyCell> createState() => _EnergyCellState();
}

class _EnergyCellState extends State<EnergyCell>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final ValueNotifier<double> _t = ValueNotifier<double>(0);
  bool _reduce = false;

  bool get _bloomOn => widget.glow && !widget.dead && !_reduce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_bloomOn) {
      _ticker ??= createTicker((d) => _t.value = d.inMicroseconds / 1e6);
      if (!_ticker!.isActive) _ticker!.start();
    } else {
      _ticker?.stop();
      _t.value = 0;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = (_nw * widget.scale).toDouble();
    final h = (_nh * widget.scale).toDouble();
    final cell = CustomPaint(
      size: Size(w, h),
      painter: EnergyCellPainter(dead: widget.dead),
    );
    if (!widget.glow || widget.dead) {
      return SizedBox(width: w, height: h, child: cell);
    }
    // Soft cyan bloom behind the cell — breathes when motion is on, else a
    // fixed dim glow (handoff: 0.78 + 0.22·sin(t/700)).
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _t,
                builder: (context, t, _) {
                  final o = _reduce ? 0.5 : 0.78 + 0.22 * math.sin(t * 1000 / 700);
                  return CustomPaint(painter: _BloomPainter(o.clamp(0.0, 1.0)));
                },
              ),
            ),
          ),
          cell,
        ],
      ),
    );
  }
}

/// A soft radial cyan glow (the cell's bloom) — blurred so it respects the
/// pixel silhouette without a hard rectangle.
class _BloomPainter extends CustomPainter {
  const _BloomPainter(this.opacity);
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.95;
    canvas.drawCircle(
      c,
      r,
      Paint()
        // BIT's energy family — the brand cyan token (the glow is brand, not
        // part of the cell's procedural sprite palette).
        ..color = kCyan.withValues(alpha: 0.34 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _BloomPainter old) => old.opacity != opacity;
}
