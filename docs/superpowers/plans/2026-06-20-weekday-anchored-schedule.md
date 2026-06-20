# Plan — Unified Weekday-Anchored Schedule (2026-06-20)

> Reconciles Ironbit's two disconnected schedule models into one weekday-anchored, forgiving
> system. Produced by `/deep-feature` (research → audit → opinion → Codex adversarial review).
> Frozen once shipped; do not rewrite history.

## Problem

Two schedule sources of truth that never reconcile:
- **`RestService.trainingWeekdays`** — calendar weekday-bound. Drives shields, planned-recovery XP,
  streak protection, LCK consistency-weeks.
- **`ProgramProgress.currentDayIndex`** — sequence index into a 7-slot `weekSchedule` (workout+rest).
  Advances only on completion; ignores weekdays entirely.

The program stamps "today" into `programTrainingDateKeys`/`programRestDateKeys` regardless of weekday,
which *overrides* the weekday calc — so the Settings → TRAINING GOALS weekday picker feels cosmetic, and
the weekday set can never choose *which* workout you do.

## User-locked decisions

1. **Full forgiveness** — training on a non-anchored weekday still counts + advances; missing an anchored
   day rolls the session forward keeping order (never lost, never snapped-to-calendar).
2. **Interaction** — tap-to-toggle weekdays + a live "which session lands on which day" projection
   preview. **Not** literal session-to-weekday drag/gluing.
3. **Hybrid model** — weekdays anchor *expectation* (shields/recovery/display); the sequence stays the
   truth for *which* workout.

## Architecture (Codex-hardened)

**Positional projection over a workout-only progression index, resolved through one pure resolver.**

### 1. Workout-only progression index
- `ProgramProgress.currentDayIndex` (index into the 7-slot cycle) → **`workoutIndex`** (index into the
  program's **workout-only** sublist `program.workouts`). Rest slots leave the progression entirely.
- `advanceDay` on workout completion: `workoutIndex = (workoutIndex + 1) % workouts.length`. One move,
  no fast-forward, no rest-slot ambiguity. *(Resolves Codex #2 critical, #6.)*
- `weekSchedule` keeps rest entries **only** as Program-Detail catalog display. UI/streak code must never
  read `weekSchedule[currentDayIndex]` for "what's today" — only the resolver.

### 2. Rest is calendar-only
- A non-training weekday IS a planned rest day — `RestService.dayInfoForState` already classifies it that
  way natively via `trainingWeekdays`. So the program **stops stamping `programRestDateKeys`** and retires
  `creditRestDayForToday` / `_rollForwardCreditedRestDay` (calendar `plannedRest` + existing
  `ensureAutomaticRecoveryForToday` already credit recovery). `programTrainingDateKeys` is still stamped
  for *completed* workout dates (so an off-anchor workout counts). *(Resolves #6.)*

### 3. One pure `ScheduleResolver`
`lib/services/schedule_resolver.dart` — pure, no I/O. Single consumer for "what happens on date D".
- **Input:** `date`, `program?`, effective weekdays for that date's week, `workoutIndex`,
  `programTrainingDateKeys`.
- **Output `ResolvedDay`:** `{ isTrainingDay, displayedWorkout?, workoutIndexToComplete?, isRest }`.
- **Precedence (documented + tested):**
  1. Historical week (`weekKey(date) < currentWeekKey`) → frozen `scheduleByWeekKey[weekKey]` snapshot.
  2. Current/future week → committed `trainingWeekdays`; `pendingTrainingWeekdays` applies from
     `pendingStartWeekKey`.
  3. No active program → weekday-only (today's RestService behavior, unchanged).
- **Frozen-history invariant:** past-day classification reads ONLY `scheduleByWeekKey` / per-date stamps,
  never a live projection. Editing weekdays only affects current/future weeks. *(Resolves #1, #3.)*

### 4. Projection (current/future weeks)
On a training weekday, the next-up workout (`workouts[workoutIndex]`) is displayed and is the one
`advanceDay` completes from. Non-training weekday → rest. Because it's positional and recomputed, a missed
anchored day just rolls the same `workoutIndex` to the next training weekday — order preserved.

### 5. "Successful week" = adherence to the chosen anchor
Defined against the **resolved anchored weekdays for that week** (every training weekday had a completed
workout), *not* `program.daysPerWeek`. A 6-day program with 3 picks → success = those 3 anchors done.
Deliberate, documented decoupling: shields reward "did you train when *you* committed." Keep sanitize
(1–6 picks; empty/all-7 → `{1,3,5}`) so ≥1 train + ≥1 rest always. *(Resolves #4.)*

### 6. Migration (versioned, one-time)
`MigrationService` step `weekdayAnchoredScheduleV1`:
- Map legacy `currentDayIndex` (7-slot) → `workoutIndex` = the next workout slot at/after the legacy index
  (count workouts; wrap). Persist as `workoutIndex`; keep `currentDayIndex` field readable for rollback.
- Do **not** apply miss/shield logic on the transition day.
- Existing `trainingWeekdays` stays valid as-is (it IS the anchor).
- Tests: legacy index on workout / on rest / end-of-week wrap / program switch / no active program.
  *(Resolves #5.)*

## Surfaces (hand visuals to `ironbit-design`)

- **Settings → TRAINING GOALS sheet** (`profile_page.dart`): seed weekday picks from the active program's
  `daysPerWeek`; add the **session-projection preview** (`MON · Push · WED · Pull · …`); keep the
  next-Monday commit (shield integrity).
- **Onboarding**: add an optional weekday step after program selection, applied **immediately** (no
  pending — no history to protect yet).

## Files

**New:** `lib/services/schedule_resolver.dart`, `test/schedule_resolver_test.dart`,
`test/weekday_anchored_migration_test.dart`.
**Model:** `lib/models/program_models.dart` (`ProgramProgress.workoutIndex` + migration-safe JSON),
`lib/data/programs_library.dart` (add `Program.workouts` getter).
**Services:** `program_service.dart` (workoutIndex advance, retire rest stamping, resolver use),
`rest_service.dart` (consume resolver; success-week against resolved anchors),
`migration_service.dart` (new step).
**UI:** `home.dart` (stamp from resolver; stop blind rest-stamp), `profile_page.dart` (projection preview
+ seed), onboarding weekday step, `program_detail_page.dart` (display unaffected),
`workout_summary.dart` / `root_page.dart` (advance call-sites).
**Docs:** `docs/program-system.md` (§5 scheduling rewrite), `docs/PRD.md` if scope line needed.

## Verification

`flutter analyze` zero issues; `flutter test` all pass. New fixture tests per archetype:
beginner (3-day), veteran (6-day PPL w/ 3 picks), every-other-day (slow roll), missing-data (no program,
legacy state). Golden/screenshot the reworked TRAINING GOALS sheet. Tokens-only colors, sharp icons.

## Checkpoints (implementation order, engine-first)

1. **Engine:** `Program.workouts`, `ProgramProgress.workoutIndex`, `ScheduleResolver` + tests. ← start
2. **Migration:** versioned step + tests.
3. **Service rewire:** `ProgramService` advance/getTodayDay via resolver; `RestService` success-week; retire
   rest stamping. Update `program_service_test` / `rest_service_test`.
4. **Home/flow rewire:** `home.dart` stamping, advance call-sites.
5. **Surfaces:** Settings projection preview + seed; onboarding step (via `ironbit-design`).
6. **Docs + reflect.**
