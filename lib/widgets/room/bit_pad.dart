import 'package:flutter/material.dart';

import '../companion/bit_core_engine.dart' show bitGlow;

/// BIT's emitter pad, **painted** (no image asset). A front-elevation console:
/// a beveled metal slab, a segmented turquoise LED strip, two lit side posts,
/// and a center emitter notch the beam rises from. Replaces the `bit_pad.png`
/// sprite, whose 108→150 non-integer upscale produced broken-looking side posts;
/// a painter is resolution-independent and crisp at any size, matching the
/// zero-asset ethos of BIT and the avatar.
///
/// Turquoise is BIT's color; the LED strip is held **dim** so BIT stays the
/// single brightest element (handoff GUARDRAILS #2). The metal tones are
/// canonical sprite-art (like `bit_companion`'s `_metal`), not brand tokens.
class BitPad extends StatelessWidget {
  const BitPad({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _BitPadPainter()),
    );
  }
}

const Color _mBase = Color(0xFF2A2A40); // body
const Color _mLight = Color(0xFF4B4B6E); // top bevel
const Color _mDark = Color(0xFF15151F); // underside
const Color _mOutline = Color(0xFF0B0B14);
const Color _mPost = Color(0xFF34344E); // side posts (a touch lighter)

class _BitPadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()..isAntiAlias = false;
    void rect(double x, double y, double rw, double rh, Color c) {
      p.color = c;
      canvas.drawRect(Rect.fromLTWH(x * w, y * h, rw * w, rh * h), p);
    }

    // Side posts (taller blocks at each end).
    for (final px in const [0.03, 0.85]) {
      rect(px, 0.30, 0.12, 0.55, _mOutline);
      rect(px + 0.01, 0.32, 0.10, 0.50, _mPost);
      rect(px + 0.01, 0.32, 0.10, 0.03, _mLight); // top bevel
      // vertical cyan accent on the post
      rect(px + 0.045, 0.40, 0.02, 0.34, bitGlow.withValues(alpha: 0.55));
    }

    // Main body slab.
    rect(0.10, 0.38, 0.80, 0.46, _mOutline);
    rect(0.115, 0.40, 0.77, 0.42, _mBase);
    rect(0.115, 0.40, 0.77, 0.04, _mLight); // top highlight
    rect(0.115, 0.78, 0.77, 0.04, _mDark); // underside shadow

    // Top deck (the raised emitter housing).
    rect(0.30, 0.22, 0.40, 0.18, _mOutline);
    rect(0.315, 0.24, 0.37, 0.15, _mBase);
    rect(0.315, 0.24, 0.37, 0.03, _mLight);

    // Center emitter notch — the beam rises from here.
    rect(0.45, 0.16, 0.10, 0.09, _mOutline);
    rect(0.465, 0.175, 0.07, 0.06, bitGlow.withValues(alpha: 0.85));
    rect(0.49, 0.135, 0.02, 0.04, bitGlow); // little tick at the very top

    // Segmented LED strip across the front (dim — BIT must out-shine it).
    const segs = 12;
    final segW = 0.62 / (segs * 1.6);
    for (var i = 0; i < segs; i++) {
      final x = 0.19 + i * (0.62 / segs);
      rect(x, 0.585, segW, 0.085, bitGlow.withValues(alpha: 0.5));
      rect(x, 0.6, segW, 0.04, bitGlow.withValues(alpha: 0.8));
    }
  }

  @override
  bool shouldRepaint(covariant _BitPadPainter oldDelegate) => false;
}
