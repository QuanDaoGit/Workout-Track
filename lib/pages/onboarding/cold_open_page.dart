import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion/power_on.dart';
import '../../widgets/welcome_bench_press_scene.dart';

/// Screen 1 - Cold Open. Arcade boot screen for first-run onboarding. Tap to
/// continue. Rendered inside the onboarding flow's scaffold.
class ColdOpenView extends StatelessWidget {
  const ColdOpenView({super.key, required this.onContinue});

  final VoidCallback onContinue;

  static const _designWidth = 390.0;
  static const _designHeight = 844.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      hint: 'Press start to continue',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onContinue,
        child: const ColoredBox(
          color: kBg,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _designWidth,
                height: _designHeight,
                child: _ColdOpenComposition(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColdOpenComposition extends StatefulWidget {
  const _ColdOpenComposition();

  @override
  State<_ColdOpenComposition> createState() => _ColdOpenCompositionState();
}

class _ColdOpenCompositionState extends State<_ColdOpenComposition>
    with SingleTickerProviderStateMixin {
  // Staged CRT entrance: the IRONBIT wordmark flies up into its slot first (the
  // shared element the boot transition powers on into), then the scene, meter,
  // lines, and prompt power on in sequence. Static under reduced motion.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _entrance.value = 1;
    } else if (!_entrance.isAnimating && _entrance.value == 0) {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, _) {
        final e = _reduceMotion ? 1.0 : _entrance.value;
        // Wordmark flies up into its slot first (top 300 → 94).
        final wt = Curves.easeOutCubic.transform(
          (e / 0.30).clamp(0.0, 1.0).toDouble(),
        );
        final wordTop = 300 - (300 - 94) * wt;
        final wordOpacity = (e / 0.20).clamp(0.0, 1.0).toDouble();

        return Stack(
          children: [
            Positioned(
              top: wordTop,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: wordOpacity,
                child: const Text(
                  'IRONBIT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 14,
                    height: 1,
                    color: kNeon,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            _PoweredSlot(
              enabled: e >= 0.34,
              top: 250,
              left: 67,
              child: const WelcomeBenchPressScene(width: 256, height: 192),
            ),
            _PoweredSlot(
              enabled: e >= 0.46,
              top: 456,
              left: 75,
              child: const _StrMeter(),
            ),
            _PoweredSlot(
              enabled: e >= 0.58,
              top: 574,
              left: 0,
              right: 0,
              child: const Text(
                'WELCOME, RECRUIT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 16,
                  height: 1,
                  color: kNeon,
                  letterSpacing: 1,
                ),
              ),
            ),
            _PoweredSlot(
              enabled: e >= 0.68,
              top: 607,
              left: 42,
              right: 42,
              child: Text(
                'YOUR TRAINING BUILDS YOUR CHARACTER',
                textAlign: TextAlign.center,
                style: AppFonts.shareTechMono(
                  color: kMutedText,
                  fontSize: 13,
                  height: 1.35,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _PoweredSlot(
              enabled: e >= 0.80,
              top: 774,
              left: 0,
              right: 0,
              child: const _PressStartPrompt(),
            ),
          ],
        );
      },
    );
  }
}

/// A `Positioned` child that CRT-powers-on (via [PowerOn]) when [enabled] flips
/// true — used to stagger the cold-open elements in after the wordmark lands.
class _PoweredSlot extends StatelessWidget {
  const _PoweredSlot({
    required this.enabled,
    required this.top,
    required this.child,
    this.left,
    this.right,
  });

  final bool enabled;
  final double top;
  final double? left;
  final double? right;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: PowerOn(
        enabled: enabled,
        builder: (context, power) =>
            Opacity(opacity: power.clamp(0.0, 1.0), child: child),
      ),
    );
  }
}

class _StrMeter extends StatefulWidget {
  const _StrMeter();

  @override
  State<_StrMeter> createState() => _StrMeterState();
}

class _StrMeterState extends State<_StrMeter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableMotion = MediaQuery.of(context).disableAnimations;
    if (disableMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STR',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              height: 1,
              color: kNeon,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final states = disableMotion
                  ? List.generate(4, (_) => const _StrCellState(1, 0))
                  : _cellStates(_controller.value);
              return Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    Expanded(child: _StrCell(state: states[i])),
                    if (i != 3) const SizedBox(width: 5),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<_StrCellState> _cellStates(double progress) {
    const repSeconds = 1.4;
    final seconds = progress * 6.3;
    if (seconds >= 5.6) {
      final fade = math.max(0.0, 1 - ((seconds - 5.6) / 0.28));
      return List.generate(4, (_) => _StrCellState(fade, fade * 0.18));
    }

    final repIndex = math.min(3, (seconds / repSeconds).floor());
    final repT = seconds - repIndex * repSeconds;
    final states = List.generate(4, (_) => const _StrCellState(0, 0));

    for (var i = 0; i < repIndex; i++) {
      states[i] = const _StrCellState(1, 0);
    }

    if (repT >= 1.13) {
      var brightness = 0.0;
      final flashAge = repT - 1.13;
      if (flashAge < 0.12) brightness = 1 - flashAge / 0.12;
      states[repIndex] = _StrCellState(1, brightness);
    }

    if (repIndex == 3 && repT >= 1.13) {
      final flashT = repT - 1.13;
      var pulse = 0.0;
      for (final phase in const [0.05, 0.15, 0.24]) {
        final distance = (flashT - phase).abs();
        if (distance < 0.04) pulse = math.max(pulse, 1 - distance / 0.04);
      }
      for (var i = 0; i < states.length; i++) {
        if (states[i].opacity > 0) {
          states[i] = _StrCellState(
            states[i].opacity,
            math.max(states[i].brightness, pulse),
          );
        }
      }
    }

    return states;
  }
}

class _StrCellState {
  const _StrCellState(this.opacity, this.brightness);

  final double opacity;
  final double brightness;
}

class _StrCell extends StatelessWidget {
  const _StrCell({required this.state});

  final _StrCellState state;

  @override
  Widget build(BuildContext context) {
    final litColor = Color.lerp(
      kNeon,
      const Color(0xFFC8FFDC),
      state.brightness,
    )!;

    return Container(
      height: 20,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: state.opacity,
              child: ColoredBox(color: litColor),
            ),
          ),
          if (state.brightness > 0.45) ...[
            Positioned(
              top: -1,
              right: 8,
              child: _Spark(opacity: state.brightness),
            ),
            Positioned(
              top: 4,
              right: -1,
              child: _Spark(opacity: state.brightness * 0.75),
            ),
          ],
        ],
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  const _Spark({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0).toDouble(),
      child: const SizedBox(
        width: 3,
        height: 3,
        child: DecoratedBox(decoration: BoxDecoration(color: kNeon)),
      ),
    );
  }
}

class _PressStartPrompt extends StatefulWidget {
  const _PressStartPrompt();

  @override
  State<_PressStartPrompt> createState() => _PressStartPromptState();
}

class _PressStartPromptState extends State<_PressStartPrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableMotion = MediaQuery.of(context).disableAnimations;
    if (disableMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dimmed = !disableMotion && _controller.value >= 0.5;
        return Text(
          'PRESS START',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            height: 1,
            color: dimmed ? kMutedText : kNeon,
            letterSpacing: 1,
          ),
        );
      },
    );
  }
}
