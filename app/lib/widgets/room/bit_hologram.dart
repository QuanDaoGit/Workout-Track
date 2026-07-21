import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../companion/bit_companion.dart' show paintBitSprite, bitNoise;
import '../companion/bit_core_engine.dart' show BitMood;

/// The **away-state hologram** — a faithful port of the handoff's `holo-bit.js`:
/// BIT's **real sprite** (`paintBitSprite`, idle bob/blink from the room clock),
/// post-processed into a holographic projection — alpha flicker, vertical
/// jitter, a turquoise tint, CRT scanlines, a sweeping roll bar and an
/// occasional glitch slice (all **over BIT's pixels only**, `srcATOP`, exactly
/// like the source) — framed in a dithered **projection rig** (emitter field +
/// containment brackets + scan-planes). The only deviation from the handoff is
/// the colour: cyan → BIT's app turquoise.
///
/// Drives off the shared room clock, already frozen under reduced motion and
/// `TickerMode`-muted off-route, so it needs no ticker, can't hang
/// `pumpAndSettle`, and won't repaint off-screen. Reduced motion → a single
/// static still. Glitch/jitter are decided by a **time-hash** (`bitNoise`), not
/// `Random`, so a frame is a pure function of time (deterministic goldens).
class BitHologramPainter extends CustomPainter {
  BitHologramPainter({
    required this.time,
    required this.reduceMotion,
    this.forceGlitch = false,
    this.ignitionStartSeconds,
  }) : super(repaint: time);

  final ValueListenable<double> time;
  final bool reduceMotion;

  /// Test hook: force the glitch slice on for a deterministic golden.
  final bool forceGlitch;

  /// The room-clock value (`time`'s seconds) at which the hologram begins its
  /// **flicker ignition** — the struggling-tube power-on (`holo-bit.js`'s
  /// `igniteEnv`). `null` ⇒ already **online** (steady projection): the only
  /// state the static goldens and a cold mid-expedition reopen ever see, so the
  /// steady render stays byte-identical. Reduced motion forces the static still
  /// regardless (no gap, no stutter — the source's `begin()` RM path).
  final double? ignitionStartSeconds;

  /// The ignition envelope (ms → 0..1): a struggling-fluorescent-tube **stutter
  /// that catches**, ported verbatim from `holo-bit.js`'s `igniteEnv`. Coarse
  /// keyframes read at the ~20fps loop so the stutter stays chunky; ≥900ms ⇒
  /// fully online.
  @visibleForTesting
  static double igniteEnv(double ms) {
    if (ms >= 900) return 1;
    const k = <List<double>>[
      [0, 0.0],
      [50, 0.9],
      [110, 0.04],
      [180, 0.62],
      [250, 0.0],
      [300, 0.72],
      [380, 0.08],
      [440, 1.0],
      [520, 0.18],
      [600, 0.92],
      [700, 0.4],
      [820, 1.0],
      [900, 1.0],
    ];
    for (var i = 1; i < k.length; i++) {
      if (ms <= k[i][0]) {
        final a = k[i - 1], b = k[i];
        final u = (ms - a[0]) / (b[0] - a[0]);
        return a[1] + (b[1] - a[1]) * u;
      }
    }
    return 1;
  }

  // Turquoise projection palette (the handoff's cyan family, recoloured).
  static const Color _tint = Color(0xFF73F2E8); // flattens BIT to monochrome
  static const Color _scan = Color(0xFF02141E); // CRT scanline dark
  static const Color _roll = Color(0xFFCDFBF4); // roll-bar pale
  static const List<Color?> _tier = [
    null,
    Color(0xFF0E6E70),
    Color(0xFF16A39A),
    Color(0xFF46D0C4),
  ];
  static const List<double> _tierA = [0, 0.16, 0.30, 0.48];
  static const Color _bracket = Color(0xFF73F2E8);
  static const List<List<int>> _bayer = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = reduceMotion ? 5.0 : (time.value * 20).floorToDouble() / 20;
    // Ignition envelope: null start (online) or reduced motion ⇒ 1.0, which
    // collapses `fade` and the `(0.3 + 0.7·ign)` factor below to the steady
    // projection (byte-identical to the online render).
    final ign = (reduceMotion || ignitionStartSeconds == null)
        ? 1.0
        : igniteEnv(
            ((t - ignitionStartSeconds!) * 1000).clamp(0.0, double.infinity),
          );
    final fade = ign; // BIT's opacity follows the ignition
    final flick = reduceMotion
        ? 1.0
        : ((0.82 +
                      0.18 * math.sin(t * 7) -
                      (bitNoise(t * 0.9) < 0.08 ? bitNoise(t * 1.3) * 0.3 : 0)) *
                  (0.3 + 0.7 * ign)) // the rig stutters on with the image
              .clamp(0.0, 1.0);

