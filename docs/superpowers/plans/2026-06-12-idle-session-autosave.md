# Idle session auto-save (30-min inactivity) — implementation plan

Status: implemented 2026-06-12 (deep-feature Stage 5). Codex-hardened from the opinion + plan
reviews. `flutter analyze` clean; `flutter test` 654/654. Code uncommitted pending user.

## Context

A live workout session today persists to storage **only** when the user explicitly leaves
(`_savePartialAndQuit` / `_pauseAndQuit`). A force-kill mid-session loses everything, and a
backgrounded session's elapsed clock inflates (time/calorie XP scale with duration). Users who
finish training but forget to tap **Finish** leave a session running indefinitely.

This feature: if a session goes **30 minutes with no new logged set**, save-and-exit it; the next
time the app is opened (or while it sits open), a calm reveal tells the user and lets them
**Save & Finish**, **Resume**, or **Discard**. Locked product decisions (user, 2026-06-12):
reveal-with-choice (not silent); a saved idle session counts like a normal Finish; both a
foreground timer and detect-on-reopen.

## Core mechanic

- New `WorkoutSession.lastActivityAt` (nullable for back-compat). Set to session start on creation,
  to `now` on each set log and on resume. **Legacy/null is never auto-timed-out** (Codex #1). Used
  **only** for the idle threshold — not for duration credit (plan-review #3).
- The checkpoint also writes `actualDurationSeconds` = **elapsed captured at the set-log moment**, so
  the credited duration is read straight off storage (clamped ≥0) with no timestamp subtraction —
  robust across repeated resumes (plan-review #3).
- The live session is **checkpointed to storage incrementally** — at start and on each set log —
  via a *silent* write (no global change-signal; the 1-s dock poll reflects it). This both enables
  idle detection on reopen and fixes the force-kill data-loss bug (Codex #3).
- Idle = `now - lastActivityAt >= 30 min`. Threshold `WorkoutStorageService.idleTimeout`.
- Commit removes the ongoing checkpoint row by id (idle SAVE passes it as `resumeFromSession`); the
  normal finish path gets the same cleanup since checkpoints now always leave an ongoing row
  (plan-review #2).

## Ownership split (avoids double-fire, Codex #4/#7 + plan-review #1/#4)

- **`ActiveWorkoutPage` owns the case where the page still exists**: a foreground `Timer` (reset on
  each set log, **cancelled in `dispose`**) and a `didChangeAppLifecycleState.resumed` elapsed check.
- **`RootPage` owns the cold case** (app was killed, page gone): `_showIdleRevealIfNeeded()` in the
  same postFrame + resumed hooks as the existing expired-paused reveal. **Gates on
  `ModalRoute.of(context)?.isCurrent`** (route-derived, not a mutable static) so it reveals only when
  the shell is the top route — when an `ActiveWorkoutPage` is pushed on top, the shell route is not
  current and RootPage stands down.
- A process-wide `IdleSessionGuard` (singleton holding `String? handlingSessionId`) makes reveal +
  commit **idempotent by session id** across both owners and across the foreground-Timer vs
  resumed-check double path: a handler claims the id before pushing the reveal and clears it only
  after the user acts. No static `isActive` flag.

## The reveal (no pre-commit; single award point, Codex #2/#7)

Detection **does not mutate XP/state**. It shows a themed dialog (arcade dialog conventions):
- **SAVE & FINISH** → routes into the existing `WorkoutSummaryPage` carrying the real logs and a
  credited `elapsedSeconds = lastActivityAt - startedAt` (caps runaway inflation, Codex #6) plus an
  `autoSavedAfterIdle` note. The summary's own **Save & Exit** is the single commit → normal
  `saveSession(isPartial:false)` → XP, mission, quests, streak (Decision B).
- **RESUME / KEEP TRAINING** → re-open / stay in the active session, idle clock reset.
- **DISCARD** → existing abandon path (`replaceOngoingWithAbandoned`), no credit.
- **Zero logged sets + timed out** → silently discarded on reopen (no reveal, nothing to save).

## Files

- `lib/models/workout_models.dart` — add `lastActivityAt` (ctor/field/`copyWith`/`toJson`/`fromJson`).
- `lib/services/workout_storage_service.dart` — `_writeSessions({notify})`; silent
  `checkpointOngoingSession`; `getIdleTimedOutSession({now, idleTimeout})`; `static const idleTimeout`;
  reuse `replaceOngoingWithAbandoned` for discard.
- `lib/pages/Workout session/active_workout.dart` — `_lastActivityAt`, checkpoint at start + each
  set log, foreground idle `Timer` + resumed elapsed check, static `isActive`, `_onIdleTimeout`
  reveal, credited duration on finish.
- `lib/pages/root_page.dart` — `_showIdleRevealIfNeeded()` (guarded), reveal dialog wired to
  Save→summary / Resume→`_resumeOngoingSession` / Discard→abandon; silent zero-set discard.
- `lib/pages/Workout session/workout_summary.dart` — optional `autoSavedAfterIdle` flag + one-line
  cutoff note; honor passed credited `elapsedSeconds`.
- `lib/widgets/idle_session_dialog.dart` — shared reveal returning a choice enum (configurable
  labels for the active-page vs reopen contexts).

## Reuse (don't reinvent)

- Reveal hooks: existing `_showExpiredPausedSummaryIfNeeded` pattern in `root_page.dart` (postFrame +
  resumed). Dialog styling: `ArcadeDialogButtonColumn`, `kCard`/`kBorder` tokens, sharp icons.
- Commit: existing `WorkoutSummaryPage` → `saveSession`. Discard: existing
  `replaceOngoingWithAbandoned`. Resume: existing `RootPage._resumeOngoingSession`.

## Tests (archetypes per CLAUDE.md)

- Model: `lastActivityAt` round-trips; legacy JSON without it → null; `copyWith` preserves it.
- Storage: `getIdleTimedOutSession` present/just-under-threshold/null-lastActivityAt(legacy, never
  trips)/zero-set; `checkpointOngoingSession` does not emit a change signal; finalize is idempotent
  (re-running after commit is a no-op).
- Credited duration = last-activity − start (beginner few-set, veteran many-set, calisthenics
  0-weight sets, missing-data legacy-null fixtures).
- `ActiveWorkoutPage` idle `Timer` fires at 30 min via `fakeAsync` and resets on a set log.

## Verification

1. `flutter analyze` — zero issues.
2. `flutter test` — full suite green incl. new cases.
3. After commit: `/codex:review --wait` (diff-grounded; the pre-commit gate is weak on this machine
   per `.claude/codex-local.md`).
4. Update docs: CLAUDE.md workout-session-flow note + PRD line.
5. On-device (user): log a set, wait 30 min idle → reveal offers Save/Resume/Discard; Save credits
   only up to the last set; killing the app mid-session and relaunching no longer loses logged sets.
