import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One launch particle — **immutable**, generated once at launch start (a seeded
/// `Random`, never read in `paint()`). Its on-screen position is a **pure
/// function of elapsed time** (birth + velocity + gravity), so a frame is stable
/// across repaints / skipped frames (Codex: no RNG-walk in paint). Coordinates
/// are room px; velocities are handoff units scaled by `kx` in the painter.
@immutable
class LaunchSpark {
  const LaunchSpark({
    required this.birth,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
    required this.color,
    this.core = false,
    this.coreColor,
  });

  final double birth, x, y, vx, vy, life, size;
  final Color color;

  /// A core flash = an expanding bright square (the ignition/exit-pop centre).
  final bool core;
  final Color? coreColor;
}

// Turquoise launch family (the handoff's cyan family, recoloured per "except
// colour"). Procedural sprite-art palette, not brand tokens.
const Color _spark = Color(0xFF5EE8DD);
const List<Color> _burstCols = [
  Color(0xFF5EE8DD),
  Color(0xFFAEF6EF),
  Color(0xFF2BB2A8),
];
const Color _coreCol = Color(0xFFEAFFFB);
const List<Color> _exitCols = [
  Color(0xFFAEF6EF),
  Color(0xFF5EE8DD),
  Color(0xFFEAFFFB),
];

/// Generate the full launch particle set once, deterministically from [seed]:
/// the inward charge sparks (P0), the ignition burst at the emitter (P1, birth
/// 350) and the exit-pop burst at the top (P3, birth 1450). A verbatim port of
/// `playLaunch`'s `spawnBurst` + charge loop.
List<LaunchSpark> generateLaunchSparks({
  required int seed,
  required double emitterX,
  required double emitterY,
  required double exitY,
}) {
  final rnd = math.Random(seed);
  final out = <LaunchSpark>[];

  void spawnBurst(
    double birth,
    double x,
    double y,
    List<Color> cols,
    int n,
    double spd,
    double coreLife,
    Color core,
  ) {
    for (var i = 0; i < n; i++) {
      final ang = math.pi * 2 * i / n + rnd.nextDouble() * 0.35;
      final s = spd * (0.55 + rnd.nextDouble() * 0.9);
      out.add(LaunchSpark(
        birth: birth,
        x: x,
        y: y,
        vx: math.cos(ang) * s,
        vy: math.sin(ang) * s,
        life: 300 + rnd.nextDouble() * 280,
        size: rnd.nextDouble() < 0.5 ? 3 : 4,
        color: cols[i % cols.length],
      ));
    }
    out.add(LaunchSpark(
      birth: birth,
      x: x,
      y: y,
      vx: 0,
      vy: 0,
      life: coreLife,
      size: 0,
      color: core,
      core: true,
      coreColor: core,
    ));
  }

  // P0 charge — sparks pulled INWARD toward the emitter, spawned 0–350ms.
  for (var e = 0; e < 350; e += 38) {
    final a0 = rnd.nextDouble() * math.pi * 2, r = 22 + rnd.nextDouble() * 10;
    out.add(LaunchSpark(
      birth: e.toDouble(),
      x: emitterX + math.cos(a0) * r,
      y: emitterY + math.sin(a0) * r * 0.6,
      vx: -math.cos(a0) * 1.3,
      vy: -math.sin(a0) * 0.8,
      life: 240,
      size: 3,
      color: _spark,
    ));
  }
  // P1 ignition burst at the emitter mouth + bright core flash.
  spawnBurst(350, emitterX, emitterY, _burstCols, 22, 3.0, 240, _coreCol);
  // P3 exit-pop burst where BIT vanishes off the top + white core.
  spawnBurst(1450, emitterX, exitY, _exitCols, 16, 2.4, 220, const Color(0xFFFFFFFF));
  return out;
}

/// Paints the send-off FX from `elapsedMs` (= the launch controller × 2000):
/// the pre-generated sparks/bursts, plus BIT's vapor trail and vertical
/// speed-streaks during the ascent — all pure functions of elapsed time.
class LaunchFxPainter extends CustomPainter {
  const LaunchFxPainter({
    required this.sparks,
    required this.elapsedMs,
    required this.emitterX,
    required this.bitCenterY,
    required this.bitSpan,
    required this.kx,
  });

  final List<LaunchSpark> sparks;
  final double elapsedMs;
  final double emitterX, bitCenterY, bitSpan, kx;

  /// BIT's vertical offset over the launch (crouch → spring → ease-in ascent),
  /// the same profile the room applies to BIT — so the trail/streaks line up.
  double _bitDy(double e) {
    if (e < 350) return 6 * math.sin((e / 350) * math.pi * 0.5) * kx;
    if (e < 520) return 6 * (1 - (e - 350) / 170) * kx;
    if (e < 1250) {
      final a = (e - 520) / 730;
      return -bitSpan * (a * a);
    }
    return -bitSpan;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final e = elapsedMs;
    final p = Paint()..isAntiAlias = false;

    // ── vapor trail (ascent) — BIT's fading past positions ──
    if (e >= 520) {
      for (var k = 0; k < 28; k++) {
        final pe = e - k * 16.0;
        if (pe < 520) break;
        final ta = 1 - (k * 16.0) / 420;
        if (ta <= 0) break;
        final ty = bitCenterY + _bitDy(pe);
        p.color = const Color(0xFF2BD6C8).withValues(alpha: (ta * 0.5).clamp(0.0, 1.0));
        canvas.drawRect(Rect.fromLTWH(emitterX - kx, ty, 2 * kx, 2 * kx), p);
      }
    }

    // ── speed-streaks (ascent) — vertical lines below BIT ──
    if (e >= 520 && e < 1250) {
      final a = (e - 520) / 730;
      final spd = math.min(1.0, a * 1.4);
      final op = a < 0.7 ? 1.0 : math.max(0.0, 1 - (a - 0.7) / 0.3);
      final by = bitCenterY + _bitDy(e);
      p.color = const Color(0xFF73F2E8).withValues(alpha: (0.5 * op).clamp(0.0, 1.0));
      for (var s2 = 0; s2 < 5; s2++) {
        final sx = emitterX + (s2 - 2) * 5 * kx;
        canvas.drawRect(
          Rect.fromLTWH(sx, by + 12 * kx, 1 * kx, (8 + 40 * spd) * kx),
          p,
        );
      }
    }

    // ── sparks + bursts + core flashes (pure function of elapsed) ──
    for (final sp in sparks) {
      final age = e - sp.birth;
      if (age < 0 || age > sp.life) continue;
      final lifeF = age / sp.life;
      if (sp.core) {
        final r = (3 + 11 * lifeF) * kx;
        p.color = (sp.coreColor ?? _coreCol)
            .withValues(alpha: ((1 - lifeF) * 0.8).clamp(0.0, 1.0));
        canvas.drawRect(
          Rect.fromLTWH(sp.x - r, sp.y - r, 2 * r + kx, 2 * r + kx),
          p,
        );
        continue;
      }
      final px = sp.x + sp.vx * 0.06 * age * kx;
      final py =
          sp.y + sp.vy * 0.06 * age * kx + 0.0003 * age * age * kx; // gravity
      p.color = sp.color.withValues(alpha: (1 - lifeF).clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromLTWH(px, py, sp.size * kx, sp.size * kx), p);
    }
  }

  @override
  bool shouldRepaint(covariant LaunchFxPainter old) =>
      old.elapsedMs != elapsedMs || !identical(old.sparks, sparks);
}
