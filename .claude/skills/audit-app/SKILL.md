---
name: audit-app
description: Use when the user wants to audit the WHOLE app (not one page) — a comprehensive, exhaustive, pre-launch / release-readiness sweep across every page, system, data set, flow, and cross-cutting aspect. Triggers on "audit the whole app", "app-wide audit", "audit everything before launch", "full audit", "find every issue", "is the app launch-ready". Runs autonomously and resumably, scaled to app size, not a token/time budget. For auditing a SINGLE page/section/flow, use `audit` instead.
---

# App-Wide Audit (Ironbit)

A campaign, not a prompt. "Audit the whole app" fails as one pass — attention smears across 45 pages
and 58 services and most get a shallow glance (see `audit` skill for the evidence). This skill is the
**orchestrator**: it builds an *exhaustive, codebase-derived* ledger of every audit unit, then drives
the **`audit`** skill on each one, checkpointing as it goes so the run survives context compaction and
spans as many turns as the app needs.

**REQUIRED SUB-SKILL:** Each unit is audited with `audit` (its 5 tracks, grounding doctrine,
reconcile/severity rules). This skill does NOT redefine how to audit a unit — it decides *what* the
units are, *in what order*, and *how to not lose progress*.

## Two principles that make it work

1. **Source-unit exhaustive, then drift-checked.** Screen/system/data units are *derived from the
   filesystem* (`Glob` over `lib/pages` / `lib/services` / `lib/data`), never hand-typed — a human
   forgets the obscure page; a glob can't, so every source file gets a row. But **flows and
   cross-cutting sweeps are NOT 1:1 with files** and can rot as the app grows. So glob-exhaustiveness
   only covers source units; flows/sweeps get **drift checks** (step 1): a navigation/route scan
   (`Grep` `Navigator.push`/route builders), a notification/deep-link entrypoint scan, and registry
   cross-reference scans. Anything those surface that has no ledger row goes into a **required
   "unmapped" section** that *blocks a complete verdict*. Claim "source-unit exhaustive + drift-checked",
   never a bare "everything".
2. **The ledger is the checkpoint.** Long-running agent work that exceeds one context window must
   persist state and resume (orchestrator-worker + checkpoint — Anthropic multi-agent system). The
   ledger file IS that state: each unit's status is saved to disk after it's audited, so a crash,
   compaction, or new turn resumes from the first `pending` row. **This is what makes effort scale to
   the app, not to a token budget** — never restart a run that already has `done` rows.

## Workflow

