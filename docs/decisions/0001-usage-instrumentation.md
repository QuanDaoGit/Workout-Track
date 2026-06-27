# ADR 0001 — Usage instrumentation: Firebase Analytics + opt-in Sentry

- **Status:** Accepted — 2026-06-27
- **Deciders:** Project owner, Claude
- **Supersedes:** the "no tracking" posture asserted in `marketing/positioning.md`, `README.md`,
  `docs/PRD.md`, `docs/app-briefing.md`, `ops/environment-setup.md`, and the pending-decision state
  in `statistics/instrumentation-plan.md`.

## Context
Ironbit is at the last pre-launch step. Until now the app shipped **zero telemetry** and was marketed
as **offline, no-account, no-tracking** — a published differentiator and the #4 trust-anchor messaging
pillar. The owner needs real visibility into the activation/retention funnel and into launch-blocking
crashes before release. `statistics/instrumentation-plan.md` framed three privacy postures
(A none / B local-only / C opt-in anonymous aggregate) plus a *separable* crash-reporting decision,
and required owner sign-off recorded as an ADR before any SDK is wired. This is that record.

## Decision
1. **Product analytics — Firebase Analytics (Google Analytics for Firebase).** Real product/retention
   analytics, **on by default with disclosure + an in-app opt-out**. This is a deliberate move
   *beyond* Posture C: the **"no tracking" claim is retired**, not preserved. It tracks the
   activation + D1/D7/D30 retention funnel for real.
2. **Crash/error reporting — Sentry (`sentry_flutter`), opt-in (off by default).** The SDK is
   initialized only after consent; Android R8/ProGuard mapping is uploaded so stack traces symbolicate.
   (Sentry chosen over Crashlytics per owner call, even though Firebase is already present — they
   coexist cleanly.)
3. **Data minimization still holds.** No PII or body-salient data leaves the device — **never** send
   bodyweight, sex, character name, free text, or exercise *content*. Events carry only anonymous
   funnel/aggregate signals (taxonomy in `metrics-glossary.md`). Workout history itself stays in local
   `SharedPreferences`; analytics is a separate, minimal event stream.

## Consequences
- **Positive:** the activation funnel, D1/D7/D30 retention, sessions/week, and crash-free rates become
  observable — the `metrics-glossary.md` hypotheses can finally be validated against real data.
- **Marketing cost (eyes open):** "no tracking / no cloud / data never leaves your device" was a
  *published* selling point, and `research/insights.md` records an assumption that privacy is "a real
  draw" for this target user. Retiring it carries a positioning cost; every copy surface must change
  (below) so the store listing is not making a false claim.
- **Compliance obligations — deploy blockers:**
  - **Privacy policy (hosted URL)** — required by Play once analytics is collected; **none exists
    yet**. Must cover Firebase + Sentry, the data types, retention, and how to opt out.
  - **Play Console "Data safety" form** — declare Firebase Analytics (app interactions, device/
    diagnostics) and Sentry (crash logs, diagnostics); mark as collected anonymously, not linked to
    identity, with an opt-out.
  - **Consent / regional** — Settings opt-out for analytics; Sentry off-by-default consent. If
    marketed in the EEA/UK, evaluate Firebase **consent mode** (identifiers + GDPR/ePrivacy).
  - Update store listing + all `marketing/*` claims (done in this change set).
- **Build/ops:** adds `firebase_core` + `firebase_analytics` + `sentry_flutter`; requires a Firebase
  project with `android/app/google-services.json` and the Google-services Gradle plugin, plus a Sentry
  DSN. The "no backend / no API keys / fully offline build" assumption in `ops/environment-setup.md`
  no longer holds (config files now exist; keep the DSN/keys out of git as needed).

## Rollout (vendor-agnostic tiers, per the plan)
- **P0 — foundation:** Sentry init (consented) + Android symbolication; `app_open` / boot success.
- **P1 — the funnel:** `onboarding_complete`, `first_workout_saved`, `workout_saved`, `app_open`
  → D1/D7/D30, sessions/week.
- **P1 — friction:** onboarding step drop-off, `workout_save_failed`.
- **P2 — performance:** screen TTI for the heavy screens (exercise picker, summary).

## Implementation notes
- Both SDKs initialize in `lib/main.dart`'s `main()` — `Firebase.initializeApp()` before `runApp`,
  and `SentryFlutter.init(..., appRunner: () => runApp(...))` gated on the stored consent flag.
  `BootSplashPage` / `BootService` stay untouched.
- A thin `AnalyticsService` wrapper owns the event taxonomy + the `analytics_opt_out_v1` /
  `crash_reporting_opt_in_v1` SharedPreferences keys, mirroring the existing opt-in pattern used for
  body metrics (Phase 7 Decision #3).

## Docs reconciled by this decision
`marketing/positioning.md`, `marketing/CLAUDE.md`, `marketing/copy/beta-invite-email.md`,
`README.md`, `statistics/{instrumentation-plan,metrics-glossary,README,CLAUDE}.md`, `docs/PRD.md`,
`docs/app-briefing.md`, `ops/environment-setup.md` — all updated to "training data stays local;
anonymous, opt-out analytics + opt-in crash reports excepted."
