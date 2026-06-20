# Workout log discoverability — two visible doors + LCK pip re-point (2026-06-20)

**Status:** shipped (UI + wiring). No mechanics/persistence change. Follow-up to the
[2026-06-13 app-area restructure](2026-06-13-app-area-restructure-ia.md).

## Problem
After the area restructure dropped the "Workout" nav tab, the workout **log** (history + calendar +
analytics, `WorkoutLogsPage` / `_LogsTab` in [workout_page.dart](../../../lib/pages/workout_page.dart))
had **exactly one entry point: an unlabelled tap on Home's LCK pip**
([home.dart](../../../lib/pages/home.dart) — the luck-multiplier metric routed to
`onViewWorkouts`). The only "this opens history" cue was a screen-reader `navHint`; sighted users saw a
**luck** icon + a multiplier number, nothing that read as "history". Tapping *luck* to find your
training log is unguessable — users reported they could not find the calendar/stats at all. The
calendar sat a further level down ("FULL MONTH →" inside the log), so the real path was
**Home → mystery luck tap → scroll → FULL MONTH**.

## Root cause
The restructure *intended* history to live "via the streak/history affordance" on Home, but that
visible affordance was never built — the route got soldered onto the luck pip instead.

## Decision (Both Home + Labs, per the user)
Add **two discoverable, labelled doors** to the same `WorkoutLogsPage`; keep the 5-slot nav
(Home · Items · ⟨TRAIN⟩ · Guild · Labs) untouched.

1. **Home — the last-workout card becomes the gate.** The "last workout" card (`_buildLastWorkoutStat`)
   was a *dead* card once a session existed. Now, when there is a completed workout, it is a button:
   a trailing **"VIEW LOG →"** cyan cue + a `Semantics(button)` label "…Opens your training log.",
   tapping → `onViewWorkouts`. The empty-state (no workouts → Start Workout) is unchanged. Least
   clutter, most native — it reuses an existing card on the ritual-return hub.
2. **Labs — a "Training Log" row.** A `_SettingsRow` (icon `icon_timeline.png`, "History, calendar,
   and stats.") under the **SETTINGS** tab's TRAINING section, beside the existing "Training Library"
   row → `WorkoutLogsPage`. Groups "what I did" next to "what to do".
3. **LCK pip re-pointed.** The luck pip now opens the **stat board** (`onViewProfile`, same as VIT —
   luck is a combat stat shown there), hint updated to "Opens your stat board". It is no longer a
   hidden gate to the log.

## Files
- [home.dart](../../../lib/pages/home.dart) — `_buildLastWorkoutStat` gate (trailing cue + semantics +
  tap); LCK pip wiring `onViewWorkouts → onViewProfile` and its `navHint`.
- [profile_page.dart](../../../lib/pages/profile_page.dart) — `_openLogs()` + the "Training Log"
  `_SettingsRow`.
- [test/workout_history_access_test.dart](../../../test/workout_history_access_test.dart) — pins the
  Labs door; [test/home_status_hud_test.dart](../../../test/home_status_hud_test.dart) comment updated.

## Verification
- `flutter analyze` clean; Labs door widget test green; HUD test (LCK re-point) green; full suite green
  except the two pre-existing user-WIP goldens.
- **On-device sign-off required** for the Home card's look + tap route: the full HomePage can't be
  widget-tested with a seeded last workout (its repeat-last-mission panel spins an ambient ticker that
  hangs the test binding), and this env can't screenshot Flutter.

## Out of scope / follow-ups
- The root [CLAUDE.md](../../../CLAUDE.md) "Navigation structure" still describes the old 5-tab
  `Home·Workout·Quests·Guild·Profile` shell — stale since the 2026-06-13 restructure (a separate
  reconcile, not this change).
- HomePage isn't widget-testable with a seeded completed session (ambient-ticker hang) — worth a
  testability pass.
