import 'package:flutter/material.dart';

import '../models/workout_models.dart';

class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.exercise});

  final Exercise exercise;

  Color _levelColor() {
    switch (exercise.level) {
      case 'beginner':
        return const Color(0xFF00FF9C);
      case 'intermediate':
        return const Color(0xFFFFD700);
      case 'expert':
        return const Color(0xFFFF2D55);
      default:
        return const Color(0xFF6B6B8A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        exercise.levelLabel.toUpperCase(),
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 9,
          color: color,
        ),
      ),
    );
  }
}
