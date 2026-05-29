import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
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

class _ColdOpenComposition extends StatelessWidget {
  const _ColdOpenComposition();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          top: 94,
          left: 0,
          right: 0,
          child: Text(
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
        const Positioned(
          top: 250,
          left: 67,
          child: WelcomeBenchPressScene(width: 256, height: 192),
        ),
        const Positioned(top: 456, left: 75, child: _StrMeter()),
        const Positioned(
          top: 574,
          left: 0,
          right: 0,
          child: Text(
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
        Positioned(
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
        const Positioned(
          top: 774,
          left: 0,
          right: 0,
          child: _PressStartPrompt(),
        ),
      ],
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
