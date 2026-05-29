import 'package:flutter/material.dart';

class AmbientDrift extends StatefulWidget {
  const AmbientDrift({
    super.key,
    this.color = const Color(0x0AFFFFFF),
    this.period = const Duration(milliseconds: 3000),
  });

  final Color color;
  final Duration period;

  @override
  State<AmbientDrift> createState() => _AmbientDriftState();
}

class _AmbientDriftState extends State<AmbientDrift>
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
  void didUpdateWidget(covariant AmbientDrift oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period == widget.period) return;
    _controller.duration = widget.period;
    if (!_reduceMotion) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = _reduceMotion ? 0.0 : _controller.value;
        return Transform.translate(offset: Offset(0, offset), child: child);
      },
      child: CustomPaint(painter: _AmbientScanlinePainter(color: widget.color)),
    );
  }
}

class _AmbientScanlinePainter extends CustomPainter {
  const _AmbientScanlinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double y = -4; y < size.height + 4; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientScanlinePainter oldDelegate) =>
      oldDelegate.color != color;
}
