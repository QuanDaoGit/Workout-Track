import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/haptic_service.dart';
import '../../services/sfx_service.dart';
import '../../services/ui_sound.dart';
import '../../theme/tokens.dart';

class PhosphorTap extends StatefulWidget {
  const PhosphorTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.color = kNeon,
    this.opacity = 0.4,
    this.borderRadius = const BorderRadius.all(Radius.circular(kCardRadius)),
    this.behavior = HitTestBehavior.opaque,
    this.haptic = HapticIntent.none,
    this.sound,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final Color color;
  final double opacity;
  final BorderRadius borderRadius;
  final HitTestBehavior behavior;

  /// Opt-in kit sound on a committed tap (SFX v2). Explicit per site — never
  /// derived from [haptic]. Defaults to silent.
  final UiSound? sound;

  /// Opt-in tactile tick on a committed tap, routed through the rate-limited
  /// [HapticService.fireCoalesced] so the broad layer stays a *tick*, never a
  /// buzz. Defaults to [HapticIntent.none] (silent) — only meaningful, committing
  /// taps should opt in (never passive scroll / informational chrome).
  final HapticIntent haptic;

  @override
  State<PhosphorTap> createState() => _PhosphorTapState();
}

class _PhosphorTapState extends State<PhosphorTap> {
  Offset? _tapPosition;
  bool _active = false;
  Timer? _timer;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startHalo(TapDownDetails details) {
    if (!widget.enabled) return;
    _timer?.cancel();
    setState(() {
      _tapPosition = details.localPosition;
      _active = true;
    });
    _timer = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      setState(() => _active = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tap = widget.enabled && widget.onTap != null ? widget.onTap : null;
    final longPress = widget.enabled && widget.onLongPress != null
        ? widget.onLongPress
        : null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _startHalo,
      onTap: tap == null
          ? null
          : () {
              HapticService.instance.fireCoalesced(widget.haptic);
              final s = widget.sound;
              if (s != null) SfxService.instance.playUi(s);
              tap();
            },
      onLongPress: longPress,
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_active)
            Positioned.fill(
              child: IgnorePointer(
                child: _reduceMotion
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: widget.color, width: 1),
                          borderRadius: widget.borderRadius,
                        ),
                      )
                    : CustomPaint(
                        painter: _PhosphorHaloPainter(
                          tapPosition: _tapPosition ?? Offset.zero,
                          borderRadius: widget.borderRadius,
                          color: widget.color,
                          opacity: widget.opacity,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhosphorHaloPainter extends CustomPainter {
  const _PhosphorHaloPainter({
    required this.tapPosition,
    required this.borderRadius,
    required this.color,
    required this.opacity,
  });

  final Offset tapPosition;
  final BorderRadius borderRadius;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final clip = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: borderRadius.topLeft,
      topRight: borderRadius.topRight,
      bottomLeft: borderRadius.bottomLeft,
      bottomRight: borderRadius.bottomRight,
    );
    canvas.clipRRect(clip);
    final radius = size.shortestSide * 0.42;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: opacity);
    canvas.drawCircle(tapPosition, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _PhosphorHaloPainter oldDelegate) =>
      oldDelegate.tapPosition != tapPosition ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.color != color ||
      oldDelegate.opacity != opacity;
}
