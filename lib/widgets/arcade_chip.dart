import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'motion/hold_depress.dart';

/// Drop-in replacement for ChoiceChip with arcade-style selection feedback.
/// Border + text color swap is instant. When the chip becomes selected,
/// the border blinks twice (on-off-on, 80ms each) then stays solid.
class ArcadeChip extends StatefulWidget {
  const ArcadeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = kNeon,
    this.unselectedTextColor = kMutedText,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color unselectedTextColor;
  @override
  State<ArcadeChip> createState() => _ArcadeChipState();
}

class _ArcadeChipState extends State<ArcadeChip> {
  bool _blinkOn = true;
  Timer? _timer;

  @override
  void didUpdateWidget(ArcadeChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _startBlink();
    } else if (!widget.selected && oldWidget.selected) {
      _timer?.cancel();
      _blinkOn = true;
    }
  }

  void _startBlink() {
    _timer?.cancel();
    setState(() => _blinkOn = true);
    var count = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      count++;
      if (count >= 2) {
        t.cancel();
        if (!mounted) return;
        setState(() => _blinkOn = true);
        return;
      }
      if (!mounted) return;
      setState(() => _blinkOn = !_blinkOn);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final borderColor = selected
        ? (_blinkOn ? widget.selectedColor : kBorderDark)
        : kBorder;
    final textColor = selected
        ? widget.selectedColor
        : widget.unselectedTextColor;
    final bg = kCard;

    return HoldDepress(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: textColor,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'PressStart2P',
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
