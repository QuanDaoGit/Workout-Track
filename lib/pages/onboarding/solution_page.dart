import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/onboarding_lifter_sprite.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/screen_shake.dart';
import '../../widgets/strobe_flash.dart';

/// Screen 3 — the Solution. The loudest beat of the onboarding intro: states
/// the payoff, builds to a level-up slam on line 2, then resolves into the CTA
/// that hands off to character building. Out-animates the quiet Screen 2 on
/// purpose. Only the CTA advances; a background tap merely completes the intro.
class SolutionView extends StatefulWidget {
  const SolutionView({super.key, required this.onContinue});

  final VoidCallback onContinue;

  static const designWidth = 390.0;
  static const designHeight = 844.0;

  // Intro timeline (ms within a ~2300ms controller).
  static const _totalMs = 2300;
  static const _line1StartMs = 100;
  static const _line1DurMs = 200;
  static const _slamMs = 600;
  static const _motivStartMs = 1100;
  static const _motivStaggerMs = 150;
  static const _motivFadeMs = 400;
  static const _ctaStartMs = 1900;
  static const _ctaDurMs = 300;

  static const _strobeWindowMs = 480; // 6 toggles × 80ms

  @override
  State<SolutionView> createState() => _SolutionViewState();
}

class _SolutionViewState extends State<SolutionView>
    with TickerProviderStateMixin {
  late final AnimationController _introController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: SolutionView._totalMs),
  );
  late final AnimationController _ctaPulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _futureSelfBlinkController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 4800),
      );

  bool _complete = false;
  bool _reducedMotion = false;
  bool _handed = false;

  int _slamTrigger = 0;
  bool _slamFired = false;
  bool _frameReacting = false;
  Timer? _frameTimer;

  // Bumped on CTA press so the button wrapper StrobeFlash fires one short
  // amber halo before the handoff transition takes over.
  int _pressTrigger = 0;

  @override
  void initState() {
    super.initState();
    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finishIntro();
    });
    _introController.addListener(_maybeFireSlam);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableMotion = MediaQuery.of(context).disableAnimations;
    if (disableMotion == _reducedMotion &&
        (_complete || _introController.isAnimating)) {
      return;
    }
    _reducedMotion = disableMotion;
    if (_reducedMotion) {
      _introController.stop();
      _ctaPulseController.stop();
      _futureSelfBlinkController.stop();
      _futureSelfBlinkController.value = 0;
      _complete = true;
      _slamFired = true;
      _introController.value = 1;
    } else if (!_complete && !_introController.isAnimating) {
      _introController.forward(from: 0);
    } else if (_complete && !_futureSelfBlinkController.isAnimating) {
      _futureSelfBlinkController.repeat();
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _introController.dispose();
    _ctaPulseController.dispose();
    _futureSelfBlinkController.dispose();
    super.dispose();
  }

  void _maybeFireSlam() {
    if (_slamFired || _reducedMotion) return;
    if (_introController.value * SolutionView._totalMs >=
        SolutionView._slamMs) {
      _slamFired = true;
      setState(() {
        _slamTrigger++;
        _frameReacting = true;
      });
      _frameTimer = Timer(
        const Duration(milliseconds: SolutionView._strobeWindowMs),
        () {
          if (mounted) setState(() => _frameReacting = false);
        },
      );
    }
  }

  void _finishIntro() {
    if (_complete) return;
    _introController.stop();
    _introController.value = 1;
    _complete = true;
    if (!_reducedMotion && !_ctaPulseController.isAnimating) {
      _ctaPulseController.repeat(reverse: true);
    }
    if (!_reducedMotion && !_futureSelfBlinkController.isAnimating) {
      _futureSelfBlinkController.repeat();
    }
    if (mounted) setState(() {});
  }

  // Background tap completes the intro but never advances — only the CTA does.
  void _handleBackgroundTap() {
    if (!_complete && !_reducedMotion) _finishIntro();
  }

  Future<void> _handleCta() async {
    if (_handed) return;
    _handed = true;
    if (_reducedMotion) {
      widget.onContinue();
      return;
    }
    setState(() => _pressTrigger++);
    // Long enough for the one-toggle amber halo to play before navigation.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Solution screen.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleBackgroundTap,
        child: ColoredBox(
          color: kBg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    key: _solutionDesignFrameKey,
                    width: SolutionView.designWidth,
                    height: SolutionView.designHeight,
                    child: _reducedMotion
                        ? _SolutionComposition(host: this)
                        : ScreenShake(
                            trigger: _slamTrigger,
                            magnitude: 2,
                            frames: 4,
                            child: _SolutionComposition(host: this),
                          ),
                  ),
                ),
              ),
              if (!_reducedMotion)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _SolutionEffectLayer(
                      slamTrigger: _slamTrigger,
                      frameReacting: _frameReacting,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const _solutionDesignFrameKey = ValueKey('solution_design_frame');
const _solutionEffectLayerKey = ValueKey('solution_effect_layer');
const _solutionEffectBorderKey = ValueKey('solution_effect_border');
const _solutionFutureSelfTop = 520.0;
const _solutionCtaTop = 674.0;

class _SolutionEffectLayer extends StatelessWidget {
  const _SolutionEffectLayer({
    required this.slamTrigger,
    required this.frameReacting,
  });

  final int slamTrigger;
  final bool frameReacting;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: _solutionEffectLayerKey,
      child: StrobeFlash(
        trigger: slamTrigger,
        color: kAmber,
        toggles: 6,
        opacity: 0.3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (frameReacting) ...[
              CustomPaint(painter: _BrightScanlinePainter()),
              DecoratedBox(
                key: _solutionEffectBorderKey,
                decoration: BoxDecoration(
                  border: Border.all(color: kAmber, width: 3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SolutionComposition extends StatelessWidget {
  const _SolutionComposition({required this.host});

  final _SolutionViewState host;

  double _opacityFor(double ms, double startMs, double durMs) {
    if (host._complete) return 1;
    return ((ms - startMs) / durMs).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        host._introController,
        host._ctaPulseController,
        host._futureSelfBlinkController,
      ]),
      builder: (context, _) {
        final ms = host._complete
            ? SolutionView._totalMs.toDouble()
            : host._introController.value * SolutionView._totalMs;

        final line1Opacity = _opacityFor(
          ms,
          SolutionView._line1StartMs.toDouble(),
          SolutionView._line1DurMs.toDouble(),
        );
        // Line 2 slams in — a hard cut, not a fade.
        final line2Visible = host._complete || ms >= SolutionView._slamMs;

        final ctaT = _opacityFor(
          ms,
          SolutionView._ctaStartMs.toDouble(),
          SolutionView._ctaDurMs.toDouble(),
        );
        final pulse = (host._complete && !host._reducedMotion)
            ? host._ctaPulseController.value
            : 0.0;
        final futureSelfOpacity = _futureSelfOpacity(ms);
        return Stack(
          children: [
            // Solution statement.
            Positioned(
              top: 226,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  Opacity(
                    opacity: line1Opacity,
                    child: const Text(
                      'HERE, EVERY REP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 16,
                        color: kText,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Opacity(
                    opacity: line2Visible ? 1.0 : 0.0,
                    child: const Text(
                      'LEVELS YOU UP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 16,
                        color: kAmber,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Motivation block — three lines arriving in sequence.
            Positioned(
              top: 404,
              left: 32,
              right: 32,
              child: Column(
                children: [
                  _motivLine(ms, 0, 'now the work ', 'shows', '.'),
                  _motivLine(ms, 1, 'every rep, a little ', 'stronger', '.'),
                  _motivLine(ms, 2, "and you'll keep coming back.", '', ''),
                ],
              ),
            ),
            // CTA — slides up + fades in, then idle-pulses.
            if (futureSelfOpacity > 0)
              Positioned(
                top: _solutionFutureSelfTop,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: futureSelfOpacity,
                    child: Column(
                      key: const ValueKey('solution_aspiration_tease'),
                      children: [
                        OnboardingLifterSprite(
                          mode: OnboardingLifterSpriteMode.triumph,
                          width: 140,
                          height: 100,
                          edgeColor: kAmber,
                          blinkProgress: host._futureSelfBlinkController.value,
                        ),
                        const SizedBox(height: 6),
                        const _TinyAmberStrBar(),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: _solutionCtaTop,
              left: 32,
              right: 32,
              child: Opacity(
                opacity: ctaT,
                child: Transform.translate(
                  offset: Offset(0, (1 - ctaT) * 20),
                  child: Transform.scale(
                    scale: 1 + 0.02 * pulse,
                    child: StrobeFlash(
                      trigger: host._pressTrigger,
                      color: kAmber,
                      opacity: 0.35,
                      toggles: 1,
                      toggleMs: 120,
                      child: PixelButton(
                        label: 'BUILD MY CHARACTER',
                        fontSize: 14,
                        minHeight: 56,
                        onPressed: host._handleCta,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _futureSelfOpacity(double ms) {
    const settledOpacity = 0.6;
    if (host._complete || host._reducedMotion) return settledOpacity;
    if (ms < 1550) return 0;
    if (ms < 1750) return ((ms - 1550) / 200).clamp(0.0, 1.0).toDouble();
    if (ms < 2500) return 1;
    if (ms < 3000) {
      final fadeT = ((ms - 2500) / 200).clamp(0.0, 1.0).toDouble();
      return 1 - fadeT * (1 - settledOpacity);
    }
    return settledOpacity;
  }

  Widget _motivLine(
    double ms,
    int index,
    String pre,
    String neon,
    String post,
  ) {
    final startMs =
        SolutionView._motivStartMs + index * SolutionView._motivStaggerMs;
    final opacity = _opacityFor(
      ms,
      startMs.toDouble(),
      SolutionView._motivFadeMs.toDouble(),
    );
    // Gentle one-shot flicker on the neon word as the line arrives.
    double neonAlpha = 1;
    if (!host._complete && neon.isNotEmpty) {
      final since = ms - (startMs + SolutionView._motivFadeMs);
      if (since >= 0 && since < 200) {
        neonAlpha = 0.55 + 0.45 * (0.5 - 0.5 * math.cos(since / 200 * math.pi));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Opacity(
        opacity: opacity,
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 14,
              height: 1.6,
            ),
            children: [
              TextSpan(text: pre),
              if (neon.isNotEmpty)
                TextSpan(
                  text: neon,
                  style: TextStyle(color: kNeon.withValues(alpha: neonAlpha)),
                ),
              if (post.isNotEmpty) TextSpan(text: post),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyAmberStrBar extends StatelessWidget {
  const _TinyAmberStrBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 12,
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: kAmber.withValues(alpha: 0.75),
                  border: Border.all(color: kAmber),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const SizedBox.expand(),
              ),
            ),
            if (i != 3) const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }
}

/// Brightened scanlines for the transient line-2 frame reaction. Stronger than
/// the always-on global 4% overlay; rendered only while the strobe fires.
class _BrightScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
