import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/bit_interview_copy.dart';
import '../../models/body_goal_models.dart';
import '../../models/calibration_quiz_models.dart';
import '../../models/resolve_models.dart';
import '../../models/training_focus.dart';
import '../../models/unit_models.dart';
import '../../models/user_profile_sex.dart';
import '../../services/unit_settings_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_chip.dart';
import '../../widgets/arcade_filled.dart';
import '../../widgets/companion/bit_mood_core.dart';
import '../../widgets/companion/bit_speech_bubble.dart';
import '../../widgets/motion/arcade_text_field.dart';
import '../../widgets/onboarding/option_question.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/arcade_bar.dart';
import '../../widgets/typewriter_text.dart';

/// The onboarding question quiz. Renders a caller-supplied list of
/// [QuizQuestion]s with a shared progress header. The onboarding flow runs it in
/// two segments around the class reveal: `[trainingWhy, goal, weightSex,
/// winningVision]` then `[experience, frequency, obstacle]` — the goal derives
/// [CharacterClass]; the vow/vision/obstacle are identity beats woven in for
/// narrative pacing. Accumulated answers are returned via [onComplete].
///
/// **Design note** — internally uses a single route with an inline step index
/// rather than a stack of pushed routes. This gives reliable back-restore
/// behavior without coordinating pop counts across questions. The arcade route
/// flash is the *enter/exit* boundary of the segment; Q→Q transitions rely on
/// the per-question typewriter + wipe-in stagger ("no motion while reading").
class CalibrationQuizPage extends StatefulWidget {
  const CalibrationQuizPage({
    super.key,
    required this.questions,
    required this.onComplete,
    this.onExit,
    this.initialAnswers,
    this.progressBaseCells = 0,
  });

  /// The ordered questions this segment renders.
  final List<QuizQuestion> questions;

  /// Called with the accumulated answers when the last question is answered.
  final void Function(QuizAnswers answers) onComplete;

  /// Back pressed on the first question. When null, the first question hides
  /// its back affordance — used for the post-reveal segment, since the
  /// calibration is the point of no return.
  final VoidCallback? onExit;

  /// Pre-fills answers (e.g. when re-entering a segment).
  final QuizAnswers? initialAnswers;

  /// Progress cells already filled before this segment's first question. The
  /// pre-class segment (goal + weight/sex) is 0; the post-reveal segment
  /// (experience + frequency) is 2.
  final int progressBaseCells;

  // Total cells across the onboarding question journey — the eight quiz
  // questions: vow + goal + training-focus + weight/sex + vision (segment A) and
  // experience + frequency + obstacle (segment B). The intro shows no bar.
  static const int totalProgressCells = 8;

  @override
  State<CalibrationQuizPage> createState() => _CalibrationQuizPageState();
}

class _CalibrationQuizPageState extends State<CalibrationQuizPage> {
  int _step = 0;

  // Re-entrancy guard for the 280 ms select-hold and the CONTINUE submit. Without
  // it, a fast double-tap fires _advance twice — skipping a question or firing
  // onComplete with default answers. Reset whenever a new question is shown.
  bool _advancing = false;

  // Steps whose entrance has already played — used to suppress the
  // typewriter + wipe-in when navigating back to an already-seen question.
  final Set<int> _seenSteps = {};

  // Reaction beat — on an emotional question, BIT types a "promise" after the
  // answer is committed; the user taps to continue (no auto-advance). EVENT-DRIVEN:
  // set only on the commit action, never on build, so it never replays on
  // back-navigation or a prefilled re-entry (a rebuilt step just shows ASKING with
  // the selection restored). Backing out of a reaction returns to ASKING.
  bool _reacting = false;
  String? _reactionText;
  // Latched when the FINAL reaction's continue fires onComplete (which replaces
  // this page with a loader). Guards a double-tap WITHOUT flipping _reacting back
  // to ASKING — see _advanceFromReaction.
  bool _completing = false;
  Timer? _selectHoldTimer; // the 280ms single-select "land" hold (cancellable)

  // Segment B opens with a brief BIT intro line ("just a few more questions")
  // before the first question morphs in. Fires once; reduced motion skips it.
  bool _showIntro = false;
  bool _introScheduled = false;
  Timer? _introTimer;

  late final QuizAnswers _answers =
      widget.initialAnswers?.copy() ?? QuizAnswers();

  int get _progressCells => widget.progressBaseCells + _step + 1;
  bool get _isLast => _step == widget.questions.length - 1;

