# Quiz Interaction Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three interaction rough edges in the onboarding quiz (`lib/pages/onboarding/calibration_quiz_page.dart`): (1) the prompt re-types itself on **back**-navigation (charming forward, annoying when fixing an answer); (2) the option cards are **top-heavy** with a large empty void beneath; (3) auto-advance is so fast (150ms) it **cuts off the selection animation** before the user sees their choice land.

**Architecture:** Questions are rendered by an inline step index in `_CalibrationQuizPageState`; each question widget wraps `_QuestionScaffold` (prompt via `TypewriterText`) and `_OptionList` (cards via `_WipeIn` stagger). We add a `Set<int> _seenSteps` in the parent so the prompt/stagger animate only on **first** view of each step (instant on back). We rewrite `_OptionList` to center its cards vertically (centered when short, scrolls when tall). We lengthen the auto-advance confirm beat from 150ms to 280ms so the 120ms selection animation completes visibly.

**Tech Stack:** Flutter / Dart. Tests via `flutter test`. Lint via `flutter analyze`.

> **Execution order:** Run this plan **after** `2026-05-26-calibrate-continue-fix.md` and `2026-05-26-q1-goal-class-reveal.md` — all three edit the same file. The `_OptionList` rewrite in Task 1 assumes Plan 2's `accentColor`/`accentLabel` forwarding is already present (shown below).

---

### Task 1: Animate prompt + card stagger only on first view (instant on back)

**Files:**
- Modify: `lib/pages/onboarding/calibration_quiz_page.dart` (`_CalibrationQuizPageState`, `_QuestionScaffold`, `_OptionList`, and the four question widgets)
- Test: `test/calibration_quiz_test.dart`

- [ ] **Step 1: Write the failing test (animations ON)**

In `test/calibration_quiz_test.dart`, add inside `group('CalibrationQuizPage widget', ...)`:

```dart
    testWidgets('returning to a question shows its prompt instantly', (
      tester,
    ) async {
      // Animations ON (reducedMotion defaults to false).
      await _openQuiz(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('GET LEANER'));
      await tester.pumpAndSettle();
      expect(find.text('HOW OFTEN?'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      // Single frame only — if the prompt re-typed, one frame would show a
      // partial string and this exact-text match would fail.
      await tester.pump();
      expect(find.text("WHAT'S THE GOAL?"), findsOneWidget);
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/calibration_quiz_test.dart --plain-name "instantly"`
Expected: FAIL — after Back, the prompt re-types, so a single `pump()` shows only a prefix (e.g. "W"), not the full `WHAT'S THE GOAL?`.

- [ ] **Step 3: Track seen steps in the parent and pass `animate`**

In `_CalibrationQuizPageState`, add the field below `int _step = 0;` (~line 45):

```dart
  // Steps whose entrance has already played — used to suppress the
  // typewriter + wipe-in when navigating back to an already-seen question.
  final Set<int> _seenSteps = {};
```

Then replace `_buildCurrentQuestion` (~117-152) so it computes `firstView` once and passes `animate:` to every branch:

```dart
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
```

- [ ] **Step 4: Add `animatePrompt` to `_QuestionScaffold`**

In `_QuestionScaffold`, add the field + constructor param:

```dart
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
```

Then in its `build`, change the prompt branch condition (~233) from `reducedMotion` to `(reducedMotion || !animatePrompt)`:

```dart
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
```

- [ ] **Step 5: Add `animate` to the three option-list questions**

In each of `_GoalQuestion`, `_FreqQuestion`, `_ExperienceQuestion`: add a required `final bool animate;` field + `required this.animate,` constructor param. Then in each `build`, add `animatePrompt: animate,` to the `_QuestionScaffold(...)` call and `animate: animate,` to the `_OptionList(...)` call. For example, `_GoalQuestion` becomes (note the body/options are owned by the Q1 class-reveal plan — only the two new argument lines are added):

```dart
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
          // ... the three goal _OptionDef entries from the class-reveal plan ...
        ],
      ),
    );
  }
}
```

Apply the identical two-line additions (`animatePrompt: animate,` on the scaffold, `animate: animate,` on the list) to `_FreqQuestion` and `_ExperienceQuestion`, adding the `animate` field/param to each. Their `prompt`/`options` stay exactly as they are today.

- [ ] **Step 6: Add `animate` to `_CalibrationQuestion` (Q4)**

`_CalibrationQuestion` is a `StatefulWidget`. Add `final bool animate;` + `required this.animate,` to its constructor/fields. Then in `_CalibrationQuestionState.build`, add `animatePrompt: widget.animate,` to its `_QuestionScaffold(...)` call (Q4 has no `_OptionList`):

