import 'dart:async';

import 'package:flutter/material.dart';

/// Renders [text] alternating between [colorA] and [colorB] every
/// [periodMs]. Hard color swap — no gradient lerp, no AnimatedDefaultTextStyle.
class PulseColorText extends StatefulWidget {
  const PulseColorText(
    this.text, {
    super.key,
    required this.style,
    this.colorA = const Color(0xFFFFD700),
    this.colorB = const Color(0xFFFFA500),
    this.periodMs = 500,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final Color colorA;
  final Color colorB;
  final int periodMs;
  final TextAlign? textAlign;

  @override
  State<PulseColorText> createState() => _PulseColorTextState();
}

class _PulseColorTextState extends State<PulseColorText> {
  bool _useA = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: widget.periodMs), (_) {
      if (!mounted) return;
      setState(() => _useA = !_useA);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.text,
      style: widget.style.copyWith(
        color: _useA ? widget.colorA : widget.colorB,
      ),
      textAlign: widget.textAlign,
    );
  }
}
