import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps [child] with a discrete translate shake. Each time [trigger]
/// changes, picks a fresh random offset within [magnitude] every
/// [frameMs] for [frames] ticks, then resets to zero. No interpolation.
class ScreenShake extends StatefulWidget {
  const ScreenShake({
    super.key,
    required this.trigger,
    required this.child,
    this.frames = 4,
    this.frameMs = 50,
    this.magnitude = 2,
  });

  final Object? trigger;
  final Widget child;
  final int frames;
  final int frameMs;
  final double magnitude;

  @override
  State<ScreenShake> createState() => _ScreenShakeState();
}

class _ScreenShakeState extends State<ScreenShake> {
  Offset _offset = Offset.zero;
  Timer? _timer;
  final _rand = math.Random();

  @override
  void didUpdateWidget(ScreenShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    var ticks = 0;
    _timer = Timer.periodic(Duration(milliseconds: widget.frameMs), (t) {
      ticks++;
      if (ticks >= widget.frames) {
        t.cancel();
        if (!mounted) return;
        setState(() => _offset = Offset.zero);
        return;
      }
      if (!mounted) return;
      setState(() {
        _offset = Offset(
          (_rand.nextDouble() * 2 - 1) * widget.magnitude,
          (_rand.nextDouble() * 2 - 1) * widget.magnitude,
        );
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(offset: _offset, child: widget.child);
  }
}
