import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Shared faceless **drone-core** sprite engine for BIT — the pixel grids,
/// palettes, plate ring, easing, and painters reused by both [BitBootCore] (the
/// cold-open boot) and `BitMoodCore` (the faceless mood presence).
///
/// A verbatim port of the prototype's `bit-sprite.js`: a 16×16 bevelled core +
/// four cut-corner plates on a 44×44 native grid, with a six-tone metal shade
/// map (`L` top-highlight, `l` left-light, `m` base, `M` right-shade,
/// `d` underside, `k` outline) plus cyan lamp dots (`c`/`C`). Painted aliased
/// (`isAntiAlias = false`) for crisp pixels. Zero image assets. The inset screen
/// is **faceless** by default; [drawBitFace] reveals the eyes for the
/// Solution-screen face reveal (screen 3).

/// Core centre in native (44-unit) coordinates.
const double bitCoreCx = 22;
const double bitCoreCy = 22;

/// Plates dock at this radius from the core centre; [dockGap] pushes the four
/// docked plates slightly off the body so they read as detached.
const double plateRadius = 12.5;
const double dockGap = 1.5;

// ── palettes ─────────────────────────────────────────────────────────────────
/// BIT's reserved machine-light hue — turquoise (`#17D6CC`), deliberately
/// between recovery-cyan (`kCyan`) and tap-green (`kNeon`) so it collides with no
/// status colour. Canonical procedural sprite-art (like [metal]/[dim]), not a
/// brand token. Used for every "BIT's own light" glow/pool/screen across the
/// boot + mood cores so they never drift back to recovery-cyan.
const Color bitGlow = Color(0xFF17D6CC);

/// Fully-lit metal shade map. Lamps (`c`/`C`) are BIT's turquoise.
const Map<String, Color> metal = {
  'k': Color(0xFF0B0B14),
  'd': Color(0xFF1E1E2E),
  'q': Color(0xFF0A0A12),
  'm': Color(0xFF34344E),
  'M': Color(0xFF2A2A40),
  'l': Color(0xFF4B4B6E),
  'L': Color(0xFF6E6E92),
  'c': Color(0xFF15B8B0),
  'C': Color(0xFF5EE8DD),
};

/// Dimmed (dormant) shade map — same metal, cooled turquoise lamps (derived
/// from the lit pair; the colour pass spec'd only the lit lamps).
const Map<String, Color> dim = {
  'k': Color(0xFF0B0B14),
  'd': Color(0xFF1E1E2E),
  'q': Color(0xFF0A0A12),
  'm': Color(0xFF34344E),
  'M': Color(0xFF2A2A40),
  'l': Color(0xFF4B4B6E),
  'L': Color(0xFF6E6E92),
  'c': Color(0xFF0D3F3C),
  'C': Color(0xFF155F58),
};

// ── canonical BIT face (single source of truth for the eyes/screen) ──────────
// BIT's neutral expression, kept identical to the companion engine + the start-
// gate sprite so the screen-3 reveal lands on the *same* face seen everywhere
// else. Screen-local coords on the 10×10 inset (which sits at native (17,17)).
// Raw colours are procedural sprite-art (documented exception, like [metal]).
const Color bitEyeColor = Color(0xFFFFFFFF);
// Neutral (calm, turquoise) — BIT's resting face.
const List<Color> bitFaceRamp = [
  Color(0xFF0A5A5E), Color(0xFF0F9EA0), Color(0xFF23D6CC), Color(0xFF73F2E8),
];
const List<List<int>> _bitEyesOpen = [
  [3, 3], [3, 4], [6, 3], [6, 4],
];
const List<List<int>> _bitEyesBlink = [
  [3, 4], [6, 4],
];
const List<List<int>> _bitMouth = [
  [4, 6], [5, 6],
];
// Cheer (energetic, amber) — wide eyes + a grin, the screen-3 reveal burst.
// Amber matches the mood system (cheer = reward/level-up colour); BIT then
// settles to the neutral turquoise above. `bitCheerGlow` is the cheer sprite-
// light (≈ kAmber #FFD700), the engine's amber counterpart to [bitGlow].
const Color bitCheerGlow = Color(0xFFFFD700);
const List<Color> bitCheerRamp = [
  Color(0xFF7A5200), Color(0xFFC99400), Color(0xFFFFD21F), Color(0xFFFFEC8C),
];
const List<List<int>> _bitCheerEyes = [
  [2, 2], [3, 2], [2, 3], [3, 3], [6, 2], [7, 2], [6, 3], [7, 3],
];
const List<List<int>> _bitCheerBlink = [
  [2, 3], [3, 3], [6, 3], [7, 3],
];
const List<List<int>> _bitCheerMouth = [
  [4, 6], [5, 6], [4, 7], [5, 7],
];

