import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/calibration_quiz_models.dart';
import '../../models/character_draft.dart';
import '../../models/resolve_models.dart';
import '../../services/body_goal_service.dart';
import '../../services/calibration_service.dart';
import '../../services/class_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_route.dart';
import 'calibration_loading_page.dart';
import 'calibration_quiz_page.dart';
import 'class_reveal_screen.dart';
import 'cold_open_page.dart';
import 'problem_question_page.dart';
import 'program_loading_page.dart';
import 'program_selection_page.dart';
import 'solution_page.dart';
import 'welcome_landing_page.dart';

enum _Step { welcome, coldOpen, problem, solution }

enum _OnboardingTransition { none, crossfade, handoff, boot }

const _onboardingTransitionLayerKey = ValueKey('onboarding_transition_layer');
const _onboardingCrossfadeKey = ValueKey('onboarding_crossfade');
const _onboardingHandoffKey = ValueKey('onboarding_handoff_iris');
const _onboardingBootKey = ValueKey('onboarding_boot_powercycle');

/// First-run flow controller for the intro and calibration quiz handoff.
/// Completing the quiz pushes the (unskippable) calibration loader, which does
/// the real persistence work and then hands off to the class reveal on tap —
/// the calibration is the point of no return after the quiz.
class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage>
    with TickerProviderStateMixin {
  _Step _step = _Step.welcome;
  // The outgoing step rendered (fading) during a BIT-preserving cross-fade.
  _Step? _prevStep;
  // Stable identity so the cold open keeps its (settled) state when it moves
  // into the fading cross-fade layer.
  final GlobalKey _coldOpenStepKey = GlobalKey();
  // Same for the problem: without a stable key the OUTGOING problem re-mounts
  // fresh when it moves into the fading layer at the problem→solution cut — its
  // intro restarts and the question text re-types mid-fade (the screen-2→3
  // "stutter"). The key preserves its completed State so it just fades.
  final GlobalKey _problemStepKey = GlobalKey();
  // Stable identity for the active step so its State (and any running intro)
  // survives the structural swap when a cross-fade ends — the step area goes
  // from Stack[current, fading] back to a bare current, and without a stable key
  // the incoming step is rebuilt fresh and its intro restarts (the transition
  // visibly plays twice).
  final GlobalKey _activeStepKey = GlobalKey();
  // Rotated whenever the user backs out of the quiz so the SolutionView
  // rebuilds with a fresh State and its internal `_handed` guard resets,
  // letting the CTA be re-pressed.
  Key _solutionKey = UniqueKey();
  _OnboardingTransition _transition = _OnboardingTransition.none;

  late final AnimationController _transitionController;

  // Accumulated across the two quiz segments + the reveal.
  PreClassAnswers? _preClass;
  DateTime _classConfirmedAt = DateTime.now();
  // Identity beats stashed from segment A so they can be folded into the draft
  // alongside segment B's obstacle answer. Multi-select.
  Set<TrainingWhy> _trainingWhy = {};
  Set<WinningVision> _winningVision = {};

  // Reduced presentation = OS "remove animations" OR an active screen reader /
  // switch access (the app-wide contract). A screen-reader user shouldn't have to
  // sit through the intro cinematics, so the shell transitions settle instantly —
  // matching the pushed onboarding screens (welcome / loaders / reveal / gate).
  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  // ── Segment A — goal + weight/sex (before the class) ─────────────────────
  /// Push the pre-class quiz segment. Completion runs the calibration loader
  /// (which persists in the background) and then the class reveal.
  Future<void> _runQuiz() async {
    await Navigator.of(context).push<void>(
      arcadeRoute(
        (_) => CalibrationQuizPage(
          questions: const [
            QuizQuestion.trainingWhy,
            QuizQuestion.goal,
            QuizQuestion.weightSex,
            QuizQuestion.winningVision,
          ],
          progressBaseCells: 0, // first segment — the vow is question 1 of 7
          onExit: _onPreClassExit,
          onComplete: _onPreClassComplete,
        ),
        motion: ArcadeRouteMotion.flow,
      ),
    );
  }

  void _onPreClassExit() {
    // Backed out of the first question — return to Solution, reset its guard.
    Navigator.of(context).pop();
    setState(() => _solutionKey = UniqueKey());
  }

  void _onPreClassComplete(QuizAnswers answers) {
    final pre = PreClassAnswers(
      goal: answers.goal!,
      bodyWeightKg: answers.bodyWeightKg,
      heightCm: answers.heightCm,
      sex: answers.sex,
    );
    _preClass = pre;
    // Stash the segment-A identity beats for the final draft.
    _trainingWhy = answers.trainingWhy;
    _winningVision = answers.winningVision;
    // Replace the quiz segment — the loader/reveal are the point of no return.
    Navigator.of(context).pushReplacement(
      arcadeRoute(
        (_) => CalibrationLoadingPage(
          answers: pre,
          onCalibrated: (at) => _persistPreClass(pre, at),
          onReveal: (at) {
            _classConfirmedAt = at;
            Navigator.of(context).pushReplacement(
              arcadeRoute(
                (_) => ClassRevealScreen(
                  answers: pre,
                  onConfirmed: _onClassConfirmed,
                ),
                motion: ArcadeRouteMotion.reveal,
              ),
            );
          },
        ),
        motion: ArcadeRouteMotion.flow,
      ),
    );
  }

  Future<void> _persistPreClass(PreClassAnswers pre, DateTime at) async {
    await BodyGoalService().setGoal(pre.goal);
    await ClassService().selectClass(pre.clazz);
    await CalibrationService().saveCalibrationInputs(
      bodyweightKg: pre.bodyWeightKg,
      heightCm: pre.heightCm,
      sex: pre.sex,
    );
    await CalibrationService().markClassConfirmed(at: at);
  }

  // ── Segment B — experience + frequency (after the class) ─────────────────
  void _onClassConfirmed() {
    // Replace (not push) the class reveal: the calibration is the point of no
    // return, so the reveal must leave the stack. Pushing it left a spent
    // reveal beneath the rest of the flow — backing into it hit a dead CTA.
    Navigator.of(context).pushReplacement(
      arcadeRoute(
        (_) => CalibrationQuizPage(
          questions: const [
            QuizQuestion.experience,
            QuizQuestion.frequency,
            QuizQuestion.obstacle,
          ],
          progressBaseCells: 4, // vow + goal + weight/sex + vision already done
          onComplete: _onOtherQuestionsComplete,
          // No onExit — the calibration is the point of no return.
        ),
        motion: ArcadeRouteMotion.flow,
      ),
    );
  }

  Future<void> _onOtherQuestionsComplete(QuizAnswers answers) async {
    final pre = _preClass!;
    final result = CalibrationResult(
      goal: pre.goal,
      freq: answers.freq!,
      exp: answers.exp!,
      bodyWeightKg: pre.bodyWeightKg,
      heightCm: pre.heightCm,
      sex: pre.sex,
      clazz: pre.clazz,
    );
    await CalibrationService().saveTrainingPreferences(
      freq: answers.freq!,
      exp: answers.exp!,
    );
    if (!mounted) return;
    final draft = CharacterDraft(
      calibration: result,
      classConfirmedAt: _classConfirmedAt,
      winningVision: _winningVision,
      obstacle: answers.obstacle,
      trainingWhy: _trainingWhy,
    );
    // Replace Quiz B (don't push over it): the program build is the point of no
    // return, so the spent quiz must leave the stack — otherwise backing out of
    // program selection lands on the completed quiz with a dead CONTINUE.
    await Navigator.of(context).pushReplacement(
      arcadeRoute(
        (_) => ProgramLoadingPage(
          result: result,
          onComplete: () async {
            if (!mounted) return;
            await Navigator.of(context).pushReplacement(
              arcadeRoute(
                (_) => ProgramSelectionPage(draft: draft),
                motion: ArcadeRouteMotion.flow,
              ),
            );
          },
        ),
        motion: ArcadeRouteMotion.fade,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Eagerly created so dispose() always has an initialized controller — a lazy
    // init during dispose (e.g. a reduced-motion run that never animated a
    // transition) would look up an inherited widget at an unsafe time.
    _transitionController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  // The landing screen hands off to the cold open with a CRT "boot the cabinet"
  // power-cycle: the welcome's logo zoom/bloom continues into a power-down to a
  // scanline, a black hold (the cold open mounts here, dark), then a power-on
  // bloom that the cold open's own entrance rides in on (wordmark first).
  Future<void> _runWelcomeToColdOpen() async {
    if (_reduceMotion) {
      setState(() => _step = _Step.coldOpen);
      return;
    }
    setState(() => _transition = _OnboardingTransition.boot);
    _transitionController
      ..duration = const Duration(milliseconds: 1000)
      ..value = 0;
    // Power-down to the black hold (~0.45), then mount the cold open behind it.
    await _transitionController.animateTo(0.45);
    if (!mounted) return;
    setState(() => _step = _Step.coldOpen);
    // Power-on bloom reveals the (entrance-animating) cold open, then clear.
    await _transitionController.forward();
    if (!mounted) return;
    setState(() => _transition = _OnboardingTransition.none);
    _transitionController.value = 0;
  }

  Future<void> _runWelcomeToProblem() async {
    if (_reduceMotion) {
      setState(() => _step = _Step.problem);
      return;
    }
    // BIT-preserving match-cut: the problem screen (BIT at the same hover home,
    // carried over neutral) mounts beneath while the cold open cross-fades out,
    // so BIT reads as one continuous companion across the cut.
    setState(() {
      _prevStep = _Step.coldOpen;
      _step = _Step.problem;
      _transition = _OnboardingTransition.crossfade;
    });
    _transitionController
      ..duration = const Duration(milliseconds: 400)
      ..value = 0;
    await _transitionController.forward();
    if (!mounted) return;
    setState(() {
      _transition = _OnboardingTransition.none;
      _prevStep = null;
    });
    _transitionController.value = 0;
  }

  Future<void> _runProblemToSolution(Offset origin) async {
    if (_reduceMotion) {
      setState(() => _step = _Step.solution);
      return;
    }
    // BIT-preserving match-cut (was an amber ripple that dropped BIT): the
    // solution mounts beneath with its rest BIT at the same hover home the
    // problem's deflated BIT held, so BIT reads as one continuous companion
    // across the cut — it then powers up + reveals its face *after* the cut. The
    // outgoing problem fades as chrome only (hideBit), so there's no double BIT.
    setState(() {
      _prevStep = _Step.problem;
      _step = _Step.solution;
      _transition = _OnboardingTransition.crossfade;
    });
    _transitionController
      ..duration = const Duration(milliseconds: 400)
      ..value = 0;
    await _transitionController.forward();
    if (!mounted) return;
    setState(() {
      _transition = _OnboardingTransition.none;
      _prevStep = null;
    });
    _transitionController.value = 0;
  }

  Future<void> _runSolutionHandoff() async {
    if (_reduceMotion) {
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
            AnimatedBuilder(
              animation: _transitionController,
              builder: (context, _) => _buildStepArea(),
            ),
            if (_transition != _OnboardingTransition.none &&
                _transition != _OnboardingTransition.crossfade)
              Positioned.fill(
                child: _OnboardingTransitionLayer(
                  transition: _transition,
                  animation: _transitionController,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The active step, plus the outgoing step fading over it during a
  /// BIT-preserving cross-fade (BIT sits at the same hover home in both, so it
  /// reads as one continuous companion across the cut).
  Widget _buildStepArea() {
    // Wrapped in a stable key so the active step's State survives the Stack↔bare
    // structural swap at a cross-fade's end (otherwise its intro restarts).
    final current = KeyedSubtree(key: _activeStepKey, child: _buildStep(_step));
    if (_transition != _OnboardingTransition.crossfade || _prevStep == null) {
      return current;
    }
    final t = Curves.easeOut.transform(
      _transitionController.value.clamp(0.0, 1.0).toDouble(),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        current,
        // The outgoing step fades as CHROME ONLY — its BIT is hidden so the
        // incoming step's identical BIT (same hover home) carries the cut as one
        // constant companion, not a cross-dissolve of two BITs.
        IgnorePointer(
          child: Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: KeyedSubtree(
              key: _onboardingCrossfadeKey,
              child: _buildStep(_prevStep!, hideBit: true),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(_Step step, {bool hideBit = false}) {
    return switch (step) {
      _Step.welcome => WelcomeLandingView(onGetStarted: _runWelcomeToColdOpen),
      _Step.coldOpen => ColdOpenView(
        key: _coldOpenStepKey,
        onContinue: _runWelcomeToProblem,
        hideBit: hideBit,
      ),
      _Step.problem => ProblemQuestionView(
        key: _problemStepKey,
        onContinue: _runProblemToSolution,
        hideBit: hideBit,
      ),
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
  });

  final _OnboardingTransition transition;
  final Animation<double> animation;

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
            _OnboardingTransition.handoff => CustomPaint(
              key: _onboardingHandoffKey,
              painter: _HandoffTransitionPainter(progress: t),
            ),
            // Boot reads the raw value — its painter owns the per-phase easing.
            _OnboardingTransition.boot => CustomPaint(
              key: _onboardingBootKey,
              painter: _BootTransitionPainter(
                progress: animation.value.clamp(0.0, 1.0).toDouble(),
              ),
            ),
            // Cross-fade is handled at the step level, not as an overlay.
            _OnboardingTransition.crossfade => const SizedBox.shrink(),
            _OnboardingTransition.none => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}

class _HandoffTransitionPainter extends CustomPainter {
  const _HandoffTransitionPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // A calm, single-bloom handoff into character-building — no rapid strobe
    // (WCAG 2.3.1: the old `_strobe` toggled ~9×/sec) and no fake "+1 LV" award
    // (real level-ups are earned after a workout, not for tapping through the
    // intro). One soft neon wash (the action just taken) + a single border
    // pulse + an iris close into the next screen.
    final p = progress.clamp(0.0, 1.0);

    final wash = math.sin(p * math.pi); // 0 → 1 → 0
    if (wash > 0.01) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = kNeon.withValues(alpha: 0.16 * wash),
      );
    }

    final border = (1 - ((p - 0.4).abs() / 0.26)).clamp(0.0, 1.0).toDouble();
    if (border > 0.01) {
      _drawBorder(canvas, size, kNeon.withValues(alpha: 0.55 * border));
    }

    if (p > 0.5) {
      final local = ((p - 0.5) / 0.5).clamp(0.0, 1.0).toDouble();
      final radius =
          math.sqrt(size.width * size.width + size.height * size.height) *
          (1 - local);
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        radius,
        Paint()..color = kNeon.withValues(alpha: 0.14 * (1 - local)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HandoffTransitionPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// "Boot the cabinet" CRT power-cycle: white hold → vertical collapse to a
/// scanline → black hold → power-on bloom (a slit opens vertically, revealing
/// the cold open beneath). Single forward pass — no strobe. Driven by the raw
/// controller value so the phase windows below line up.
class _BootTransitionPainter extends CustomPainter {
  const _BootTransitionPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress;
    final h = size.height;
    final w = size.width;
    final center = h / 2;

    double bandHalf;
    var opening = false; // band reveals the cold open beneath
    var fillBright = 1.0; // brightness of the lit band (pre power-on)
    if (p < 0.18) {
      bandHalf = h / 2; // white hold — full bright
    } else if (p < 0.40) {
      final c = ((p - 0.18) / 0.22).clamp(0.0, 1.0).toDouble();
      bandHalf = _lerp(h / 2, 2, Curves.easeIn.transform(c)); // collapse
    } else if (p < 0.50) {
      bandHalf = 2;
      fillBright = _lerp(
        1,
        0.15,
        ((p - 0.40) / 0.10).clamp(0.0, 1.0).toDouble(),
      ); // dim to a faint line
    } else if (p < 0.80) {
      final o = ((p - 0.50) / 0.30).clamp(0.0, 1.0).toDouble();
      bandHalf = _lerp(2, h / 2, Curves.easeOut.transform(o)); // power-on
      opening = true;
    } else {
      bandHalf = h / 2;
      opening = true; // fully open — overlay is empty
    }

    final top = (center - bandHalf).clamp(0.0, h).toDouble();
    final bot = (center + bandHalf).clamp(0.0, h).toDouble();

    // kBg shutters above + below the band (hide whatever is beneath).
    final bg = Paint()..color = kBg;
    if (top > 0) canvas.drawRect(Rect.fromLTRB(0, 0, w, top), bg);
    if (bot < h) canvas.drawRect(Rect.fromLTRB(0, bot, w, h), bg);

    if (!opening) {
      // Bright band: white during the hold, lerping to neon as it collapses.
      final color = Color.lerp(
        kWhite,
        kNeon,
        ((p - 0.18) / 0.22).clamp(0.0, 1.0).toDouble(),
      )!;
      canvas.drawRect(
        Rect.fromLTRB(0, top, w, bot),
        Paint()..color = color.withValues(alpha: fillBright),
      );
    } else {
      // Power-on: the band is transparent (cold open shows through); glow its
      // opening edges and fade a scanline boost as it clears.
      final edgeAlpha =
          ((1 - ((p - 0.50) / 0.30).clamp(0.0, 1.0)) * 0.9).toDouble();
      if (edgeAlpha > 0 && bandHalf < h / 2) {
        final edge = Paint()
          ..color = kNeon.withValues(alpha: edgeAlpha)
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawLine(Offset(0, top), Offset(w, top), edge);
        canvas.drawLine(Offset(0, bot), Offset(w, bot), edge);
      }
      _drawScanBoost(
        canvas,
        size,
        ((1 - (p - 0.50) / 0.30).clamp(0.0, 1.0) * 0.6).toDouble(),
      );
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _BootTransitionPainter oldDelegate) =>
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
