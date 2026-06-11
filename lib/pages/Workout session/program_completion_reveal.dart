import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/loot_registry.dart';
import '../../data/programs_library.dart';
import '../../models/loot_item.dart';
import '../../models/program_models.dart';
import '../../services/program_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_progress_bar.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/screen_shake.dart';
import '../../widgets/strobe_flash.dart';

/// Dedicated arc-completion celebration, pushed at Save & Exit when a program
/// reaches its session target. Distinct from the workout finish arc so it reads
/// as "a path completed," not "another XP receipt."
///
/// The two CTAs are the next-path prompt: BEGIN NEXT PATH starts the chained
/// program with a fresh arc; STAY WITH THIS PROGRAM rolls a new cycle of the
/// same program without wiping history. Either way, control returns to Home.
class ProgramCompletionRevealScreen extends StatefulWidget {
  const ProgramCompletionRevealScreen({super.key, required this.completion});

  final ProgramCompletion completion;

  @override
  State<ProgramCompletionRevealScreen> createState() =>
      _ProgramCompletionRevealScreenState();
}

class _ProgramCompletionRevealScreenState
    extends State<ProgramCompletionRevealScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _timelineDuration = Duration(milliseconds: 3000);

  late final AnimationController _controller;
  int _strobe = 0;
  int _shake = 0;
  bool _busy = false;
  bool _started = false;
  bool _skipped = false;
  Timer? _impactTimer;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  double get _progress => _reduceMotion || _skipped ? 1 : _controller.value;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _timelineDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduceMotion) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
    _impactTimer = Timer(const Duration(milliseconds: 720), () {
      if (!mounted || _reduceMotion || _skipped) return;
      setState(() {
        _strobe++;
        _shake++;
      });
    });
  }

  @override
  void dispose() {
    _impactTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  double _reveal(double start, [double span = 0.12]) {
    if (_reduceMotion || _skipped) return 1;
    return ((_controller.value - start) / span).clamp(0.0, 1.0);
  }

  bool _visible(double start) => _progress >= start;

  void _skip() {
    if (_reduceMotion || _skipped || _controller.isCompleted) return;
    _impactTimer?.cancel();
    setState(() {
      _skipped = true;
      _controller.value = 1;
    });
  }

  Future<void> _beginNext() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ProgramService().beginNextPath();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _stay() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ProgramService().stayWithProgram();
    if (mounted) Navigator.of(context).pop();
  }

  static String _flavor(String programId) => switch (programId) {
    'full_body_3x' => 'Your foundation is set. The base holds.',
    'upper_lower' => 'The rhythm is yours. Discipline locked in.',
    'ppl' => 'The split is mastered. Repeatable strength.',
    _ => 'The path is complete.',
  };

  static String _nextPathLine(String programId, Program? next) {
    if (next == null) return 'NEXT PATH: STAY READY';
    if (programId == 'ppl' && next.id == 'ppl') {
      return 'NEXT PATH: PUSH PULL LEGS - CYCLE II';
    }
    return 'NEXT PATH: ${next.name} - ${next.targetSessions} SESSIONS';
  }

  @override
  Widget build(BuildContext context) {
    final program = programById(widget.completion.programId);
    final title = lootItemById(widget.completion.titleId);
    final target = program?.targetSessions ?? widget.completion.sessions;
    final next = nextProgramInChain(widget.completion.programId);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _skip,
              child: StrobeFlash(
                trigger: _strobe,
                color: kAmber,
                opacity: 0.16,
                toggles: 1,
                toggleMs: 120,
                child: ScreenShake(
                  trigger: _reduceMotion ? 0 : _shake,
                  magnitude: 2,
                  frames: 4,
                  frameMs: 50,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kSpace4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),
                        Opacity(
                          opacity: _reveal(0.0, 0.08),
                          child: const Text(
                            'PATH COMPLETE',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 9,
                              color: kMutedText,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpace3),
                        _SlamText(
                          visible: _visible(0.18),
                          progress: _reveal(0.18, 0.10),
                          text: program?.name ?? 'PROGRAM',
                        ),
                        const SizedBox(height: kSpace4),
                        _CompletionMeter(
                          visible: _visible(0.34),
                          progress: _reveal(0.34, 0.18),
                          sessions: widget.completion.sessions,
                          target: target,
                        ),
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (title != null && _visible(0.56))
                                  Opacity(
                                    opacity: _reveal(0.56, 0.12),
                                    child: _TitleEarnedCard(title: title),
                                  ),
                                const SizedBox(height: kSpace4),
                                if (_visible(0.68))
                                  Opacity(
                                    opacity: _reveal(0.68, 0.12),
                                    child: Text(
                                      _flavor(widget.completion.programId),
                                      textAlign: TextAlign.center,
                                      style: AppFonts.shareTechMono(
                                        color: kMutedText,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (_visible(0.82))
                          Opacity(
                            opacity: _reveal(0.82, 0.10),
                            child: IgnorePointer(
                              ignoring: !_visible(0.82),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: kSpace2,
                                    ),
                                    child: Text(
                                      _nextPathLine(
                                        widget.completion.programId,
                                        next,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: AppFonts.shareTechMono(
                                        color: kMutedText,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  PixelButton(
                                    label: 'BEGIN NEXT PATH',
                                    color: kAmber,
                                    minHeight: 56,
                                    onPressed: _busy ? null : _beginNext,
                                  ),
                                  const SizedBox(height: kSpace2),
                                  PixelButton(
                                    label: 'STAY WITH THIS PROGRAM',
                                    secondary: true,
                                    onPressed: _busy ? null : _stay,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: kSpace5),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SlamText extends StatelessWidget {
  const _SlamText({
    required this.visible,
    required this.progress,
    required this.text,
  });

  final bool visible;
  final double progress;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox(height: 52);
    final offset = (1 - progress) * 8;
    return Transform.translate(
      offset: Offset(offset, 0),
      child: Opacity(
        opacity: progress,
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 20,
            color: kAmber,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

class _CompletionMeter extends StatelessWidget {
  const _CompletionMeter({
    required this.visible,
    required this.progress,
    required this.sessions,
    required this.target,
  });

  final bool visible;
  final double progress;
  final int sessions;
  final int target;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox(height: 38);
    final edgeAlpha = (1 - ((progress - 0.85) / 0.15).clamp(0.0, 1.0)) * 0.28;
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: kAmber.withValues(alpha: edgeAlpha)),
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ArcadeProgressBar(
                value: progress.clamp(0.0, 1.0),
                fillColor: kAmber,
                height: 12,
              ),
              const SizedBox(height: kSpace2),
              Text(
                '$sessions / $target SESSIONS - 100% COMPLETE',
                style: AppFonts.shareTechMono(color: kText, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleEarnedCard extends StatelessWidget {
  const _TitleEarnedCard({required this.title});

  final LootItem title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace4,
        vertical: kSpace3,
      ),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: LootRarity.legendary.color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'TITLE EARNED',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 7,
              color: kMutedText,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: kSpace2),
          Text(
            title.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 13,
              color: LootRarity.legendary.color,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
