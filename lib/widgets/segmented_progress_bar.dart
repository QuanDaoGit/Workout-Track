import 'dart:async';

import 'package:flutter/material.dart';

/// Discrete segmented progress bar. Cells are either lit or unlit — no
/// smooth fill. When [litCells] grows, the newly lit cell(s) strobe via
/// binary on/off toggles before settling.
class SegmentedProgressBar extends StatefulWidget {
  const SegmentedProgressBar({
    super.key,
    required this.totalCells,
    required this.litCells,
    this.height = 8,
    this.gap = 2,
    this.litColor = const Color(0xFF00FF9C),
    this.unlitBorderColor = const Color(0xFF2A2A3E),
    this.litBorderColor = const Color(0xFF7FFFCE),
    this.toggles = 6,
    this.toggleMs = 80,
  });

  final int totalCells;
  final int litCells;
  final double height;
  final double gap;
  final Color litColor;
  final Color unlitBorderColor;
  final Color litBorderColor;
  final int toggles;
  final int toggleMs;

  @override
  State<SegmentedProgressBar> createState() => _SegmentedProgressBarState();
}

class _SegmentedProgressBarState extends State<SegmentedProgressBar> {
  final Set<int> _blinking = {};
  final Map<int, bool> _blinkState = {};
  final Map<int, Timer> _timers = {};
  final Map<int, int> _toggledCount = {};
  int _previousLit = 0;

  @override
  void initState() {
    super.initState();
    _previousLit = widget.litCells;
  }

  @override
  void didUpdateWidget(SegmentedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.litCells > _previousLit) {
      for (var i = _previousLit; i < widget.litCells; i++) {
        _startBlink(i);
      }
    }
    _previousLit = widget.litCells;
  }

  void _startBlink(int index) {
    _timers[index]?.cancel();
    _blinking.add(index);
    _blinkState[index] = true;
    _toggledCount[index] = 0;
    setState(() {});
    _timers[index] = Timer.periodic(Duration(milliseconds: widget.toggleMs), (
      t,
    ) {
      final count = (_toggledCount[index] ?? 0) + 1;
      _toggledCount[index] = count;
      if (count >= widget.toggles) {
        t.cancel();
        if (!mounted) return;
        setState(() {
          _blinking.remove(index);
          _blinkState[index] = true;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _blinkState[index] = !(_blinkState[index] ?? true);
      });
    });
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }

  bool _isVisuallyLit(int index) {
    if (index >= widget.litCells) return false;
    if (_blinking.contains(index)) return _blinkState[index] ?? true;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        children: [
          for (var i = 0; i < widget.totalCells; i++) ...[
            Expanded(child: _cell(i)),
            if (i < widget.totalCells - 1) SizedBox(width: widget.gap),
          ],
        ],
      ),
    );
  }

  Widget _cell(int index) {
    final lit = _isVisuallyLit(index);
    return Container(
      decoration: BoxDecoration(
        color: lit ? widget.litColor : Colors.transparent,
        border: Border.all(
          color: lit ? widget.litBorderColor : widget.unlitBorderColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
