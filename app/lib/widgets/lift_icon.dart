import 'package:flutter/material.dart';

import '../data/lift_icons.dart';
import '../theme/tokens.dart';

/// A movement-pattern pixel icon for a lift (see `data/lift_icons.dart`). The art
/// is a white silhouette on transparent, recoloured via `BlendMode.srcIn` to a
/// single token colour (the verdict glyph stays the only colour that *means*
/// something). Rendered nearest-neighbour at an **integer fraction of the 80px
/// source** (the art is authored on a 20px grid, exported 4×) so the pixels stay
/// crisp — keep [size] a multiple of 20 (40 fits a 48px tile). A missing asset
/// falls back to a sharp dumbbell, never a broken row.
class LiftIcon extends StatelessWidget {
  const LiftIcon({
    super.key,
    required this.exerciseName,
    this.size = 40,
    this.color = kMutedText,
  });

  final String exerciseName;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      liftIconAssetFor(exerciseName),
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (_, _, _) =>
          Icon(Icons.fitness_center_sharp, size: size * 0.8, color: color),
    );
  }
}