// ── grid builders (ported verbatim from bit-sprite.js) ──────────────────────
List<List<String>> _bevelBlock(int w, int h, int cut) {
  bool inside(int x, int y) =>
      x >= 0 &&
      x < w &&
      y >= 0 &&
      y < h &&
      (x + y) >= cut &&
      ((w - 1 - x) + y) >= cut &&
      (x + (h - 1 - y)) >= cut &&
      ((w - 1 - x) + (h - 1 - y)) >= cut;
  final g = List.generate(
    h,
    (y) => List.generate(w, (x) => inside(x, y) ? 'm' : '.'),
  );
  bool isIn(int x, int y) =>
      x >= 0 && x < w && y >= 0 && y < h && g[y][x] != '.';
  final s = [for (final r in g) [...r]];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (g[y][x] == '.') continue;
      final up = isIn(x, y - 1),
          dn = isIn(x, y + 1),
          lf = isIn(x - 1, y),
          rt = isIn(x + 1, y);
      if (!up) {
        s[y][x] = 'L';
      } else if (!dn) {
        s[y][x] = 'd';
      } else if (!lf) {
        s[y][x] = 'l';
      } else if (!rt) {
        s[y][x] = 'M';
      }
    }
  }
  for (var y = 1; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (s[y][x] == 'm' && s[y - 1][x] == 'L') s[y][x] = 'l';
    }
  }
  return s;
}

List<List<String>> _outlinePass(List<List<String>> g) {
  final h = g.length, w = g[0].length;
  final out = [for (final r in g) [...r]];
  // 4-connected (orthogonal only). An 8-connected pass also outlines diagonal
  // neighbours, which paints protruding near-black `k` nubs at the plates' 45°
  // cut corners (they catch against BIT's cyan bloom). Orthogonal-only keeps the
  // crisp outline on flat edges while dropping those corner specks.
  const dirs = [
    [1, 0], [-1, 0], [0, 1], [0, -1],
  ];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (g[y][x] != '.') continue;
      var adj = false;
      for (final d in dirs) {
        final nx = x + d[0], ny = y + d[1];
        if (nx >= 0 &&
            nx < w &&
            ny >= 0 &&
            ny < h &&
            g[ny][nx] != '.' &&
            g[ny][nx] != 'k') {
          adj = true;
          break;
        }
      }
      if (adj) out[y][x] = 'k';
    }
  }
  return out;
}

void _addDot(List<List<String>> g, int x, int y) {
  if (y >= 0 && y < g.length && x >= 0 && x < g[0].length && g[y][x] != '.') {
    g[y][x] = 'C';
    if (x + 1 < g[0].length && g[y][x + 1] != '.') g[y][x + 1] = 'c';
  }
}

List<List<String>> _buildCore() {
  final g = _bevelBlock(16, 16, 3);
  for (var y = 2; y <= 13; y++) {
    for (var x = 2; x <= 13; x++) {
      final ring = (x == 2 || x == 13 || y == 2 || y == 13);
      if (x >= 3 && x <= 12 && y >= 3 && y <= 12) {
        g[y][x] = 'q';
      } else if (ring) {
        g[y][x] = (x == 2 || y == 2) ? 'd' : 'k';
      }
    }
  }
  for (var y = 5; y <= 10; y++) {
    g[y][1] = 'd';
  }
  g[5][1] = 'k';
  g[10][1] = 'k';
  g[7][2] = 'l';
  return _outlinePass(g);
}

