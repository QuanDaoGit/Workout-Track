import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A CRT "glitch slam": the text crashes in split into red/cyan channels
/// (chromatic aberration) with a scanline tear, jitters, then resolves to clean
/// text. Used for the level-up headline. Reduced motion renders clean text.
class GlitchText extends StatefulWidget {
  const GlitchText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 520),
  });

  final String text;
  final TextStyle? style;
  final Duration duration;

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  // Pre-rolled jitter offsets so the glitch is erratic but deterministic.
  late final List<double> _jitter;

  @override
  void initState() {
    super.initState();
    final rand = math.Random(widget.text.hashCode);
    _jitter = List.generate(14, (_) => rand.nextDouble() * 2 - 1);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? const TextStyle();
    final clean = Text(widget.text, textAlign: TextAlign.center, style: style);
    if (MediaQuery.of(context).disableAnimations) return clean;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Glitch is strongest at the start and resolves to 0.
        final glitch = (1 - Curves.easeOut.transform(_controller.value)).clamp(
          0.0,
          1.0,
        );
        final step = (_controller.value * (_jitter.length - 1)).floor();
        final j = _jitter[step.clamp(0, _jitter.length - 1)];
        final offset = glitch * 5 * j;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Red channel.
            Transform.translate(
              offset: Offset(-offset, glitch * 1.2 * j),
              child: Opacity(
                opacity: 0.65 * glitch,
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: style.copyWith(color: const Color(0xFFFF2D55)),
                ),
              ),
            ),
            // Cyan channel.
            Transform.translate(
              offset: Offset(offset, glitch * -1.2 * j),
              child: Opacity(
                opacity: 0.65 * glitch,
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: style.copyWith(color: kCyan),
                ),
              ),
            ),
            // Main channel, with a tiny vertical jitter while glitching.
            Transform.translate(
              offset: Offset(0, glitch * 1.5 * j),
              child: clean,
            ),
            // Scanline tear bands.
            if (glitch > 0.15)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _TearPainter(glitch: glitch, jitter: j),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TearPainter extends CustomPainter {
  _TearPainter({required this.glitch, required this.jitter});

  final double glitch;
  final double jitter;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.22 * glitch);
    // A couple of bright horizontal tear bands at jittered heights.
    final y1 = size.height * (0.35 + 0.15 * jitter);
    final y2 = size.height * (0.65 - 0.15 * jitter);
    final dx = 6 * glitch * jitter;
    canvas.drawRect(Rect.fromLTWH(dx, y1, size.width, 2), paint);
    canvas.drawRect(Rect.fromLTWH(-dx, y2, size.width, 2), paint);
  }

  @override
  bool shouldRepaint(covariant _TearPainter old) =>
      old.glitch != glitch || old.jitter != jitter;
}
