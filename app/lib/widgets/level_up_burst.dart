import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The app's native level-up celebration, mirroring the onboarding handoff
/// (`onboarding_flow_page.dart` `_HandoffTransitionPainter`): an amber CRT
/// strobe + scanline surge, an amber phosphor wash, a rising "+1 LV" pixel
/// banner, and a contracting iris. Drive it by bumping [trigger]. Plays once;
/// reduced motion keeps it inert.
class LevelUpBurst extends StatefulWidget {
  const LevelUpBurst({super.key, required this.trigger});

  /// Increment to play the burst.
  final int trigger;

  @override
  State<LevelUpBurst> createState() => _LevelUpBurstState();
}

class _LevelUpBurstState extends State<LevelUpBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );

  @override
  void didUpdateWidget(covariant LevelUpBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      if (MediaQuery.of(context).disableAnimations) return;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final value = _controller.value;
          if (value <= 0 || value >= 1) return const SizedBox.expand();
          return CustomPaint(
            size: Size.infinite,
            painter: _LevelUpBurstPainter(
              progress: Curves.easeOut.transform(value),
            ),
          );
        },
      ),
    );
  }
}

class _LevelUpBurstPainter extends CustomPainter {
  _LevelUpBurstPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final strobe = _strobe(progress);
    if (strobe > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = kAmber.withValues(alpha: 0.12 * strobe),
      );
      _drawBorder(canvas, size, kAmber.withValues(alpha: 0.85 * strobe));
      _drawScanBoost(canvas, size, 0.85 * strobe);
    }

    final wash = (1 - ((progress - 0.32).abs() / 0.18)).clamp(0.0, 1.0);
    if (wash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = kAmber.withValues(alpha: 0.22 * wash),
      );
    }

    // The "+1 LV" text is drawn locally by the XP meter (one float per level),
    // so the full-screen burst no longer draws its own.

    if (progress > 0.58) {
      final local = ((progress - 0.58) / 0.24).clamp(0.0, 1.0);
      final radius =
          math.sqrt(size.width * size.width + size.height * size.height) *
          (1 - local);
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        radius,
        Paint()..color = kAmber.withValues(alpha: 0.20 * (1 - local)),
      );
    }
  }

  double _strobe(double t) {
    if (t > 0.44) return 0;
    final frame = (t / 0.055).floor();
    return frame.isEven ? 1 : 0;
  }

  @override
  bool shouldRepaint(covariant _LevelUpBurstPainter old) =>
      old.progress != progress;
}

void _drawScanBoost(Canvas canvas, Size size, double opacity) {
  if (opacity <= 0) return;
  final paint = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.10 * opacity)
    ..strokeWidth = 1;
  for (double y = 0; y < size.height; y += 4) {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
}

void _drawBorder(Canvas canvas, Size size, Color color) {
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color
      ..isAntiAlias = false,
  );
}
