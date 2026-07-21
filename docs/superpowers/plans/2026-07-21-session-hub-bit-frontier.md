# Session Hub Frontier BIT Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** BIT rides the session hub — a small faced `BitMoodCore` inside the frontier exercise card, quiet neon warmth on cleared cards, and a static cheer dock above the enabled Finish button at all-clear.

**Architecture:** All changes are private to `ActiveWorkoutPage` (`app/lib/pages/Workout session/active_workout.dart`). One new frontier getter becomes the single source of truth shared with the existing `_nextUndoneExerciseName`. No services, no persistence, no new routes. The shared `BitMoodCore` primitive is consumed as-is (`reveal: 1` mandatory — it defaults to faceless).

**Tech Stack:** Flutter widget layer only; `flutter_test` widget tests + two page goldens.

**Spec:** `docs/superpowers/specs/2026-07-21-session-hub-bit-frontier-design.md` (approved).

**Known hazard (drives Task 3):** `BitMoodCore` runs a perpetual `Ticker`. Once the hub always hosts one, **any `pumpAndSettle` while the hub is the top route hangs** (10-min timeout). The existing `active_workout_*` tests + `audit/screens_c_test.dart` + `exercise_session_durability_test.dart` use `pumpAndSettle` against this page and must be swept to bounded pumps. (Covered-route ticker behavior is uncertain — treat every `pumpAndSettle` in files that mount this page as suspect.)

---

### Task 1: New failing test file (the behavior contract)

**Files:**
- Test: `app/test/active_workout_bit_frontier_test.dart` (create)

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/active_workout.dart';
import 'package:workout_track/services/exercise_kind_cache.dart';
import 'package:workout_track/services/rest_timer_service.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/companion/bit_mood_core.dart';

/// The session hub's frontier BIT: a small faced BitMoodCore rides the first
/// un-cleared exercise card (one source of truth with the rest panel's NEXT),
/// cleared cards keep a quiet neon warmth, and at all-clear BIT docks in cheer
/// above the enabled Finish button. Spec:
/// docs/superpowers/specs/2026-07-21-session-hub-bit-frontier-design.md
const _frontierKey = ValueKey('frontier_bit');
const _dockKey = ValueKey('session_bit_dock');

Exercise _exercise(String id) =>
    Exercise(id: id, name: id, level: 'beginner', images: const []);

ExerciseLog _doneLog(String id) => ExerciseLog(
  exerciseId: id,
  exerciseName: id,
  sets: const [SetEntry(weight: 40, reps: 8)],
);