List<List<String>> _buildTopPlate() {
  final g = _bevelBlock(18, 5, 3);
  _addDot(g, 3, 3);
  _addDot(g, 13, 3);
  return _outlinePass(g);
}

List<List<String>> _buildBottomPlate() {
  final g = _bevelBlock(18, 5, 3);
  _addDot(g, 3, 1);
  _addDot(g, 13, 1);
  return _outlinePass(g);
}

List<List<String>> _buildLeftPlate() {
  final g = _bevelBlock(5, 14, 2);
  _addDot(g, 2, 2);
  _addDot(g, 2, 11);
  return _outlinePass(g);
}

List<List<String>> _buildRightPlate() {
  final g = _bevelBlock(5, 14, 2);
  _addDot(g, 1, 2);
  _addDot(g, 1, 11);
  return _outlinePass(g);
}

/// The 16×16 bevelled core grid (faceless — the inset screen is drawn by each
/// caller's own painter).
final List<List<String>> coreGrid = _buildCore();

class Plate {
  Plate(this.grid, this.baseAngle);
  final List<List<String>> grid;

  /// Angle of this plate's docked seat around the core centre.
  final double baseAngle;

  double get halfW => grid[0].length / 2;
  double get halfH => grid.length / 2;
}

/// The four plates with their docked seat angles (top / bottom / left / right).
final List<Plate> plates = [
  Plate(_buildTopPlate(), -math.pi / 2),
  Plate(_buildBottomPlate(), math.pi / 2),
  Plate(_buildLeftPlate(), math.pi),
  Plate(_buildRightPlate(), 0),
];

// ── shared easing ────────────────────────────────────────────────────────────
double lerp(double a, double b, double t) => a + (b - a) * t;

double easeInOutQuad(double t) =>
    t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2).toDouble() / 2;

/// easeOutBack — a fast launch out of a crouch that overshoots its target and
/// settles back (Disney overshoot-and-settle).
double easeOutBack(double t, [double s = 1.70158]) {
  final u = t - 1;
  return u * u * ((s + 1) * u + s) + 1;
}

/// Normalised progress of `b` across `[start, end]`, clamped 0..1.
double phaseProgress(double b, double start, double end) =>
    ((b - start) / (end - start)).clamp(0.0, 1.0);

// ── shared painters ──────────────────────────────────────────────────────────
/// Paints a char-grid at native offset ([oxN], [oyN]) scaled by [s], one aliased
/// rect per cell. `.` cells are skipped; unknown chars are ignored.
void drawGrid(
  Canvas canvas,
  List<List<String>> grid,
  double s,
  double oxN,
  double oyN,
  Map<String, Color> pal,
) {
  for (var y = 0; y < grid.length; y++) {
    final row = grid[y];
    for (var x = 0; x < row.length; x++) {
      final ch = row[x];
      if (ch == '.') continue;
      final col = pal[ch];
      if (col == null) continue;
      canvas.drawRect(
        Rect.fromLTWH((oxN + x) * s, (oyN + y) * s, s, s),
        Paint()
          ..color = col
          ..isAntiAlias = false,
      );
    }
  }
}

