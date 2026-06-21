import 'package:flutter/material.dart';

import '../../services/haptic_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_bar.dart';
import '../../widgets/companion/bit_boot.dart' show BitVoiceWaveform;
import '../../widgets/companion/bit_core_engine.dart' show bitGlow;
import '../../widgets/companion/bit_mood_core.dart';
import '../../widgets/pixel_button.dart';

/// Screen 3 — the Solution. The **emotional peak** of the onboarding intro and
/// the payoff to Screen 2's low: the companion **BIT**, carried in still slumped
/// (rest), **bursts into a cheer face** (energetic, amber — eyes open, a grin,
/// plates spread) as he says *"HERE, EVERY REP LEVELS YOU UP"*, then **settles to
/// a steady neutral** (turquoise) for *"YOU WILL KEEP COMING BACK FOR MORE"*.
/// Now present, he runs a small **level-up preview** (fills then resets — a
/// demonstration, never an earned reward). Only the CTA advances; a background
/// tap completes the intro.
///
/// The cheer burst → neutral settle is the focal beat (one phosphor-soft glow
/// surge + one haptic; no rapid strobe/shake). Reduced motion renders the
/// settled, revealed *neutral* state directly.
class SolutionView extends StatefulWidget {
  const SolutionView({super.key, required this.onContinue});

  final VoidCallback onContinue;

  static const designWidth = 390.0;
  static const designHeight = 844.0;

  // Intro timeline (ms within a ~3700ms controller). The weighty power-up:
  // carry-in → anticipation INHALE → surge → peak HOLD → settle. Tunable knobs.
  static const _totalMs = 3700;
  static const _inhaleStartMs = 520; // the coil begins to gather (ease in)
  static const _inhalePeakMs = 760; // deepest inhale; pose flips rest→cheer here
  static const _surgeStartMs = 760; // (== inhale peak) the surge fires
  static const _releaseEndMs = 980; // the coil snaps released as BIT rises
  static const _revealStartMs = 820; // eyes begin opening with the surge
  static const _revealEndMs = 1320; // eyes fully open
  static const _bloomAtMs = 1340; // the surge punch — glow surge + haptic
  static const _blinkStartMs = 1380; // one blink — the "sign of life"
  static const _blinkEndMs = 1540;
  static const _settleStartMs = 1920; // peak-hold done → cheer → neutral settle
  static const _idleRampEndMs = 2320; // idle bob/breathe faded back to full
  static const _line1StartMs = 880; // "HERE, EVERY REP / LEVELS YOU UP" (cheer)
  static const _line1EndMs = 1720;
  static const _line2StartMs = 2000; // "YOU WILL KEEP COMING / BACK FOR MORE"
  static const _line2EndMs = 2840;
  static const _demoStartMs = 1100; // the level preview fills (with line 1)…
  static const _demoFillEndMs = 1720;
  static const _demoHoldMs = 1880; // …shows LV 2 briefly…
  static const _demoResetEndMs = 2200; // …then resets to locked (honest)
  static const _ctaStartMs = 3000;
  static const _ctaEndMs = 3400;

  // BIT rises from the Screen-2 carry-in home up to its Screen-3 stage as it
  // bursts (motivates the rise; leaves room for the lines + preview below).
  static const _bitCarryTop = 232.0;
  static const _bitStageTop = 150.0;

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

  bool _complete = false;
  bool _reducedMotion = false;
  bool _handed = false;

  // One haptic at the cheer-burst peak.
  bool _bloomFired = false;

