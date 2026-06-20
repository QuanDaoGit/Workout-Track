import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/bit_interview_copy.dart';
import '../../models/body_goal_models.dart';
import '../../models/calibration_quiz_models.dart';
import '../../models/character_class.dart';
import '../../models/unit_models.dart';
import '../../services/unit_settings_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/companion/bit_mood_core.dart';
import '../../widgets/companion/bit_speech_bubble.dart';

/// Authentic, tap-gated "technical calibration" loader shown after the quiz and
/// before the class reveal.
///
/// It *shows the work* (Labor Illusion): a live operation log of steps that flip
/// pending → running → done at uneven, hand-authored times, while a non-linear
/// bar jumps and creeps into a confident finish. The real persistence work
/// ([onCalibrated]) runs in the background and the screen holds until BOTH a
/// minimum display time and the real work are done — so it never reads as a
/// flicker. At COMPLETE the screen holds with a `▶ TAP TO REVEAL` prompt; only
/// then does a tap fire [onReveal]. The loading itself is unskippable.
class CalibrationLoadingPage extends StatefulWidget {
  const CalibrationLoadingPage({
    super.key,
    required this.answers,
    required this.onCalibrated,
    required this.onReveal,
  });

  /// The pre-class answers (goal + body metrics). Frequency/experience aren't
  /// collected until after the reveal, so the loader narrates only these.
  final PreClassAnswers answers;

  /// The real background work (persist goal/class/inputs, seed stats). Awaited
  /// during the load; the screen won't complete until it resolves.
  final Future<void> Function(DateTime classConfirmedAt) onCalibrated;

  /// Fired when the user taps at the COMPLETE state.
  final void Function(DateTime classConfirmedAt) onReveal;

  @override
  State<CalibrationLoadingPage> createState() => _CalibrationLoadingPageState();
}

class _CalibrationLoadingPageState extends State<CalibrationLoadingPage>
    with SingleTickerProviderStateMixin {
  static const _minDisplayMs = 4000;

  late final List<_StepDef> _steps;
  late final AnimationController _controller;
  late final DateTime _classConfirmedAt;

  bool _started = false;
  bool _workDone = false;
  bool _minTimeDone = false;
  bool _complete = false;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _steps = _buildSteps(widget.answers);
    _classConfirmedAt = DateTime.now();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: _minDisplayMs),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _minTimeDone = true;
            _maybeComplete();
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Kick off the real work immediately — it persists in the background while
    // the operation log narrates it.
    widget.onCalibrated(_classConfirmedAt).whenComplete(() {
      if (!mounted) return;
      _workDone = true;
      _maybeComplete();
    });

    if (_reduceMotion) {
      _controller.value = 1;
      _minTimeDone = true;
      _maybeComplete();
      return;
    }
    _controller.forward(from: 0);
  }

  void _maybeComplete() {
    if (_complete || !mounted) return;
    if (_workDone && _minTimeDone) {
      setState(() => _complete = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!_complete) return; // unskippable until the work is done
    widget.onReveal(_classConfirmedAt);
  }

  @override
  Widget build(BuildContext context) {
    // Unskippable: the system back button must not pop the calibration mid-work
    // (it persists the class). Tapping is the only way forward, at COMPLETE.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final elapsed = _complete
        ? _minDisplayMs
        : (_controller.value * _minDisplayMs).round();

    // How many steps are done. The first four resolve by time; the final
    // "RESOLVING CLASS" step resolves only when everything is COMPLETE.
    var doneCount = 0;
    for (var i = 0; i < _steps.length; i++) {
      final isLast = i == _steps.length - 1;
      if (_complete || (!isLast && elapsed >= _steps[i].doneAtMs)) doneCount++;
    }

    final progress = _progressFor(elapsed, doneCount);
    final pulse = 0.5 + 0.5 * math.sin(_controller.value * math.pi * 8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace5, kSpace4, kSpace5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // BIT frames the calibration — it's "picking a path that fits you".
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              BitMoodCore(pose: BitPose.neutral, reveal: 1, size: 48),
              SizedBox(width: 12),
              Expanded(
                child: BitSpeechBubble(text: BitInterviewCopy.pickingPath),
              ),
            ],
          ),
          const SizedBox(height: kSpace5),
          const Text(
            'CALIBRATING PROFILE',
            key: ValueKey('calibration_header'),
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: kNeon,
              height: 1.4,
            ),
          ),
          const SizedBox(height: kSpace2),
          Text(
            _telemetry(widget.answers),
            key: const ValueKey('calibration_telemetry'),
            style: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: kSpace5),
          const Divider(color: kBorder, height: 1, thickness: 1),
          const SizedBox(height: kSpace5),
          for (var i = 0; i < _steps.length; i++) ...[
            _CalibStep(
              key: ValueKey('calibration_step_$i'),
              label: _steps[i].label,
              finding: _steps[i].finding,
              state: i < doneCount
                  ? _StepState.done
                  : (i == doneCount ? _StepState.running : _StepState.pending),
              pulse: pulse,
            ),
            if (i != _steps.length - 1) const SizedBox(height: kSpace3),
          ],
          const Spacer(),
          _SegmentedProgress(
            key: const ValueKey('calibration_progress'),
            value: progress,
            complete: _complete,
          ),
          const SizedBox(height: kSpace3),
          Text(
            _complete ? 'CALIBRATION COMPLETE' : 'CALIBRATING…',
            key: const ValueKey('calibration_status'),
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(
              color: _complete ? kNeon : kMutedText,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: kSpace4),
          SizedBox(
            height: 24,
            child: _complete
                ? const _PulsingPrompt(
                    key: ValueKey('calibration_tap_prompt'),
                    text: '▶ TAP TO REVEAL',
                  )
                : null,
          ),
          const SizedBox(height: kSpace3),
        ],
      ),
    );
  }

  /// Non-linear: each done step is a 1/5 chunk (jumps), with a creep inside the
  /// running step so the bar is never static. Snaps to full at COMPLETE.
  double _progressFor(int elapsed, int doneCount) {
    if (_complete) return 1;
    final running = doneCount.clamp(0, _steps.length - 1);
    final prevMs = running == 0 ? 0 : _steps[running - 1].doneAtMs;
    final nextMs = running < _steps.length - 1
        ? _steps[running].doneAtMs
        : _minDisplayMs;
    final span = (nextMs - prevMs).clamp(1, _minDisplayMs);
    final creep = ((elapsed - prevMs) / span).clamp(0.0, 1.0);
    return ((doneCount + creep * 0.85) / _steps.length).clamp(0.0, 0.98);
  }
}

