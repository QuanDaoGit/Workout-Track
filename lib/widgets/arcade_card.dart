import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The app's **canonical card surface** — a token-styled panel (dark fill, 1px
/// border, `kCardRadius` corners, `kCardPadding` insets) with an optional accent
/// border and neon [glow]. Promote bespoke `Container(decoration: BoxDecoration(
/// color/border/borderRadius))` cards onto this so every panel shares one
/// shape / border / padding language instead of drifting per screen.
class ArcadeCard extends StatelessWidget {
  const ArcadeCard({
    super.key,
    required this.child,
    this.background = kCard,
    this.borderColor = kBorder,
    this.borderAlpha = 1.0,
    this.backgroundAlpha = 1.0,
    this.borderWidth = 1.0,
    this.padding,
    this.boxShadow,
    this.glow = false,
    this.glowColor = kNeon,
  });

  final Widget child;
  final Color background;
  final Color borderColor;
  final double borderAlpha;
  final double backgroundAlpha;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;

  /// Explicit shadow; takes precedence over [glow]. Most callers want [glow].
  final List<BoxShadow>? boxShadow;
  final bool glow;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(kCardPadding),
      decoration: BoxDecoration(
        color: background.withValues(alpha: backgroundAlpha),
        border: Border.all(
          color: borderColor.withValues(alpha: borderAlpha),
          width: borderWidth,
        ),
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: boxShadow ?? (glow ? neonGlow(color: glowColor) : null),
      ),
      child: child,
    );
  }
}