  @override
  void initState() {
    super.initState();
    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finishIntro();
    });
    _introController.addListener(_maybeFireBloom);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced presentation = OS reduce-motion OR an active screen reader / switch
    // access (app-wide contract) — a screen-reader user lands on the settled,
    // revealed neutral state, not the power-up cinematic.
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;
    if (reduceMotion == _reducedMotion &&
        (_complete || _introController.isAnimating)) {
      return;
    }
    _reducedMotion = reduceMotion;
    if (_reducedMotion) {
      _introController.stop();
      _ctaPulseController.stop();
      _complete = true;
      _bloomFired = true;
      _introController.value = 1;
    } else if (!_complete && !_introController.isAnimating) {
      _introController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _ctaPulseController.dispose();
    super.dispose();
  }

  void _maybeFireBloom() {
    if (_bloomFired || _reducedMotion) return;
    if (_introController.value * SolutionView._totalMs >=
        SolutionView._bloomAtMs) {
      _bloomFired = true;
      HapticService.instance.reward();
    }
  }

  void _finishIntro() {
    if (_complete) return;
    _introController.stop();
    _introController.value = 1;
    _complete = true;
    _bloomFired = true;
    if (!_reducedMotion && !_ctaPulseController.isAnimating) {
      _ctaPulseController.repeat(reverse: true);
    }
    if (mounted) setState(() {});
  }

  // Background tap completes the intro but never advances — only the CTA does.
  void _handleBackgroundTap() {
    if (!_complete && !_reducedMotion) _finishIntro();
  }

  Future<void> _handleCta() async {
    if (_handed || !_complete) return; // gated until the settled state
    _handed = true;
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Here, every rep levels you up. You will keep coming back for more.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleBackgroundTap,
        child: DecoratedBox(
          key: _solutionBackdropKey,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -1.08),
              radius: 1.35,
              colors: [kBgGradientTop, kBg, kBgGradientBottom],
              stops: [0, 0.52, 1],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: CustomPaint(painter: _CrtScreenPainter())),
              Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    key: _solutionDesignFrameKey,
                    width: SolutionView.designWidth,
                    height: SolutionView.designHeight,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _introController,
                        _ctaPulseController,
                      ]),
                      builder: (context, _) => _composition(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composition() {
    final ms = (_complete ? 1.0 : _introController.value) * SolutionView._totalMs;

    // The weighty power-up: rest (carry-in) → an anticipation INHALE (the coil
    // deepens BIT then releases) → a surge into cheer (gentle overshoot in the
    // engine) → a still peak-cheer HOLD → a calm settle to neutral (grounded,
    // not the sunk/tilted deflate of Screen 2).
    final pose = ms < SolutionView._surgeStartMs
        ? BitPose.rest
        : (ms < SolutionView._settleStartMs ? BitPose.cheer : BitPose.neutral);
    final anticipation = _anticipationFor(ms);
    final idleAmp = _idleAmpFor(ms);
    final reveal = _complete
        ? 1.0
        : Curves.easeOutCubic.transform(
            ((ms - SolutionView._revealStartMs) /
                    (SolutionView._revealEndMs - SolutionView._revealStartMs))
                .clamp(0.0, 1.0),
          );
    final blink =
        !_complete &&
        ms >= SolutionView._blinkStartMs &&
        ms < SolutionView._blinkEndMs;
    final bitTop =
        SolutionView._bitCarryTop +
        (SolutionView._bitStageTop - SolutionView._bitCarryTop) * reveal;

    // A brief scale surge centred on the burst punch — the "pop".
    final surge = _complete
        ? 0.0
        : (1 - ((ms - SolutionView._bloomAtMs).abs() / 260)).clamp(0.0, 1.0);
    final bitScale = 1 + 0.07 * Curves.easeOut.transform(surge);

    final line1Count = _countFor(ms, SolutionView._line1StartMs,
        SolutionView._line1EndMs, _line1.length);
    final line2Count = _countFor(ms, SolutionView._line2StartMs,
        SolutionView._line2EndMs, _line2.length);
    final speaking = !_complete &&
        ((ms >= SolutionView._line1StartMs && ms < SolutionView._line1EndMs) ||
            (ms >= SolutionView._line2StartMs && ms < SolutionView._line2EndMs));

    final demo = _demoState(ms);

    final ctaT = _complete
        ? 1.0
        : ((ms - SolutionView._ctaStartMs) /
                (SolutionView._ctaEndMs - SolutionView._ctaStartMs))
            .clamp(0.0, 1.0);
    final pulse = (_complete && !_reducedMotion) ? _ctaPulseController.value : 0.0;

    return Stack(
      children: [
        // BIT — the continuous subject, bursting into cheer then settling.
        Positioned(
          top: bitTop,
          left: 63,
          child: Transform.scale(
            scale: bitScale,
            child: BitMoodCore(
              key: const ValueKey('solution_bit'),
              pose: pose,
              reveal: reveal,
              blink: blink,
              anticipation: anticipation,
              // Idle is held through the carry-in + inhale + surge + peak hold (a
              // clean choreography and a still hitstop), then ramped back in as
              // BIT settles to its neutral idle — no resume pop.
              idleAmp: idleAmp,
            ),
          ),
        ),
        // Voice cue — BIT is the one speaking.
        Positioned(
          top: 440,
          left: 137,
          child: speaking
              ? const BitVoiceWaveform(width: 115, height: 30, intensity: 1)
              : const SizedBox.shrink(),
        ),
        // The two lines: white statement (during cheer), turquoise hook (as BIT
        // settles to neutral). Excluded from semantics (the screen node carries
        // the full line) so a reader never announces half-typed text. Sat lower
        // (was 470) so the speaking waveform at 440 has clear breathing room and
        // doesn't cramp the text; the freed space comes from the empty lower third.
        Positioned(
          top: 505,
          left: 20,
          right: 20,
          child: ExcludeSemantics(
            child: Column(
              children: [
                _StrongLine(text: _visible(_line1, line1Count)),
                const SizedBox(height: 14),
                _StrongLine(text: _visible(_line2, line2Count), accent: true),
              ],
            ),
          ),
        ),
        // Level-up PREVIEW — a demonstration BIT runs, not a reward (no caption).
        Positioned(
          top: 632,
          left: 0,
          right: 0,
          child: ExcludeSemantics(
            child: Opacity(
              opacity: reveal.clamp(0.0, 1.0),
              child: _LevelDemoMeter(fill: demo.$1, levelTwo: demo.$2),
            ),
          ),
        ),
        // CTA — slides up + fades, then idle-pulses. Disabled until settled.
        Positioned(
          top: 700,
          left: 32,
          right: 32,
          child: Opacity(
            opacity: ctaT,
            child: Transform.translate(
              offset: Offset(0, (1 - ctaT) * 20),
              child: Transform.scale(
                scale: 1 + 0.02 * pulse,
                child: PixelButton(
                  label: "LET'S BUILD MY CHARACTER",
                  fontSize: 12,
                  minHeight: 64,
                  onPressed: _complete ? _handleCta : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Two beats: the white statement (BIT cheers it), then the turquoise hook (BIT
  // settles to neutral). Deliberate line breaks keep PressStart2P readable.
  static const _line1 = 'HERE, EVERY REP\nLEVELS YOU UP';
  static const _line2 = 'YOU WILL KEEP COMING\nBACK FOR MORE';

  /// The anticipation coil 0..1: eases up to a deep inhale, then releases as the
  /// surge fires — the wind-up the cold launch was missing.
  double _anticipationFor(double ms) {
    if (_complete || ms < SolutionView._inhaleStartMs) return 0;
    if (ms < SolutionView._inhalePeakMs) {
      final t =
          ((ms - SolutionView._inhaleStartMs) /
                  (SolutionView._inhalePeakMs - SolutionView._inhaleStartMs))
              .clamp(0.0, 1.0);
      return Curves.easeIn.transform(t);
    }
    if (ms < SolutionView._releaseEndMs) {
      final t =
          ((ms - SolutionView._inhalePeakMs) /
                  (SolutionView._releaseEndMs - SolutionView._inhalePeakMs))
              .clamp(0.0, 1.0);
      return 1 - Curves.easeOut.transform(t);
    }
    return 0;
  }

  /// Idle amplitude 0..1: off through the burst, then eased in over ~400ms from
  /// the settle so the float + breathe resume without a step pop.
  double _idleAmpFor(double ms) {
    if (_complete) return 1;
    if (ms < SolutionView._settleStartMs) return 0;
    final t =
        ((ms - SolutionView._settleStartMs) /
                (SolutionView._idleRampEndMs - SolutionView._settleStartMs))
            .clamp(0.0, 1.0);
    return Curves.easeOut.transform(t);
  }

  int _countFor(double ms, int startMs, int endMs, int length) {
    if (_complete) return length;
    final t = ((ms - startMs) / (endMs - startMs)).clamp(0.0, 1.0);
    return (t * length).floor();
  }

  String _visible(String full, int count) =>
      full.substring(0, count.clamp(0, full.length));

  /// (fill 0..1, showingLevelTwo). Resting/complete = locked at 0 (nothing
  /// earned before training).
  (double, bool) _demoState(double ms) {
    if (_complete) return (0.0, false);
    if (ms < SolutionView._demoStartMs) return (0.0, false);
    if (ms < SolutionView._demoFillEndMs) {
      final t = ((ms - SolutionView._demoStartMs) /
              (SolutionView._demoFillEndMs - SolutionView._demoStartMs))
          .clamp(0.0, 1.0);
      return (Curves.easeOut.transform(t), false);
    }
    if (ms < SolutionView._demoHoldMs) return (1.0, true);
    if (ms < SolutionView._demoResetEndMs) {
      final t = ((ms - SolutionView._demoHoldMs) /
              (SolutionView._demoResetEndMs - SolutionView._demoHoldMs))
          .clamp(0.0, 1.0);
      return (1 - t, false);
    }
    return (0.0, false);
  }
}

const _solutionDesignFrameKey = ValueKey('solution_design_frame');
const _solutionBackdropKey = ValueKey('solution_backdrop');

/// A bold screen line. PressStart2P caps reads as solid/declarative; line 1 is
/// white (BIT's cheered statement), line 2 the turquoise hook (BIT's steady
/// voice). Deliberate `\n` breaks keep the wide font on tidy rows.
class _StrongLine extends StatelessWidget {
  const _StrongLine({required this.text, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: 14,
        height: 1.5,
        color: accent ? bitGlow : kText,
      ),
    );
  }
}

/// The level-up PREVIEW: a small pixel meter BIT runs as a demonstration. It
/// fills LV 1 → LV 2 once, then resets to locked — it never awards a level (real
/// progression is earned by training). Turquoise (BIT's own light), not
/// reward-amber, so it reads as "BIT's system", not a payout.
class _LevelDemoMeter extends StatelessWidget {
  const _LevelDemoMeter({required this.fill, required this.levelTwo});

  final double fill; // 0..1
  final bool levelTwo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _lvTag('LV 1', active: !levelTwo),
        const SizedBox(width: 10),
        SizedBox(
          width: 170,
          child: ArcadeBar.segments(
            litCells: (fill * 10).round().clamp(0, 10),
            totalCells: 10,
            accent: bitGlow,
            height: 12,
          ),
        ),
        const SizedBox(width: 10),
        _lvTag('LV 2', active: levelTwo),
      ],
    );
  }

  Widget _lvTag(String label, {required bool active}) => Text(
        label,
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 10,
          color: active ? bitGlow : kMutedText,
        ),
      );
}


/// Always-on faint CRT scanlines + a soft vignette (no flashing).
class _CrtScreenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scanPaint = Paint()
      ..color = const Color(0x06FFFFFF)
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.12),
        radius: 0.95,
        colors: [
          Colors.transparent,
          Colors.transparent,
          kBlack.withValues(alpha: 0.42),
        ],
        stops: const [0, 0.58, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignettePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
