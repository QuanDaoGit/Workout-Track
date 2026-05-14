import 'dart:async';

import 'package:flutter/material.dart';

/// Binary visibility toggle. Shows [child] for [onMs], hides for [offMs].
/// Uses Visibility with maintainSize/State/Animation so layout is stable.
class BlinkingColon extends StatefulWidget {
  const BlinkingColon({
    super.key,
    required this.child,
    this.onMs = 500,
    this.offMs = 500,
  });

  final Widget child;
  final int onMs;
  final int offMs;

  @override
  State<BlinkingColon> createState() => _BlinkingColonState();
}

class _BlinkingColonState extends State<BlinkingColon> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final ms = _visible ? widget.onMs : widget.offMs;
    _timer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() => _visible = !_visible);
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: _visible,
      maintainSize: true,
      maintainState: true,
      maintainAnimation: true,
      child: widget.child,
    );
  }
}
