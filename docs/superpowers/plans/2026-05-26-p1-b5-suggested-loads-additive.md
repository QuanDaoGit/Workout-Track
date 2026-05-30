# P1 / B5 — Suggested Loads Additive (1RM Safety Cap + Trends Chart) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the two genuinely-new, soul-rule-aligned pieces of B5 on top of the **already-shipped** progression engine: a 0.9×1RM safety cap on suggestions, and a per-exercise progression chart with a plateau cue in the Trends surface.

**Architecture:** `ProgressiveOverloadService` (`lib/services/progressive_overload_service.dart`) already implements `suggestNext` (plate-true ±2.5 kg / repeat / deload / detrained branches), `epley1RM`, rep-targets-by-kind, PR detection, and deltas. The "Suggested loads" toggle (`ProgressionSettingsService`) already exists and **defaults ON** (per PRODUCT.md). Per the reconciled spec we therefore **reject** the prompt's ×0.95 math (produces non-loadable weights) and its default-OFF + opt-in-prompt flow (contradicts PRODUCT.md). We add only: (1) the 0.9×1RM cap inside `suggestNext`, (2) a per-exercise Trends chart. The suggestion never auto-fills the field (already true — user taps the TRY pill).

**Tech Stack:** Flutter / Dart. Charts: the repo already uses `fl_chart` (it's imported in `workout_page.dart`). Tests via `flutter test`. Lint baseline ~8 pre-existing; add zero new.

---

### Task 1: 0.9×1RM safety cap in `suggestNext`

**Files:**
- Modify: `lib/services/progressive_overload_service.dart` (`suggestNext`, the weight-increase branch ~117–123; add a final clamp)
- Test: `test/progressive_overload_service_test.dart` (existing if present; else new)

- [ ] **Step 1: Confirm the engine + 1RM helper**

Read `lib/services/progressive_overload_service.dart`. Confirm `suggestNext` returns `OverloadSuggestion(weight, reps, reason)`, `getPersonalBest(exerciseId)` returns the all-time best Epley 1RM, and `epley1RM(weight, reps, isBodyweight)` exists. Confirm `OverloadReason` enum values (`weightIncrease`, `repTarget`, `deload`, `detrained`).

- [ ] **Step 2: Write the failing test**

In `test/progressive_overload_service_test.dart` (create if absent; mirror existing service-test setup — `SharedPreferences.setMockInitialValues({})` + seeding sessions via `WorkoutStorageService` or the `.fromSessions` constructor):

```dart
test('weight-increase suggestion is capped at 0.9x estimated 1RM', () async {
  // History where the next +2.5kg step would exceed 0.9 x best 1RM.
  // Seed a top set that hits target reps at a weight near the 1RM ceiling,
  // then assert the returned suggestion.weight <= getPersonalBest * 0.9 + epsilon.
  final svc = ProgressiveOverloadService.fromSessions(seededSessions);
  final s = await svc.suggestNext(exercise);
  final cap = svc.getPersonalBest(exercise.id) * 0.9;
  expect(s!.weight, lessThanOrEqualTo(cap + 0.001));
});
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/progressive_overload_service_test.dart --plain-name "capped at 0.9"`
Expected: FAIL — the uncapped `+2.5` exceeds `0.9 × 1RM`.

- [ ] **Step 4: Add the cap**

In `suggestNext`, after computing the candidate weight in the **weighted weight-increase** branch (and any branch that returns an *increased* weight), clamp it. Implement once before the weight-increase `return`:

```dart
    if (topSet.reps >= targetReps) {
      final best = getPersonalBest(exercise.id); // all-time Epley 1RM
      final raw = topSet.weight + _weightIncrement;
      // Never suggest above 90% of estimated 1RM (safety rail). best==0 → no cap.
      final capped = best > 0 ? raw.clamp(0.0, best * 0.9).toDouble() : raw;
      return OverloadSuggestion(
        weight: capped,
        reps: targetReps,
        reason: OverloadReason.weightIncrease,
      );
    }
```

(Deload/repeat/detrained branches never increase weight, so they don't need the cap. Bodyweight branch is rep-based — unaffected.)

- [ ] **Step 5: Run the test to verify it passes; full file regression**

Run: `flutter test test/progressive_overload_service_test.dart`
Expected: PASS (cap test + all existing branch tests still green — the cap is inert when `raw ≤ 0.9×1RM`, which is the normal case).

- [ ] **Step 6: Analyze + commit**

Run: `flutter analyze` (zero new).
```bash
git add lib/services/progressive_overload_service.dart test/progressive_overload_service_test.dart
git commit -m "feat(overload): cap suggested load at 0.9x estimated 1RM

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Per-exercise progression chart in Trends

**Files:**
- Locate first: the Trends surface in `lib/pages/workout_page.dart` (the renamed STATS/`_StatsTab`, possibly under a LOGS▸TRENDS toggle depending on branch state)
- Create: `lib/widgets/exercise_progression_chart.dart`
- Modify: `lib/pages/workout_page.dart` (add per-exercise chart entry into the Trends view)
- Test: `test/exercise_progression_chart_test.dart` (new)

- [ ] **Step 1: Locate the Trends surface + confirm fl_chart usage**

Read `lib/pages/workout_page.dart`. Find the Trends view (`_StatsTab` / the TRENDS branch) and how it already renders charts (it imports `package:fl_chart/fl_chart.dart`). Identify where a per-exercise progression section should slot in and how exercises with history are enumerated (reuse `ProgressiveOverloadService` / `WorkoutStorageService().getSessions()`).

- [ ] **Step 2: Write the failing widget test**

Create `test/exercise_progression_chart_test.dart`:

```dart
testWidgets('renders empty-state under threshold', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: ExerciseProgressionChart(points: const [], plateauFromIndex: null),
  )));
  expect(find.text('Log 5 sets of any exercise to see trends.'), findsOneWidget);
});

