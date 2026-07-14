import 'dart:async';

import 'package:flutter/material.dart';

import 'pixel_button.dart';

/// A [PixelButton] that stays disabled for [delay] before becoming tappable.
/// The brief ceremonial pause turns a tap into a deliberate commitment — the
/// same mechanism used by the body-metrics pledge, extracted for reuse.
class DelayedConfirmButton extends StatefulWidget {
  const DelayedConfirmButton({
    super.key,
    required this.label,
    required this.onConfirm,
    this.delay = const Duration(seconds: 2),
    this.color,
  });

  final String label;
  final VoidCallback onConfirm;
  final Duration delay;
  final Color? color;

  @override
  State<DelayedConfirmButton> createState() => _DelayedConfirmButtonState();
}

class _DelayedConfirmButtonState extends State<DelayedConfirmButton> {
  bool _ready = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PixelButton(
      label: widget.label,
      color: widget.color,
      onPressed: _ready ? widget.onConfirm : null,
    );
  }
}