    // BIT fills the box width at the same size as the home companion; the box
    // is taller so the rig frames him above and below.
    final s = size.width / 44.0;
    final spriteW = 44 * s, spriteH = 44 * s;
    final ox = 0.0, oy = (size.height - spriteH) / 2;

    _drawRig(canvas, size, s, oy, spriteH, flick, t);
    _drawHoloBit(canvas, s, ox, oy, spriteW, spriteH, flick, fade, t);
  }

  // ── the hologram of BIT (his real sprite, post-processed) ──────────────────
  void _drawHoloBit(
    Canvas canvas,
    double s,
    double ox,
    double oy,
    double spriteW,
    double spriteH,
    double flick,
    double fade,
    double t,
  ) {
    final jit = (!reduceMotion && bitNoise(t * 0.5 + 3) < 0.07)
        ? (bitNoise(t * 4) * 3 - 1.5) * s
        : 0.0;
    final alpha =
        ((reduceMotion ? 0.44 : 0.44 + 0.12 * math.sin(t * 6)) * flick * fade)
            .clamp(0.0, 1.0);

    final glitch = forceGlitch || (!reduceMotion && bitNoise(t * 1.7 + 13) < 0.05);
    final gh = glitch ? (2 + (bitNoise(t * 1.1) * 5).floor()) * s : 0.0;
    final gy = glitch ? (bitNoise(t * 2.3) * (spriteH - 8 * s)) : 0.0;
    final gdx = glitch ? ((bitNoise(t * 3.1) * 7).floor() - 3) * s : 0.0;

    void drawBit(double dx) {
      canvas.save();
      canvas.translate(ox + dx, oy + jit);
      paintBitSprite(
        canvas,
        s,
        tms: t * 1000,
        mood: BitMood.neutral,
        opacity: alpha,
        reduceMotion: reduceMotion,
      );
      canvas.restore();
    }

    final tightBounds = Rect.fromLTWH(ox, oy + jit, spriteW, spriteH);
    canvas.saveLayer(tightBounds, Paint());

    if (glitch) {
      // Three clipped passes: above-band normal, below-band normal, band
      // translated → the band shifts, the original band is never left behind.
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(ox, oy + jit, spriteW, gy));
      drawBit(0);
      canvas.restore();
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(ox, oy + jit + gy + gh, spriteW, spriteH - gy - gh),
      );
      drawBit(0);
      canvas.restore();
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(ox, oy + jit + gy, spriteW, gh));
      drawBit(gdx);
      canvas.restore();
    } else {
      drawBit(0);
    }

    // tint + scanlines + roll bar — all srcATOP, so they fall on BIT's pixels
    // only (faithful to holo-bit.js).
    // tint + scanlines + roll bar — all srcATOP (BIT's pixels only), each
    // scaled by `fade` so they ramp in with the ignition (faithful to
    // holo-bit.js; `fade=1` when online ⇒ unchanged).
    Paint atop(Color c, double a) => Paint()
      ..color = c.withValues(alpha: a.clamp(0.0, 1.0))
      ..blendMode = BlendMode.srcATop;
    canvas.drawRect(tightBounds, atop(_tint, 0.32 * fade));
    final scan = atop(_scan, 0.42 * fade);
    for (var y = oy + jit; y < oy + jit + spriteH; y += 2 * s) {
      canvas.drawRect(Rect.fromLTWH(ox, y, spriteW, 1 * s), scan);
    }
    final rollY =
        oy + jit + (((t * 46) % (44 + 8)) - 8) * s; // sweep, in native units
    canvas.drawRect(
      Rect.fromLTWH(ox, rollY, spriteW, 6 * s),
      atop(_roll, 0.12 * fade),
    );

    canvas.restore();
  }

  // ── the projection rig (dithered, behind BIT) ──────────────────────────────
  void _drawRig(
    Canvas canvas,
    Size size,
    double s,
    double oy,
    double spriteH,
    double flick,
    double t,
  ) {
    final cx = size.width / 2;
    final emY = size.height - 2 * s; // emitter plane (toward the pad)
    final topY = oy - 6 * s; // top of the projected volume (above BIT)
    final span = (emY - topY).clamp(1.0, double.infinity);
    final halfBot = size.width * 0.42, halfTop = size.width * 0.5;
    double halfAt(double y) {
      final u = ((emY - y) / span).clamp(0.0, 1.0);
      return halfBot + (halfTop - halfBot) * u;
    }

    final paint = Paint()..isAntiAlias = false;
    void plot(double xPx, double yPx, double v, double br) {
      if (v <= 0) return;
      final xi = (xPx / s).floor(), yi = (yPx / s).floor();
      final th = (_bayer[yi & 3][xi & 3] + 0.5) / 16;
      var q = v * 3, lvl = q.floor();
      if (q - lvl > th) lvl++;
      if (lvl <= 0) return;
      if (lvl > 3) lvl = 3;
      paint.color = _tier[lvl]!.withValues(
        alpha: (_tierA[lvl] * br * flick).clamp(0.0, 1.0),
      );
      canvas.drawRect(Rect.fromLTWH(xi * s, yi * s, s, s), paint);
    }

    // 1) emitter field — pulsing dithered band at the pad mouth.
    final pulse = reduceMotion ? 0.7 : 0.55 + 0.45 * math.sin(t * 5);
    for (var y = emY; y <= emY + 5 * s; y += s) {
      for (var x = cx - halfBot; x <= cx + halfBot; x += s) {
        final dxn = (x - cx).abs() / halfBot;
        if (dxn > 1) continue;
        plot(x, y, (1 - dxn * dxn) * pulse * 0.9, 1);
      }
    }

    // 2) containment brackets — corner frames top & bottom of the volume.
    void bracket(double y, int dir) {
      final hw = halfAt(y), len = 9 * s;
      paint.color = _bracket.withValues(alpha: (0.7 * flick).clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromLTWH(cx - hw, y, len, s), paint);
      canvas.drawRect(Rect.fromLTWH(cx + hw - len + s, y, len, s), paint);
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(Rect.fromLTWH(cx - hw, y + dir * i * s, s, s), paint);
        canvas.drawRect(Rect.fromLTWH(cx + hw, y + dir * i * s, s, s), paint);
      }
      paint.color = _bracket.withValues(alpha: (0.4 * flick).clamp(0.0, 1.0));
      for (var x = cx - hw + len; x <= cx + hw - len; x += 3 * s) {
        canvas.drawRect(Rect.fromLTWH(x, y, s, s), paint);
      }
    }

    bracket(topY, 1);
    bracket(emY - 2 * s, -1);

    // 3) scan-planes — 2 horizontal dithered lines sweeping up the volume.
    for (var p = 0; p < 2; p++) {
      final prog = reduceMotion
          ? (p == 0 ? 0.5 : 0.0)
          : ((t * 0.32 + p * 0.5) % 1);
      final py = emY - prog * span;
      final hw2 = halfAt(py).clamp(1.0, double.infinity);
      final bright = 0.5 + 0.5 * math.sin(prog * math.pi);
      for (var x = cx - hw2; x <= cx + hw2; x += s) {
        final edge = 1 - (x - cx).abs() / hw2 * 0.35;
        plot(x, py, 0.7 * edge * bright, 1);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BitHologramPainter old) =>
      old.reduceMotion != reduceMotion ||
      old.forceGlitch != forceGlitch ||
      old.ignitionStartSeconds != ignitionStartSeconds;
}
