# Calibrate Step — CONTINUE-Always + Retitle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the dead-button trap on the calibrate step (Q4 of the onboarding quiz): make CONTINUE always work — it submits whatever's entered, including nothing — and retitle the screen from the jargon "CALIBRATE" to something a first-timer understands.

**Architecture:** The live "CALIBRATE 5/5" screen is `_CalibrationQuestion` (a private `StatefulWidget`) inside `lib/pages/onboarding/calibration_quiz_page.dart` — NOT `calibration_data_page.dart`, which is orphaned (never referenced; leave it alone). Today CONTINUE is disabled until a valid weight is typed (`onPressed: _validBodyWeight == null ? null : _submit`) and the only empty-handed exit is a low-contrast "skip — calibrate later" `TextButton`. We make CONTINUE always-enabled (it already routes `_validBodyWeight`, which is `null` when empty), delete the redundant skip link and its now-unused `_skip` method, retitle to `DIAL IT IN`, and reword the subtitle to signal weight is optional.

**Tech Stack:** Flutter / Dart. Tests via `flutter test`. Lint via `flutter analyze`.

**Out of scope / deliberate non-changes:**
- The "SEX" default stays `Prefer not to say`. The audit flagged it, but PRODUCT.md mandates body-neutral defaults — forcing a sex choice contradicts that. Leave it.
- `calibration_data_page.dart` is orphaned dead code — do not edit; flag for separate triage.

---

### Task 1: Retitle "CALIBRATE" → "DIAL IT IN" and reword subtitle

**Files:**
- Modify: `lib/pages/onboarding/calibration_quiz_page.dart` (`_CalibrationQuestionState.build`, ~line 692-695)
- Test: `test/calibration_quiz_test.dart` (existing happy-path test, ~line 127)

- [ ] **Step 1: Update the failing test assertion**

In `test/calibration_quiz_test.dart`, in the test `'Full happy path returns a populated CalibrationResult'`, change the Q4 title assertion:

```dart
// BEFORE:
      expect(find.text('CALIBRATE'), findsOneWidget);
// AFTER:
      expect(find.text('DIAL IT IN'), findsOneWidget);
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/calibration_quiz_test.dart --plain-name "Full happy path"`
Expected: FAIL — `Found 0 widgets with text "DIAL IT IN"` (screen still says CALIBRATE).

- [ ] **Step 3: Update the prompt + subtitle in `_CalibrationQuestionState.build`**

Find this block (~line 692):

```dart
    return _QuestionScaffold(
      progressCells: widget.progressCells,
      prompt: 'CALIBRATE',
      subtitle: 'your weight tunes the numbers. skip if you like.',
      onBack: widget.onBack,
```

Replace the `prompt` and `subtitle` lines with:

