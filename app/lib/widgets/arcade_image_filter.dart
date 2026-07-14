import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class ArcadeImageFilter extends StatelessWidget {
  const ArcadeImageFilter({
    super.key,
    required this.child,
    this.enabled = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  final Widget child;
  final bool enabled;
  final BorderRadius borderRadius;

  static const ColorFilter _grayscale = ColorFilter.matrix(<double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  static final ColorFilter _neonTint = ColorFilter.mode(
    kNeon.withValues(alpha: 68 / 255),
    BlendMode.color,
  );

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return ClipRRect(
      borderRadius: borderRadius,
      child: ColorFiltered(
        colorFilter: _neonTint,
        child: ColorFiltered(colorFilter: _grayscale, child: child),
      ),
    );
  }
}
