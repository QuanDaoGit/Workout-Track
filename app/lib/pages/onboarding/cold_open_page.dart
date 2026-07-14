import 'package:flutter/material.dart';

import '../../services/haptic_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/companion/bit_boot.dart';
import '../../widgets/companion/bit_core_engine.dart' show bitGlow;
import '../../widgets/motion/haptic_pulse_track.dart';
import '../../widgets/motion/power_on.dart';
import '../../widgets/typewriter_text.dart';

/// Style for BIT's first spoken line at the cold open — BIT's turquoise (its
/// voice), not neon. Neon is reserved for the one action (PRESS START), so it
/// never competes with BIT's colour right beside the sprite.
const _greetingStyle = TextStyle(
  fontFamily: 'PressStart2P',
  fontSize: 14,
  height: 1,
  color: bitGlow,
  letterSpacing: 1,
);

/// Screen 1 - Cold Open. BIT lies dormant on the floor; the user taps to wake it
/// (accelerating flicker → gather → fly up → plates spin out as it says
/// "WELCOME, WARRIOR"), then taps again to continue. Inside the flow's scaffold.
class ColdOpenView extends StatefulWidget {
  const ColdOpenView({
    super.key,
    required this.onContinue,
    this.hideBit = false,
  });

  final VoidCallback onContinue;

  /// During the hand-off to the problem screen the flow renders this cold open
  /// fading out as **chrome only** — BIT is hidden here so the problem screen's
  /// identical BIT (at the same hover home) stays the single, solid companion
  /// across the cut (a "constant subject", not a cross-dissolve of two BITs).
  final bool hideBit;

  static const _designWidth = 390.0;
  static const _designHeight = 844.0;

  @override
  State<ColdOpenView> createState() => _ColdOpenViewState();
}