```dart
    return _QuestionScaffold(
      progressCells: widget.progressCells,
      prompt: 'DIAL IT IN',
      subtitle: 'optional — your weight fine-tunes the numbers.',
      animatePrompt: widget.animate,
      onBack: widget.onBack,
      body: ListView(
```

(Prompt/subtitle shown here reflect the calibrate-fix plan; if that plan hasn't run yet they'll still read `'CALIBRATE'` — only the `animatePrompt:` line is added by this task.)

- [ ] **Step 7: Rewrite `_OptionList` — `animate` flag + vertical centering**

Replace the entire `_OptionList` class with (this both gates the `_WipeIn` stagger on `animate` and centers the cards vertically; the `_OptionCard` arguments include Plan 2's `accentColor`/`accentLabel`):

```dart
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
        accentColor: options[i].accentColor,
        accentLabel: options[i].accentLabel,
      );
      children.add(
        animate
            ? _WipeIn(delay: Duration(milliseconds: i * 80), child: card)
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
```

- [ ] **Step 8: Run the new test to verify it passes**

Run: `flutter test test/calibration_quiz_test.dart --plain-name "instantly"`
Expected: PASS — after Back, the prompt is rendered as plain `Text` (full string in one frame).

- [ ] **Step 9: Run the full quiz file + analyze (regression)**

Run: `flutter test test/calibration_quiz_test.dart`
Expected: PASS (reduced-motion tests unaffected — they already render the prompt instantly and skip `_WipeIn`).
Run: `flutter analyze`
Expected: no new issues (every `_GoalQuestion`/`_FreqQuestion`/`_ExperienceQuestion`/`_CalibrationQuestion` constructor call in `_buildCurrentQuestion` now passes `animate:`, so no "missing required argument").

- [ ] **Step 10: Commit**

```bash
git add lib/pages/onboarding/calibration_quiz_page.dart test/calibration_quiz_test.dart
git commit -m "feat(onboarding): play quiz entrance once; center option cards

Prompt typewriter + card wipe-in run only on first view of each step
(instant on back). Option cards now center vertically instead of
clustering at the top with a void beneath.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Lengthen the auto-advance confirm beat (150ms → 280ms)

**Files:**
- Modify: `lib/pages/onboarding/calibration_quiz_page.dart` (`_advanceFrom` ~57-69)

- [ ] **Step 1: Bump the hold so the selection animation lands**

In `_advanceFrom`, change the delay (~62-66) from 150ms to 280ms (the `_OptionCard` selected-state animation is 120ms; 280ms lets it complete + a brief "landed" beat before the swap):

```dart
    // 280 ms hold so the selection animation (120 ms) completes and the
    // choice visibly "lands" before the screen swaps.
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (!reducedMotion) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }
```

- [ ] **Step 2: Verify the full quiz suite still passes**

Run: `flutter test test/calibration_quiz_test.dart`
Expected: PASS. The reduced-motion tests skip the delay entirely (`if (!reducedMotion)`); the animations-on test from Task 1 uses `pumpAndSettle`, which absorbs the longer beat.

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 4: Commit**

```bash
git add lib/pages/onboarding/calibration_quiz_page.dart
git commit -m "fix(onboarding): let the quiz selection animation land before advancing

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** typewriter/stagger once, instant on back (Task 1, `_seenSteps` + `animate`) ✓; center option cards / kill top-heavy void (Task 1 Step 7, `LayoutBuilder`+`ConstrainedBox`+centered `Column`) ✓; auto-advance no longer cuts the selection animation (Task 2, 150→280ms) ✓.
- **Placeholder scan:** the only `// ...` is the explicit pointer to the class-reveal plan's option list (which owns that code) inside an illustrative example — not a code step to implement. Every actual implementation step has complete code.
- **Type consistency:** `animate` is `bool` across `_GoalQuestion`/`_FreqQuestion`/`_ExperienceQuestion`/`_CalibrationQuestion`; `_QuestionScaffold.animatePrompt` is `bool` (default true); `_OptionList.animate` is `bool` (default true). `_seenSteps.add(_step)` returns `bool`. Parent passes `animate: firstView` to all four branches — matches the required params added in Steps 5–6.
- **Interaction with other plans:** `_OptionList` is rewritten here once, already including Plan 2's `accentColor`/`accentLabel` forwarding — no double-edit conflict if executed after Plan 2. The `_QuestionScaffold` prompt branch keeps the reduced-motion path intact (`reducedMotion || !animatePrompt`).
