import 'dart:async';

import 'package:flutter/material.dart';

/// Binary on/off strobe overlay. Each time [trigger] changes value, runs
/// [toggles] hard cuts of the overlay color at [toggleMs] intervals, then
/// stays off. No fade, no interpolation.
class StrobeFlash extends StatefulWidget {
  const StrobeFlash({
    super.key,
    required this.trigger,
    required this.child,
    this.color = const Color(0xFF00FF9C),
    this.opacity = 0.25,
    this.borderRadius,
    this.toggles = 6,
    this.toggleMs = 80,
    this.fireOnMount = false,
  });

  final Object? trigger;
  final Widget child;
  final Color color;
  final double opacity;
  final BorderRadius? borderRadius;
  final int toggles;
  final int toggleMs;
  final bool fireOnMount;

  @override
  State<StrobeFlash> createState() => _StrobeFlashState();
}

class _StrobeFlashState extends State<StrobeFlash> {
  bool _on = false;
  int _toggled = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.fireOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void didUpdateWidget(StrobeFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    _toggled = 0;
    setState(() => _on = true);
    _timer = Timer.periodic(Duration(milliseconds: widget.toggleMs), (t) {
      _toggled++;
      if (_toggled >= widget.toggles) {
        t.cancel();
        if (!mounted) return;
        setState(() => _on = false);
        return;
      }
      if (!mounted) return;
      setState(() => _on = !_on);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_on)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: widget.opacity),
                  borderRadius: widget.borderRadius,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
