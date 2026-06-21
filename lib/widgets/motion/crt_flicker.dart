import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// A near-still CRT phosphor flicker for a short label. Renders [text] in
/// [style] and, at random intervals, briefly *brightens* a single random glyph
/// toward [highlightColor] — one phosphor cell "catching" to full brightness,
/// like an unstable cabinet panel, not a marquee.
///
/// Brightening (not dimming) is deliberate: the eyebrow's base color is *muted*,
/// so dimming it toward the near-black background is an imperceptible contrast
/// change. A glyph momentarily reaching the real text brightness reads clearly
/// while staying tasteful — it never touches neon, so the card's neon budget
/// (border + progress bar) is untouched; the glyph just stops being muted for a
/// beat. Salience stays low: exactly one glyph ever moves, briefly.
///
/// Reduced motion → steady text, no flicker (a still, legible label).
class CrtFlicker extends StatefulWidget {
  const CrtFlicker({
    super.key,
    required this.text,
    required this.style,
    this.highlightColor,
    this.minGap = const Duration(milliseconds: 2600),
    this.maxGap = const Duration(milliseconds: 5200),
    this.flickerDuration = const Duration(milliseconds: 240),
  });

  final String text;
  final TextStyle style;

  /// The brightness a flicking glyph reaches at the peak. Defaults to the base
  /// color lerped 70% toward white when null.
  final Color? highlightColor;

  /// Shortest / longest rest between flickers; the gap is uniform in this range.
  final Duration minGap;
  final Duration maxGap;

  /// How long a single glyph's flash lasts (rise, brief hold, fall).
  final Duration flickerDuration;

  @override
  State<CrtFlicker> createState() => _CrtFlickerState();
}

class _CrtFlickerState extends State<CrtFlicker>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.flickerDuration,
  );

  Timer? _timer;
  int _index = -1; // glyph currently flicking, -1 = none

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  // Glyph indices worth flicking — spaces brighten invisibly, so skip them.
  List<int> get _candidates {
    final out = <int>[];
    for (var i = 0; i < widget.text.length; i++) {
      if (widget.text[i] != ' ') out.add(i);
    }
    return out;
  }

  // 0 → 1 → 0 flash: quick rise, brief hold at full, slower fall.
  double _flickerEnv(double t) {
    const up = 0.25;
    const hold = 0.45;
    if (t < up) return t / up;
    if (t < hold) return 1.0;
    return 1 - (t - hold) / (1 - hold);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _timer?.cancel();
      _timer = null;
      _controller.stop();
      _controller.value = 0;
      _index = -1;
    } else if (_timer == null && !_controller.isAnimating) {
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    final span = widget.maxGap.inMilliseconds - widget.minGap.inMilliseconds;
    final gap = widget.minGap.inMilliseconds + _random.nextInt(max(1, span));
    _timer = Timer(Duration(milliseconds: gap), _flick);
  }

  void _flick() {
    _timer = null;
    if (!mounted || _reduceMotion) return;
    final candidates = _candidates;
    if (candidates.isEmpty) return;
    setState(() => _index = candidates[_random.nextInt(candidates.length)]);
    _controller.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted) return;
      setState(() => _index = -1);
      if (!_reduceMotion) _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion (and the no-candidate degenerate case) → a plain, steady
    // label carrying its own semantics.
    if (_reduceMotion) {
      return Text(widget.text, style: widget.style);
    }

    final base = widget.style.color ?? const Color(0xFFFFFFFF);
    final highlight =
        widget.highlightColor ??
        Color.lerp(base, const Color(0xFFFFFFFF), 0.7)!;

    return Semantics(
      label: widget.text,
      container: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final amt = _flickerEnv(_controller.value);
            final lit = Color.lerp(base, highlight, amt)!;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.text.length; i++)
                  Text(
                    widget.text[i],
                    style: i == _index
                        ? widget.style.copyWith(color: lit)
                        : widget.style,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
