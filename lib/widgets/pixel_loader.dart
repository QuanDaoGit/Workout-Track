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

class _PixelLoaderState extends State<PixelLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: ImageIcon(
        const AssetImage('assets/icons/control/icon_loader.png'),
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}
