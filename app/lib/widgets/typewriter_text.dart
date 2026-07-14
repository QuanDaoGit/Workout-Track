import 'dart:async';

import 'package:flutter/material.dart';

/// Reveals [text] one character at a time via Timer.periodic + setState.
/// Restarts whenever [text] changes. No fade, no animation curves.
class TypewriterText extends StatefulWidget {
  const TypewriterText(
    this.text, {
    super.key,
    this.style,
    this.charMs = 40,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int charMs;
  final TextAlign? textAlign;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    _count = 0;
    if (widget.text.isEmpty) return;
    _timer = Timer.periodic(Duration(milliseconds: widget.charMs), (t) {
      if (!mounted) return;
      if (_count >= widget.text.length) {
        t.cancel();
        return;
      }
      setState(() => _count++);
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
      widget.text.substring(0, _count),
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }
}
