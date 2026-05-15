import 'dart:async';

import 'package:flutter/material.dart';

/// Drop-in replacement for InkWell that does a hard color swap on tap
/// instead of a Material ripple. Background flashes [flashColor] for
/// [flashMs] then snaps back to transparent. No splash, no interpolation.
class ArcadeTap extends StatefulWidget {
  const ArcadeTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.flashColor = const Color(0xFF00FF9C),
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
  State<ArcadeTap> createState() => _ArcadeTapState();
}

class _ArcadeTapState extends State<ArcadeTap> {
  bool _flashing = false;
  Timer? _timer;

  void _fire() {
    _timer?.cancel();
    setState(() => _flashing = true);
    _timer = Timer(Duration(milliseconds: widget.flashMs), () {
      if (!mounted) return;
      setState(() => _flashing = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tappable = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: tappable ? (_) => _fire() : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Stack(
        children: [
          widget.child,
          if (_flashing)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.flashColor.withValues(
                      alpha: widget.flashOpacity,
                    ),
                    borderRadius: widget.borderRadius,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
