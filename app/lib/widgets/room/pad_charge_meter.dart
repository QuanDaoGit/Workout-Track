import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The pad's **integrated charge meter** — a faithful port of the `pad-charge-meter`
/// handoff (`assets/handoff_BIT_expedition/pad-charge-meter/Energy Pad.html`,
/// `paintMeter`). The pad sprite's own cyan readout strip (native px **x25–82,
/// y21–24**) is repainted as a **3-segment LED**: it lights 0–3 cyan for BIT's
/// banked expedition charges. The pad sprite and dimensions are unchanged —
/// nothing protrudes; this is the dock's own integrated level bar.
///
/// Painted in the sprite's **native 108×40** grid scaled to the rendered pad box,
/// so it tracks the pad image's `BoxFit.fill` stretch 1:1 and the segments stay
/// locked to the strip rows. A static **armed glow** (cyan, opacity
/// `0.30 + 0.20·charges`) sits behind the strip when the dock can dispatch — the
/// handoff's value, no breathing (so the meter needs no ticker).
///
/// The strip's lit/recess/notch colours are the sprite's own pixels (raw hex —
/// the documented procedural sprite-art exception, like `bit_companion`'s
/// `_metal`); only the brand glow uses the [kCyan] token.
class PadChargeMeterPainter extends CustomPainter {
  const PadChargeMeterPainter({
    required this.charges,
    required this.armed,
    this.pulse = 0,
  });

  /// Banked charges 0–3 — how many segments light.
  final int charges;

  /// Whether a dispatch is actually possible right now — shows the armed glow
  /// (the app's `canDispatch`; the handoff couples it to `charge>0`, but the app
  /// also gates on idle / not-capped / no-haul).
  final bool armed;

  /// 0→1 one-shot "a charge just landed" flash on the **newly-lit** segment
  /// (`charges-1`). 0 = no flash (the steady meter). Not in the handoff — an
  /// app-side reward beat for the rare, earned charge arrival; reduced-motion
  /// stays at 0 (no flash).
  final double pulse;

  // ── geometry (verbatim) ──────────────────────────────────────────────────
  static const List<List<int>> _segs = [
    [25, 42], [45, 62], [65, 82],
  ];
  static const List<List<int>> _notch = [
    [43, 44], [63, 64],
  ];
  static const int _y0 = 21, _y1 = 24;

  // ── strip's own colours (verbatim) ───────────────────────────────────────
  static const List<int> _lit = [0xFF57DBFF, 0xFFAEEEFF, 0xFFAEEEFF, 0xFF1C6E92];
  static const List<int> _off = [0xFF1A1C32, 0xFF111222, 0xFF111222, 0xFF0C0D1A];
  static const int _dark = 0xFF0A0B14;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 108.0, sy = size.height / 40.0;
    final p = Paint()..isAntiAlias = false;
    void px(num x, num y, num w, num h, int argb) {
      p.color = Color(argb);
      canvas.drawRect(Rect.fromLTWH(x * sx, y * sy, w * sx, h * sy), p);
    }

    // armed glow (behind the strip) — a soft cyan halo whose intensity tracks
    // the charge count (handoff `.arm`: opacity 0.30 + 0.20·charge, peak α .5).
    if (armed && charges > 0) {
      final o = (0.30 + 0.20 * charges).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(53.5 * sx, 22.5 * sy),
          width: 80 * sx,
          height: 26 * sy,
        ),
        Paint()
          ..color = kCyan.withValues(alpha: 0.5 * o)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * sx),
      );
    }

    // 1) cover the whole strip (x25..82) with the dark recess, per row.
    for (var y = _y0; y <= _y1; y++) {
      px(25, y, 58, 1, _off[y - _y0]);
    }
    // 2) light the segments (i < charges) in the strip's authentic cyan.
    for (var i = 0; i < 3; i++) {
      final s = _segs[i];
      final pal = i < charges ? _lit : _off;
      final w = s[1] - s[0] + 1;
      for (var y = _y0; y <= _y1; y++) {
        px(s[0], y, w, 1, pal[y - _y0]);
      }
    }
    // 3) cut the two notch dividers (1px taller so the cells read separate).
    for (final n in _notch) {
      px(n[0], _y0 - 1, n[1] - n[0] + 1, (_y1 - _y0) + 3, _dark);
    }

    // 4) "a charge landed" flash on the newly-lit segment (charges-1): a quick
    // near-white bloom over the cell + a soft cyan halo, both scaled by the
    // pulse's rise-and-fall. On top of everything (it's a momentary highlight).
    if (pulse > 0 && charges > 0 && charges <= 3) {
      final inten = math.sin(math.pi * pulse.clamp(0.0, 1.0));
      final s = _segs[charges - 1];
      final fx = s[0] * sx, fw = (s[1] - s[0] + 1) * sx;
      final fy = _y0 * sy, fh = (_y1 - _y0 + 1) * sy;
      canvas.drawRect(
        Rect.fromLTWH(fx - 5 * sx, fy - 5 * sy, fw + 10 * sx, fh + 10 * sy),
        Paint()
          ..color = kCyan.withValues(alpha: 0.55 * inten)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * sx),
      );
      p.color = const Color(0xFFD6FBFF).withValues(alpha: 0.85 * inten);
      canvas.drawRect(Rect.fromLTWH(fx, fy, fw, fh), p);
    }
  }

  @override
  bool shouldRepaint(covariant PadChargeMeterPainter old) =>
      old.charges != charges || old.armed != armed || old.pulse != pulse;
}
