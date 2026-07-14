import 'package:flutter/material.dart';

/// A traveling "glint" sweep for a short, *active* label. Renders [text] in
/// [style] and repeatedly passes a bright band left→right across the glyphs —
/// the arcade "READY / INSERT COIN" ticker feel — with a rest between sweeps so
/// it reads as a live, awaiting-you state rather than a frantic chase.
///
/// This is the louder sibling of [CrtFlicker]: use it only for a genuinely
/// actionable state (a mission still to be done today), where "this is live,
/// act now" is real *meaning*, not decoration. The base color carries the
/// signal on its own; the sweep is the heartbeat on top.
///
/// Reduced motion → the steady base label (still a legible, on-state signal),
/// no sweep.
class CrtSweep extends StatefulWidget {
  const CrtSweep({
    super.key,
    required this.text,
    required this.style,
    this.highlightColor,
    this.sweepDuration = const Duration(milliseconds: 850),
    this.gap = const Duration(milliseconds: 1300),
    this.spread = 2.2,
  });

  final String text;
  final TextStyle style;

  /// Brightness the glint reaches at its head. Defaults to the base color lerped
  /// 75% toward white when null.
  final Color? highlightColor;

  /// How long one sweep takes to cross the word.
  final Duration sweepDuration;

  /// Rest between sweeps (no glyph lit) — the breath that keeps it calm.
  final Duration gap;

  /// Glint half-width in glyphs — how many letters the band lights at once.
  final double spread;

  @override
  State<CrtSweep> createState() => _CrtSweepState();
}

class _CrtSweepState extends State<CrtSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.sweepDuration + widget.gap,
  );

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  double get _sweepFraction {
    final total = (widget.sweepDuration + widget.gap).inMilliseconds;
    return total == 0 ? 1 : widget.sweepDuration.inMilliseconds / total;
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

  // Brightness 0..1 for glyph [i] at the current sweep phase.
  double _intensity(int i) {
    final p = _controller.value;
    final sweep = _sweepFraction;
    if (p > sweep) return 0; // resting between sweeps
    final head = _lerp(-widget.spread, (widget.text.length - 1) + widget.spread,
        p / sweep);
    final d = (i - head).abs() / widget.spread;
    if (d >= 1) return 0;
    final f = 1 - d;
    return f * f; // eased falloff
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) {
      return Text(widget.text, style: widget.style);
    }

    final base = widget.style.color ?? const Color(0xFFFFFFFF);
    final highlight = widget.highlightColor ??
        Color.lerp(base, const Color(0xFFFFFFFF), 0.75)!;

    return Semantics(
      label: widget.text,
      container: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.text.length; i++)
                  Text(
                    widget.text[i],
                    style: widget.text[i] == ' '
                        ? widget.style
                        : widget.style.copyWith(
                            color: Color.lerp(base, highlight, _intensity(i)),
                          ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
