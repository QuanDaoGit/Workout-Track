import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class FocusFrame extends StatelessWidget {
  const FocusFrame({
    super.key,
    required this.focused,
    required this.child,
    this.error = false,
    this.height,
  });

  final bool focused;
  final bool error;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;
    final borderColor = error ? kDanger : (focused ? kNeon : kBorder);
    final borderWidth = focused || error ? 2.0 : 1.0;
    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : kMotionFast,
      curve: Curves.linear,
      height: height,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (focused)
            IgnorePointer(
              child: CustomPaint(painter: const _FieldScanlinePainter()),
            ),
        ],
      ),
    );
  }
}

class _FieldScanlinePainter extends CustomPainter {
  const _FieldScanlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kText.withValues(alpha: 0.065)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
