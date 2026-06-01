# Instrumentation & Observability Plan — Ironbit

> Seed document from the 2026-05-31 audit. **Decisions here are proposals pending user sign-off.**

## Audit snapshot (current state)
- **Telemetry SDKs:** none. No Sentry/Crashlytics/Firebase/analytics anywhere.
- **Crash reporting:** none (no symbolication config, no error reporter).
- **Analytics:** none. Persistence is `SharedPreferences` JSON only; nothing leaves the device.
- **Coverage score:** 0% (greenfield) — which is *consistent* with the offline/no-tracking promise.

## The core tension
The product is marketed as **offline, no-account, no-tracking**. Standard mobile analytics
(server-side event streams) would contradict that. Pick a posture before writing any code:

| Posture | What it means | Trade-off |
|---|---|---|
| **A. None** | Ship blind; learn from store reviews + manual feedback. | Keeps the promise; no funnel visibility. |
| **B. Local-only metrics** | Compute funnel/retention on-device; user can view ("your stats"), nothing sent. | Keeps the promise; you only see *your own* device. |
| **C. Opt-in anonymous aggregate** | Explicit opt-in, no PII, aggregate counters only, clearly disclosed. | Some visibility; must update store copy + privacy text honestly. |

**Crash reporting is separable:** even under Posture A/B, an *opt-in* crash reporter (or local
crash log the user can share) is defensible and high-value. Keep it a distinct decision.

## If/when instrumented — priority tiers (vendor-agnostic)
- **P0 Foundation:** crash capture + symbolication (Android R8/ProGuard mapping upload), app-start success.
- **P1 The funnel:** onboarding completion, first-workout-saved, week-1 return, sessions/week.
- **P1 Friction:** onboarding step drop-off, workout-save failures.
- **P2 Performance:** screen TTI for heavy screens (exercise picker, summary), jank on lists.

## Trust anchors (if any data is collected)
- Opt-in, off by default. No PII, no bodyweight values, no exercise content off-device.
- Disclose in store listing + in-app. Provide a kill switch.

## Hook-health priorities
- Identity attachment: class confirmed, avatar selected, name committed, profile returns.
- Ritual return: D1/D7/D30 return, sessions/week, home mission completion.
- Competence growth: first stat delta seen, level-up seen, suggested-load usage.
- Collection desire: inventory opens, unlock viewed, title/frame equipped.
- Recovery protection: planned rest viewed, shield used, VIT recovered.

## Next action
Get the user's decision on posture (A/B/C) and on crash reporting, then record it as an ADR in
[../docs/decisions/](../docs/) and only then plan implementation.