enum _StepState { pending, running, done }

class _StepDef {
  const _StepDef(this.label, this.finding, this.doneAtMs);
  final String label;
  final String? finding;
  final int doneAtMs;
}

List<_StepDef> _buildSteps(PreClassAnswers a) {
  // Hand-authored uneven completion times — organic, but deterministic/testable.
  final weight = a.bodyWeightKg;
  return [
    _StepDef('READING GOAL VECTOR', _goalLabel(a.goal), 700),
    _StepDef(
      'READING BODY METRICS',
      weight == null ? '—' : formatWeight(weight, Units.weight),
      1500,
    ),
    _StepDef('MAPPING MUSCLE EMPHASIS', _focusLabel(a.clazz), 2250),
    _StepDef('CROSS-REFERENCING STANDARDS', null, 3100),
    // Resolves only at COMPLETE (gated on the real work + min display time).
    _StepDef('RESOLVING CLASS', null, 1 << 30),
  ];
}

String _telemetry(PreClassAnswers a) {
  final base = 'goal ${_goalLabel(a.goal)}';
  final weight = a.bodyWeightKg;
  if (weight == null) return base;
  return '$base · ${formatWeight(weight, Units.weight)}';
}

String _focusLabel(CharacterClass c) => switch (c) {
  CharacterClass.assassin => 'shoulders·core',
  CharacterClass.bruiser => 'chest·back·arms',
  CharacterClass.tank => 'legs',
};

String _goalLabel(BodyGoal goal) => switch (goal) {
  BodyGoal.cut => 'leaner',
  BodyGoal.recomp => 'recomp',
  BodyGoal.bulk => 'bigger',
};


class _CalibStep extends StatelessWidget {
  const _CalibStep({
    super.key,
    required this.label,
    required this.finding,
    required this.state,
    required this.pulse,
  });

  final String label;
  final String? finding;
  final _StepState state;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final done = state == _StepState.done;
    final running = state == _StepState.running;
    final labelColor = done || running
        ? kText
        : kMutedText.withValues(alpha: 0.5);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _StatusCell(state: state, pulse: pulse),
        const SizedBox(width: kSpace3),
        Expanded(
          child: Text(
            label,
            style: AppFonts.shareTechMono(
              color: labelColor,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
        if (done && finding != null) ...[
          const SizedBox(width: kSpace2),
          Text(
            finding!,
            style: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
        if (done) ...[
          const SizedBox(width: kSpace2),
          const Text(
            '✓',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 11,
              color: kNeon,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.state, required this.pulse});

  final _StepState state;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final fill = switch (state) {
      _StepState.done => kNeon,
      _StepState.running => kNeon.withValues(alpha: 0.25 + 0.55 * pulse),
      _StepState.pending => Colors.transparent,
    };
    final border = state == _StepState.pending ? kBorder : kNeon;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({
    super.key,
    required this.value,
    required this.complete,
  });

  final double value;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    const segments = 12;
    final raw = (value.clamp(0.0, 1.0) * segments).ceil();
    final lit = complete ? segments : math.min(raw, segments - 1);

    return Row(
      children: [
        for (var i = 0; i < segments; i++) ...[
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: i < lit ? kNeon : kBorderDark,
                border: Border.all(color: i < lit ? kNeon : kBorder),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          if (i != segments - 1) const SizedBox(width: kSpace1),
        ],
      ],
    );
  }
}

class _PulsingPrompt extends StatefulWidget {
  const _PulsingPrompt({super.key, required this.text});

  final String text;

  @override
  State<_PulsingPrompt> createState() => _PulsingPromptState();
}

class _PulsingPromptState extends State<_PulsingPrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_reduceMotion && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: _reduceMotion ? 1 : 0.55 + 0.45 * _controller.value,
          child: child,
        ),
        child: Text(
          widget.text,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 13,
            color: kNeon,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