```dart
    return _QuestionScaffold(
      progressCells: widget.progressCells,
      prompt: 'DIAL IT IN',
      subtitle: 'optional — your weight fine-tunes the numbers.',
      onBack: widget.onBack,
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/calibration_quiz_test.dart --plain-name "Full happy path"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/onboarding/calibration_quiz_page.dart test/calibration_quiz_test.dart
git commit -m "feat(onboarding): retitle calibrate step to DIAL IT IN

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Make CONTINUE always-enabled and remove the redundant skip link

**Files:**
- Modify: `lib/pages/onboarding/calibration_quiz_page.dart` (`_CalibrationQuestionState`, `_skip` method ~686-688 and the `body` ListView tail ~733-747)
- Test: `test/calibration_quiz_test.dart` (rewrite the skip test, ~line 145-174)

- [ ] **Step 1: Rewrite the failing test**

In `test/calibration_quiz_test.dart`, replace the entire test `'Q4 CONTINUE disabled with empty bodyweight; skip still works'` (the whole `testWidgets(...)` block, ~line 145-174) with:

```dart
    testWidgets(
      'Q4 CONTINUE with empty bodyweight continues with null weight',
      (tester) async {
        final obs = await _openQuiz(tester, reducedMotion: true);

        await tester.tap(find.text('GET LEANER'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2–3 DAYS'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('NOVICE'));
        await tester.pumpAndSettle();

        // CONTINUE is always enabled now. Empty field => continue with null
        // bodyweight and the default sex. pump(Duration) instead of
        // pumpAndSettle because the TextField cursor blink never settles.
        await tester.tap(find.text('CONTINUE'));
        await tester.pump(const Duration(milliseconds: 400));

        expect(obs.resolved, isTrue);
        expect(obs.popped!.bodyWeightKg, isNull);
        expect(obs.popped!.sex, UserProfileSex.preferNotToSay);
        expect(obs.popped!.goal, BodyGoal.cut);
        expect(obs.popped!.clazz, CharacterClass.assassin);
      },
    );
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/calibration_quiz_test.dart --plain-name "continues with null weight"`
Expected: FAIL — `obs.resolved` is `false` (current CONTINUE is disabled on empty, so the tap is a no-op and nothing pops).

- [ ] **Step 3: Remove the unused `_skip` method**

In `_CalibrationQuestionState`, delete this method (~line 686-688):

```dart
  void _skip() {
    widget.onContinue(bodyWeightKg: null, sex: _sex);
  }
```

- [ ] **Step 4: Enable CONTINUE always and delete the skip TextButton**

Find the tail of the `body` ListView (~line 733-747):

```dart
          PixelButton(
            label: 'CONTINUE',
            powerOn: true,
            onPressed: _validBodyWeight == null ? null : _submit,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _skip,
              child: Text(
                'skip — calibrate later',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
```

Replace it with (CONTINUE always enabled; skip link gone; `_submit` already passes `_validBodyWeight`, which is `null` when the field is empty/invalid):

```dart
          PixelButton(
            label: 'CONTINUE',
            powerOn: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
```

- [ ] **Step 5: Run the rewritten test to verify it passes**

Run: `flutter test test/calibration_quiz_test.dart --plain-name "continues with null weight"`
Expected: PASS.

- [ ] **Step 6: Run the full quiz test file to catch regressions**

Run: `flutter test test/calibration_quiz_test.dart`
Expected: PASS (all tests in the file). The `Full happy path` test (which types `78` then taps CONTINUE) still works because a valid weight still submits.

- [ ] **Step 7: Analyze for unused-symbol/lint regressions**

Run: `flutter analyze`
Expected: no NEW issues (baseline is the known ~7-8 pre-existing info lints). Specifically confirm there is no `unused_element` warning for `_skip` (it was deleted) and no unused import. `kMutedText` / `AppFonts` are still used elsewhere in the file, so their imports stay.

- [ ] **Step 8: Commit**

```bash
git add lib/pages/onboarding/calibration_quiz_page.dart test/calibration_quiz_test.dart
git commit -m "fix(onboarding): make calibrate CONTINUE always-enabled, drop dead skip link

CONTINUE now submits whatever is entered (null weight when empty),
removing the disabled-primary + muted-text-escape anti-pattern.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** CONTINUE-always (Task 2) ✓; retitle (Task 1) ✓; sex default deliberately unchanged (documented) ✓; orphan `calibration_data_page.dart` flagged, not edited ✓.
- **Placeholder scan:** none — every step has exact code/commands.
- **Type consistency:** `_submit` (unchanged) sends `bodyWeightKg: _validBodyWeight` (nullable) — matches `onContinue({double? bodyWeightKg, required UserProfileSex sex})`. `_skip` is fully removed (no dangling reference). Title string `'DIAL IT IN'` matches between implementation (Task 1 Step 3) and test (Task 1 Step 1).
- **Cross-file test impact:** Only `calibration_quiz_test.dart` references the Q4 title and the skip link. `class_reveal_screen_test.dart` / `name_screen_test.dart` reach Q4 only via a valid-weight path or don't reach it — unaffected. Re-run full suite (`flutter test`) at the end of execution.
