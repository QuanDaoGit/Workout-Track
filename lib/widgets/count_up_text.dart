import 'package:flutter/material.dart';

/// An integer that animates from 0 up to [value] (count-up), used for the
/// finish-arc hero amount and XP counter. Honors reduced motion: when the OS /
/// in-app reduce-motion flag is on, the final value renders instantly with no
/// animation. Uses an animated value (not a timer hack) per the design's
/// technical constraints.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 600),
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.textAlign,
  });

  final int value;
  final Duration duration;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced) {
      return Text('$prefix$value$suffix', style: style, textAlign: textAlign);
    }
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, current, _) =>
          Text('$prefix$current$suffix', style: style, textAlign: textAlign),
    );
  }
}
