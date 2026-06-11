import 'package:flutter/material.dart';

import '../models/workout_models.dart';
import '../theme/tokens.dart';

class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('level_badge_${exercise.level}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kCard.withValues(alpha: 0.35),
        border: Border.all(color: kBorderVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        exercise.levelLabel.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 9,
          color: kMutedText,
        ),
      ),
    );
  }
}
