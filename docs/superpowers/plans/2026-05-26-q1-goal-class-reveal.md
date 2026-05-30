# Q1 Goal Cards — Class-Defining Choice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the onboarding quiz's first question ("WHAT'S THE GOAL?") visibly the choice that defines the player's class — today it's three identical text cards with no hint that it silently picks Assassin / Bruiser / Tank.

**Architecture:** Q1 is `_GoalQuestion` in `lib/pages/onboarding/calibration_quiz_page.dart`, rendering three `_OptionCard`s via `_OptionList`. The goal→class map already exists: `deriveClass(BodyGoal)` in `lib/models/calibration_quiz_models.dart` (cut→assassin, recomp→bruiser, bulk→tank), and `CharacterClass.themeColor` / `.displayName` exist in `lib/models/character_class.dart` (assassin cyan `#4DE5FF`, bruiser amber `#FFD700`, tank red `#FF2D55`). We add two optional fields (`accentColor`, `accentLabel`) to the shared `_OptionDef`/`_OptionCard`, render a small class-color tag pill on each Q1 card and tint the selected border/title in the class color, and add a Q1 subtitle "this sets your class." Q2/Q3 pass the fields as `null` and render exactly as today (neon).

**Tech Stack:** Flutter / Dart. Tests via `flutter test`. Lint via `flutter analyze`.

**Design decision (locked):** Subtle telegraph — a class-color tag + class-tinted selected state + explanatory subtitle. We do NOT add new icons/art.

---

### Task 1: Add optional accent fields to `_OptionDef` and `_OptionCard`

**Files:**
- Modify: `lib/pages/onboarding/calibration_quiz_page.dart` (`_OptionDef` ~593-604, `_OptionCard` ~288-364, `_OptionList` ~606-634)

- [ ] **Step 1: Add `accentColor` + `accentLabel` to `_OptionDef`**

Replace the `_OptionDef` class (~line 593-604):

```dart
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
```

with:

```dart
class _OptionDef {
  const _OptionDef({
    required this.title,
    required this.subtext,
    required this.isSelected,
    required this.onTap,
    this.accentColor,
    this.accentLabel,
  });
  final String title;
  final String subtext;
  final bool isSelected;
  final VoidCallback onTap;

  /// When set, this card carries a class identity: the selected border/title
  /// use [accentColor] instead of neon, and an [accentLabel] tag is shown.
  final Color? accentColor;
  final String? accentLabel;
}
```

- [ ] **Step 2: Add the fields to `_OptionCard` and use them**

In `_OptionCard`, add the two fields after `onTap` in the field list and constructor (~289-302):

```dart
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.subtext,
    required this.isSelected,
    required this.hasAnySelection,
    required this.onTap,
    this.accentColor,
    this.accentLabel,
  });

  final String title;
  final String subtext;
  final bool isSelected;
  final bool hasAnySelection;
  final VoidCallback onTap;
  final Color? accentColor;
  final String? accentLabel;
```

Then in `_OptionCard.build`, change the border/title color lines (~307-308) from:

```dart
    final borderColor = isSelected ? kNeon : kBorder;
    final titleColor = isSelected ? kNeon : kText;
```

to (fall back to neon when no accent is supplied — preserves Q2/Q3 behavior):

```dart
    final accent = accentColor ?? kNeon;
    final borderColor = isSelected ? accent : kBorder;
    final titleColor = isSelected ? accent : kText;
```

- [ ] **Step 3: Render the class tag inside the card**

In `_OptionCard.build`, the title currently sits in a `Column` child as a bare `AnimatedDefaultTextStyle`. Replace that title child (~338-347):

```dart
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
```

with a `Row` that keeps the title and adds the optional tag pill on the right:

```dart
                Row(
                  children: [
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: duration,
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 11,
                          color: titleColor,
                          height: 1.2,
                        ),
                        child: Text(title),
                      ),
                    ),
                    if (accentLabel != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: accent),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          accentLabel!,
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 7,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
```

- [ ] **Step 4: Forward the fields through `_OptionList`**

In `_OptionList.build`, the `_OptionCard(...)` constructor call (~620-626) forwards each `_OptionDef`. Add the two new fields:

```dart
              child: _OptionCard(
                title: options[i].title,
                subtext: options[i].subtext,
                isSelected: options[i].isSelected,
                hasAnySelection: hasAnySelection,
                onTap: options[i].onTap,
                accentColor: options[i].accentColor,
                accentLabel: options[i].accentLabel,
              ),
```

- [ ] **Step 5: Verify it compiles with no behavior change yet**

Run: `flutter analyze`
Expected: no new issues. Q2/Q3 still pass `accentColor: null` (the default), so they render exactly as before.

- [ ] **Step 6: Commit**

