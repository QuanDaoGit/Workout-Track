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

## Retention
- **D1 / D7 / D30 return** — opened the app on day 1/7/30 after install.
- **W1 retention** — performed an active day in the first 7 days.

## Reliability (if crash reporting is adopted)
- **Crash-free sessions %** — sessions with no fatal crash.
- **Crash-free users %** — users with no fatal crash in the period.

## Notes
- Bodyweight, exercise content, and stat values are **never** metric inputs that leave the device
  (privacy guardrail — see `instrumentation-plan.md`).
