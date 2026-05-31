# statistics/ — Agent operating brief

You are working in **statistics**: product analytics, metrics, and observability *planning*.

## Critical context
The app is **pre-launch with zero telemetry** — no analytics, crash reporting, or tracking SDKs
anywhere in the codebase (verified by audit 2026-05-31). It is also positioned as
**offline, no-account, no-tracking** (see [../marketing/positioning.md](../marketing/positioning.md)).
So instrumentation is a **product decision, not just wiring**: any measurement must not break the
privacy promise. Resolve that tension *before* adding SDKs.

## Purpose
Define *what to measure and how to measure it without betraying the privacy promise*, then (once
decided) hold dashboards, reports, and the metrics glossary. No real data exists yet.

## What lives here
- `instrumentation-plan.md` — the observability/analytics plan and the privacy decision. **Read first.**
- `metrics-glossary.md` — definitions of every KPI so numbers mean the same thing everywhere.
- `dashboards/` — dashboard specs/exports (once a tool is chosen).
- `reports/` — periodic performance reports (post-launch).

## How to work here well
1. **Decide privacy posture first.** Options live in `instrumentation-plan.md` (local-only metrics,
   opt-in anonymous aggregate, or none). Don't add a tracking SDK that contradicts the store copy.
2. **Crash reporting ≠ analytics.** Symbolicated crash capture (e.g. local logs or an opt-in
   reporter) can be justified even under a strict privacy posture — treat it separately.
3. **Define the metric before you measure it.** New KPI → add it to `metrics-glossary.md` first.
4. **Tie metrics to the funnel that matters:** onboarding completion → first workout → week-1
   retention → habit (3+ sessions/week). These are the survival metrics for this app.

## Do NOT
- Wire any third-party analytics/crash SDK without the privacy decision being recorded here and
  agreed with the user.
- Invent benchmark numbers — there is no data yet; mark targets as hypotheses.