WorkoutSession _resume(List<String> doneIds) => WorkoutSession(
  id: 'r1',
  date: DateTime.now(),
  startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
  muscleGroup: 'Chest',
  targetDurationMinutes: 30,
  actualDurationSeconds: 180,
  estimatedCalories: 20,
  isPartial: true,
  selectedExerciseIds: const ['a', 'b'],
  exercises: [for (final id in doneIds) _doneLog(id)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RestTimerService.instance.cancel();
    ExerciseKindCache.instance.resetForTest();
  });
  tearDown(() => RestTimerService.instance.cancel());

  // Bounded pumps — the hub now hosts a perpetual-ticker BIT, so
  // pumpAndSettle would never settle while this page is on top.
  Future<void> pumpHub(
    WidgetTester tester, {
    WorkoutSession? resume,
    double textScale = 1.0,
    bool reduceMotion = false,
    Size surface = const Size(1080, 3000),
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: ActiveWorkoutPage(
          muscleGroup: 'Chest',
          durationMinutes: 30,
          exercises: [_exercise('a'), _exercise('b')],
          resumeFromSession: resume,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('fresh session: one neutral frontier BIT on the first card', (
    tester,
  ) async {
    await pumpHub(tester);
    expect(find.byKey(_frontierKey), findsOneWidget);
    expect(find.byKey(_dockKey), findsNothing);
    final bit = tester.widget<BitMoodCore>(find.byKey(_frontierKey));
    expect(bit.reveal, 1); // faceless-default trap — must be faced
    expect(bit.pose, BitPose.neutral);
    expect(bit.size, 44);
    expect(bit.idleAmp, 0.55);
    // Hosted in exercise a's card (the frontier), not b's.
    expect(
      find.ancestor(
        of: find.byKey(_frontierKey),
        matching: find.widgetWithText(Row, 'a'),
      ),
      findsWidgets,
    );
  });

  testWidgets('frontier advances past cleared exercises on resume', (
    tester,
  ) async {
    await pumpHub(tester, resume: _resume(['a']));
    expect(find.byKey(_frontierKey), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(_frontierKey),
        matching: find.widgetWithText(Row, 'b'),
      ),
      findsWidgets,
    );
  });

  testWidgets('cleared card carries the quiet neon warmth', (tester) async {
    await pumpHub(tester, resume: _resume(['a']));
    final warmBorder = Border.all(color: kNeon.withValues(alpha: 0.38));
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border == warmBorder,
      ),
      findsOneWidget, // exactly the one cleared card
    );
  });

  testWidgets('all-clear: no frontier BIT, cheer dock above Finish', (
    tester,
  ) async {
    await pumpHub(tester, resume: _resume(['a', 'b']));
    expect(find.byKey(_frontierKey), findsNothing);
    expect(find.byKey(_dockKey), findsOneWidget);
    final bit = tester.widget<BitMoodCore>(find.byKey(_dockKey));
    expect(bit.reveal, 1);
    expect(bit.pose, BitPose.cheer);
    expect(find.text('Finish Workout'), findsOneWidget);
  });

  testWidgets('large text hides the frontier BIT, card layout intact', (
    tester,
  ) async {
    await pumpHub(
      tester,
      textScale: 1.3,
      surface: const Size(320, 800),
    );
    expect(find.byKey(_frontierKey), findsNothing);
    expect(find.text('a'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text keeps the all-clear dock', (tester) async {
    await pumpHub(tester, resume: _resume(['a', 'b']), textScale: 1.3);
    expect(find.byKey(_dockKey), findsOneWidget);
  });

  testWidgets('reduced motion: BIT still present and still', (tester) async {
    await pumpHub(tester, reduceMotion: true);
    expect(find.byKey(_frontierKey), findsOneWidget);
    // Static under reduced motion — one more pump must not throw or change
    // semantics; the status text remains the assistive carrier.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('READY'), findsNWidgets(2));
  });
}
```

- [ ] **Step 2: Run to verify the suite fails for the right reason**

Run (from `app/`): `flutter test test/active_workout_bit_frontier_test.dart`
Expected: FAIL — `find.byKey(ValueKey('frontier_bit'))` finds nothing (feature absent). The
harness itself (pumps, fixtures) must not error.

- [ ] **Step 3: Commit the red tests**

```bash
git add app/test/active_workout_bit_frontier_test.dart
git commit -m "test: session-hub frontier BIT behavior contract (red)"
```

---

### Task 2: Implement the page changes

**Files:**
- Modify: `app/lib/pages/Workout session/active_workout.dart` (frontier getter ~line 254; card loop ~lines 1093–1156; dock before the Finish button ~line 1158)

- [ ] **Step 1: Add the import**

After the existing widget imports (beside `import '../../widgets/blinking_colon.dart';`):

```dart
import '../../widgets/companion/bit_mood_core.dart';
```

- [ ] **Step 2: Make the frontier the single source of truth**

Replace the existing `_nextUndoneExerciseName` getter:

```dart
  /// The next exercise not yet cleared (list order) — the session's frontier.
  /// One source of truth for the rest panel's NEXT line AND the frontier BIT,
  /// so the two can never disagree. Null when all cleared.
  Exercise? get _frontierExercise {
    for (final e in widget.exercises) {
      if (_status[e.id] != _ExerciseStatus.done) return e;
    }
    return null;
  }

  /// The next exercise's name — shown on the rest panel so the user can eye
  /// the next movement during the break.
  String? get _nextUndoneExerciseName => _frontierExercise?.name;
```

- [ ] **Step 3: Rework the exercise-card loop (frontier BIT + cleared warmth)**

In the non-resting `Column` builder, immediately before `for (final exercise in widget.exercises)`, compute (these live inside the `builder:` closure, which has a `context`):

```dart
                    // Frontier BIT: hidden at large text scales so the card
                    // never trades legibility for charm (spec: >= 1.3).
                    final frontierId = _frontierExercise?.id;
                    final showFrontierBit =
                        MediaQuery.textScalerOf(context).scale(14) < 14 * 1.3;
```

Then change the card's `DecoratedBox` decoration (cleared warmth) and the inner `Row` (leading BIT). The full replacement for the loop body's `DecoratedBox`:

```dart
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                // Cleared work stays visibly banked: a quiet
                                // neon wash + border, well below action-neon.
                                color:
                                    _status[exercise.id] == _ExerciseStatus.done
                                    ? Color.alphaBlend(
                                        kNeon.withValues(alpha: 0.05),
                                        kCard,
                                      )
                                    : kCard,
                                border: Border.all(
                                  color:
                                      _status[exercise.id] ==
                                          _ExerciseStatus.done
                                      ? kNeon.withValues(alpha: 0.38)
                                      : kBorder,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
```

And the `Row`'s children gain a leading block before the `Expanded`:

```dart
                                      child: Row(
                                        children: [
                                          if (exercise.id == frontierId &&
                                              showFrontierBit) ...[
                                            const ExcludeSemantics(
                                              child: BitMoodCore(
                                                key: ValueKey('frontier_bit'),
                                                pose: BitPose.neutral,
                                                reveal: 1,
                                                size: 44,
                                                idleAmp: 0.55,
                                              ),
                                            ),
                                            const SizedBox(width: kSpace2),
                                          ],
                                          Expanded(
```

(Everything inside `Expanded(...)` and the trailing status widget is untouched.)

- [ ] **Step 4: Add the all-clear dock**

Between the existing `const SizedBox(height: 16),` and the `PixelButton(label: 'Finish Workout', ...)`:

```dart
                        if (_allDone) ...[
                          // The goal-gradient peak: BIT witnesses the finish.
                          // Static dock — no travel (Codex F4); the final
                          // card's StrobeFlash is the flash beat.
                          const Center(
                            child: ExcludeSemantics(
                              child: BitMoodCore(
                                key: ValueKey('session_bit_dock'),
                                pose: BitPose.cheer,
                                reveal: 1,
                                size: 56,
                                idleAmp: 0.55,
                              ),
                            ),
                          ),
                          const SizedBox(height: kSpace3),
                        ],
```

- [ ] **Step 5: Run the new tests**

Run: `flutter test test/active_workout_bit_frontier_test.dart`
Expected: ALL PASS. If the warmth-predicate test finds 2 widgets, another DecoratedBox matched — tighten the predicate to also require the wash color.

- [ ] **Step 6: Commit**

```bash
git add "app/lib/pages/Workout session/active_workout.dart"
git commit -m "feat: BIT rides the session hub — frontier companion, cleared warmth, all-clear dock"
```

---

### Task 3: Sweep existing tests off pumpAndSettle (the ticker hazard)

**Files:**
- Modify: `app/test/active_workout_rest_panel_test.dart`, `app/test/active_workout_idle_test.dart`, `app/test/active_workout_end_early_test.dart`, `app/test/audit/screens_c_test.dart`, `app/test/exercise_session_durability_test.dart` (only where the hub is top-of-route)

- [ ] **Step 1: Run each file to find the hangs/failures**

Run: `flutter test test/active_workout_rest_panel_test.dart test/active_workout_idle_test.dart test/active_workout_end_early_test.dart test/audit/screens_c_test.dart test/exercise_session_durability_test.dart --timeout 120s`
Expected: timeouts/failures wherever `pumpAndSettle` runs with the hub on top and a BIT mounted.

- [ ] **Step 2: Replace each offending `pumpAndSettle` with bounded pumps**

The pattern (matches the rest-panel file's existing post-BIT idiom):

```dart
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
```

Rules: a `pumpAndSettle` while a *pushed* route (exercise session, summary, dialog) is on top may stay IF it demonstrably settles (covered-route tickers are muted by the route's TickerMode) — verify by running, don't assume. Any pump against the hub itself becomes bounded.

- [ ] **Step 3: Re-run the five files — all green**

Run: same command. Expected: PASS ×5.

- [ ] **Step 4: Commit**

```bash
git add app/test
git commit -m "test: bounded pumps for the always-live session-hub BIT ticker"
```

---

### Task 4: Pin the no-double-BIT invariant during rest

**Files:**
- Modify: `app/test/active_workout_rest_panel_test.dart` (the takeover test)

- [ ] **Step 1: Extend the takeover test**

In `finishing an exercise (work remaining) takes over the list`, after the existing expectations:

```dart
    // Exactly one BIT on screen during the takeover — the rest panel's.
    // The hub list (and with it the frontier BIT) is structurally unmounted.
    expect(find.byType(BitMoodCore), findsOneWidget);
    expect(find.byKey(const ValueKey('frontier_bit')), findsNothing);
```

Add the import: `import 'package:workout_track/widgets/companion/bit_mood_core.dart';`

- [ ] **Step 2: Run — expect PASS (it pins existing structure)**

Run: `flutter test test/active_workout_rest_panel_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add app/test/active_workout_rest_panel_test.dart
git commit -m "test: pin single-BIT invariant during the rest takeover"
```

---

### Task 5: Page goldens (the rendered artifact)

**Files:**
- Create: `app/test/active_workout_hub_golden_test.dart` + `app/test/goldens/active_workout_hub_mid.png`, `app/test/goldens/active_workout_hub_all_clear.png` (paths per the repo's existing golden convention — copy the harness from the nearest existing golden test, including any font loading)

- [ ] **Step 1: Write the golden test** — two scenarios in one file (this page's async init is light; the HomePage one-per-file rule doesn't apply), each: pump via the Task-1 `pumpHub` idiom (mid = resume `['a']`, all-clear = resume `['a','b']`), then `await expectLater(find.byType(ActiveWorkoutPage), matchesGoldenFile(...))`. Bounded pumps only.

- [ ] **Step 2: Generate + eyeball**

Run: `flutter test test/active_workout_hub_golden_test.dart --update-goldens` then open both PNGs (Read tool) and verify: BIT faced (not the faceless dormant core) on card b / docked in cheer; warmth visible but quiet; no layout shift.

- [ ] **Step 3: Run without --update-goldens — PASS. Commit.**

```bash
git add app/test/active_workout_hub_golden_test.dart app/test/goldens/
git commit -m "test: session-hub goldens (frontier BIT mid-session + all-clear dock)"
```

---

### Task 6: Full verification

- [ ] **Step 1:** `flutter analyze` → 0 issues.
- [ ] **Step 2:** `flutter test` (full suite) → no new failures beyond the 6 known env baselines (finish_reveal, home_level_strip, room ×4).
- [ ] **Step 3:** Finish-time audit greps over the changed lib file — `Color(0x`, `fromARGB`, `fromRGBO`, `.withOpacity(`, `Colors.`, `ColorScheme`, `ElevatedButton`, `MaterialPageRoute`, `Icons.` without `_sharp`, raw `GestureDetector(onTap:`/`InkWell` → 0 new hits (state result).
- [ ] **Step 4:** Commit anything outstanding.

---

### Task 7: Docs, insights, reflect

**Files:**
- Modify: `docs/PRD.md` (shipped entry), `CLAUDE.md` (session-flow row 2 sentence — re-read the section first; the file was recently edited), `research/insights.md` (dated entry: the evidence + `[assumption]` tag + decision), learnings per the reflect gates.

- [ ] **Step 1:** PRD shipped entry (one bullet, dated 2026-07-21).
- [ ] **Step 2:** CLAUDE.md `ActiveWorkoutPage` row: append one sentence describing frontier BIT + cleared warmth + all-clear dock + the large-text/reduced-motion gates.
- [ ] **Step 3:** insights.md entry: companion-witness evidence set (Köhler meta + ghost-null boundary reuse, D/A attention, Clippy contrary, between-sets consensus contrary, goal-gradient), tagged, tied to this decision; the tracker-transfer `[assumption]`.
- [ ] **Step 4:** Reflect gates: ironbit-design learnings (update the companion single-placement category ONLY if implementation surfaced a generalizable defect; else "No new design learning"), deep-feature learnings likewise, research self-score.
- [ ] **Step 5:** Commit docs.

```bash
git add docs/PRD.md CLAUDE.md research/insights.md .claude/skills
git commit -m "docs: session-hub frontier BIT — PRD, architecture row, research insights"
```

---

## Self-review notes

- Spec coverage: frontier BIT (T1/T2), warmth (T1/T2), dock (T1/T2), state machine (T1 fixtures cover fresh/advance/all-done; out-of-order is the same getter — no extra path exists), boundaries (T1 large-text/reduced-motion/rest tests + T4), goldens (T5), docs (T7). Spec test-contract items 1–8 all mapped.
- The `Row` finder (`find.widgetWithText(Row, 'a')`) matches any ancestor Row containing the text; the card Row qualifies — assertion is `findsWidgets` (≥1), not `findsOneWidget`, deliberately.
- Named on-device gap (from the spec) survives to the completion report: idle feel at 44 px + wash brightness need device sign-off.
