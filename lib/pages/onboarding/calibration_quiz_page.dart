import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/body_goal_models.dart';
import '../../models/calibration_quiz_models.dart';
import '../../models/character_class.dart';
import '../../models/user_profile_sex.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_chip.dart';
import '../../widgets/motion/arcade_text_field.dart';
import '../../widgets/motion/hold_depress.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/segmented_progress_bar.dart';
import '../../widgets/typewriter_text.dart';

/// 4-question calibration quiz. Derives [CharacterClass] from Q1, captures
/// training cadence + experience + (optional) bodyweight & sex. Returns the
/// [CalibrationResult] via `Navigator.pop(result)` on completion unless
/// [onResult] is provided. Onboarding uses [onResult] to push the class reveal
/// over Q4 so back-navigation can restore the completed quiz answers.
///
/// **Design note** — internally uses a single route with an inline step index
/// rather than a stack of pushed routes. This gives reliable back-restore
/// behavior and a clean result return without coordinating pop counts across
/// 4 routes. The arcade route flash is therefore the *enter/exit* boundary of
/// the quiz; Q→Q transitions use a quieter directional fade-slide, consistent
/// with the prompt's "no motion while reading" principle.
class CalibrationQuizPage extends StatefulWidget {
  const CalibrationQuizPage({super.key, this.onResult});

  final Future<void> Function(CalibrationResult result)? onResult;

  // Cell 1 is "borrowed" from the intro; the quiz contributes cells 2–5.
  static const int totalProgressCells = 5;
  static const int introHeadStart = 1;

  @override
  State<CalibrationQuizPage> createState() => _CalibrationQuizPageState();
}

class _CalibrationQuizPageState extends State<CalibrationQuizPage> {
  int _step = 0; // 0=Q1, 1=Q2, 2=Q3, 3=Q4

  // Steps whose entrance has already played — used to suppress the
  // typewriter + wipe-in when navigating back to an already-seen question.
  final Set<int> _seenSteps = {};

  // Accumulated answers.
  BodyGoal? _goal;
  TrainingFreq? _freq;
  Experience? _exp;
  double? _bodyWeightKg;
  UserProfileSex _sex = UserProfileSex.preferNotToSay;

  int get _progressCells =>
      CalibrationQuizPage.introHeadStart + _step + 1; // 2..5 across Q1..Q4

