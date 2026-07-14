import 'package:flutter/material.dart';

import '../services/xp_service.dart';
import '../theme/tokens.dart';

/// LCK shown as **four dimensional diamond pips** — filled per the weekly ladder
/// (`XpService.lckDiamondCount`). A filled pip is a faceted amber gem (top-left
/// bevel highlight + a soft bloom); empty pips are dim outlines. Painted,
/// zero-asset (like the avatar / BIT), so it stays crisp at any size and never
/// reads as a flat sprite. Replaces the tiered `lck-*.png` icon.
class LckPips extends StatelessWidget {
  const LckPips({super.key, required this.lck, this.size = 14, this.gap = 3});

  /// Raw LCK (weekly consistency streak); converted to 0–4 filled pips.
  final int lck;

  /// Pip height (each pip is a square diamond of this size).
  final double size;
  final double gap;

  static const int max = 4;

  @override
  Widget build(BuildContext context) {
    final filled = XpService.lckDiamondCount(lck).clamp(0, max);
    return Semantics(
      label: 'Luck $filled of $max',
      child: SizedBox(
        width: max * size + (max - 1) * gap,
        height: size,
        child: CustomPaint(painter: _LckPipsPainter(filled: filled, gap: gap)),
      ),
    );
  }
}

class _LckPipsPainter extends CustomPainter {
  _LckPipsPainter({required this.filled, required this.gap});

  final int filled;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final pip = size.height;
    for (var i = 0; i < LckPips.max; i++) {
      final cx = i * (pip + gap) + pip / 2;
      _diamond(canvas, Offset(cx, size.height / 2), pip / 2, i < filled);
    }
  }

  void _diamond(Canvas canvas, Offset c, double r, bool isFilled) {
    final body = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();

    if (!isFilled) {
      canvas.drawPath(
        body,
        Paint()
          ..isAntiAlias = false
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = kBorder,
      );
      return;
    }

    // Soft bloom so the gem reads emissive on the dark bar.
    canvas.drawPath(
      body,
      Paint()
        ..color = kAmber.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Gem body.
    canvas.drawPath(
      body,
      Paint()
        ..isAntiAlias = false
        ..color = kAmber,
    );
    // Top-left facet — the bevel highlight that gives the pip its dimension.
    final facet = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx, c.dy)
      ..close();
    canvas.drawPath(
      facet,
      Paint()
        ..isAntiAlias = false
        ..color = Color.lerp(kAmber, kText, 0.5)!,
    );
    // Outline.
    canvas.drawPath(
      body,
      Paint()
        ..isAntiAlias = false
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = kAmberDark,
    );
  }

  @override
  bool shouldRepaint(covariant _LckPipsPainter old) => old.filled != filled;
}