/// Paints BIT's inset screen-face into the 10×10 recess at native ([oxN],[oyN]).
/// [reveal] 0→1 is the cinematic "BIT opens its eyes" beat (faceless calm dot →
/// full face, blooming centre→out). [cheer] 0→1 blends the **expression**:
/// 0 = neutral (turquoise screen, calm eyes), 1 = cheer (amber screen, wide eyes
/// + grin) — the screen-3 reveal bursts in cheer (≈1) then settles to neutral
/// (0). The caller punctuates with one [blink]; [glow]/[pulse] scale the dot so
/// reveal-0 is byte-identical to the prior faceless dot.
void drawBitFace(
  Canvas canvas,
  double s,
  double oxN,
  double oyN, {
  required double reveal,
  required double cheer,
  required bool blink,
  required double glow,
  required double pulse,
}) {
  final r = reveal.clamp(0.0, 1.0);
  final c = cheer.clamp(0.0, 1.0);
  final paint = Paint()..isAntiAlias = false;
  void px(double x, double y, double w, double h, Color col) {
    paint.color = col;
    canvas.drawRect(
      Rect.fromLTWH((oxN + x) * s, (oyN + y) * s, w * s, h * s),
      paint,
    );
  }

  // The faced screen blooms in (centre → out) as the reveal rises; its ramp
  // lerps turquoise (neutral) → amber (cheer).
  if (r > 0.001) {
    for (var y = 0; y < 10; y++) {
      for (var x = 0; x < 10; x++) {
        final dx = x - 4.5, dy = y - 4.5;
        final d = math.sqrt(dx * dx + dy * dy);
        final ringT = ((r - d / 16) / 0.35).clamp(0.0, 1.0);
        if (ringT <= 0) continue;
        final idx = d < 1.5 ? 3 : (d < 2.9 ? 2 : (d < 4.2 ? 1 : 0));
        final col = Color.lerp(bitFaceRamp[idx], bitCheerRamp[idx], c)!;
        px(x.toDouble(), y.toDouble(), 1, 1, col.withValues(alpha: ringT));
      }
    }
    // Faint scanlines over the lit screen (CRT texture).
    for (var y = 0; y < 10; y += 2) {
      px(0, y.toDouble(), 10, 1, Color.fromRGBO(2, 8, 12, 0.18 * r));
    }
    // Eyes + mouth fade in with the reveal; neutral ↔ cheer cells cross-fade by
    // [cheer] so the burst→settle reads as the expression relaxing.
    final eyeT = ((r - 0.55) / 0.3).clamp(0.0, 1.0);
    if (eyeT > 0) {
      void cells(List<List<int>> grid, double a) {
        if (a <= 0.01) return;
        for (final p in grid) {
          px(p[0].toDouble(), p[1].toDouble(), 1, 1,
              bitEyeColor.withValues(alpha: a.clamp(0.0, 1.0)));
        }
      }
      cells(blink ? _bitEyesBlink : _bitEyesOpen, eyeT * (1 - c));
      cells(_bitMouth, eyeT * (1 - c) * 0.85);
      cells(blink ? _bitCheerBlink : _bitCheerEyes, eyeT * c);
      cells(_bitCheerMouth, eyeT * c * 0.9);
    }
  }

  // The faceless calm dot — full at reveal 0, fades out as the face arrives.
  final dotA = ((1 - r) * (0.32 + 0.5 * glow) * (0.72 + 0.28 * pulse)).clamp(
    0.0,
    1.0,
  );
  if (dotA > 0.01) {
    px(4, 4, 2, 2, bitGlow.withValues(alpha: dotA));
  }
}

/// Draws one plate at its seat (`baseAngle + delta`) at [radius] from the core
/// centre ([cx], [cy]), rotated by the same [delta] so the four-plate ring turns
/// as a rigid body and lands crisp at delta ≡ 0. [alpha] < 1 paints a
/// motion-trail ghost.
void orbitPlate(
  Canvas canvas,
  Plate pl,
  double s,
  double radius,
  double delta,
  double cx,
  double cy,
  Map<String, Color> pal,
  double alpha,
) {
  final ang = pl.baseAngle + delta;
  final px = (cx + radius * math.cos(ang)) * s;
  final py = (cy + radius * math.sin(ang)) * s;
  canvas
    ..save()
    ..translate(px, py)
    ..rotate(delta);
  final ghost = alpha < 1.0;
  if (ghost) {
    // RGB ignored — saveLayer uses the paint's alpha as group opacity.
    canvas.saveLayer(null, Paint()..color = kText.withValues(alpha: alpha));
  }
  drawGrid(canvas, pl.grid, s, -pl.halfW, -pl.halfH, pal);
  if (ghost) canvas.restore();
  canvas.restore();
}
