import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'count_up_text.dart';

/// A stat gain that counts up from +0 to its final value as a mono pixel ticker.
/// The count-up **duration scales with magnitude** — a bigger gain ticks for
/// longer (more dopamine). Reduced motion shows the final value statically.
class FloatingStatNumber extends StatelessWidget {
  const FloatingStatNumber({
    super.key,
    required this.stat,
    required this.value,
    this.color = kNeon,
    this.fontSize = 12,
  });

  final String stat;
  final int value;
  final Color color;
  final double fontSize;

  /// The more you earn, the longer the ticker runs (~35ms per point, clamped).
  static Duration durationFor(int value) =>
      Duration(milliseconds: (value * 35).clamp(450, 1800));

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'PressStart2P',
      fontSize: fontSize,
      color: color,
      shadows: neonGlow(
        color: color,
        opacity: 0.5,
        blur: 8,
      ).map((s) => Shadow(color: s.color, blurRadius: s.blurRadius)).toList(),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$stat +', style: style),
        CountUpText(value: value, duration: durationFor(value), style: style),
      ],
    );
  }
}