testWidgets('renders a line chart when points exist', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: ExerciseProgressionChart(
      points: const [ProgressionPoint(loadKg: 40, isPr: false),
                      ProgressionPoint(loadKg: 42.5, isPr: true)],
      plateauFromIndex: null,
    ),
  )));
  expect(find.byType(LineChart), findsOneWidget);
});
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/exercise_progression_chart_test.dart`
Expected: FAIL — `ExerciseProgressionChart` undefined.

- [ ] **Step 4: Build the chart widget**

Create `lib/widgets/exercise_progression_chart.dart`. A pure, presentational widget (data computed by the caller — keeps it testable and the service untouched):

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';

class ProgressionPoint {
  const ProgressionPoint({required this.loadKg, required this.isPr});
  final double loadKg;
  final bool isPr;
}

/// Top-set load over time for one exercise. PR points are highlighted; a flat
/// run of [plateauFromIndex]..end is drawn in amber as a plateau cue. Shows an
/// empty-state below the data threshold.
class ExerciseProgressionChart extends StatelessWidget {
  const ExerciseProgressionChart({
    super.key,
    required this.points,
    required this.plateauFromIndex,
  });

  final List<ProgressionPoint> points;
  final int? plateauFromIndex; // null = no plateau

  static const int minPointsToShow = 5;

  @override
  Widget build(BuildContext context) {
    if (points.length < minPointsToShow) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Log 5 sets of any exercise to see trends.',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].loadKg),
    ];
    final inPlateau = plateauFromIndex != null;
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: inPlateau ? kAmber : kNeon,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, _, index) => FlDotCirclePainter(
                  radius: points[index].isPr ? 4 : 2,
                  color: points[index].isPr ? kAmber : kNeon,
                  strokeWidth: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Wire it into the Trends view**

In `workout_page.dart` Trends view, for each exercise with history, compute `List<ProgressionPoint>` from `WorkoutStorageService().getSessions()` (top-set load per session via the existing top-set logic; mark `isPr` using `ProgressiveOverloadService.checkPR`/`getPersonalBest`) and a `plateauFromIndex` = start of a flat run of ≥3 sessions (no load increase). Render `ExerciseProgressionChart` under an exercise selector or list. Keep the existing aggregate Trends content; this is an added per-exercise section.

- [ ] **Step 6: Run tests + analyze**

Run: `flutter test test/exercise_progression_chart_test.dart` (PASS).
Run: `flutter test` (full suite — no regressions).
Run: `flutter analyze` (zero new).

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/exercise_progression_chart.dart lib/pages/workout_page.dart test/exercise_progression_chart_test.dart
git commit -m "feat(trends): per-exercise progression chart with PR + plateau cue

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Out of scope (rejected per reconciled spec)
- The prompt's ×0.95 deload/return math (non-loadable weights) — keep plate-true ±2.5.
- Default-OFF toggle + opt-in prompt (contradicts PRODUCT.md "default on") — keep default-ON, no prompt.
- Soreness rail (no soreness logging exists).
- Confidence dot / 5-set surfacing gate — **optional polish, deferred**; the engine already gates on history existing. (If desired later: add a `total_sets_logged`-style gate, small follow-up.)

## Self-Review
- **Spec coverage:** 0.9×1RM cap ✓; Trends per-exercise chart + plateau cue + empty-state ✓; ×0.95 / opt-in / soreness correctly excluded ✓.
- **Placeholder scan:** Step 1 and Step 5 are "locate + compute from existing services" because the exact Trends widget location depends on branch state (LOGS/LIBRARY restructure may or may not be present) — these are real locate-then-edit steps, and the chart widget itself (Step 4) is complete code.
- **Type consistency:** `ExerciseProgressionChart({points: List<ProgressionPoint>, plateauFromIndex: int?})` and `ProgressionPoint({loadKg: double, isPr: bool})` match between the widget (Step 4) and the tests (Step 2). `getPersonalBest`/`epley1RM`/`checkPR` names match `progressive_overload_service.dart`.
- **fl_chart API note:** `getDotPainter` signature is version-sensitive; Step 5/6 must compile against the repo's pinned `fl_chart` — adjust the callback arity to match if analyze flags it.
