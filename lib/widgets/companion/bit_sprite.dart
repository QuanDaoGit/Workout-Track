import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// BIT's expression. The screen-face + plate pose are baked into each sprite;
/// the body metal never changes — only the screen tint and eyes carry the mood.
enum BitMood { neutral, cheer, alert, rest }

extension _BitMoodAsset on BitMood {
  /// Native 1× sprite (44×44, transparent) for this mood.
  String get asset => switch (this) {
    BitMood.neutral => 'assets/mascot/bit-sprites/bit_neutral_1x.png',
    BitMood.cheer => 'assets/mascot/bit-sprites/bit_cheer_1x.png',
    BitMood.alert => 'assets/mascot/bit-sprites/bit_alert_1x.png',
    BitMood.rest => 'assets/mascot/bit-sprites/bit_rest_1x.png',
  };
}

/// All declared BIT sprite asset paths — used by the manifest test to assert
/// every mood resolves to a bundled file.
const List<String> kBitSpriteAssets = [
  'assets/mascot/bit-sprites/bit_neutral_1x.png',
  'assets/mascot/bit-sprites/bit_cheer_1x.png',
  'assets/mascot/bit-sprites/bit_alert_1x.png',
  'assets/mascot/bit-sprites/bit_rest_1x.png',
];

/// BIT — the companion mascot. Renders the approved pixel sprite for [mood] at
/// [size]×[size], crisp (nearest-neighbour) to match the pixel-arcade theme.
///
/// If the bundled image fails to load (missing/undeclared asset), a painted
/// fallback keeps a recognizable BIT-like glyph on screen rather than a
/// broken-image icon — this surface must never crash or show a placeholder X.
class BitSprite extends StatelessWidget {
  const BitSprite({super.key, this.mood = BitMood.neutral, this.size = 64});

  final BitMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      mood.asset,
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
      gaplessPlayback: true,
      semanticLabel: 'BIT, your companion',
      errorBuilder: (context, error, stack) => _BitFallback(size: size),
    );
  }
}

/// Painted last-resort BIT: a dim metal box with a cyan screen, themed and
/// recognizable. Shown only when the sprite asset cannot load.
class _BitFallback extends StatelessWidget {
  const _BitFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BitFallbackPainter()),
    );
  }
}

class _BitFallbackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: s * 0.74, height: s * 0.74),
      Radius.circular(s * 0.12),
    );
    canvas.drawRRect(body, Paint()..color = kCard);
    canvas.drawRRect(
      body,
      Paint()
        ..color = kBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.04).clamp(1.0, 3.0),
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: s * 0.42, height: s * 0.42),
      Paint()..color = kCyan,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