class _ColdOpenViewState extends State<ColdOpenView>
    with TickerProviderStateMixin {
  // Tap-triggered power-on: BIT flickers, lights, then the plates spin out as
  // the greeting types. Its 0..1 value drives the whole composition.
  late final AnimationController _boot = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000), // deliberate wake + slow stretch
  );
  // Slow blink for the OFF "TAP TO WAKE" hint.
  late final AnimationController _standby = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  // A gentle "continuous weak" haptic that rides BIT's boot rise — a few soft
  // selection ticks coupled to the `_boot` ticker (no free timer, no drift),
  // so the wake *feels* alive. Attached on the wake tap; suppressed under
  // reduced motion (the boot is instant — there's no rise to ride).
  HapticPulseTrack? _bootHaptics;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _standby.stop();
    } else if (_boot.isDismissed && !_standby.isAnimating) {
      _standby.repeat(reverse: true);
    }
  }

  void _handleTap() {
    if (_boot.isDismissed) {
      _standby.stop();
      // Power-on is a deliberate, satisfying action → a light press ack.
      HapticService.instance.tap();
      if (_reduceMotion) {
        _boot.value = 1; // instant power-on (no rise to ride → no train)
      } else {
        // Weak, slow ticks rising with the boot (the "BIT waking" feel) — kept
        // sparse (2 ticks over the rise + the wake ack) so the ambient cue
        // stays gentle, not chatty.
        _bootHaptics ??= HapticPulseTrack(animation: _boot, pulses: 2);
        _boot.forward();
      }
    } else if (_boot.isCompleted) {
      HapticService.instance.selection(); // advancing past the cold open
      widget.onContinue();
    }
    // Mid-boot taps are ignored — the user just triggered the brief power-on.
  }

  @override
  void dispose() {
    _bootHaptics?.dispose();
    _boot.dispose();
    _standby.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _boot.isCompleted ? 'Continue' : 'Power on BIT',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: ColoredBox(
          // During the hand-off this view is the outgoing CHROME-ONLY layer
          // composited over the live problem screen — paint no background so the
          // problem's BIT shows continuously beneath (no opaque-over-opaque
          // cross-fade dip / "darken"). Otherwise it owns the screen → kBg.
          color: widget.hideBit ? Colors.transparent : kBg,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: ColdOpenView._designWidth,
                height: ColdOpenView._designHeight,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_boot, _standby]),
                  builder: (context, _) => _composition(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Stable Stack order — only each slot's child swaps, so stateful children
  // (BIT, the waveform) keep their identity across the boot.
  Widget _composition() {
    final b = _boot.value; // 0..1 boot progress
    final off = b <= 0;
    final reduce = _reduceMotion;
    return Stack(
      children: [
        const Positioned(
          top: 108,
          left: 0,
          right: 0,
          child: Text(
            'IRONBIT',
            textAlign: TextAlign.center,
            // White brand/identity — not neon. Keeps the action colour for the
            // one action and stops the wordmark fighting BIT's turquoise below.
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 16,
              height: 1,
              color: kText,
              letterSpacing: 1,
            ),
          ),
        ),
        // Taller than the sprite so BIT has floor to lie on and sky to rise
        // into; at hover (boot done) the sprite lands where it always has.
        // Hidden during the hand-off so the problem screen's BIT carries the cut.
        if (!widget.hideBit)
          Positioned(
            top: 194,
            left: 63,
            child: BitBootCore(
              width: 264,
              height: 432,
              boot: b,
              // Once the boot settles, BIT keeps a gentle idle float + breathe
              // (faded in by the boot's own settle ramp) — the missing screen-1
              // life after "WELCOME, WARRIOR". The small bob delta at the
              // cold→problem cut is masked by the problem BIT's immediate
              // drift-in; reduced motion zeroes the idle (clean still home).
            ),
          ),
        // DORMANT: blinking "TAP TO WAKE" hint, sat under BIT on the floor.
        Positioned(
          top: 640,
          left: 0,
          right: 0,
          child: off
              ? Opacity(
                  opacity: reduce ? 1.0 : 0.35 + 0.45 * _standby.value,
                  child: Text(
                    'TAP TO WAKE',
                    textAlign: TextAlign.center,
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Voice waveform — appears with the spoken line, set clear below BIT.
        Positioned(
          top: 494,
          left: 137,
          child: b >= kBitSpeakAt
              ? const BitVoiceWaveform(width: 115, height: 33)
              : const SizedBox.shrink(),
        ),
        // The spoken greeting — types in sync with the plate spin.
        Positioned(
          top: 538,
          left: 0,
          right: 0,
          child: b < kBitSpeakAt
              ? const SizedBox.shrink()
              : reduce
              ? const Text(
                  'WELCOME, WARRIOR',
                  textAlign: TextAlign.center,
                  style: _greetingStyle,
                )
              : const TypewriterText(
                  'WELCOME, WARRIOR',
                  textAlign: TextAlign.center,
                  style: _greetingStyle,
                  charMs: 60,
                ),
        ),
        // Settled chrome (CRT power-on reveal once BIT is up). BIT's faceless
        // self-introduction — it's the voice through screens 1-2. Big white mono
        // (the machine's terminal voice), with its own name in BIT's turquoise
        // (bitGlow, matching the sprite) and the aspiration "dream self" in amber
        // (the token reserved for celebrating progression). Coloured spans mirror
        // the problem screen's RichText; wider margins let the longer line breathe.
        _PoweredSlot(
          enabled: b >= kBitSettleAt,
          top: 584,
          left: 34,
          right: 34,
          child: Text.rich(
            const TextSpan(
              children: [
                TextSpan(text: 'I am '),
                TextSpan(text: 'BIT', style: TextStyle(color: bitGlow)),
                TextSpan(
                  text:
                      ', and I will accompany you on your journey of becoming '
                      'your ',
                ),
                TextSpan(text: 'dream self', style: TextStyle(color: kAmber)),
              ],
            ),
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(
              color: kText,
              fontSize: 18,
              height: 1.4,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _PoweredSlot(
          enabled: b >= 0.97,
          top: 729,
          left: 0,
          right: 0,
          child: const _PressStartPrompt(),
        ),
      ],
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
    // Reduced presentation = OS reduce-motion OR an active screen reader / switch
    // access (app-wide contract) — the looping PRESS START pulse freezes to its
    // still, legible neon frame.
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;
    if (reduceMotion) {
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
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dimmed = !reduceMotion && _controller.value >= 0.5;
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
