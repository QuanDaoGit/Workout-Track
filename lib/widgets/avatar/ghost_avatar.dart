import 'package:flutter/material.dart';

import '../../models/avatar_spec.dart';
import '../../theme/tokens.dart';
import 'ironbit_avatar.dart';

/// The user's own pixel face rendered as their Shadow: desaturated, tinted
/// spectral cyan, with a scanline pass. Zero new art — it must read instantly
/// as "that's me, but spectral", never as a stranger.
class GhostAvatar extends StatelessWidget {
  const GhostAvatar({super.key, required this.spec, this.size = 60});

  final AvatarSpec spec;
  final double size;

  // Luminance-weighted desaturation matrix (standard Rec. 601 weights).
  static const _grayscale = <double>[
    0.299, 0.587, 0.114, 0, 0, //
    0.299, 0.587, 0.114, 0, 0, //
    0.299, 0.587, 0.114, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Your Shadow',
      child: Opacity(
        opacity: 0.92,
        child: CustomPaint(
          foregroundPainter: _ScanlinePainter(),
          // Tint only where the sprite drew (srcATop), over a desaturated
          // base, so the ghost stays recognizably the user's face.
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              kCyan.withValues(alpha: 0.4),
              BlendMode.srcATop,
            ),
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(_grayscale),
              child: IronbitAvatar(spec: spec, size: size),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kBg.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var y = 1.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) => false;
}
