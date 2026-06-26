---
name: audit
description: Use when running a comprehensive, autonomous pre-launch audit of the whole app — or one page/section/flow — for UI slop, visual-hierarchy problems, UX bugs, and data-calculation errors. Fans out scoped per-unit passes grounded in REAL rendered screenshots + code oracles instead of one vague "audit everything" prompt. Effort scales to app surface area, not a token budget.
---

# App Audit (Ironbit)

A single "Audit the app comprehensively before launch" prompt **structurally** under-performs and
empirically missed UI slop, hierarchy problems, UX bugs, and calc errors. The reason isn't smarts —
it's that one attention budget smears across the whole app (LLM "lost in the middle"), and one broad
pass finds far less than several scoped ones (heuristic-eval: 1 evaluator ≈ 35% of problems, 3–5
independent ≈ 75%). This skill replaces the prompt with a **fan-out of scoped, grounded, per-unit
passes** plus a layer of **deterministic checks the model can't blind-spot**, then reconciles and
synthesizes. Evidence + rationale: `research/insights.md` → "Pre-launch app audit" (2026-06-26).

> **This is not a vibe pass.** Every finding is anchored to evidence: a screenshot path + region, or a
> `file:line`, or an **oracle mismatch**. A finding with no anchor is a deletion candidate, not a finding.

## Core doctrine (the four things that make it actually work)

1. **Ground or don't claim.** A presentation finding must point at a **real rendered PNG** of that
   surface (see *Grounding harness*). Never audit from reading widget code alone — code-reading misses
   what the eye catches (overlap, contrast, rhythm) and invents problems that don't render.
2. **Calc audits use independent oracles, never the code under review.** Reading a formula and
   "recomputing" it rubber-stamps it. A correctness finding cites a **known-answer fixture from
   `docs/`**, a violated **invariant**, or a **separate recomputation that does not call the
   production service** — not "the code says X".
3. **Diversity, not just parallelism.** Same model × N scoped prompts = correlated blind spots, not N
   independent evaluators. Real diversity comes from (a) the **deterministic lint track** (no model
   taste involved), (b) **≥1 non-identical vision model** on the screenshot pass, and (c) a
   **calibration corpus** of known-bad cases that proves recall before you trust a clean result.
4. **Reconcile by downgrading, never deleting.** Design-system exceptions (e.g. VIT's red heart is
   intentional) must be **exact + validated** (page/region + rationale + owner/date + the constraint
   that must still hold), and they **tag/lower-confidence** a finding — they don't silently erase it.

## Tracks (front-end ≠ one thing)

| Track | Catches | Grounded in | Model judgment? |
|---|---|---|---|
| **Deterministic lint** | hex-literal colors (token violations), `RenderFlex` overflow, sub-48px tap targets, missing `Semantics`, rounded (non-`_sharp`) Material icons | grep + the render harness's caught `FlutterError`s + widget-tree measurement | **No** — hard assertions |
| **Presentation** | slop, spacing rhythm, visual hierarchy, contrast, theme coherence, alignment | a **rendered PNG** of the section | Yes (+ 2nd vision model) |
| **Journey** | flow breaks, dead ends, cross-page inconsistency, lost back-stack, empty/loading/error states | a **multi-screen capture sequence** | Yes |
| **Correctness** | wrong e1RM / volume / XP / coverage / streak math, off-by-one, unit/rounding bugs | **oracles** (docs fixtures, invariants, independent recompute) | No (oracle-driven) |
| **State / integration** | bad persistence, resume-after-kill, stale state, summary mismatch, idempotency | code + a **replayed session** through real service APIs | Partial |

The original complaint's "data-calc misses" are the **Correctness track**, not a visual audit — a
screenshot cannot see a wrong formula. Keep them separate or they fall between the cracks.

## Grounding harness (the prerequisite — already exists in this repo)

`test/quests_page_golden_test.dart` proves a **full page** renders to a real PNG with **real fonts**
(`FontLoader` PressStart2P + ShareTechMono), **real seeded state**, a **pinned clock**
(`nowProvider`), a **real device size** (390×844), reduced motion, and precached images. The reusable
helper is **`test/audit/audit_capture.dart`** → `captureSurface(...)`. It:
- loads real fonts so type/measure is honest;
- forces `disableAnimations` (deterministic);
- **fails the capture if its `smokeText` isn't present** (a broken/empty render can't masquerade as polished);
- **records any `RenderFlex`/overflow `FlutterError`** during pump (feeds the lint track);
- writes `test/audit/_shots/<name>.png` (gitignored) for the auditor to `Read`.

