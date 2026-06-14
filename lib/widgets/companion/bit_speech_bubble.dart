import 'package:flutter/material.dart';

import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';

/// An arcade-styled speech callout for [BitSprite]. The painted tail points
/// left toward the sprite. [emphasis] (e.g. the user's name) is tinted [kCyan]
/// inline where it occurs in [text].
///
/// Static by design (no typewriter) so it is inherently reduce-motion safe —
/// the reveal/“online” beat is owned by the caller (the start gate's
/// StrobeFlash power-on).
class BitSpeechBubble extends StatelessWidget {
  const BitSpeechBubble({super.key, required this.text, this.emphasis});

  /// The line BIT speaks.
  final String text;

  /// Optional substring of [text] to tint (the user's name). Ignored when null,
  /// empty, or not found in [text].
  final String? emphasis;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: CustomPaint(size: Size(7, 12), painter: _TailPainter()),
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kCard,
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(kCardRadius),
            ),
            child: _buildText(),
          ),
        ),
      ],
    );
  }

  Widget _buildText() {
    final style = AppFonts.shareTechMono(
      color: kText,
      fontSize: 14,
      height: 1.4,
    );
    final emph = emphasis;
    final idx = (emph == null || emph.isEmpty) ? -1 : text.indexOf(emph);
    if (idx < 0) return Text(text, style: style);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: emph,
            style: AppFonts.shareTechMono(
              color: kCyan,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          TextSpan(text: text.substring(idx + emph!.length)),
        ],
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = kCard);
    final edge = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height);
    canvas.drawPath(
      edge,
      Paint()
        ..color = kBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) => false;
}
