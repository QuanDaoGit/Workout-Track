import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The **Haul Cache** — a code-painted 28×20 "Banded Coffer" (handoff Option B),
/// the tangible haul that sits on BIT's pad after an expedition returns. A
/// verbatim port of the prototype's `coffer-paint.js` (`paintCoffer`), magenta
/// latch only (no per-route seal — product decision).
///
/// Native grid is 28×20; blit at an **integer** multiple, `isAntiAlias:false`,
/// `FilterQuality.none` (a non-integer upscale shatters the pixel grid). The
/// homecoming drives [build] (0→1, bottom-up fabricate) and the COLLECT dissolve
/// drives [dropped] (a set of 2×2 block ids to omit). Both gate the same baked
/// grid, so the silhouette is always coherent.
///
/// The pad-metal + magenta-gem palettes below are canonical procedural
/// sprite-art (the same documented raw-`Color` exception as `bit_companion`'s
/// `_metal` and the pad-light `_tiers`), not brand tokens.
class CofferPainter extends CustomPainter {
  const CofferPainter({this.build = 1.0, this.dropped = const <int>{}});

  /// 0→1 bottom-up fabricate (homecoming). 1 = fully built.
  final double build;

  /// 2×2 block ids (`blockY * 14 + blockX`) to omit — the COLLECT dissolve.
  final Set<int> dropped;

  static const int nw = 28, nh = 20;
  static const int _blocksX = 14, _blockRows = 10; // 2×2 blocks across the grid

  // pad metal family + magenta gem ramp (sampled from bit_pad.png / gem.png).
  static const Color _out = Color(0xFF0B0C16);
  static const Color _d2 = Color(0xFF15172A);
  static const Color _d1 = Color(0xFF212439);
  static const Color _m = Color(0xFF2E3150);
  static const Color _l1 = Color(0xFF3D4262);
  static const Color _l2 = Color(0xFF525879);
  static const Color _l3 = Color(0xFF6B72A0);
  static const Color _gDk = Color(0xFF961C8C);
  static const Color _gMid = Color(0xFFE028A0);
  static const Color _g = Color(0xFFFF4DCD);
  static const Color _gHi = Color(0xFFFF96E6);

  /// The baked coffer — fixed art, computed once.
  static final List<Color?> _grid = _bake();

  static List<Color?> _bake() {
    final px = List<Color?>.filled(nw * nh, null);
    void set(int x, int y, Color c) {
      if (x < 0 || x >= nw || y < 0 || y >= nh) return;
      px[y * nw + x] = c;
    }

    void rect(int x, int y, int w, int h, Color c) {
      for (var j = 0; j < h; j++) {
        for (var i = 0; i < w; i++) {
          set(x + i, y + j, c);
        }
      }
    }

    void hline(int x, int y, int w, Color c) => rect(x, y, w, 1, c);
    void vline(int x, int y, int h, Color c) => rect(x, y, 1, h, c);

    // beveled metal block: outline + fill, top/left lit, bottom/right shadowed.
    void bevelBox(
      int x,
      int y,
      int w,
      int h,
      Color fill,
      Color lit,
      Color shade, [
      Color? top,
    ]) {
      rect(x, y, w, h, _out);
      rect(x + 1, y + 1, w - 2, h - 2, fill);
      hline(x + 1, y + 1, w - 2, top ?? lit);
      vline(x + 1, y + 1, h - 2, lit);
      hline(x + 1, y + h - 2, w - 2, shade);
      vline(x + w - 2, y + 1, h - 2, shade);
    }

    // 2×2 faceted magenta gem (highlight TL, core TR/BL, deep facet BR).
    void gem(int x, int y) {
      set(x, y, _gHi);
      set(x + 1, y, _g);
      set(x, y + 1, _g);
      set(x + 1, y + 1, _gDk);
    }

    // recessed dark plate + glowing magenta gem core (route 'none').
    void sealPlate(int cx, int cy) {
      rect(cx - 3, cy - 3, 6, 7, _out);
      rect(cx - 2, cy - 2, 4, 5, _d2);
      hline(cx - 2, cy - 2, 4, _d1);
      set(cx - 1, cy, _g);
      set(cx, cy, _gHi);
      set(cx + 1, cy, _g);
      set(cx - 1, cy - 1, _gDk);
      set(cx, cy - 1, _g);
      set(cx + 1, cy - 1, _gDk);
      set(cx - 1, cy + 1, _gDk);
      set(cx, cy + 1, _g);
      set(cx + 1, cy + 1, _gDk);
      set(cx, cy + 2, _gDk);
    }

    // Option B — banded coffer: stepped top + slat vents bleeding gem-light.
    bevelBox(2, 12, 24, 7, _m, _l1, _d2); // wide base
    bevelBox(5, 6, 18, 7, _m, _l2, _d1, _l3); // stacked top tier
    hline(5, 12, 18, _d2); // step seam shadow
    bevelBox(7, 12, 3, 7, _l1, _l3, _d2); // strap L
    bevelBox(18, 12, 3, 7, _l1, _l3, _d2); // strap R
    for (var i = 0; i < 4; i++) {
      final sx = 8 + i * 3; // slatted vents w/ magenta gem-bleed
      vline(sx, 8, 3, _out);
      set(sx + 1, 8, _gDk);
      set(sx + 1, 9, _g);
      set(sx + 1, 10, _gMid);
    }
    sealPlate(14, 15); // route latch
    gem(11, 4);
    gem(14, 3);
    gem(16, 4); // gem spill over the rim
    set(13, 5, _gHi);
    set(18, 5, _g);
    set(10, 5, _gDk);
    return px;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / nw, ch = size.height / nh;
    final b = build.clamp(0.0, 1.0);
    final shown = (b * (_blocksX * _blockRows)).floor();
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < nh; y++) {
      for (var x = 0; x < nw; x++) {
        final c = _grid[y * nw + x];
        if (c == null) continue;
        final bx = x >> 1, by = y >> 1;
        if (dropped.contains(by * _blocksX + bx)) continue;
        // bottom-up reveal: block order index is (bottom row first).
        if (b < 1 && ((_blockRows - 1 - by) * _blocksX + bx) >= shown) continue;
        paint.color = c;
        canvas.drawRect(Rect.fromLTWH(x * cw, y * ch, cw, ch), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CofferPainter old) =>
      old.build != build || !setEquals(old.dropped, dropped);
}
