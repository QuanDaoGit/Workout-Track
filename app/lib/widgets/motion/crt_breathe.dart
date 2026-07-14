import 'dart:math';

import 'package:flutter/material.dart';

/// A slow, whole-label "breathing" glow for a *recovery / rest* label. Renders
/// [text] in [style] and gently oscillates its brightness on a slow sine —
/// inhale (brighten) / exhale (dim) — matched to a resting breath (~4.5s), the
/// calm counterpart to [CrtFlicker]'s rare glint and [CrtSweep]'s active chase.
///
/// Restraint is the whole point (this is a rest state): brightness only — never
/// geometry — at low amplitude, soft and sinusoidal, one element. The breath
/// dims the label's alpha toward the dark card and back; it never brightens past
/// the base color, so it adds no contrast / no neon budget.
///
/// Reduced motion → the steady base label (a still, legible rest signal), no
/// breathing.
class CrtBreathe extends StatefulWidget {
  const CrtBreathe({
    super.key,
    required this.text,
    required this.style,
    this.period = const Duration(milliseconds: 4500),
    this.minBrightness = 0.6,
  });

  final String text;
  final TextStyle style;

  /// One full inhale→exhale cycle.
  final Duration period;

  /// Brightness floor at the exhale trough (0..1 of the base alpha); the peak is
  /// the base color at full.
  final double minBrightness;

  @override
  State<CrtBreathe> createState() => _CrtBreatheState();
}

class _CrtBreatheState extends State<CrtBreathe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) {
      return Text(widget.text, style: widget.style);
    }

    final base = widget.style.color ?? const Color(0xFFFFFFFF);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Smooth 0→1→0 over the cycle (trough at the ends, peak mid).
        final wave = 0.5 - 0.5 * cos(_controller.value * 2 * pi);
        final brightness =
            widget.minBrightness + (1 - widget.minBrightness) * wave;
        return Text(
          widget.text,
          style: widget.style.copyWith(
            color: base.withValues(alpha: base.a * brightness),
          ),
        );
      },
    );
  }
}
