import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class PixelLoader extends StatefulWidget {
  const PixelLoader({
    super.key,
    this.size = 24,
    this.color = const Color(0xFF00FF9C),
  });

  final double size;
  final Color color;

  @override
  State<PixelLoader> createState() => _PixelLoaderState();
}

class _PixelLoaderState extends State<PixelLoader> {
  int _frame = 0;
  Timer? _timer;

  static const _kFrames = 8;
  static const _kFrameMs = 125;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: _kFrameMs), (_) {
      if (!mounted) return;
      setState(() => _frame = (_frame + 1) % _kFrames);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: _frame * (math.pi / 4),
      child: ImageIcon(
        const AssetImage('assets/icons/control/icon_loader.png'),
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}
