import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'arcade_badge.dart';

/// The level-rank → accent ladder. Rank is a prestige signal, so it earns colour
/// (warm/red at the top), unlike the muted-only treatment it used to carry on the
/// profile card. Mirrors the level bands from `XpService.getRank`.
///
/// Single source of truth — both the profile hero card and the Logs header render
/// through [RankBadge], so the two surfaces can never drift apart again.
Color rankColor(String rank) => switch (rank) {
  'Legend' || 'Champion' => kDanger,
  'Knight' => kAmber,
  'Squire' => kNeon,
  _ => kMutedText, // Recruit + any unknown → quiet
};

/// Canonical rank pill. [Legend] (the apex) also gets the filled colour wash;
/// every other rank is an outlined micro-label in its ladder colour.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank, this.fontSize = 8});

  final String rank;
  final double fontSize;

  @override
  Widget build(BuildContext context) => ArcadeBadge(
    label: rank,
    color: rankColor(rank),
    filled: rank == 'Legend',
    fontSize: fontSize,
  );
}
