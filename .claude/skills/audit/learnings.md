# Audit — learnings (generalizable misses only)

Distill a *generalizable* failure mode the workflow missed (not a feature-specific bug). Update an
existing category over appending a near-duplicate. Cap: 12 entries — prune the least-recently-fired
when full. Most runs add nothing; that is correct.

## Categories

### Grounding fidelity
- A directly-constructed page can render a *different* state than the real navigated route — always
  prefer real-service seeding + smoke assertions, and label constructed captures `medium` confidence.
  (seed: this is why scenarios carry a confidence label.)

### Correctness oracle discipline
- "Read the formula and recompute" rubber-stamps the code. A real calc finding needs a docs
  known-answer, an invariant, or an independent recompute that doesn't call the service.

### Reconciliation
- A broad exception ("ignore red") suppresses real regressions. Exceptions must be exact + carry the
  constraint that must still hold, and downgrade rather than delete.

### Render-harness mechanics (Flutter golden capture)
- Capturing a real app page hits three FakeAsync traps, each a multi-minute hang if unknown: (1) real
  disk I/O for fonts and `precacheImage` must run inside `tester.runAsync` (FakeAsync never completes
  real I/O); (2) `runAsync` DEADLOCKS while any Ticker is live (loading spinner) — only call it before
  the first widget or after the load settles; (3) `pumpAndSettle` hangs on the app's perpetual
  animations — flush loads with plain bounded pumps. The capture itself uses `matchesGoldenFile`
  (proven path), which only writes under `--update-goldens`. Build the harness against a 1-second
  minimal diagnostic before trusting it.

<!-- Add new generalizable misses above this line. -->
