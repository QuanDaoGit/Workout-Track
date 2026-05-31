import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/calibration_quiz_models.dart';
import '../../services/body_goal_service.dart';
import '../../services/calibration_service.dart';
import '../../services/class_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_route.dart';
import 'calibration_quiz_page.dart';
import 'class_reveal_screen.dart';
import 'cold_open_page.dart';
import 'problem_question_page.dart';
import 'solution_page.dart';

enum _Step { coldOpen, problem, solution }

enum _OnboardingTransition { none, wipe, ripple, handoff }

const _onboardingTransitionLayerKey = ValueKey('onboarding_transition_layer');
const _onboardingCrtWipeLineKey = ValueKey('onboarding_crt_wipe_line');
const _onboardingAmberRippleKey = ValueKey('onboarding_amber_ripple');
const _onboardingHandoffKey = ValueKey('onboarding_handoff_iris');

/// First-run flow controller for the intro and calibration quiz handoff.
/// The quiz route stays alive while the class reveal is pushed above it, so
/// reveal back-navigation restores Q4 with answers intact.
class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage>
    with TickerProviderStateMixin {
  _Step _step = _Step.coldOpen;
  // Rotated whenever the user backs out of the quiz so the SolutionView
  // rebuilds with a fresh State and its internal `_handed` guard resets,
  // letting the CTA be re-pressed.
  Key _solutionKey = UniqueKey();
  _OnboardingTransition _transition = _OnboardingTransition.none;
  Offset _rippleOrigin = Offset.zero;

  late final AnimationController _transitionController = AnimationController(
    vsync: this,
  );

  /// Push the 4-question Calibration Quiz. In onboarding, completion pushes the
  /// class reveal over Q4 instead of popping the quiz result immediately.
  Future<void> _runQuiz() async {
    final result = await Navigator.of(context).push<CalibrationResult>(
      arcadeRoute(
        (_) => CalibrationQuizPage(onResult: _openClassReveal),
        motion: ArcadeRouteMotion.flow,
      ),
    );
    if (!mounted) return;
    if (result == null) {
      // User backed out — stay on Solution but reset its handed guard.
      setState(() => _solutionKey = UniqueKey());
      return;
    }
  }

  Future<void> _openClassReveal(CalibrationResult result) async {
    await Navigator.of(context).push<void>(
      arcadeRoute(
        (_) => ClassRevealScreen(
          result: result,
          onClassConfirmed: _persistClassConfirmation,
        ),
        motion: ArcadeRouteMotion.reveal,
      ),
    );
  }

  Future<void> _persistClassConfirmation(
    CalibrationResult result,
    DateTime classConfirmedAt,
  ) async {
    await BodyGoalService().setGoal(result.goal);
    await ClassService().selectClass(result.clazz);
    await CalibrationService().saveCalibrationInputs(
      bodyweightKg: result.bodyWeightKg,
      sex: result.sex,
    );
    await CalibrationService().saveTrainingPreferences(
      freq: result.freq,
      exp: result.exp,
    );
    // Seed starting capability stats from the quiz's self-reported experience
    // (replaces the old calibration-run workout assessment). Written now, before
    // the user reaches Home, so the stat board shows seeded ranks immediately.
    await CalibrationService().seedFromQuiz(exp: result.exp);
    await CalibrationService().markClassConfirmed(at: classConfirmedAt);
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  Future<void> _runWelcomeToProblem() async {
    if (MediaQuery.of(context).disableAnimations) {
      setState(() => _step = _Step.problem);
      return;
    }
    await _runTransition(
      _OnboardingTransition.wipe,
      const Duration(milliseconds: 410),
    );
    if (mounted) setState(() => _step = _Step.problem);
  }

  Future<void> _runProblemToSolution(Offset origin) async {
    if (MediaQuery.of(context).disableAnimations) {
      setState(() => _step = _Step.solution);
      return;
    }
    _rippleOrigin = origin;
    await _runTransition(
      _OnboardingTransition.ripple,
      const Duration(milliseconds: 480),
    );
    if (mounted) setState(() => _step = _Step.solution);
  }

  Future<void> _runSolutionHandoff() async {
    if (MediaQuery.of(context).disableAnimations) {
      await _runQuiz();
      return;
    }
    await _runTransition(
      _OnboardingTransition.handoff,
      const Duration(milliseconds: 820),
    );
    if (mounted) await _runQuiz();
  }

  Future<void> _runTransition(
    _OnboardingTransition transition,
    Duration duration,
  ) async {
    setState(() => _transition = transition);
    _transitionController
      ..duration = duration
      ..value = 0;
    await _transitionController.forward();
    if (!mounted) return;
    setState(() => _transition = _OnboardingTransition.none);
    _transitionController.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCurrentStep(),
            if (_transition != _OnboardingTransition.none)
              Positioned.fill(
                child: _OnboardingTransitionLayer(
                  transition: _transition,
                  animation: _transitionController,
                  rippleOrigin: _rippleOrigin,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    return switch (_step) {
      _Step.coldOpen => ColdOpenView(onContinue: _runWelcomeToProblem),
      _Step.problem => ProblemQuestionView(onContinue: _runProblemToSolution),
      _Step.solution => SolutionView(
        key: _solutionKey,
        onContinue: _runSolutionHandoff,
      ),
    };
  }
}

class _OnboardingTransitionLayer extends StatelessWidget {
  const _OnboardingTransitionLayer({
    required this.transition,
    required this.animation,
    required this.rippleOrigin,
  });

  final _OnboardingTransition transition;
  final Animation<double> animation;
  final Offset rippleOrigin;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        key: _onboardingTransitionLayerKey,
        animation: animation,
        builder: (context, _) {
          final t = Curves.easeOut.transform(
            animation.value.clamp(0.0, 1.0).toDouble(),
          );
          return switch (transition) {
            _OnboardingTransition.wipe => _WipeLayer(progress: t),
            _OnboardingTransition.ripple => CustomPaint(
              key: _onboardingAmberRippleKey,
              painter: _RippleTransitionPainter(
                progress: t,
                origin: rippleOrigin,
              ),
            ),
            _OnboardingTransition.handoff => CustomPaint(
              key: _onboardingHandoffKey,
              painter: _HandoffTransitionPainter(progress: t),
            ),
            _OnboardingTransition.none => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}

class _WipeLayer extends StatelessWidget {
  const _WipeLayer({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final lineT = (progress / 0.78).clamp(0.0, 1.0).toDouble();
    final darkAlpha = ((progress - 0.72) / 0.28).clamp(0.0, 0.85).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final y = constraints.maxHeight * lineT;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (darkAlpha > 0)
              ColoredBox(color: kBg.withValues(alpha: darkAlpha)),
            Positioned(
              key: _onboardingCrtWipeLineKey,
              left: 0,
              right: 0,
              top: y - 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: kNeon,
                  boxShadow: [
                    BoxShadow(
                      color: kNeon.withValues(alpha: 0.45),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const SizedBox(height: 6),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RippleTransitionPainter extends CustomPainter {
  const _RippleTransitionPainter({
    required this.progress,
    required this.origin,
  });

  final double progress;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    final maxRadius = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    final pulse = math.sin(progress * math.pi).clamp(0.0, 1.0).toDouble();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = kAmber.withValues(alpha: pulse * 0.65);
    canvas.drawCircle(origin, 16 + maxRadius * progress, paint);

    _drawScanBoost(canvas, size, pulse * 0.75);
    if (progress > 0.58 && progress < 0.82) {
      final borderAlpha = (1 - ((progress - 0.70).abs() / 0.12))
          .clamp(0.0, 1.0)
          .toDouble();
      _drawBorder(canvas, size, kAmber.withValues(alpha: borderAlpha));
    }
  }

  @override
  bool shouldRepaint(covariant _RippleTransitionPainter oldDelegate) =>
      progress != oldDelegate.progress || origin != oldDelegate.origin;
}

class _HandoffTransitionPainter extends CustomPainter {
  const _HandoffTransitionPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final strobe = _strobe(progress);
    if (strobe > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = kAmber.withValues(alpha: 0.12 * strobe),
      );
      _drawBorder(canvas, size, kAmber.withValues(alpha: 0.85 * strobe));
      _drawScanBoost(canvas, size, 0.85 * strobe);
    }

    final wash = (1 - ((progress - 0.32).abs() / 0.18))
        .clamp(0.0, 1.0)
        .toDouble();
    if (wash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = kAmber.withValues(alpha: 0.22 * wash),
      );
    }

    final textPulse = (1 - ((progress - 0.33).abs() / 0.26))
        .clamp(0.0, 1.0)
        .toDouble();
    if (textPulse > 0) {
      final painter = TextPainter(
        text: TextSpan(
          text: '+1 LV',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 16,
            height: 1,
            color: kAmber.withValues(alpha: textPulse),
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final y = size.height / 2 - painter.height / 2 - progress * 80;
      painter.paint(canvas, Offset(size.width / 2 - painter.width / 2, y));
    }

    if (progress > 0.58) {
      final local = ((progress - 0.58) / 0.24).clamp(0.0, 1.0).toDouble();
      final radius =
          math.sqrt(size.width * size.width + size.height * size.height) *
          (1 - local);
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        radius,
        Paint()..color = kAmber.withValues(alpha: 0.20 * (1 - local)),
      );
    }
  }

  double _strobe(double t) {
    if (t > 0.44) return 0;
    final frame = (t / 0.055).floor();
    return frame.isEven ? 1 : 0;
  }

  @override
  bool shouldRepaint(covariant _HandoffTransitionPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

void _drawScanBoost(Canvas canvas, Size size, double opacity) {
  if (opacity <= 0) return;
  final paint = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.10 * opacity)
    ..strokeWidth = 1;
  for (double y = 0; y < size.height; y += 4) {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
}

void _drawBorder(Canvas canvas, Size size, Color color) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = color
    ..isAntiAlias = false;
  canvas.drawRect(Offset.zero & size, paint);
}
