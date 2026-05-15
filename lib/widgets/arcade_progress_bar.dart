import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class ArcadeProgressBar extends StatefulWidget {
  const ArcadeProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.fillColor = kNeon,
    this.trackColor = kBorder,
    this.flashOnIncrease = false,
    this.increaseSignal,
    this.duration = const Duration(milliseconds: 350),
  });

  final double value;
  final double height;
  final Color fillColor;
  final Color trackColor;
  final bool flashOnIncrease;
  final int? increaseSignal;
  final Duration duration;

  @override
  State<ArcadeProgressBar> createState() => _ArcadeProgressBarState();
}

class _ArcadeProgressBarState extends State<ArcadeProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _flashOpacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.32), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 0.32, end: 0.0), weight: 65),
  ]).animate(CurvedAnimation(parent: _flashController, curve: Curves.easeOut));

  double _previousValue = 0;

  double get _clampedValue => widget.value.clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _previousValue = _clampedValue;
  }

  @override
  void didUpdateWidget(covariant ArcadeProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _clampedValue;
    final signalIncreased =
        widget.increaseSignal != null && oldWidget.increaseSignal != null
        ? widget.increaseSignal! > oldWidget.increaseSignal!
        : next > _previousValue;
    if (widget.flashOnIncrease && signalIncreased) {
      _flashController.forward(from: 0);
    }
    _previousValue = next;
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: widget.trackColor),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _clampedValue),
              duration: widget.duration,
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: ColoredBox(color: widget.fillColor),
                );
              },
            ),
            if (widget.flashOnIncrease)
              AnimatedBuilder(
                animation: _flashOpacity,
                builder: (context, _) {
                  return ColoredBox(
                    color: widget.fillColor.withValues(
                      alpha: _flashOpacity.value,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