  Future<void> _advanceFrom(int currentStep, Object answer) async {
    // Apply the answer immediately so back-navigation restores it.
    if (answer is BodyGoal) _goal = answer;
    if (answer is TrainingFreq) _freq = answer;
    if (answer is Experience) _exp = answer;
    // 280 ms hold so the selection animation (120 ms) completes and the
    // choice visibly "lands" before the screen swaps.
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (!reducedMotion) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }
    if (!mounted) return;
    setState(() => _step = currentStep + 1);
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop(); // null result → flow re-renders SolutionView
      return;
    }
    setState(() => _step--);
  }

  Future<void> _finish({
    double? bodyWeightKg,
    required UserProfileSex sex,
  }) async {
    final goal = _goal!;
    final freq = _freq!;
    final exp = _exp!;
    _bodyWeightKg = bodyWeightKg;
    _sex = sex;
    final result = CalibrationResult(
      goal: goal,
      freq: freq,
      exp: exp,
      bodyWeightKg: _bodyWeightKg,
      sex: _sex,
      clazz: deriveClass(goal),
    );
    final callback = widget.onResult;
    if (callback != null) {
      await callback(result);
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    // Note: internal Q→Q transitions are intentionally instant (no
    // AnimatedSwitcher) — the visible inter-question motion is provided by
    // the per-question typewriter + wipe-in stagger that runs when each new
    // question screen mounts. Keeps the Q4 form's TextField/ChoiceChips out
    // of any animation overlap.
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(child: _buildCurrentQuestion()),
    );
  }

  Widget _buildCurrentQuestion() {
    // Set.add returns true only the first time this step is viewed.
    final firstView = _seenSteps.add(_step);
    return switch (_step) {
      0 => _GoalQuestion(
        key: const ValueKey('quiz-q1'),
        step: _step,
        progressCells: _progressCells,
        selected: _goal,
        animate: firstView,
        onBack: _goBack,
        onSelect: (g) => _advanceFrom(0, g),
      ),
      1 => _FreqQuestion(
        key: const ValueKey('quiz-q2'),
        step: _step,
        progressCells: _progressCells,
        selected: _freq,
        animate: firstView,
        onBack: _goBack,
        onSelect: (f) => _advanceFrom(1, f),
      ),
      2 => _ExperienceQuestion(
        key: const ValueKey('quiz-q3'),
        step: _step,
        progressCells: _progressCells,
        selected: _exp,
        animate: firstView,
        onBack: _goBack,
        onSelect: (e) => _advanceFrom(2, e),
      ),
      _ => _CalibrationQuestion(
        key: const ValueKey('quiz-q4'),
        progressCells: _progressCells,
        initialBodyWeightKg: _bodyWeightKg,
        initialSex: _sex,
        animate: firstView,
        onBack: _goBack,
        onContinue: _finish,
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Shared layout
// ---------------------------------------------------------------------------

class _QuestionScaffold extends StatelessWidget {
  const _QuestionScaffold({
    required this.progressCells,
    required this.prompt,
    required this.body,
    required this.onBack,
    this.subtitle,
    this.animatePrompt = true,
  });

  final int progressCells;
  final String prompt;
  final Widget body;
  final VoidCallback onBack;
  final String? subtitle;
  final bool animatePrompt;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return Column(
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
                child: Semantics(
                  button: true,
                  label: 'Back',
                  child: IconButton(
                    icon: const Icon(
                      Icons.chevron_left_sharp,
                      color: kText,
                      size: 28,
                    ),
                    onPressed: onBack,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SegmentedProgressBar(
                    totalCells: CalibrationQuizPage.totalProgressCells,
                    litCells: progressCells,
                  ),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '$progressCells/${CalibrationQuizPage.totalProgressCells}',
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
        // Zone 2 — prompt.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: (reducedMotion || !animatePrompt)
                    ? Text(
                        prompt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 16,
                          color: kNeon,
                          height: 1.4,
                        ),
                      )
                    : TypewriterText(
                        prompt,
                        textAlign: TextAlign.center,
                        charMs: 30,
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 16,
                          color: kNeon,
                          height: 1.4,
                        ),
                      ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Zone 3 — answer.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: body,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Option card (variant A)
// ---------------------------------------------------------------------------

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.subtext,
    required this.isSelected,
    required this.hasAnySelection,
    required this.onTap,
  });

  final String title;
  final String subtext;
  final bool isSelected;
  final bool hasAnySelection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final dimmed = hasAnySelection && !isSelected;
    const accent = kNeon;
    final borderColor = isSelected ? accent : kBorder;
    final titleColor = isSelected ? accent : kText;
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 120);

    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: isSelected,
      label: '$title. $subtext',
      child: HoldDepress(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: AnimatedOpacity(
          duration: duration,
          opacity: dimmed ? 0.4 : 1.0,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: kCard,
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: duration,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 11,
                    color: titleColor,
                    height: 1.2,
                  ),
                  child: Text(title),
                ),
                const SizedBox(height: 6),
                Text(
                  subtext,
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WipeIn extends StatefulWidget {
  const _WipeIn({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_WipeIn> createState() => _WipeInState();
}

class _WipeInState extends State<_WipeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Timer? _startTimer;
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.of(context).disableAnimations;
    _reducedMotion = reduced;
    if (reduced) {
      _controller.value = 1;
      return;
    }
    if (!_controller.isAnimating && _controller.value == 0) {
      _startTimer?.cancel();
      _startTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reducedMotion) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t.clamp(0.0001, 1.0),
            child: Opacity(opacity: t, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Q1 — GOAL (determines class)
// ---------------------------------------------------------------------------

class _GoalQuestion extends StatelessWidget {
  const _GoalQuestion({
    super.key,
    required this.step,
    required this.progressCells,
    required this.selected,
    required this.animate,
    required this.onBack,
    required this.onSelect,
  });

  final int step;
  final int progressCells;
  final BodyGoal? selected;
  final bool animate;
  final VoidCallback onBack;
  final ValueChanged<BodyGoal> onSelect;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      progressCells: progressCells,
      prompt: "WHAT'S THE GOAL?",
      subtitle: 'this sets your class.',
      animatePrompt: animate,
      onBack: onBack,
      body: _OptionList(
        hasAnySelection: selected != null,
        animate: animate,
        options: [
          _OptionDef(
            title: 'GET LEANER',
            subtext: 'drop fat. keep strength.',
            isSelected: selected == BodyGoal.cut,
            onTap: () => onSelect(BodyGoal.cut),
          ),
          _OptionDef(
            title: 'STAY + STRENGTHEN',
            subtext: 'hold weight. add strength.',
            isSelected: selected == BodyGoal.recomp,
            onTap: () => onSelect(BodyGoal.recomp),
          ),
          _OptionDef(
            title: 'GET BIGGER',
            subtext: 'add size. accept the gain.',
            isSelected: selected == BodyGoal.bulk,
            onTap: () => onSelect(BodyGoal.bulk),
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
    required this.step,
    required this.progressCells,
    required this.selected,
    required this.animate,
    required this.onBack,
    required this.onSelect,
  });

  final int step;
  final int progressCells;
  final TrainingFreq? selected;
  final bool animate;
  final VoidCallback onBack;
  final ValueChanged<TrainingFreq> onSelect;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      progressCells: progressCells,
      prompt: 'HOW OFTEN?',
      animatePrompt: animate,
      onBack: onBack,
      body: _OptionList(
        hasAnySelection: selected != null,
        animate: animate,
        options: [
          _OptionDef(
            title: '2–3 DAYS',
            subtext: 'steady. sustainable.',
            isSelected: selected == TrainingFreq.low,
            onTap: () => onSelect(TrainingFreq.low),
          ),
          _OptionDef(
            title: '4–5 DAYS',
            subtext: 'serious volume.',
            isSelected: selected == TrainingFreq.mid,
            onTap: () => onSelect(TrainingFreq.mid),
          ),
          _OptionDef(
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
    required this.step,
    required this.progressCells,
    required this.selected,
    required this.animate,
    required this.onBack,
    required this.onSelect,
  });

  final int step;
  final int progressCells;
  final Experience? selected;
  final bool animate;
  final VoidCallback onBack;
  final ValueChanged<Experience> onSelect;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      progressCells: progressCells,
      prompt: 'YOUR LEVEL?',
      animatePrompt: animate,
      onBack: onBack,
      body: _OptionList(
        hasAnySelection: selected != null,
        animate: animate,
        options: [
          _OptionDef(
            title: 'NOVICE',
            subtext: 'first real program.',
            isSelected: selected == Experience.novice,
            onTap: () => onSelect(Experience.novice),
          ),
          _OptionDef(
            title: 'BEGINNER',
            subtext: 'a few months in.',
            isSelected: selected == Experience.beginner,
            onTap: () => onSelect(Experience.beginner),
          ),
          _OptionDef(
            title: 'INTERMEDIATE',
            subtext: 'consistent for a year+.',
            isSelected: selected == Experience.intermediate,
            onTap: () => onSelect(Experience.intermediate),
          ),
          _OptionDef(
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

class _OptionDef {
  const _OptionDef({
    required this.title,
    required this.subtext,
    required this.isSelected,
    required this.onTap,
  });
  final String title;
  final String subtext;
  final bool isSelected;
  final VoidCallback onTap;
}

class _OptionList extends StatelessWidget {
  const _OptionList({
    required this.hasAnySelection,
    required this.options,
    this.animate = true,
  });

  final bool hasAnySelection;
  final List<_OptionDef> options;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < options.length; i++) {
      final card = _OptionCard(
        title: options[i].title,
        subtext: options[i].subtext,
        isSelected: options[i].isSelected,
        hasAnySelection: hasAnySelection,
        onTap: options[i].onTap,
      );
      children.add(
        animate
            ? _WipeIn(
                delay: Duration(milliseconds: i * 80),
                child: card,
              )
            : card,
      );
      if (i != options.length - 1) children.add(const SizedBox(height: 12));
    }
    // Center the cards in the available space (kills the top-heavy void) while
    // still scrolling if the list is taller than the viewport (Q3 has four).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
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
    required this.initialSex,
    required this.animate,
    required this.onBack,
    required this.onContinue,
  });

  final int progressCells;
  final double? initialBodyWeightKg;
  final UserProfileSex initialSex;
  final bool animate;
  final VoidCallback onBack;
  final FutureOr<void> Function({
    double? bodyWeightKg,
    required UserProfileSex sex,
  })
  onContinue;

  @override
  State<_CalibrationQuestion> createState() => _CalibrationQuestionState();
}

class _CalibrationQuestionState extends State<_CalibrationQuestion> {
  late final TextEditingController _weightController = TextEditingController(
    text: widget.initialBodyWeightKg?.toString() ?? '',
  );
  late UserProfileSex _sex = widget.initialSex;

  double? get _validBodyWeight {
    final raw = _weightController.text.trim();
    final parsed = double.tryParse(raw);
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onContinue(bodyWeightKg: _validBodyWeight, sex: _sex);
  }

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      progressCells: widget.progressCells,
      prompt: 'DIAL IT IN',
      subtitle: 'optional — your weight fine-tunes the numbers.',
      animatePrompt: widget.animate,
      onBack: widget.onBack,
      body: ListView(
        children: [
          Text(
            'BODYWEIGHT (KG)',
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
            hintText: 'e.g. 75',
            onChanged: (_) => setState(() {}), // re-evaluate CONTINUE enable
          ),
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
}