```bash
git add lib/pages/onboarding/calibration_quiz_page.dart
git commit -m "feat(onboarding): add optional class-accent fields to quiz option cards

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Wire Q1 goal cards to their derived class

**Files:**
- Modify: `lib/pages/onboarding/calibration_quiz_page.dart` (`_GoalQuestion.build` ~448-478)
- Test: `test/calibration_quiz_test.dart`

- [ ] **Step 1: Write the failing test**

In `test/calibration_quiz_test.dart`, add this test inside the `group('CalibrationQuizPage widget', ...)` block (after the existing `'reduced motion renders Q1 prompt and option cards'` test):

```dart
    testWidgets('Q1 goal cards reveal their class and consequence', (
      tester,
    ) async {
      await _openQuiz(tester, reducedMotion: true);

      // Each goal advertises the class it derives.
      expect(find.text('ASSASSIN'), findsOneWidget); // cut
      expect(find.text('BRUISER'), findsOneWidget); // recomp
      expect(find.text('TANK'), findsOneWidget); // bulk
      // And the prompt now tells the user this choice matters.
      expect(find.text('this sets your class.'), findsOneWidget);
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/calibration_quiz_test.dart --plain-name "reveal their class"`
Expected: FAIL — `Found 0 widgets with text "ASSASSIN"`.

- [ ] **Step 3: Add the subtitle + per-card accents in `_GoalQuestion`**

Replace `_GoalQuestion.build` (~448-478) with:

```dart
  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      progressCells: progressCells,
      prompt: "WHAT'S THE GOAL?",
      subtitle: 'this sets your class.',
      onBack: onBack,
      body: _OptionList(
        hasAnySelection: selected != null,
        options: [
          _OptionDef(
            title: 'GET LEANER',
            subtext: 'drop fat. keep strength.',
            isSelected: selected == BodyGoal.cut,
            onTap: () => onSelect(BodyGoal.cut),
            accentColor: deriveClass(BodyGoal.cut).themeColor,
            accentLabel: deriveClass(BodyGoal.cut).displayName,
          ),
          _OptionDef(
            title: 'STAY + STRENGTHEN',
            subtext: 'hold weight. add strength.',
            isSelected: selected == BodyGoal.recomp,
            onTap: () => onSelect(BodyGoal.recomp),
            accentColor: deriveClass(BodyGoal.recomp).themeColor,
            accentLabel: deriveClass(BodyGoal.recomp).displayName,
          ),
          _OptionDef(
            title: 'GET BIGGER',
            subtext: 'add size. accept the gain.',
            isSelected: selected == BodyGoal.bulk,
            onTap: () => onSelect(BodyGoal.bulk),
            accentColor: deriveClass(BodyGoal.bulk).themeColor,
            accentLabel: deriveClass(BodyGoal.bulk).displayName,
          ),
        ],
      ),
    );
  }
```

(No new imports: `deriveClass` comes from `calibration_quiz_models.dart` and `.themeColor`/`.displayName` from `character_class.dart` — both already imported in this file.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/calibration_quiz_test.dart --plain-name "reveal their class"`
Expected: PASS.

- [ ] **Step 5: Run the full quiz file (regression)**

Run: `flutter test test/calibration_quiz_test.dart`
Expected: PASS. The `'STAY + STRENGTHEN'` title now shares its `Row` with a `BRUISER` tag — confirm the existing `find.text('STAY + STRENGTHEN')` assertions still match (they do; `Text` finds by exact string within the Row).

- [ ] **Step 6: Analyze**

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 7: Commit**

```bash
git add lib/pages/onboarding/calibration_quiz_page.dart test/calibration_quiz_test.dart
git commit -m "feat(onboarding): Q1 goal cards reveal the class they pick

Each goal shows its class tag in the class identity color, tints its
selected state to match, and the prompt now reads 'this sets your class.'

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** class tag per goal card ✓; class-tinted selected border/title ✓; "this sets your class." subtitle ✓; Q2/Q3 unchanged (null accents) ✓; no new art ✓.
- **Placeholder scan:** none.
- **Type consistency:** `_OptionDef.accentColor` (`Color?`) and `accentLabel` (`String?`) match `_OptionCard`'s fields and the `_OptionList` forwarding. `deriveClass(BodyGoal)` returns `CharacterClass`; `.themeColor` → `Color`, `.displayName` → `String` — both match the field types.
- **Layout note (manual check):** "STAY + STRENGTHEN" is the longest title; with an 8px gap + ~52px `BRUISER` pill it must not overflow the card at 375px width. The title is in `Expanded` so it ellipsizes rather than overflows, but verify on a 375px screenshot that the title isn't clipped mid-word — if tight, drop the pill `fontSize` to 7 (already 7) or shorten via the existing 2-line allowance. No code change unless the screenshot shows clipping.
