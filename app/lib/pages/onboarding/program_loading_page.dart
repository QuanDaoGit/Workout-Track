import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/body_goal_models.dart';
import '../../models/calibration_quiz_models.dart';
import '../../services/sfx_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';

class ProgramLoadingPage extends StatefulWidget {
  const ProgramLoadingPage({
    super.key,
    required this.result,
    required this.onComplete,
  });

  final CalibrationResult result;
  final FutureOr<void> Function() onComplete;

  @override
  State<ProgramLoadingPage> createState() => _ProgramLoadingPageState();
}

class _ProgramLoadingPageState extends State<ProgramLoadingPage>
    with SingleTickerProviderStateMixin {
  static const _normalDuration = Duration(milliseconds: 5000);
  static const _reducedMotionPause = Duration(milliseconds: 500);
  static const _readyWindowMs = 350;
  static const _iconSize = 44.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _normalDuration,
  )
    ..addStatusListener(_handleStatus)
    ..addListener(_handleTick);

  Timer? _completeTimer;
  bool _started = false;
  bool _completed = false;
  bool _ignoreStatusCompletion = false;
  // Onboarding SFX fire-once guards (crossing-based, driven by _handleTick).
  final List<bool> _confirmFired = [false, false, false, false];
  bool _seekFired = false;
  bool _readyFired = false;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (_reduceMotion) {
      _ignoreStatusCompletion = true;
      _controller.value = 1;
      _ignoreStatusCompletion = false;
      // Static PROGRAM READY: the ready chord is the ONLY cue (no boot/confirm/seek).
      _readyFired = true;
      SfxService.instance.playOnbReady();
      _completeTimer = Timer(_reducedMotionPause, _finish);
      return;
    }

    _completeTimer = Timer(_normalDuration, _finish);
    // Ring spin-up: 'system waking' boot blip on the same edge forward() starts.
    SfxService.instance.playOnbBoot();
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _completeTimer?.cancel();
    _controller.removeStatusListener(_handleStatus);
    _controller.removeListener(_handleTick);
    _controller.dispose();
    super.dispose();
  }

  void _handleStatus(AnimationStatus status) {
    if (_ignoreStatusCompletion) return;
    if (status == AnimationStatus.completed) {
      _finish();
    }
  }

  // Fire onboarding cues on the animation-frame edge where each visual beat
  // crosses its threshold (never on build). Fire-once via the guard flags;
  // reduced motion fires its single cue in didChangeDependencies instead.
  void _handleTick() {
    if (_completed || _reduceMotion) return;
    final elapsedMs =
        (_controller.value.clamp(0.0, 1.0) * _normalDuration.inMilliseconds)
            .round();

    // Readback confirm ladder — rungs 1..3 for the first three status lines. The
    // 4th line ('Matching program…') is voiced by the seek climb below, NOT a 4th
    // pip: on the single ceremony channel confirm(4) + seek fire the same frame,
    // so seek (the forging texture) owns that beat cleanly (Codex should-fix).
    for (var i = 0; i < 3; i++) {
      if (!_confirmFired[i] && elapsedMs >= _StatusStack._activationMs[i]) {
        _confirmFired[i] = true;
        SfxService.instance.playOnbConfirm(i + 1);
      }
    }

    // Readback -> forging: the long 'matching…' climb begins (~1450ms) — the sound
    // for the 4th status line. Its asset self-silences ~0.45s before READY, so the
    // ready chord at 4650ms only ever cuts silence (no audible clip).
    if (!_seekFired && elapsedMs >= _StatusStack._activationMs.last) {
      _seekFired = true;
      SfxService.instance.playOnbSeekClimb();
    }

    // PROGRAM READY edge (~4650ms = _normalDuration - _readyWindowMs).
    if (!_readyFired &&
        elapsedMs >= _normalDuration.inMilliseconds - _readyWindowMs) {
      _readyFired = true;
      SfxService.instance.playOnbReady();
    }
  }

  Future<void> _finish() async {
    if (_completed || !mounted) return;
    _completed = true;
    await widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final lines = [
      'Reading goal: ${_goalLabel(widget.result.goal)}',
      'Training rhythm: ${_freqLabel(widget.result.freq)}',
      'Experience level: ${widget.result.exp.name}',
      'Matching program...',
    ];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = _controller.value.clamp(0.0, 1.0).toDouble();
              final elapsedMs = (progress * _normalDuration.inMilliseconds)
                  .round()
                  .clamp(0, _normalDuration.inMilliseconds);
              final ready =
                  elapsedMs >= _normalDuration.inMilliseconds - _readyWindowMs;
              final buildProgress = _buildProgressFor(elapsedMs);

              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  kSpace4,
                  kSpace5,
                  kSpace4,
                  kSpace5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Center(
                      child: _ProgramLoadingMark(
                        progress: progress,
                        iconSize: _iconSize,
                      ),
                    ),
                    const SizedBox(height: kSpace5),
                    const Text(
                      'BUILDING YOUR PROGRAM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 13,
                        color: kNeon,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: kSpace5),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: _StatusStack(
                          lines: lines,
                          elapsedMs: elapsedMs,
                          ready: ready,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _SegmentedBuildProgress(value: buildProgress, ready: ready),
                    const SizedBox(height: kSpace3),
                    Text(
                      ready ? 'PROGRAM READY' : 'CALIBRATING',
                      textAlign: TextAlign.center,
                      style: AppFonts.shareTechMono(
                        color: ready ? kNeon : kMutedText,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double _buildProgressFor(int elapsedMs) {
    const readbackDoneMs = 1450;
    final readyStartMs = _normalDuration.inMilliseconds - _readyWindowMs;
    final ms = elapsedMs.clamp(0, _normalDuration.inMilliseconds);

    if (ms <= readbackDoneMs) {
      return _lerp(0, 1 / 3, ms / readbackDoneMs);
    }
    if (ms < readyStartMs) {
      return _lerp(
        1 / 3,
        0.88,
        (ms - readbackDoneMs) / (readyStartMs - readbackDoneMs),
      );
    }
    return _lerp(0.88, 1, (ms - readyStartMs) / _readyWindowMs);
  }

  double _lerp(double start, double end, double t) {
    final clamped = t.clamp(0.0, 1.0).toDouble();
    return start + (end - start) * clamped;
  }
}

class _ProgramLoadingMark extends StatelessWidget {
  const _ProgramLoadingMark({required this.progress, required this.iconSize});

  final double progress;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: progress * math.pi * 2,
            child: CustomPaint(
              key: const ValueKey('program_loading_dashed_ring'),
              painter: const _DashedRingPainter(),
              child: const SizedBox(width: 70, height: 70),
            ),
          ),
          Image.asset(
            'assets/branding/app_logo.png',
            key: const ValueKey('program_loading_app_logo'),
            width: iconSize,
            height: iconSize,
            filterQuality: FilterQuality.medium,
          ),
        ],
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..color = kNeon
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    const dashCount = 28;
    const gapRadians = 0.055;
    final sweep = (math.pi * 2 / dashCount) - gapRadians;
    for (var i = 0; i < dashCount; i++) {
      final start = i * (math.pi * 2 / dashCount);
      canvas.drawArc(rect, start, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) => false;
}

class _StatusStack extends StatelessWidget {
  const _StatusStack({
    required this.lines,
    required this.elapsedMs,
    required this.ready,
  });

  static const _activationMs = [350, 750, 1150, 1450];

  final List<String> lines;
  final int elapsedMs;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          _StatusLine(
            index: i,
            text: lines[i],
            active: ready || elapsedMs >= _activationMs[i],
          ),
          if (i != lines.length - 1) const SizedBox(height: kSpace3),
        ],
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.index,
    required this.text,
    required this.active,
  });

  final int index;
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          key: ValueKey('program_loading_status_dot_$index'),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? kNeon : kBorder,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: kSpace3),
        Expanded(
          child: Text(
            text,
            style: AppFonts.shareTechMono(
              color: active ? kText : kMutedText,
              fontSize: 13,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _SegmentedBuildProgress extends StatelessWidget {
  const _SegmentedBuildProgress({required this.value, required this.ready});

  final double value;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    const segmentCount = 12;
    final rawActiveSegments = (value.clamp(0.0, 1.0) * segmentCount).ceil();
    final activeSegments = ready
        ? rawActiveSegments
        : math.min(rawActiveSegments, segmentCount - 1);

    return Row(
      key: const ValueKey('program_loading_progress_segments'),
      children: [
        for (var i = 0; i < segmentCount; i++) ...[
          Expanded(
            child: Container(
              key: ValueKey('program_loading_progress_segment_$i'),
              height: 8,
              decoration: BoxDecoration(
                color: i < activeSegments ? kNeon : kBorderDark,
                border: Border.all(color: i < activeSegments ? kNeon : kBorder),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          if (i != segmentCount - 1) const SizedBox(width: kSpace1),
        ],
      ],
    );
  }
}

String _goalLabel(BodyGoal goal) => switch (goal) {
  BodyGoal.cut => 'cut',
  BodyGoal.recomp => 'recomp',
  BodyGoal.bulk => 'bulk',
};

String _freqLabel(TrainingFreq freq) => switch (freq) {
  TrainingFreq.low => '2-3 days',
  TrainingFreq.mid => '4-5 days',
  TrainingFreq.high => '6+ days',
};
