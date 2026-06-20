import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'motion/phosphor_tap.dart';

/// Drop-in replacement for InkWell that does a hard color swap on tap
/// instead of a Material ripple. Background flashes [flashColor] for
/// [flashMs] then snaps back to transparent. No splash, no interpolation.
class ArcadeTap extends StatelessWidget {
  const ArcadeTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.flashColor = kNeon,
    this.flashOpacity = 0.15,
    this.flashMs = 80,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final Color flashColor;
  final double flashOpacity;
  final int flashMs;
  final HitTestBehavior behavior;

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null || onLongPress != null;
    return PhosphorTap(
      onTap: onTap,
      onLongPress: onLongPress,
      enabled: tappable,
      color: flashColor,
      opacity: flashOpacity,
      borderRadius: borderRadius ?? const BorderRadius.all(Radius.circular(0)),
      behavior: behavior,
      child: child,
    );
  }
}
