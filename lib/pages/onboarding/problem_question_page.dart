import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/onboarding_lifter_sprite.dart';

class ProblemQuestionView extends StatefulWidget {
  const ProblemQuestionView({super.key, required this.onContinue});

  final ValueChanged<Offset> onContinue;

  static const designWidth = 390.0;
  static const designHeight = 844.0;

  @override
  State<ProblemQuestionView> createState() => _ProblemQuestionViewState();
}

class _ProblemQuestionViewState extends State<ProblemQuestionView>
    with TickerProviderStateMixin {
  static const _beforeStrong = 'Ever start ';
  static const _strong = 'strong';
  static const _afterStrong = ' —\nthen quit by week two?';
  static const _question = '$_beforeStrong$_strong$_afterStrong';
  static const _sympathy =
      "You're not alone. The work never feels like it adds up and so it fades away before it even shows.";
  static const _introMs = 3000;
  static const _typeEndMs = 1280;
  static const _strongStartMs = 1600;
  static const _strongDurMs = 240;
  static const _sympathyStartMs = 1920;
  static const _sympathyFadeMs = 480;
  static const _footerStartMs = 2560;
  static const _footerFadeMs = 320;

  late final AnimationController _introController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _introMs),
  );
  late final AnimationController _footerPulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool _complete = false;
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
      label: 'Problem screen. Tap to continue.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _handleTap(details.localPosition),
        child: const ColoredBox(
          color: kBg,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: ProblemQuestionView.designWidth,
                height: ProblemQuestionView.designHeight,
                child: _ProblemQuestionComposition(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProblemQuestionComposition extends StatefulWidget {
  const _ProblemQuestionComposition();

  @override
  State<_ProblemQuestionComposition> createState() =>
      _ProblemQuestionCompositionState();
}

class _ProblemQuestionCompositionState
    extends State<_ProblemQuestionComposition> {
  _ProblemQuestionViewState get _host =>
      context.findAncestorStateOfType<_ProblemQuestionViewState>()!;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _host._introController,
        _host._footerPulseController,
      ]),
      builder: (context, _) {
        final t = _host._complete ? 1.0 : _host._introController.value;
        final visibleCount = _host._complete
            ? _ProblemQuestionViewState._question.length
            : (math.min(
                        t,
                        _ProblemQuestionViewState._typeEndMs /
                            _ProblemQuestionViewState._introMs,
                      ) /
                      (_ProblemQuestionViewState._typeEndMs /
                          _ProblemQuestionViewState._introMs) *
                      _ProblemQuestionViewState._question.length)
                  .floor();
        final strongT = _host._complete
            ? 1.0
            : ((t -
                          _ProblemQuestionViewState._strongStartMs /
                              _ProblemQuestionViewState._introMs) /
                      (_ProblemQuestionViewState._strongDurMs /
                          _ProblemQuestionViewState._introMs))
                  .clamp(0.0, 1.0)
                  .toDouble();
        final sympathyOpacity = _host._complete
            ? 1.0
            : ((t -
                          _ProblemQuestionViewState._sympathyStartMs /
                              _ProblemQuestionViewState._introMs) /
                      (_ProblemQuestionViewState._sympathyFadeMs /
                          _ProblemQuestionViewState._introMs))
                  .clamp(0.0, 1.0)
                  .toDouble();
        final footerOpacity = _host._complete
            ? 1.0
            : ((t -
                          _ProblemQuestionViewState._footerStartMs /
                              _ProblemQuestionViewState._introMs) /
                      (_ProblemQuestionViewState._footerFadeMs /
                          _ProblemQuestionViewState._introMs))
                  .clamp(0.0, 1.0)
                  .toDouble();
        final failedOpacity = _host._complete
            ? 1.0
            : ((t - 2200 / _ProblemQuestionViewState._introMs) /
                      (600 / _ProblemQuestionViewState._introMs))
                  .clamp(0.0, 1.0)
                  .toDouble();
        final pulse = _host._reducedMotion
            ? 0.0
            : _host._footerPulseController.value;

        return Stack(
          children: [
            Positioned(
              top: 232,
              left: 32,
              right: 32,
              child: _TypedQuestion(
                visibleCount: visibleCount,
                strongT: strongT,
              ),
            ),
            Positioned(
              top: 348,
              left: 32,
              right: 32,
              child: Opacity(
                opacity: sympathyOpacity,
                child: Text(
                  _ProblemQuestionViewState._sympathy,
                  textAlign: TextAlign.left,
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 538,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: failedOpacity,
                child: const Column(
                  children: [
                    OnboardingLifterSprite(
                      key: ValueKey('problem_failed_lifter'),
                      mode: OnboardingLifterSpriteMode.failed,
                      width: 160,
                      height: 120,
                    ),
                    SizedBox(height: 12),
                    _EmptyStrBar(),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 776,
              right: 32,
              child: Opacity(
                opacity: footerOpacity,
                child: Text(
                  'tap to continue ›',
                  textAlign: TextAlign.right,
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
      },
    );
  }
}

class _EmptyStrBar extends StatelessWidget {
  const _EmptyStrBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 14,
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: kCard.withValues(alpha: 0.55),
                  border: Border.all(color: kBorder),
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

class _TypedQuestion extends StatelessWidget {
  const _TypedQuestion({required this.visibleCount, required this.strongT});

  final int visibleCount;
  final double strongT;

  @override
  Widget build(BuildContext context) {
    final beforeStrong = _visibleSegment(
      _ProblemQuestionViewState._beforeStrong,
      0,
      visibleCount,
    );
    final strongStart = _ProblemQuestionViewState._beforeStrong.length;
    final strong = _visibleSegment(
      _ProblemQuestionViewState._strong,
      strongStart,
      visibleCount,
    );
    final afterStart = strongStart + _ProblemQuestionViewState._strong.length;
    final afterStrong = _visibleSegment(
      _ProblemQuestionViewState._afterStrong,
      afterStart,
      visibleCount,
    );

    return RichText(
      textAlign: TextAlign.left,
      text: TextSpan(
        style: AppFonts.shareTechMono(color: kText, fontSize: 22, height: 1.5),
        children: [
          TextSpan(text: beforeStrong),
          TextSpan(
            text: strong,
            style: TextStyle(color: Color.lerp(kText, kNeon, strongT)),
          ),
          TextSpan(text: afterStrong),
        ],
      ),
    );
  }

  String _visibleSegment(String segment, int start, int visibleCount) {
    final localCount = (visibleCount - start).clamp(0, segment.length).toInt();
    return segment.substring(0, localCount);
  }
}