  // Reduced presentation = OS reduce-motion OR an active screen reader / switch
  // access (app-wide contract) — skips the intro beat and the select-hold so an
  // AT user advances immediately instead of waiting out the cinematic.
  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    // The post-reveal segment opens on the experience question.
    _showIntro = widget.questions.isNotEmpty &&
        widget.questions.first == QuizQuestion.experience;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_showIntro && !_introScheduled) {
      _introScheduled = true;
      if (_reduceMotion) {
        _showIntro = false; // no intro beat under reduced motion
      } else {
        // Time the intro to the typewriter: it types out, holds ~900 ms, then the
        // question types in — at the same consistent speed.
        _introTimer = Timer(
          Duration(
            milliseconds:
                BitInterviewCopy.segmentBIntro.length * kBitTypeCharMs + 900,
          ),
          () {
            if (mounted) setState(() => _showIntro = false);
          },
        );
      }
    }
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _selectHoldTimer?.cancel();
    super.dispose();
  }

  void _select(Object answer) {
    if (_advancing) return;
    _advancing = true;
    // Apply the answer immediately so back-navigation restores it.
    if (answer is BodyGoal) _answers.goal = answer;
    if (answer is TrainingFocus) _answers.focus = answer;
    if (answer is TrainingFreq) _answers.freq = answer;
    if (answer is Experience) _answers.exp = answer;
    if (answer is Obstacle) _answers.obstacle = answer;
    // 280 ms hold so the selection animation (120 ms) completes and the choice
    // visibly "lands" before the screen swaps. Owned + step-guarded: a Back press
    // during the hold cancels it (see _goBack), so a stale commit can never react
    // or advance for a question that is no longer current.
    final step = _step;
    void commit() {
      if (!mounted || _step != step) return;
      final current = widget.questions[step];
      // Emotional questions: BIT reacts (and owns the advance); the rest advance.
      if (_isReactionQuestion(current)) {
        _enterReaction(current);
      } else {
        _advance();
      }
    }

    if (_reduceMotion) {
      commit();
    } else {
      _selectHoldTimer = Timer(const Duration(milliseconds: 280), commit);
    }
  }

  // Multi-select identity questions confirm via an explicit CONTINUE: store the
  // chosen set, then react (emotional) or advance under the same re-entrancy guard.
  void _confirmIdentity(VoidCallback applyAnswer) {
    if (_advancing) return;
    _advancing = true;
    applyAnswer();
    final current = widget.questions[_step];
    if (_isReactionQuestion(current)) {
      _enterReaction(current);
    } else {
      _advance();
    }
  }

  void _finishWeightSex({
    double? bodyWeightKg,
    double? heightCm,
    required UserProfileSex sex,
  }) {
    if (_advancing) return;
    _advancing = true;
    _answers.bodyWeightKg = bodyWeightKg;
    _answers.heightCm = heightCm;
    _answers.sex = sex;
    _advance();
  }

  void _advance() {
    if (_isLast) {
      widget.onComplete(_answers);
    } else {
      setState(() => _step++);
      _advancing = false; // new question — accept input again
    }
  }

  // ── BIT reaction beat ─────────────────────────────────────────────────────
  // The emotional questions BIT reacts to (goal + body-metrics are ask-only).
  bool _isReactionQuestion(QuizQuestion q) => switch (q) {
    QuizQuestion.trainingWhy ||
    QuizQuestion.winningVision ||
    QuizQuestion.experience ||
    QuizQuestion.frequency ||
    QuizQuestion.obstacle => true,
    QuizQuestion.goal ||
    QuizQuestion.trainingFocus ||
    QuizQuestion.weightSex => false,
  };

  String _reactionTextFor(QuizQuestion q) => switch (q) {
    QuizQuestion.trainingWhy => BitInterviewCopy.vowReaction(
      BitInterviewCopy.vowPrimary(_answers.trainingWhy),
    ),
    QuizQuestion.winningVision => BitInterviewCopy.visionReaction(
      BitInterviewCopy.visionPrimary(_answers.winningVision),
    ),
    QuizQuestion.experience => BitInterviewCopy.experienceReaction(
      _answers.exp!,
    ),
    QuizQuestion.frequency => BitInterviewCopy.frequencyReaction(_answers.freq!),
    QuizQuestion.obstacle => BitInterviewCopy.obstacleReaction(
      _answers.obstacle!,
      freq: _answers.freq,
    ),
    QuizQuestion.goal ||
    QuizQuestion.trainingFocus ||
    QuizQuestion.weightSex => '',
  };

  void _enterReaction(QuizQuestion q) {
    // The segment-B intro is moot once the user has answered.
    _introTimer?.cancel();
    _showIntro = false;
    setState(() {
      _reacting = true;
      _reactionText = _reactionTextFor(q);
    });
  }

  void _advanceFromReaction() {
    if (!_reacting || _completing) return; // re-entrancy (double tap)
    if (_isLast) {
      // This page is about to be REPLACED by the next route (a loader that
      // animates in semi-transparent). Keep the reaction on screen — do NOT flip
      // back to ASKING — so the loader rises over BIT's promise, not a one-frame
      // flash of the answered question's options bleeding through the incoming
      // route. (Mid-quiz, the revert is fine: the next question's ASKING replaces
      // it in the same frame.)
      _completing = true;
      widget.onComplete(_answers);
      return;
    }
    setState(() {
      _reacting = false;
      _reactionText = null;
    });
    _advance();
  }

  void _goBack() {
    // A Back press during the 280ms select-hold cancels the pending commit, so a
    // stale callback can never react/advance for a question that's no longer up.
    _selectHoldTimer?.cancel();
    _selectHoldTimer = null;
    // Back during a reaction returns to ASKING of the SAME question (cancel the
    // timer, keep the selection editable) — not to the previous question.
    if (_reacting) {
      setState(() {
        _reacting = false;
        _reactionText = null;
        _advancing = false;
      });
      return;
    }
    if (_step == 0) {
      widget.onExit?.call();
      return;
    }
    setState(() => _step--);
    _advancing = false;
  }

  @override
  Widget build(BuildContext context) {
    // Note: internal Q→Q transitions are intentionally instant (no
    // AnimatedSwitcher) — the visible inter-question motion is provided by
    // the per-question typewriter + wipe-in stagger that runs when each new
    // question screen mounts.
    // Mirror the on-screen back button for the system back gesture: step back
    // within the segment, or exit via onExit at the first step. When onExit is
    // null (post-reveal segment) the first step is the point of no return, so
    // _goBack no-ops and the gesture is absorbed.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(child: _buildCurrentQuestion()),
      ),
    );
  }

  Widget _buildCurrentQuestion() {
    // Set.add returns true only the first time this step is viewed.
    final firstView = _seenSteps.add(_step);
    // Hide the back affordance on the first question when there's no exit.
    final onBack = (_step == 0 && widget.onExit == null) ? null : _goBack;
    return switch (widget.questions[_step]) {
      QuizQuestion.goal => _GoalQuestion(
        key: const ValueKey('quiz-goal'),
        progressCells: _progressCells,
        selected: _answers.goal,
        animate: firstView,
        onBack: onBack,
        onSelect: _select,
        bitAsk: BitInterviewCopy.ask(QuizQuestion.goal),
      ),
      QuizQuestion.trainingFocus => _FocusQuestion(
        key: const ValueKey('quiz-trainingFocus'),
        progressCells: _progressCells,
        selected: _answers.focus,
        animate: firstView,
        onBack: onBack,
        onSelect: _select,
        bitAsk: BitInterviewCopy.ask(QuizQuestion.trainingFocus),
      ),
      QuizQuestion.frequency => _FreqQuestion(
        key: const ValueKey('quiz-frequency'),
        progressCells: _progressCells,
        selected: _answers.freq,
        animate: firstView,
        onBack: onBack,
        onSelect: _select,
        bitAsk: BitInterviewCopy.ask(QuizQuestion.frequency),
        reacting: _reacting,
        reactionText: _reactionText,
        onReactionContinue: _advanceFromReaction,
      ),
      QuizQuestion.experience => _ExperienceQuestion(
        key: const ValueKey('quiz-experience'),
        progressCells: _progressCells,
        selected: _answers.exp,
        animate: firstView,
        onBack: onBack,
        onSelect: _select,
        // Segment-B intro line precedes the question, then morphs to the ask.
        bitAsk: _showIntro
            ? BitInterviewCopy.segmentBIntro
            : BitInterviewCopy.ask(QuizQuestion.experience),
        reacting: _reacting,
        reactionText: _reactionText,
        onReactionContinue: _advanceFromReaction,
      ),
      QuizQuestion.weightSex => _CalibrationQuestion(
        key: const ValueKey('quiz-weightSex'),
        progressCells: _progressCells,
        initialBodyWeightKg: _answers.bodyWeightKg,
        initialHeightCm: _answers.heightCm,
        initialSex: _answers.sex,
        animate: firstView,
        onBack: onBack,
        onContinue: _finishWeightSex,
        bitAsk: BitInterviewCopy.ask(QuizQuestion.weightSex),
      ),
      QuizQuestion.trainingWhy => _MultiSelectQuestion<TrainingWhy>(
        key: const ValueKey('quiz-trainingWhy'),
        progressCells: _progressCells,
        prompt: 'I TRAIN BECAUSE…',
        options: [
          for (final w in TrainingWhy.values) _MultiOption(w, w.label),
        ],
        selected: _answers.trainingWhy,
        animate: firstView,
        onBack: onBack,
        onConfirm: (set) => _confirmIdentity(() => _answers.trainingWhy = set),
        bitAsk: BitInterviewCopy.ask(QuizQuestion.trainingWhy),
        reacting: _reacting,
        reactionText: _reactionText,
        onReactionContinue: _advanceFromReaction,
      ),
      QuizQuestion.winningVision => _MultiSelectQuestion<WinningVision>(
        key: const ValueKey('quiz-winningVision'),
        progressCells: _progressCells,
        prompt: 'WHAT DOES WINNING\nLOOK LIKE TO YOU?',
        options: [
          for (final v in WinningVision.values)
            _MultiOption(v, v.label, v.subtext),
        ],
        selected: _answers.winningVision,
        animate: firstView,
        onBack: onBack,
        onConfirm: (set) =>
            _confirmIdentity(() => _answers.winningVision = set),
        bitAsk: BitInterviewCopy.ask(QuizQuestion.winningVision),
        reacting: _reacting,
        reactionText: _reactionText,
        onReactionContinue: _advanceFromReaction,
      ),
      QuizQuestion.obstacle => _ObstacleQuestion(
        key: const ValueKey('quiz-obstacle'),
        progressCells: _progressCells,
        selected: _answers.obstacle,
        animate: firstView,
        onBack: onBack,
        onSelect: _select,
        bitAsk: BitInterviewCopy.ask(QuizQuestion.obstacle),
        reacting: _reacting,
        reactionText: _reactionText,
        onReactionContinue: _advanceFromReaction,
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Shared layout
// ---------------------------------------------------------------------------

class _QuestionScaffold extends StatefulWidget {
  const _QuestionScaffold({
    required this.progressCells,
    required this.prompt,
    required this.body,
    required this.onBack,
    this.animatePrompt = true,
    this.subtitle,
    this.bitAsk,
    this.reacting = false,
    this.reactionText,
    this.onReactionContinue,
  });

  final int progressCells;
  final String prompt;
  final Widget body;
  final VoidCallback? onBack;
  final bool animatePrompt;

  /// Optional muted line beneath the prompt — the multi-select "Pick all that
  /// apply"; single-select questions leave it null.
  final String? subtitle;

  /// When non-null, BIT *asks* the question: the prompt zone becomes BIT's sprite
  /// + a typing speech bubble (the companion is the interviewer).
  final String? bitAsk;

  /// Reaction beat — BIT *types* [reactionText] (the promise) and the answer zone
  /// becomes a "tap to continue" hint. Tapping anywhere continues
  /// ([onReactionContinue]) once typed, or skips the type if still typing. No
  /// auto-advance.
  final bool reacting;
  final String? reactionText;
  final VoidCallback? onReactionContinue;

  @override
  State<_QuestionScaffold> createState() => _QuestionScaffoldState();
}

class _QuestionScaffoldState extends State<_QuestionScaffold> {
  static const _neonPromptStyle = TextStyle(
    fontFamily: 'PressStart2P',
    fontSize: 16,
    color: kNeon,
    height: 1.4,
  );

  // Reaction tap-to-continue: a tap before BIT finishes typing *skips* the type;
  // a tap after *continues*.
  bool _reactionTyped = false;
  bool _skip = false;

  @override
  void didUpdateWidget(_QuestionScaffold old) {
    super.didUpdateWidget(old);
    if (widget.reacting != old.reacting) {
      _reactionTyped = false;
      _skip = false;
    }
  }

  void _onTyped() {
    if (mounted) setState(() => _reactionTyped = true);
  }

  void _onReactionTap() {
    if (_reactionTyped) {
      widget.onReactionContinue?.call();
    } else {
      setState(() => _skip = true); // first tap finishes the line
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reducedMotion = media.disableAnimations || media.accessibleNavigation;
    return GestureDetector(
      // Tap anywhere to continue — but only while reacting (asking taps belong to
      // the options). The back button is a child, so it wins its own taps.
      behavior: widget.reacting
          ? HitTestBehavior.opaque
          : HitTestBehavior.deferToChild,
      onTap: widget.reacting ? _onReactionTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Zone 1 — top bar (56 px including SafeArea padding above).
          SizedBox(
            height: 56,
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: widget.onBack == null
                      ? null
                      : Semantics(
                          button: true,
                          label: 'Back',
                          child: ArcadeIconButton(
                            icon: const Icon(
                              Icons.chevron_left_sharp,
                              color: kText,
                              size: 28,
                            ),
                            onPressed: widget.onBack,
                          ),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ArcadeBar.segments(
                      totalCells: CalibrationQuizPage.totalProgressCells,
                      litCells: widget.progressCells,
                    ),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${widget.progressCells}/${CalibrationQuizPage.totalProgressCells}',
                    textAlign: TextAlign.center,
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          // Zone 2 — BIT asking/reacting, or the neon prompt.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: widget.bitAsk != null
                ? _bitPrompt()
                : _neonPrompt(reducedMotion),
          ),
          const SizedBox(height: 32),
          // Zone 3 — the answer, or the reaction's "tap to continue" hint.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: widget.reacting ? _reactionBody() : widget.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _neonPrompt(bool reducedMotion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: (reducedMotion || !widget.animatePrompt)
              ? Text(widget.prompt,
                  textAlign: TextAlign.center, style: _neonPromptStyle)
              : TypewriterText(
                  widget.prompt,
                  textAlign: TextAlign.center,
                  charMs: 30,
                  style: _neonPromptStyle,
                ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
        ],
      ],
    );
  }

  // BIT asks (or, when reacting, delivers its promise) — the bubble *types* the
  // line (robotic), re-typing whenever the line changes (question→question and
  // question→response). The sprite stays put; cheer on a reaction.
  Widget _bitPrompt() {
    final line =
        widget.reacting ? (widget.reactionText ?? widget.bitAsk!) : widget.bitAsk!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BitMoodCore(
                pose: widget.reacting ? BitPose.cheer : BitPose.neutral,
                reveal: 1,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BitSpeechBubble(
                    text: line,
                    typewriter: true,
                    skip: _skip,
                    onTypingComplete: _onTyped,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.subtitle != null && !widget.reacting) ...[
          const SizedBox(height: 12),
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
        ],
      ],
    );
  }

  // No CONTINUE button — a subtle "tap to continue" hint appears once BIT has
  // finished typing the promise; the whole screen is the tap target.
  Widget _reactionBody() {
    return Column(
      children: [
        const Spacer(),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: _reactionTyped ? 1.0 : 0.0,
          child: Text(
            'tap to continue ›',
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Q1 — GOAL (determines class)
// ---------------------------------------------------------------------------

class _GoalQuestion extends StatelessWidget {
  const _GoalQuestion({
    super.key,
    required this.progressCells,
    required this.selected,
    required this.animate,
    required this.onBack,
    required this.onSelect,
    this.bitAsk,
  });

  final int progressCells;
  final BodyGoal? selected;
  final bool animate;
  final VoidCallback? onBack;
  final ValueChanged<BodyGoal> onSelect;
  final String? bitAsk;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      progressCells: progressCells,
      prompt: "WHAT'S THE GOAL?",
      bitAsk: bitAsk,
      animatePrompt: animate,
      onBack: onBack,
      body: OptionList(
        hasAnySelection: selected != null,
        animate: animate,
        mainAxisAlignment: MainAxisAlignment.start,
        options: [
          OptionDef(
            title: 'GET LEANER',
            subtext: 'drop fat. keep strength.',
            icon: Icons.trending_down_sharp,
            isSelected: selected == BodyGoal.cut,
            onTap: () => onSelect(BodyGoal.cut),
          ),
          OptionDef(
            title: 'STAY + STRENGTHEN',
            subtext: 'hold weight. add strength.',
            icon: Icons.trending_flat_sharp,
            isSelected: selected == BodyGoal.recomp,
            onTap: () => onSelect(BodyGoal.recomp),
          ),
          OptionDef(
            title: 'GET BIGGER',
            subtext: 'add size. accept the gain.',
            icon: Icons.trending_up_sharp,
            isSelected: selected == BodyGoal.bulk,
            onTap: () => onSelect(BodyGoal.bulk),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Q1b — TRAINING FOCUS (seeds the cold-start rep target)
// ---------------------------------------------------------------------------

/// The rep-range goal (Strength / Muscle / Endurance) asked right after the
/// body goal. Single-select, ask-only (no BIT reaction) — mirrors the goal
/// question, with pixel-art leading icons. Its only mechanical effect is seeding
/// the suggested reps before an exercise has history (see [TrainingFocus]).
class _FocusQuestion extends StatelessWidget {
  const _FocusQuestion({
    super.key,
    required this.progressCells,
    required this.selected,
    required this.animate,
    required this.onBack,
    required this.onSelect,
    this.bitAsk,
  });

  final int progressCells;
  final TrainingFocus? selected;
  final bool animate;
  final VoidCallback? onBack;
  final ValueChanged<TrainingFocus> onSelect;
  final String? bitAsk;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      progressCells: progressCells,
      prompt: 'HOW TO TRAIN?',
      bitAsk: bitAsk,
      animatePrompt: animate,
      onBack: onBack,
      body: OptionList(
        hasAnySelection: selected != null,
        animate: animate,
        mainAxisAlignment: MainAxisAlignment.start,
        options: [
          for (final focus in TrainingFocus.values)
            OptionDef(
              title: focus.title,
              subtext: focus.subtext,
              assetIcon: focus.assetIcon,
              isSelected: selected == focus,
              onTap: () => onSelect(focus),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Q2 — FREQUENCY
// ---------------------------------------------------------------------------

class _FreqQuestion extends StatelessWidget {
  const _FreqQuestion({
    super.key,
    required this.progressCells,
    required this.selected,
    required this.animate,
    required this.onBack,
    required this.onSelect,
    this.bitAsk,
    this.reacting = false,
    this.reactionText,
    this.onReactionContinue,
  });

  final int progressCells;
  final TrainingFreq? selected;
  final bool animate;
  final VoidCallback? onBack;
  final ValueChanged<TrainingFreq> onSelect;
  final String? bitAsk;
  final bool reacting;
  final String? reactionText;
  final VoidCallback? onReactionContinue;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      progressCells: progressCells,
      prompt: 'HOW OFTEN?',
      bitAsk: bitAsk,
      reacting: reacting,
      reactionText: reactionText,
      onReactionContinue: onReactionContinue,
      animatePrompt: animate,
      onBack: onBack,
      body: OptionList(
        hasAnySelection: selected != null,
        animate: animate,
        mainAxisAlignment: MainAxisAlignment.start,
        options: [
          OptionDef(
            title: '2–3 DAYS',
            subtext: 'steady. sustainable.',
            isSelected: selected == TrainingFreq.low,
            onTap: () => onSelect(TrainingFreq.low),
          ),
          OptionDef(
            title: '4–5 DAYS',
            subtext: 'serious volume.',
            isSelected: selected == TrainingFreq.mid,
            onTap: () => onSelect(TrainingFreq.mid),
          ),
          OptionDef(
            title: '6+ DAYS',
            subtext: 'all in.',
            isSelected: selected == TrainingFreq.high,
            onTap: () => onSelect(TrainingFreq.high),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Q3 — EXPERIENCE
// ---------------------------------------------------------------------------

class _ExperienceQuestion extends StatelessWidget {
  const _ExperienceQuestion({
    super.key,
    required this.progressCells,
    required this.selected,
    required this.animate,
    required this.onBack,
    required this.onSelect,
    this.bitAsk,
    this.reacting = false,
    this.reactionText,
    this.onReactionContinue,
  });

  final int progressCells;
  final Experience? selected;
  final bool animate;
  final VoidCallback? onBack;
  final ValueChanged<Experience> onSelect;
  final String? bitAsk;
  final bool reacting;
  final String? reactionText;
  final VoidCallback? onReactionContinue;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      progressCells: progressCells,
      prompt: 'YOUR LEVEL?',
      bitAsk: bitAsk,
      reacting: reacting,
      reactionText: reactionText,
      onReactionContinue: onReactionContinue,
      animatePrompt: animate,
      onBack: onBack,
      body: OptionList(
        hasAnySelection: selected != null,
        animate: animate,
        mainAxisAlignment: MainAxisAlignment.start,
        options: [
          OptionDef(
            title: 'NOVICE',
            subtext: 'first real program.',
            isSelected: selected == Experience.novice,
            onTap: () => onSelect(Experience.novice),
          ),
          OptionDef(
            title: 'BEGINNER',
            subtext: 'a few months in.',
            isSelected: selected == Experience.beginner,
            onTap: () => onSelect(Experience.beginner),
          ),
          OptionDef(
            title: 'INTERMEDIATE',
            subtext: 'consistent for a year+.',
            isSelected: selected == Experience.intermediate,
            onTap: () => onSelect(Experience.intermediate),
          ),
          OptionDef(
            title: 'ADVANCED',
            subtext: 'years under the bar.',
            isSelected: selected == Experience.advanced,
            onTap: () => onSelect(Experience.advanced),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OBSTACLE (single-select) — the one barrier BIT responds to
// ---------------------------------------------------------------------------

class _ObstacleQuestion extends StatelessWidget {
  const _ObstacleQuestion({
    super.key,
    required this.progressCells,
    required this.selected,
    required this.animate,
    required this.onBack,
    required this.onSelect,
    this.bitAsk,
    this.reacting = false,
    this.reactionText,
    this.onReactionContinue,
  });

  final int progressCells;
  final Obstacle? selected;
  final bool animate;
  final VoidCallback? onBack;
  final ValueChanged<Obstacle> onSelect;
  final String? bitAsk;
  final bool reacting;
  final String? reactionText;
  final VoidCallback? onReactionContinue;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      progressCells: progressCells,
      prompt: 'WHAT USUALLY GETS\nIN THE WAY?',
      bitAsk: bitAsk,
      reacting: reacting,
      reactionText: reactionText,
      onReactionContinue: onReactionContinue,
      animatePrompt: animate,
      onBack: onBack,
      body: OptionList(
        hasAnySelection: selected != null,
        animate: animate,
        mainAxisAlignment: MainAxisAlignment.start,
        options: [
          for (final o in Obstacle.values)
            OptionDef(
              title: o.label,
              isSelected: selected == o,
              onTap: () => onSelect(o),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Identity beats — vow / vision / obstacle (Resolve questions, interleaved)
// ---------------------------------------------------------------------------

/// One selectable option for a [_MultiSelectQuestion].
class _MultiOption<T> {
  const _MultiOption(this.value, this.title, [this.subtext]);
  final T value;
  final String title;
  final String? subtext;
}

/// A multi-select identity question: tap any number of cards (each highlights,
/// none dim), then CONTINUE (enabled once ≥1 is picked) commits the chosen set.
/// Restores prior picks on back-nav from the set passed in [selected].
class _MultiSelectQuestion<T> extends StatefulWidget {
  const _MultiSelectQuestion({
    super.key,
    required this.progressCells,
    required this.prompt,
    required this.options,
    required this.selected,
    required this.animate,
    required this.onBack,
    required this.onConfirm,
    this.bitAsk,
    this.reacting = false,
    this.reactionText,
    this.onReactionContinue,
  });

  final int progressCells;
  final String prompt;
  final List<_MultiOption<T>> options;
  final Set<T> selected;
  final bool animate;
  final VoidCallback? onBack;
  final ValueChanged<Set<T>> onConfirm;
  final String? bitAsk;
  final bool reacting;
  final String? reactionText;
  final VoidCallback? onReactionContinue;

  @override
  State<_MultiSelectQuestion<T>> createState() =>
      _MultiSelectQuestionState<T>();
}

class _MultiSelectQuestionState<T> extends State<_MultiSelectQuestion<T>> {
  late final Set<T> _selected = {...widget.selected};

  void _toggle(T value) => setState(() {
    // Set.add returns false when already present → treat as a deselect.
    if (!_selected.add(value)) _selected.remove(value);
  });

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      progressCells: widget.progressCells,
      prompt: widget.prompt,
      subtitle: 'Pick all that apply',
      bitAsk: widget.bitAsk,
      reacting: widget.reacting,
      reactionText: widget.reactionText,
      onReactionContinue: widget.onReactionContinue,
      animatePrompt: widget.animate,
      onBack: widget.onBack,
      body: Column(
        children: [
          Expanded(
            child: OptionList(
              // Multi-select: never dim non-selected cards — all stay tappable.
              hasAnySelection: false,
              animate: widget.animate,
              mainAxisAlignment: MainAxisAlignment.start,
              options: [
                for (final o in widget.options)
                  OptionDef(
                    title: o.title,
                    subtext: o.subtext,
                    isSelected: _selected.contains(o.value),
                    onTap: () => _toggle(o.value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PixelButton(
            label: 'CONTINUE',
            powerOn: true,
            onPressed: _selected.isEmpty
                ? null
                : () => widget.onConfirm(_selected),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Q4 — CALIBRATE (bodyweight + sex; CONTINUE / skip)
// ---------------------------------------------------------------------------

class _CalibrationQuestion extends StatefulWidget {
  const _CalibrationQuestion({
    super.key,
    required this.progressCells,
    required this.initialBodyWeightKg,
    required this.initialHeightCm,
    required this.initialSex,
    required this.animate,
    required this.onBack,
    required this.onContinue,
    this.bitAsk,
  });

  final int progressCells;
  final double? initialBodyWeightKg;
  final double? initialHeightCm;
  final UserProfileSex initialSex;
  final bool animate;
  final VoidCallback? onBack;
  final FutureOr<void> Function({
    double? bodyWeightKg,
    double? heightCm,
    required UserProfileSex sex,
  })
  onContinue;

  final String? bitAsk;

  @override
  State<_CalibrationQuestion> createState() => _CalibrationQuestionState();
}

class _CalibrationQuestionState extends State<_CalibrationQuestion> {
  // Units default to the app-wide preference (lbs / ft-in on a fresh install);
  // toggling here updates that preference for the rest of the app.
  late WeightUnit _weightUnit = Units.weight;
  late LengthUnit _heightUnit = Units.height;

  late final TextEditingController _weightController = TextEditingController(
    text: widget.initialBodyWeightKg != null
        ? weightValue(widget.initialBodyWeightKg!, _weightUnit)
        : '',
  );
  late final TextEditingController _cmController = TextEditingController(
    text: (widget.initialHeightCm != null && _heightUnit == LengthUnit.cm)
        ? widget.initialHeightCm!.round().toString()
        : '',
  );
  late final TextEditingController _feetController = TextEditingController(
    text: _initialFeetInches?.feet.toString() ?? '',
  );
  late final TextEditingController _inchController = TextEditingController(
    text: _initialFeetInches?.inches.toString() ?? '',
  );
  late UserProfileSex _sex = widget.initialSex;

  ({int feet, int inches})? get _initialFeetInches {
    if (widget.initialHeightCm == null || _heightUnit != LengthUnit.ftIn) {
      return null;
    }
    return cmToFeetInches(widget.initialHeightCm!);
  }

  /// Bodyweight parsed in the active unit, returned in canonical kg.
  double? get _bodyWeightKg =>
      parseWeightToKg(_weightController.text, _weightUnit);

  /// Height parsed in the active unit, returned in canonical cm.
  double? get _heightCm {
    if (_heightUnit == LengthUnit.cm) {
      final v = double.tryParse(_cmController.text.trim());
      return (v != null && v > 0) ? v : null;
    }
    final ft = int.tryParse(_feetController.text.trim()) ?? 0;
    final inch = int.tryParse(_inchController.text.trim()) ?? 0;
    if (ft <= 0 && inch <= 0) return null;
    return feetInchesToCm(ft, inch);
  }

  void _setWeightUnit(WeightUnit unit) {
    if (unit == _weightUnit) return;
    final kg = _bodyWeightKg; // parse with the old unit before switching
    Units.setWeight(unit);
    setState(() {
      _weightUnit = unit;
      _weightController.text = kg != null ? weightValue(kg, unit) : '';
    });
  }

  void _setHeightUnit(LengthUnit unit) {
    if (unit == _heightUnit) return;
    final cm = _heightCm; // parse with the old unit before switching
    Units.setHeight(unit);
    setState(() {
      _heightUnit = unit;
      if (unit == LengthUnit.cm) {
        _cmController.text = cm != null ? cm.round().toString() : '';
      } else {
        final h = cm != null ? cmToFeetInches(cm) : null;
        _feetController.text = h?.feet.toString() ?? '';
        _inchController.text = h?.inches.toString() ?? '';
      }
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _cmController.dispose();
    _feetController.dispose();
    _inchController.dispose();
    super.dispose();
  }

  void _submit() {
    // Bodyweight seeds the stat engine, so drop an implausible fat-finger value
    // (treat as not provided) rather than letting it inflate the seed.
    final bw = _bodyWeightKg;
    widget.onContinue(
      bodyWeightKg: (bw != null && isPlausibleWeightKg(bw)) ? bw : null,
      heightCm: _heightCm,
      sex: _sex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      progressCells: widget.progressCells,
      prompt: 'DIAL IT IN',
      bitAsk: widget.bitAsk,
      animatePrompt: widget.animate,
      onBack: widget.onBack,
      body: ListView(
        children: [
          _UnitToggleRow(
            options: const ['KG', 'LBS'],
            selectedIndex: _weightUnit == WeightUnit.kg ? 0 : 1,
            onSelect: (i) =>
                _setWeightUnit(i == 0 ? WeightUnit.kg : WeightUnit.lbs),
          ),
          const SizedBox(height: 8),
          Text(
            'BODYWEIGHT (${_weightUnit.labelUpper})',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ArcadeTextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: AppFonts.shareTechMono(color: kText, fontSize: 16),
            hintText: _weightUnit == WeightUnit.kg ? 'e.g. 75' : 'e.g. 165',
            onChanged: (_) => setState(() {}), // re-evaluate CONTINUE enable
          ),
          const SizedBox(height: 24),
          _UnitToggleRow(
            options: const ['CM', 'FT-IN'],
            selectedIndex: _heightUnit == LengthUnit.cm ? 0 : 1,
            onSelect: (i) =>
                _setHeightUnit(i == 0 ? LengthUnit.cm : LengthUnit.ftIn),
          ),
          const SizedBox(height: 8),
          Text(
            'HEIGHT (${_heightUnit.labelUpper})',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _buildHeightField(),
          const SizedBox(height: 24),
          Text(
            'SEX',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in UserProfileSex.values)
                ArcadeChip(
                  label: s.label,
                  selected: _sex == s,
                  onTap: () => setState(() => _sex = s),
                ),
            ],
          ),
          const SizedBox(height: 32),
          PixelButton(label: 'CONTINUE', powerOn: true, onPressed: _submit),
        ],
      ),
    );
  }

  Widget _buildHeightField() {
    if (_heightUnit == LengthUnit.cm) {
      return ArcadeTextField(
        controller: _cmController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        style: AppFonts.shareTechMono(color: kText, fontSize: 16),
        hintText: 'e.g. 180',
        onChanged: (_) => setState(() {}),
      );
    }
    return Row(
      children: [
        Expanded(
          child: ArcadeTextField(
            controller: _feetController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppFonts.shareTechMono(color: kText, fontSize: 16),
            hintText: 'e.g. 5',
            suffixText: 'ft',
            suffixStyle: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 12,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ArcadeTextField(
            controller: _inchController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppFonts.shareTechMono(color: kText, fontSize: 16),
            hintText: 'e.g. 11',
            suffixText: 'in',
            suffixStyle: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 12,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }
}

/// Compact two-option segmented toggle for unit selection, styled with the
/// existing arcade chip language.
class _UnitToggleRow extends StatelessWidget {
  const _UnitToggleRow({
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (var i = 0; i < options.length; i++)
          ArcadeChip(
            label: options[i],
            selected: selectedIndex == i,
            onTap: () => onSelect(i),
          ),
      ],
    );
  }
}
