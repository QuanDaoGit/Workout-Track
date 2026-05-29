import 'dart:async';

import 'package:flutter/material.dart';

class PowerOn extends StatefulWidget {
  const PowerOn({super.key, required this.enabled, required this.builder});

  final bool enabled;
  final Widget Function(BuildContext context, double power) builder;

  @override
  State<PowerOn> createState() => _PowerOnState();
}

class _PowerOnState extends State<PowerOn> {
  static const _steps = [0.0, 0.3, 0.8, 1.0];
  Timer? _timer;
  int _step = 3;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void didUpdateWidget(covariant PowerOn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled == oldWidget.enabled) return;
    if (_reduceMotion) {
      _timer?.cancel();
      setState(() => _step = widget.enabled ? 3 : 0);
      return;
    }
    _start(widget.enabled);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) _step = widget.enabled ? 3 : 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start(bool poweringOn) {
    _timer?.cancel();
    final sequence = poweringOn ? [1, 2, 3] : [2, 1, 0];
    var index = 0;
    setState(() => _step = sequence[index]);
    _timer = Timer.periodic(const Duration(milliseconds: 66), (timer) {
      index++;
      if (index >= sequence.length) {
        timer.cancel();
        return;
      }
      if (mounted) setState(() => _step = sequence[index]);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_reduceMotion && _timer == null) {
      _step = widget.enabled ? 3 : 0;
    }
    return widget.builder(context, _steps[_step]);
  }
}
