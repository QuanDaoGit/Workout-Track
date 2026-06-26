# Audit-app — learnings (generalizable misses only)

Distill a *generalizable* orchestration failure (a unit class the taxonomy lacked, an ordering mistake,
a resumability bug, a false "complete" verdict). Update an existing category over a near-duplicate.
Cap: 10 entries — prune the least-recently-fired when full. Most runs add nothing; say so.

## Categories

### Coverage completeness
- The unit list MUST be glob-derived, not memory-derived — a hand-typed list silently drops the obscure
  page/service. Reconcile ledger against `lib/pages`/`lib/services` globs before auditing.

### Resumability
- The ledger is the checkpoint: save it after every unit, resume from the first `pending`. Never restart
  a run with `done` rows. A run that doesn't persist state can't be "not token/time limited".

### Honest coverage
- A partial run reported as complete is the cardinal sin (it re-creates the original "comprehensive but
  shallow" failure). Always emit audited/total + the explicit `pending`/`blocked` gap list. Hard-gate
  the launch verdict to 100% coverage with no blocked P0/P1 — otherwise `verdict: incomplete`.

### Worker dispatch
- A cold subagent given only "follow the audit skill" degrades to code-reading dressed as findings.
  Inline the full worker contract (unit, tracks, required-evidence-or-drop, render/oracle commands,
  MANIFEST line, refusal→blocked) into every dispatch. No manifest ⇒ treat as blocked.

### Single-writer state
- Parallel workers + one ledger = lost updates. Workers write only their unit file + a MANIFEST; the
  orchestrator is the sole ledger writer, reconciling per batch via temp-then-rename and validating
  each `done` against the unit file's existence.

### Two-skill boundary
- A per-unit auditor that can also inventory/fan-out the whole app will recursively re-expand a campaign
  and corrupt coverage accounting. Keep `audit` single-unit; `audit-app` owns all orchestration.

### Rendering heavy pages — settle mode + cache pre-warm (from the 2026-06-26 run)
- Most pages render with bounded plain pumps. HEAVY pages (deep sequential prefs-await chains like a
  20-service profile load) need a **`settle`** pass: interleave `tester.runAsync(Future.delayed(...))`
  with pumps so the load completes in the REAL event loop, then the setState applies. (runAsync does
  NOT deadlock on tickers — that earlier worry was wrong; the real trap was File/rootBundle I/O run in
  the fake-async zone.) This unblocked profile + root (the home shell).
- A page that calls `rootBundle.loadString` / a plugin channel INSIDE its own `_load` can't be rendered
  this way — that I/O runs in the page's fake-async zone and never completes (no test runAsync wraps it).
  Pre-warming a STATIC cache in the test's real zone helps IF the service caches statically; if not (or
  if there's a min-display loader ticker), accept it and audit the page's content via its component
  goldens instead (e.g. workout_logs == the `_body_map_*` goldens; adventure == `expedition_dock_*`).
  Harness knobs: `captureSurface(..., precache:false, settle:true)`; theme + mono font + kBg backdrop
  are applied so transparent scaffolds don't render light-on-white.

### Reuse existing goldens before re-rendering (from the 2026-06-26 run)
- The repo already has a large `test/goldens/*.png` set (onboarding cold_open/problem/solution, home_room,
  quests_board, expedition_dock, session_projection, all the BIT/companion states). For the
  presentation pass, **`Read` those existing PNGs first** — it's far cheaper than authoring a new seeded
  capture scenario per screen. Only write a new `captureSurface` scenario for a screen with NO golden.
  Caveat: some goldens render body text (Gotham) as solid boxes because that golden didn't load Gotham —
  you can audit LAYOUT/STRUCTURE from those but not body-copy legibility (PressStart2P/ShareTechMono load
  fine). Also check `test/failures/` — diff artifacts there mean a golden may currently be failing
  (regression vs. in-flight rework — verify, don't assume).

### Sequencing / ROI (from the 2026-06-26 run)
- Front-load the cheap, code-grounded signal: the **grep-based lint sweeps** (icons/theme/copy/
  body-neutral) and the **correctness/integrity oracles** are fast, reliable, and find the bug class a
  generic prompt misses — run them FIRST. The **screen-render** presentation pass is the slow, finicky
  tail (each needs a seeded scenario); it's where UI-slop findings live but it's the last thing to do,
  not the first. A run that front-loads code-grounded work delivers a real report even if the render
  tail isn't finished. Split sweeps: grep-lint sweeps run early (no per-unit evidence needed);
  render-based sweeps (a11y/device) wait for renders.
- Reclassify, don't false-pass: when a unit doesn't fit its assumed track (e.g. a "data registry" that's
  actually an algorithm), mark it reclassified — never let a category-mismatched check report a clean pass.

<!-- Add new generalizable misses above this line. -->
