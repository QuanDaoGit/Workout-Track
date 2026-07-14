import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Canonical small **status / label pill** — a bordered PressStart2P micro-label
/// in a single accent [color]. Replaces the many bespoke `_RankBadge` /
/// `_StatusBadge` / `_TierBadge` / `_RarityBadge` containers so every badge
/// shares one shape and type treatment. [filled] adds a faint colour wash behind
/// the outline for a stronger state (e.g. an active/earned badge).
class ArcadeBadge extends StatelessWidget {
  const ArcadeBadge({
    super.key,
    required this.label,
    this.color = kMutedText,
    this.filled = false,
    this.fontSize = 8,
  });

  final String label;
  final Color color;
  final bool filled;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      // PressStart2P caps are tall + the optical-centre nudge below shifts the
      // ink down, so a tight box reads cramped (the glyphs hug the border).
      // Give it real breathing room — comparable to the LCK buff chip beside it.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      // PressStart2P's all-caps glyphs sit high in the em box: caps span ~0.06–
      // 0.76 of the line, leaving the ~0.24 descent below the baseline empty, so
      // the ink centre lands ~0.09·fontSize above the box centre and the label
      // reads top-biased. (height:1 leaves no leading, so even/proportional
      // distribution can't move it.) Nudge the ink down to the optical centre.
      child: Transform.translate(
        offset: Offset(0, fontSize * 0.1),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: fontSize,
            color: color,
            height: 1,
          ),
        ),
      ),
    );
  }
}