### 0. Scope & resume
Look for an open run at `audit-runs/<run-id>/ledger.md`. If one exists with `pending` rows, **RESUME
it** — do not start over. Otherwise open a new run (`run-id` = today's date, e.g. `2026-06-26`).

Default scope is **the whole app** — that's the point. The prioritization (step 2) means an interrupted
run still covers the core loop first, and resumability (the ledger) is what makes a full-app run viable
across many turns instead of collapsing into one context. The user may narrow scope on request (a
priority tier — "P0 only" — or an area — "just the systems"); record the scope in the ledger header so
the coverage stat is honest about what "100%" means for this run.

### 1. Build the coverage ledger (exhaustive)
`Glob` `lib/pages/**/*.dart`, `lib/services/**/*.dart`, `lib/data/**/*.dart`. Map each file to one or
more audit units + the tracks it needs, using `references/taxonomy.md`. Add the **flow units** and the
**cross-cutting sweeps** listed there (they span files, so they aren't 1:1 with globs). Write every
unit as a `pending` row. See `references/ledger.md` for the exact ledger format.

> The ledger must reconcile against the globs: if a page file has no row, the ledger is incomplete —
> fix it before auditing. Coverage is the whole point.

### 2. Prioritize by core-loop reach
Order the ledger so a *partial* run still covers what matters most: **onboarding flow → Home → TRAIN /
workout session → Summary → the systems that compute the numbers (XP, stats, overload, quests, gems) →
everything else**. Reach (how many users hit it) × blast-radius, high first.

### 3. Run dedicated per-unit audits (the loop)
For each `pending` unit, **dispatch a subagent** (Agent tool) with the **full worker contract** from
`references/worker-contract.md` inlined into the prompt — NOT a bare "follow the audit skill" pointer.
A cold subagent that only gets a path silently degrades to code-reading; the contract forces it to
produce grounded evidence (render commands, oracle inputs, evidence filenames, severity/reconcile
rules) and to **refuse + return `blocked`** if it can't.

**Ledger ownership (no write races):** workers are **forbidden to touch `ledger.md`**. Each worker
writes only its immutable `audit-runs/<run-id>/units/<unit>.md` plus a one-line completion manifest
(`status`, `findings`, `maxSeverity`, `evidence`). Fan out independent units in **parallel batches**;
when a batch returns, the **orchestrator alone** reconciles every manifest into the ledger in a single
serial pass — validating each claimed `done` against the presence of its unit file — and rewrites the
ledger via **temp-file-then-rename** (atomic checkpoint). One batch = one ledger write. Never patch the
ledger from a stale in-memory snapshot; re-read before each reconcile.

Engineer diversity per the `audit` skill (deterministic lint track + a non-identical vision model on
presentation passes) — fan-out of the same model is correlated, not independent.

### 4. Cross-cutting sweeps
Two kinds, sequenced differently (learned 2026-06-26 — front-load cheap signal):
- **Grep-based lint sweeps** (theme coherence · icons · copy · body-neutral voice ·
  persistence/migration · notifications) need NO per-unit evidence — run them **early/in parallel** with
  the per-unit oracles. They're the highest-ROI pass: fast, deterministic, and they catch slop across
  *every* screen at once.
- **Render-based sweeps** (a11y + reduced-motion · interrupt/state-recovery · device/responsive) read
  across rendered evidence — run them *after* the screen renders.
Each sweep is its own ledger row with its own finding file.

### 5. Synthesize the master report
Emit **`audit-runs/<run-id>/report.html`** — generate it FROM `references/report-template.html` (the
app-aesthetic, collapsible-`<details>` design; keep its `<style>` verbatim, fill the body per its
header comment). Dedup findings across units, rank by **severity × reach**, show a **coverage stat**
(units audited / total, rendered-PNG vs code-only) + the **unmapped section** from step 1. Each finding
is one collapsed `<details>` (sev colour: minor=cyan · nit=muted · major=amber · blocker=danger ·
process=violet · pass=neon). To let the user view it: `python -m http.server 8000 --directory
audit-runs/<run-id>` → http://localhost:8000/report.html.

**Verdict is hard-gated** — the report may emit `launch-ready` / `not-launch-ready` **only when**
coverage is 100% AND no P0/P1 unit, oracle, render, or sweep is `blocked`. Otherwise it MUST emit
**`verdict: incomplete`** with the explicit `pending`/`blocked`/`unmapped` list — no ship/no-ship
language. A skipped unit may only be excluded from "100%" via an **explicitly acknowledged exception**
(reason + owner). This gate is the antidote to a "comprehensive-looking" audit that quietly skipped
half the app — stakeholders read the verdict, so the verdict must never overstate coverage.

## Gates

- No unit audited without a ledger row (else coverage is unprovable).
- Workers **never write `ledger.md`** — only their `units/<unit>.md` + manifest; the orchestrator is
  the sole, serial ledger writer (temp-then-rename per batch).
- No ledger row marked `done` without a findings file (even "no issues" is a recorded result), and the
  orchestrator validates that file exists before accepting a `done`.
- Every worker dispatch carries the full `references/worker-contract.md` — never a bare skill pointer.
- No `launch-ready`/`not-launch-ready` verdict below 100% coverage or with any blocked P0/P1 unit —
  emit `verdict: incomplete` instead.
- No restart of a run that has `done` rows — resume.

## Reflect (gated)

After a full run, fold any *generalizable* miss (a unit type the taxonomy lacked, an ordering mistake,
a resumability bug) into `.claude/skills/audit-app/learnings.md`. A genuinely new unit class →
`references/taxonomy.md`. Most runs add nothing; say "no growth this run" when so.
