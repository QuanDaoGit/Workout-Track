import 'package:flutter/material.dart';

/// A faint, **static** CRT scanline wash — the app's phosphor-screen grade,
/// painted as hard 1px lines at a low alpha so a video/surface reads as a lit
/// screen without any drawn bezel. Static by design (research + `learnings.md`:
/// a *moving* scanline reads as a gimmick); safe under reduced motion because it
/// never animates. Overlay it (last child of a `Stack`) with `IgnorePointer`.
class CrtScanlineOverlay extends StatelessWidget {
  const CrtScanlineOverlay({
    super.key,
    this.opacity = 0.5,
    this.pitch = 3,
    this.lineColor = const Color(0xFF000000),
  });

  /// Overall wash strength (the per-line alpha is [opacity] × the line's own).
  final double opacity;

  /// Vertical period in logical px (line + gap).
  final double pitch;

  /// The dark line color (near-black by default).
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScanlinePainter(
          opacity: opacity,
          pitch: pitch,
          lineColor: lineColor,
        ),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  _ScanlinePainter({
    required this.opacity,
    required this.pitch,
    required this.lineColor,
  });

  final double opacity;
  final double pitch;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: (0.26 * opacity).clamp(0.0, 1.0))
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (double y = 0; y < size.height; y += pitch) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter old) =>
      old.opacity != opacity ||
      old.pitch != pitch ||
      old.lineColor != lineColor;
}
