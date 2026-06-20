import 'package:flutter/material.dart';

import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/companion/bit_boot.dart' show BitVoiceWaveform;
import '../../widgets/companion/bit_mood_core.dart';

/// Screen 2 — the problem, carried by **BIT**. BIT greets in **cheer** and
/// speaks; a slow "..." lands; the line types ("Ever start strong — then quit by
/// week two?") and BIT **deflates cheer → rest** as the truth lands; a sympathy
/// line settles in; on tap BIT **steadies to neutral** and the screen advances.
/// Faceless throughout (the face is a later reveal) — emotion is body language.
///
/// Two-tap: the first tap completes the intro (skip), the second continues.
class ProblemQuestionView extends StatefulWidget {
  const ProblemQuestionView({
    super.key,
    required this.onContinue,
    this.hideBit = false,
  });

  final ValueChanged<Offset> onContinue;

  /// When true, BIT is omitted so this view can be the chrome-only outgoing
  /// layer of the problem→solution cross-fade — the incoming solution's
  /// identical rest BIT carries the cut as one continuous companion.
  final bool hideBit;

  static const designWidth = 390.0;
  static const designHeight = 844.0;

  @override
  State<ProblemQuestionView> createState() => _ProblemQuestionViewState();
}

class _ProblemQuestionViewState extends State<ProblemQuestionView>
    with TickerProviderStateMixin {
  static const _beforeStrong = 'Ever start ';
  static const _strong = 'strong';
  // Split so the "..." lands *between* the halves: the optimistic opener holds,
  // the ellipsis trails slowly, then the turn drops as BIT deflates.
  static const _firstHalf = '$_beforeStrong$_strong'; // "Ever start strong"
  static const _secondHalf = '\nthen quit by week two?';
  static const _strongStart = _beforeStrong.length;

  // One intro clock drives the whole arc (ms thresholds below). Tightened from
  // 6800ms: the dead hold is gone and the "..." is a real beat (~250ms/dot), so
  // the arc lands in ~3.6s instead of dragging. Two-tap still skips it.
  static const _introMs = 3600;
  static const _driftEndMs = 600; // BIT drifts from the cut-home to its centre
  static const _greetRiseMs = 300; // neutral carry-over from the cut, then perks
  static const _firstStartMs = 150; // opener types early, overlapping the cut
  static const _firstEndMs = 1100;
  static const _dotsStartMs = 1350; // a short confident hold, then "..." trails
  static const _dotsEndMs = 2100; // ~250ms/dot — a beat, not a wait
  static const _secondStartMs = 2100; // the turn types: "then quit by week two?"
  static const _secondEndMs = 3150;
  static const _deflateMs = 2100; // BIT sags cheer → rest as the turn lands
  static const _footerMs = 3250; // a beat after the turn lands

  // BIT enters at the cold-open cut-home (top 194) and drifts down to a centred
  // home so the BIT + line group balances the screen (fixes the empty bottom).
  static const _bitCutTop = 194.0;
  static const _bitHomeTop = 232.0;

  late final AnimationController _introController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _introMs),
  );
  late final AnimationController _footerPulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool _complete = false;
  bool _continuing = false; // 2nd tap: BIT steadies to neutral as it hands off
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finishIntro();
    });
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
      _footerPulseController.stop();
      _complete = true;
      _introController.value = 1;
    } else if (!_complete && !_introController.isAnimating) {
      _introController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _footerPulseController.dispose();
    super.dispose();
  }

  void _handleTap(Offset localPosition) {
    if (!_complete && !_reducedMotion) {
      _finishIntro();
      return;
    }
    // BIT steadies to neutral as the screen hands off to the solution.
    setState(() => _continuing = true);
    widget.onContinue(localPosition);
  }

  void _finishIntro() {
    if (_complete) return;
    _introController.stop();
    _introController.value = 1;
    _complete = true;
    if (!_reducedMotion && !_footerPulseController.isAnimating) {
      _footerPulseController.repeat(reverse: true);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // The full line lives on the screen's own node so a screen reader
      // announces it whole; the typed RichText below is excluded so it never
      // reads half-typed text. ("tap to continue" is its own footer node.)
      label: 'Ever start strong... then quit by week two?',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _handleTap(details.localPosition),
        child: ColoredBox(
          // During the problem→solution cross-fade this view is the fading
          // CHROME-ONLY top layer; paint no background so the solution's gradient
          // + rest BIT show continuously beneath (no opaque-over-opaque dip that
          // blinks BIT out at the cut). Mirrors ColdOpenView. Otherwise owns the
          // screen → kBg.
          color: widget.hideBit ? Colors.transparent : kBg,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: ProblemQuestionView.designWidth,
                height: ProblemQuestionView.designHeight,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _introController,
                    _footerPulseController,
                  ]),
                  builder: (context, _) => _composition(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _composition() {
    final ms = (_complete ? 1.0 : _introController.value) * _introMs;

    // BIT's body language: cheer while it greets/asks, rest once the truth
    // lands, neutral as it hands off.
    final BitPose pose;
    if (_continuing) {
      pose = BitPose.neutral;
    } else if (_complete || ms >= _deflateMs) {
      pose = BitPose.rest;
    } else if (ms < _greetRiseMs) {
      pose = BitPose.neutral; // carried over from the cold-open cut
    } else {
      pose = BitPose.cheer; // perks up to greet
    }

    // The optimistic opener types and holds; the "..." then trails slowly
    // *between* the halves; then the turn types as BIT deflates.
    final firstCount = _complete
        ? _firstHalf.length
        : (((ms - _firstStartMs) / (_firstEndMs - _firstStartMs)).clamp(
                    0.0,
                    1.0,
                  ) *
                  _firstHalf.length)
              .floor();
    final dotCount = _complete
        ? 3
        : (((ms - _dotsStartMs) / ((_dotsEndMs - _dotsStartMs) / 3)).floor())
              .clamp(0, 3);
    final secondCount = _complete
        ? _secondHalf.length
        : (((ms - _secondStartMs) / (_secondEndMs - _secondStartMs)).clamp(
                    0.0,
                    1.0,
                  ) *
                  _secondHalf.length)
              .floor();
    final strongT = _complete
        ? 1.0
        : ((firstCount - _strongStart) / _strong.length).clamp(0.0, 1.0);

    final footerOpacity = _complete
        ? 1.0
        : ((ms - _footerMs) / 300).clamp(0.0, 1.0);
    final pulse = _reducedMotion ? 0.0 : _footerPulseController.value;

    // BIT drifts from the cut-home down to its centred home over the greet beat
    // (a gentle "leans in to talk to you"); the bob is frozen through the drift
    // so the cold-open → problem cut stays pixel-identical, then idle resumes.
    final drift = _complete
        ? 1.0
        : Curves.easeOutCubic.transform((ms / _driftEndMs).clamp(0.0, 1.0));
    final bitTop = _bitCutTop + (_bitHomeTop - _bitCutTop) * drift;
    final freezeBob = !_complete && drift < 1.0;

    // BIT speaks the opener and the turn; through the hold + the "..." it pauses
    // (calm voice). Drive the waveform from that so the cue matches BIT.
    final speaking =
        !_complete && ms >= _firstStartMs && ms < _secondEndMs + 200;
    final speechIntensity =
        ((ms >= _firstStartMs && ms < _firstEndMs) ||
            (ms >= _secondStartMs && ms < _secondEndMs))
        ? 1.0
        : 0.0;

    return Stack(
      children: [
        // BIT — enters at the cold-open hover home (continuity across the cut),
        // then drifts to its centred home.
        Positioned(
          top: bitTop,
          left: 63,
          child: widget.hideBit
              ? const SizedBox.shrink()
              : BitMoodCore(
                  key: const ValueKey('problem_bit'),
                  pose: pose,
                  freezeBob: freezeBob,
                ),
        ),
        // Voice — BIT is the one speaking, not the app. Spaced below BIT's
        // bottom plate (~478) so it doesn't crowd the body.
        Positioned(
          top: 500,
          left: 137,
          child: speaking
              ? BitVoiceWaveform(
                  width: 115,
                  height: 33,
                  intensity: speechIntensity,
                )
              : const SizedBox.shrink(),
        ),
        // The line — the "..." lands between the optimistic opener and the turn.
        // Excluded from semantics (the screen's node carries the full line) so a
        // screen reader never reads the half-typed RichText.
        Positioned(
          top: 548,
          left: 28,
          right: 28,
          child: ExcludeSemantics(
            child: _TypedQuestion(
              firstCount: firstCount,
              dotCount: dotCount,
              secondCount: secondCount,
              strongT: strongT,
            ),
          ),
        ),
        // Continue hint — centred at the bottom (matches the cold open's centred
        // affordance; the old bottom-right placement read as off-axis).
        Positioned(
          top: 760,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: footerOpacity,
            child: Text(
              'tap to continue ›',
              textAlign: TextAlign.center,
              style: AppFonts.shareTechMono(
                color: Color.lerp(kMutedText, kDim, pulse * 0.5),
                fontSize: 12,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypedQuestion extends StatelessWidget {
  const _TypedQuestion({
    required this.firstCount,
    required this.dotCount,
    required this.secondCount,
    required this.strongT,
  });

  final int firstCount; // chars revealed of "Ever start strong"
  final int dotCount; // dots revealed of the mid-sentence "..."
  final int secondCount; // chars revealed of "\nthen quit by week two?"
  final double strongT;

  @override
  Widget build(BuildContext context) {
    final before = _seg(_ProblemQuestionViewState._beforeStrong, 0, firstCount);
    final strong = _seg(
      _ProblemQuestionViewState._strong,
      _ProblemQuestionViewState._strongStart,
      firstCount,
    );
    final second = _ProblemQuestionViewState._secondHalf.substring(
      0,
      secondCount.clamp(0, _ProblemQuestionViewState._secondHalf.length),
    );

    return RichText(
      // Centred to share BIT's axis (left-aligned read off-centre under the
      // centred companion); short lines keep the typed re-centre subtle.
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppFonts.shareTechMono(color: kText, fontSize: 20, height: 1.5),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: strong,
            style: TextStyle(color: Color.lerp(kText, kNeon, strongT)),
          ),
          TextSpan(
            text: '.' * dotCount,
            style: const TextStyle(color: kMutedText),
          ),
          TextSpan(text: second),
        ],
      ),
    );
  }

  String _seg(String segment, int start, int count) {
    final localCount = (count - start).clamp(0, segment.length).toInt();
    return segment.substring(0, localCount);
  }
}