**Scenario authoring contract** (this is the maintainability risk — keep it honest, per `references/scenarios.md`):
- **Seed via real service write APIs** (`WorkoutStorageService.saveSession(...)`, `LootService.grantItem(...)`),
  **never raw `SharedPreferences` keys** — so a schema change breaks the seed loudly instead of
  rendering a stale lie.
- **Construct the page the way the app does** (same constructor/params `RootPage` passes).
- A scenario that is **constructed, not navigated**, is labelled **confidence: medium**; only a
  capture reached by driving real navigation from `RootPage` is **high**.
- Always assert visible **smoke text/actions** so an empty-state or missing-dependency bug fails the
  capture rather than producing a clean-but-wrong image.

## The workflow

`audit` audits ONE **target** — a page, a page-section, a flow, a system, or a data registry. The
caller names the target (inside a campaign, `audit-app` names it). Run the stages in order.

> **Single-unit only.** Do NOT inventory the whole app or fan out across pages/services — that is the
> `audit-app` skill's job, and a per-unit worker that re-expands into a whole-app sweep corrupts the
> campaign's coverage accounting. Auditing everything? Start **`audit-app`**, which drives this skill
> once per unit.

**0 — Calibration gate (first run / after big UI churn).** Before trusting the audit, run it over the
**calibration corpus** (`references/calibration.md`): a tiny set of *known* defects — one slop case,
one hierarchy case, one stale-state case, one seeded formula bug. If the audit doesn't catch them, fix
the checklist/grounding **before** auditing real surfaces. This is what proves it beats the old prompt.

**1 — Scope the target + pick tracks.** Identify the one target and the tracks it needs (screen →
Presentation + lint; flow → Journey; system → Correctness + State; registry → integrity). If the
target is a single page with several distinct sections, you MAY fan out one subagent per *section of
that page*; a system/registry is audited directly. **Never expand beyond the named target.**

**2 — Ground it.** Produce the target's evidence: render its PNG (`captureSurface`, see
`references/scenarios.md`) for Presentation/Journey; gather the service file + its **independent
oracle** for Correctness; run the deterministic-lint greps. Route the presentation vision pass through
a non-identical model (`Agent` `model:` override) for diversity. **If the required evidence can't be
produced (no render, no oracle), say so and mark the track `blocked` — never substitute code-reading
for a grounded finding.**

**3 — Collect findings.** Each finding =
`{severity: blocker|major|minor|nit, confidence, track, unit, evidence: <png#region | file:line | oracle-mismatch>, claim, fix}`.
No evidence anchor ⇒ drop it.

**4 — Reconcile.** Apply `references/exceptions.md` (the design-system intent ledger). Exceptions
**downgrade/tag** — they never delete — and must be exact + validated (region + rationale + owner/date
+ constraint-that-must-hold). Anything not covered by an exact exception stays.

**5 — Synthesize.** Dedup across units, rank by **severity × reach** (a slop on Home outranks a nit on
a rare page), and emit the **punch list**: grouped by severity, each row linking its evidence. End with
the **recall caveat** (which tracks/units were grounded vs code-only, and what a human still must eyeball
— motion, haptics, on-device-only rendering).

## Gates (don't skip)

- No presentation finding without a rendered PNG anchor.
- No correctness finding without an oracle (docs fixture / invariant / independent recompute).
- No exception that deletes rather than downgrades.
- No "clean" verdict on a track that never ran its calibration case.

## Relationship to other skills

- **`research`** owns evidence for *why* a pattern is good/bad; this skill finds *where the app
  violates it*. Hand cross-cutting "is this even the right UX" questions to `research`, not the audit.
- **`ironbit-design`** owns the *fix* pixels. The audit reports the defect + a fix direction; the
  redesign/repair of a flagged surface routes through `ironbit-design` (or `/deep-feature` if behavioral).
- **`/deep-feature`** is for building ONE feature well; **`/audit` is for sweeping the WHOLE app for
  defects.** Different cadence — don't fold one into the other.

## Reflect (gated)

After a run, distill any *generalizable* miss into `.claude/skills/audit/learnings.md` (a real
defect the workflow missed and why — update-over-append, respect the cap). Add a *durable* new defect
class or check to `references/checklists.md`. A new validated design-system intent → `references/exceptions.md`.
Most runs add nothing; say **"no growth this run"** when so.
