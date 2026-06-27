# statistics/

Product analytics, metrics, and observability planning. **No real data yet (pre-launch).**

## Structure
- `instrumentation-plan.md` — what to measure + the privacy decision (read first).
- `metrics-glossary.md` — KPI definitions.
- `dashboards/` — dashboard specs/exports (later).
- `reports/` — periodic performance reports (post-launch).

As of **2026-06-27 ([ADR 0001](../docs/decisions/0001-usage-instrumentation.md))** the app adopts
**Firebase Analytics (opt-out) + Sentry crash reporting (opt-in)** — the "no tracking" positioning is
retired in favor of anonymous, data-minimized telemetry. Measurement planning still focuses on hook
health first: onboarding completion, first workout, ritual return, collection engagement, and whether
the user keeps strengthening their character. See [CLAUDE.md](CLAUDE.md).
