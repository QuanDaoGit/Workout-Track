# Metrics Glossary — Ironbit

> Seed document. Define a KPI here *before* anyone reports on it, so a number means one thing.
> All targets below are **hypotheses** — there is no live data yet.

## Acquisition
- **Install** — a Play Store install (source of truth: Play Console, not in-app).

## Activation (the make-or-break funnel)
- **Onboarding complete** — user reaches the start gate / `OnboardingService.isComplete() == true`.
- **First workout saved** — first `WorkoutSession` persisted via `WorkoutStorageService`.
- **Activation** — onboarding complete **and** first workout saved within 24h of install.

## Engagement
- **Active day** — a day with at least one saved workout *or* a recovery/rest action.
- **Sessions/week** — count of saved `WorkoutSession`s in an ISO week.
- **Habit** — 3+ sessions/week for 2+ consecutive weeks (the streak/LCK sweet spot).
- **Character attachment** — returning to Profile/Inventory after onboarding, equipping title/frame,
  or revisiting the character sheet outside a workout flow.
- **Ritual return** — opening Home and completing the day's mission loop after at least one prior
  saved workout.
- **Collection engagement** — viewing newly unlocked loot or changing equipped cosmetics.

## Retention
- **D1 / D7 / D30 return** — opened the app on day 1/7/30 after install.
- **W1 retention** — performed an active day in the first 7 days.

## Reliability (Sentry, opt-in — adopted 2026-06-27, ADR 0001)
- **Crash-free sessions %** — sessions with no fatal crash.
- **Crash-free users %** — users with no fatal crash in the period.

## Event taxonomy (Firebase) — define-before-measure
Snake_case names (Firebase convention; OTel-ish, stable). Each maps to a KPI above. **Params are
anonymous counters/enums only** — never bodyweight, name, or exercise content.

| Event | When | Params (allowed) | Feeds KPI |
|---|---|---|---|
| `app_open` | app foregrounded (Firebase auto-logs) | — | D1/D7/D30, ritual return |
| `onboarding_step` | each onboarding screen advanced | `step` (enum: cold_open…start_gate) | step drop-off |
| `onboarding_complete` | start gate reached | — | Onboarding complete, Activation |
| `workout_started` | loadout confirmed (session begins) | `muscle_groups`, `exercise_count`, `source` (mission/free) | pre-workout funnel start |
| `first_workout_saved` | first-ever session persisted | — | Activation (with onboarding ≤24h) |
| `workout_saved` | any session persisted | `exercise_count`, `set_count`, `duration_seconds`† | Sessions/week, Habit |
| `workout_save_failed` | persistence throws | `reason` (enum) | Friction / reliability |
| `workout_discarded` | user discards (idle-dialog DISCARD / zero-set drop) | `reason` (enum) | terminal state |
| `incomplete_workout_found` | ongoing session detected on launch (force-kill recovery) | — | reliability / recovery |
| `workout_recovered` | a found session resumed & saved | — | recovery |
| `rest_action` | rest/recovery action taken | `kind` (enum) | Active day |
| `character_view` | Profile/Inventory opened outside a flow | `surface` (enum) | Character attachment |
| `cosmetic_equipped` | title/frame equipped | `kind` (title/frame) | Collection engagement |
| `loot_unlock_viewed` | unlock reveal seen | — | Collection engagement |
| `consent_changed` | analytics opt-out / crash opt-in toggled | `scope` (enum), `value` (bool) | consent telemetry |

> User properties: `class` (assassin/bruiser/tank), `reduced_motion` (bool). No identifiers, no
> bodyweight, no name.

**Implemented (pass 1, 2026-06-27):** `onboarding_complete`, `workout_saved` (+params), and
`first_workout_saved` (lifetime-once, dedupe-on-resave) are wired at their service chokepoints;
`app_open`/`screen_view`/`session_start` are auto-collected by Firebase. Remaining events
(`workout_started`, the save-failed/discard/recovery lifecycle, and the engagement events) are
pending follow-up passes.

† `duration_seconds` is the app's own `actualDurationSeconds` (time credited up to the
last logged set) — **NOT** Firebase `engagement_time_msec`, which is foreground-only and mis-counts a
workout (users background the app between sets; Android can even over-count). Engagement time is not a
valid workout-duration proxy.

## Retention definitions & measurement contract (2026-06-27 — ADR 0001 + research)
Ironbit is **non-daily** (target ~3–4×/week), so **weekly metrics are PRIMARY**; classic N-day is a
secondary guardrail (it reads low for a non-daily app — don't optimize it).

**Cohorts (anchor + timezone):** cohort users by BOTH `first_open` (acquisition) and
`first_workout_saved` (activation); all day/week bucketing in **user-local time**.

**Primary (weekly):**
- **Active week** — a user-local calendar week with ≥1 `workout_saved`.
- **W1 / W4 retention** — active in the 1st / 4th week after the cohort week.
- **Habit established (confirmed)** — 3+ sessions/week for 2+ consecutive weeks (the app's KPI).

**Leading indicator (an activation *hypothesis* to VALIDATE, not assume):**
- **Week-1 establishment** — **≥3 `workout_saved` within the first 7 days** (Duolingo-streak analog).
  Confirm the real threshold post-launch by **backward cohort analysis** (users retained at W4 → the
  early action they shared). `first_workout_saved` is correlation, **not** proven cause (survivorship
  bias) — never claim it as a retention lever without an experiment.

**Secondary guardrails (keep for comparability):** exact **D1 / D7 / D30** (return on that user-local day).

**Consent-aware denominators (opt-out skew):**
- Report retention over the **analytics-enabled population** (opt-outs are invisible) — state this so a
  change in opt-out rate isn't misread as a retention move. Segment by **platform / app_version /
  channel** so skew is visible.
- **Sentry crash cohorts are incomplete** (opt-in subset only) — crash-free % is not population-wide.
- A reinstall / data-clear resets the Firebase app-instance id → reads as a new user (document it).

**Abandonment is a DERIVED state, not raw absence:** `workout_started` with no terminal event
(`workout_saved` / `workout_discarded` / `workout_save_failed`) within ~24h **and** not
`workout_recovered`. Raw "started but no saved" also captures app-kill / crash / offline-batching —
segment by `app_version` + reliability before calling it UX abandonment.

## Consent & PII rules
- **Analytics:** on by default, **opt-out** in Settings (`analytics_opt_out_v1`); when opted out,
  call `setAnalyticsCollectionEnabled(false)` and log nothing.
- **Crash (Sentry):** **opt-in**, off by default (`crash_reporting_opt_in_v1`); the SDK is only
  initialized after consent.
- **Never off-device:** bodyweight/sex, character name, free text, exercise *content*, stat values.

## Notes
- Bodyweight, exercise content, and stat values are **never** event params that leave the device
  (trust anchor — see `instrumentation-plan.md` / ADR 0001). "No tracking" is retired, but data
  minimization is not.
