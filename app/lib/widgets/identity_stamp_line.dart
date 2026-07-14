import 'package:flutter/material.dart';

import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'rank_badge.dart';

/// The competence "stamp line" that sits directly under the profile nameplate.
///
/// Replaces the two stacked filled badges (an amber LV chip above the name + a
/// coloured RANK chip below it) with one typographic line: the earned RANK is
/// the colour-laddered, letter-spaced headline; the LEVEL recedes to muted
/// metadata. Rank stays the single dominant identity cue (no second accent
/// competing), and glyph + word + colour give a non-colour-only role signal.
///
/// One line by construction — a [FittedBox] scales the whole line down rather
/// than wrapping it into an asymmetric two-line split at large text scales; the
/// [Semantics] label carries the real values for the screen reader.
class IdentityStampLine extends StatelessWidget {
  const IdentityStampLine({super.key, required this.level, required this.rank});

  final int level;
  final String rank;

  @override
  Widget build(BuildContext context) {
    final color = rankColor(rank);
    return Semantics(
      label: 'Rank $rank, level $level',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_sharp, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              rank.toUpperCase(),
              style: AppFonts.shareTechMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 1.5,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '·',
                style: AppFonts.shareTechMono(fontSize: 13, color: kMutedText),
              ),
            ),
            Icon(Icons.bolt_sharp, size: 13, color: kMutedText),
            const SizedBox(width: 4),
            Text(
              'LV. $level',
              style: AppFonts.shareTechMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kMutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
