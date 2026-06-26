---
name: deep-feature
description: Research-first pipeline for features and non-trivial fixes — route to helper skills, audit the code, research (domain accuracy + user/gamer psychology), compile an opinion, have Codex adversarially review the opinion and the plan, then implement behind the verification bar. Use when the user asks to add a feature, fix, improve, rework, or redesign any non-trivial part of the app.
---

# Deep Feature Pipeline

Run the stages **in order**. This is the process that produced the workout-logs redesign and the
stat-engine intensity rework — keep its shape.

## Carve-out (check first, risk-based)

A change may skip stages 0 and 2–4 **only if** it is non-behavioral text or formatting with no
impact on state, navigation, persistence, scoring/XP/stats, accessibility, or design tokens
(typos, comment edits, doc wording). **State in one line why the change qualifies** before
skipping; then implement and run `flutter analyze` + `flutter test`. A one-liner that touches
validation, rewards, persistence, or theme tokens is NOT trivial. When unsure, it isn't.

## Stage tracking (enforcement)

At start, create one TodoWrite/Task item per stage. A stage is complete only when its named
artifact exists in the conversation. Hard gates:

- No plan before the Stage-4 CHALLENGE findings are resolved.
- No implementation before an approved plan.
- No completion claim before analyze/test/review outputs are shown.

## Stage 0 — Skill routing

Classify the task, check the **session's available-skills list**, and invoke the matching
helpers. Reference by capability; the named skill is the current best fit — if it is missing
from the session list, skip it with a note, never block on it.

| Task signal | Capability → current best skill |
|---|---|
| Vague/new feature, unclear requirements | Brainstorming → `superpowers:brainstorming` (fires before everything else) |
| UI / visual / motion / copy / screen work | App design language → `ironbit-design` — the **single** owner of all UI/UX here (visual, layout, motion/transitions, micro-interactions, typography, icons, in-app copy, accessibility, and design critique). It supersedes the generic `ui-ux-pro-max` / `design:*` skills; do not also route to those. |
| Porting a design/asset/animation **handoff** (runnable reference + engine source + assets) into the app | Faithful-port discipline → `port-handoff` — read source-not-summary, inventory + delta contract gate, translate verbatim, adapt only the named delta. It owns the implement stage when a handoff is the input (route layer-1 surfaces here, not `ironbit-design`). |
| Bug fix / unexpected behavior | Root-cause discipline → `superpowers:systematic-debugging` |
| Research / evidence gathering (domain, competitor, behavioral, UX, technical, safety) | Field-detecting research engine → `research` — owns field detection (incl. the Safety/clinical overlay), source routing, evidence grading, and the Codex-review-of-the-evidence. **This is the engine Stage 2 runs.** |
| Implementation phase | TDD → `superpowers:test-driven-development`; Done-claims → `superpowers:verification-before-completion` |
| Stuck / second implementation opinion | `codex:rescue` |

Known-incompatible with this app/environment (do not route to these; reasons checked 2026-06):
`uxaudit` (needs a browser-drivable running app; Flutter web preview cannot render/screenshot
here), `mobile-observability` (pre-launch, no telemetry backend), `brand-voice` / `marketing:*`
(they serve the `marketing/` folder, not app code), `figma:*` (no Figma sources in this repo),
`huggingface:*` (no ML). **Superseded for this app:** the generic UI/UX skills — `ui-ux-pro-max` and
`design:design-critique` / `ux-copy` / `accessibility-review` / `design-system` — are replaced by
`ironbit-design`; they emit catalog styles/palettes/components that fight the locked pixel-arcade
language. Route UI/UX work to `ironbit-design` only.

*Artifact: one line per selected skill, or "none apply" + reason.*

## Stage 1 — Audit

Read the relevant code before forming any view: `docs/PRD.md` for scope, the owning service(s)
in `lib/services/`, the models/data involved, and the tests pinning current behavior. Name
concrete problems with `file:line` evidence. Separate **defects** from **deliberate design
intent** (e.g. Tank=END radar identity is intent) — intent questions go to the user, not into a
"fix". *Artifact: numbered problem list.*

## Stage 2 — Research program (multi-field, audited, app-grounded, self-growing)

The `research` skill is the **per-field engine** (it owns field detection, tiering, SIFT, the
contrary-evidence guardrail, the Codex-review-of-the-evidence, and persistence — **don't redefine its
evidence bar here**). This stage **orchestrates a research *program* across the fields a feature
touches**, sized by an **objective trigger, not a vibe** (so a small change can't be rationalized into a
big research bill, and a flagship still gets full coverage):
- A change is **major** if **any** of these hold: it adds a new screen / bespoke surface, a new
  persistence key or scoring/XP/stats path, it changes the **core loop**, or it is **cross-cutting**
  (≥3 files/systems). The body-map is major on three of these.
- **No trigger → it is small:** cap at **≤3 kept fields** (often 1–2). The carve-out skips Stage 2
  entirely.
- **Major → the broad sweep is appropriate** — but it is still a **prune, not a checklist**: every
  *kept* field carries a one-line decision-relevance reason and every *dropped* field a one-line
  why-not. Running all 12 reflexively is the failure mode; "this field changes a decision" is the bar.

- **Evidence-sensitive even when "small":** some user-facing **behavior/policy** changes are easy to
  get wrong from stale priors even though they trip no structural trigger — defaults, validation,
  onboarding/friction, accessibility, notifications/reminders, monetization, privacy/consent, and
  irreversible/destructive flows. These **must research their relevant field(s) and run 2.3 regardless
  of the ≤3 cap**, and they are **not** carve-out material.

The menu is rich on purpose; the audit is what makes a body-diagram-scale feature get full coverage
while a one-liner stays cheap.

**Worked routing — sanity-check yourself against these:**
- *Soften onboarding copy to cut friction* → structurally small, but **evidence-sensitive**
  (friction/onboarding/behavioral) → research those fields, **2.3 runs** (external evidence used); it is
  **not** carve-out.
- *Rename a private field / extract a helper* → purely internal, no external evidence → one
  engineering-fit (INTERNAL) question or carve-out; **2.3 collapses into Stage 4**.
- *Add the body-diagram surface* → **major** (new screen + new data read + cross-cutting) → broad sweep
  across placement / UI-UX / aesthetic / frictionless / competitor / data / engineering-fit /
  behavioral, **each kept field justified, each dropped one noted**; **2.3 runs**.

**2.0 — Field audit (scope the research).** Before searching, enumerate which fields THIS feature needs
from the **candidate menu in `research/references/field-map.md`** (placement/IA · UI-UX-motion ·
aesthetic/graphic precedent · frictionless/interaction-cost · competitor/market · user-taste · domain
accuracy · data/analytics · engineering-quality & architecture-fit · behavioral/gamification ·
safety/accessibility overlay · idea/handoff market-fit critique). **Prune to the load-bearing few** —
one-line keep/drop reason each (decision-relevance, not completeness — the same prune that bounds the
research decomposition). For each kept field write **one app-contextual question** — phrased through the
app's soul + *current architecture*, never generic (e.g. "given our pixel-arcade, body-neutral, offline
app and its IndexedStack / SharedPreferences / Logs structure, where does X live and what must
reorganize so it scales without tech debt?"). **Tag each field INTERNAL or EXTERNAL** (next step).

**2.1 — Run the batches.**
- **EXTERNAL** fields (competitor, domain science, general UX/architecture patterns, aesthetic
  precedent, market-fit) → the `research` engine, **web-grounded** (current sources, not pretrained),
  parallelized.
- **INTERNAL** fields (where it fits *our* code, what to reorganize, our tech-debt/tangle/scalability
  risk, placement in our IA) are answered by **extending the Stage-1 code audit — NOT** forced through
  web search; pushing a web query at an internal-codebase question is a category error that wastes
  budget and invents false precedent.
- A **MIXED** field must emit **two sub-questions — one INTERNAL, one EXTERNAL — each with an explicit
  keep/skip decision**, so it can't silently collapse to one side. For engineering-quality: the
  INTERNAL fit (does it belong here, what reorganizes) is **mandatory whenever code is affected**; the
  EXTERNAL pattern search is **optional — run it only when the architecture question is novel or
  contested**, else skip it with a note (don't fetch generic advice about our own repo).

**2.2 — Cross-field synthesis.** Merge the briefs and surface the **cross-field tensions** explicitly —
the recurring accuracy-vs-hook axis plus taste-vs-frictionless, aspiration-vs-maintainability, and
idea-vs-market. Aesthetic findings are **evidence/precedent only — the pixels defer to `ironbit-design`**.

**2.3 — Codex adversarial review of the EVIDENCE (conditional).** Run it (prompt-carried — see
`.claude/codex-local.md`; the prompt-only review *works*, do **not** assume Codex is unavailable) whenever
**any kept field used EXTERNAL evidence**, or the change is **high-impact / safety / analytics /
cross-field** — i.e. wherever coverage can actually be wrong. **Collapse it into the Stage-4 plan
review** (with a one-line note that 2.3 was intentionally skipped) **only when the change is purely
internal** — zero external evidence *and* no high-impact/safety/analytics/cross-field claim;
manufacturing a Codex pass over one internal finding is theater, not rigor. When it runs, challenge **coverage**: a
missing field, a weak/biased source, **app-soul or architecture drift**, overgeneralization, stale
recency, and **confirmation bias introduced by the app-grounding** (did we only find what flatters the
app?). This reviews the **evidence**; it is **not** Stage 4 (which reviews the opinion/plan) — different
objects, neither substitutes for the other.

**2.4 — Evaluate Codex + wrap-up.** Do **not** blind-accept — for each point: agree / partial / reject,
with a reason (receiving-review discipline). Then run **one** wrap-up research loop to close the real
gaps. Output the consolidated **research brief**.

**2.5 — Reflect → self-growth (gated; this is what compounds).** Make each use leave research better —
but only when something durable actually surfaced (no mandatory churn):
- Persist durable findings → `research/insights.md` (tied to a decision + doctrine). **Reuse-first**
  next time is the compounding — later features start from accumulated knowledge, not zero.
- Distill a *generalizable* method/source failure → `research/learnings.md` (update-over-append,
  respect the cap, prune the least-recently-fired when full).
- **Grow the field-map *structurally only*** — a genuinely new field, a routing rule, or a question
  template; **never** dated sources or stale-flags (a reusable menu must not decay into a time-sensitive
  source registry — those belong in `insights.md` with dates + a review cadence). Most runs add nothing,
  and that is correct.
- **Self-score** the run (coverage · recency · app-grounding · contrary-evidence · Codex-resolution ·
  decision-tied), name the **single weakest dimension + one concrete fix** as next time's focus —
  anchored to the Codex 2.3 findings, not a vacuum self-grade.
- State **"no growth this run"** when nothing qualifies — the visible gate that keeps the stores from
  rotting.

The product **acceptance criteria** the brief must still cover where they apply: domain accuracy
(primary sources for mechanics), user/gamer psychology (SDT / loss-aversion / identity), and
leading-app precedent. Accuracy and the hook usually point the same way — a farmable stat undermines the
competence signal that makes the number satisfying.

*Artifacts: the field-audit (kept/dropped fields + INTERNAL/EXTERNAL tags + per-field app-contextual
question) · per-field briefs · cross-field synthesis · the Codex evidence verdict + your evaluation ·
the consolidated research brief · the reflect note (growth, or "no growth this run").*

## Stage 3 — Opinion

Synthesize a recommendation with explicit tensions/tradeoffs (accuracy vs hook is this app's
recurring axis). Separate engineering calls (yours) from intent calls (the user's). Before
writing, read `.claude/skills/deep-feature/learnings.md` (if present) and check the
recommendation against every category that applies. State what you would change, what you would
keep, and why. *Artifact: the opinion section.*

## Stage 4 — Codex adversarial review (opinion, then plan)

Review the **opinion** before planning, and the **plan** before implementation, in the
foreground via the codex plugin (`/codex:adversarial-review` flow). Stable rules:

- Carry the full design context (current behavior + proposal) **in the prompt** — never assume
  the reviewer can read the repo.
- End the prompt with a numbered **CHALLENGE** list naming the weakest assumptions: migration
  cliffs, exploit surfaces, hook regressions, missing-data fallbacks — plus every
  `.claude/skills/deep-feature/learnings.md` category that applies to the change.
- Treat findings as design input, not a gate to argue past — revise the design before planning.
  (The stat rework reversed its core mechanism — bounded e1RM tiers → cumulative intensity
  currency — because of this step.)
- Consult `.claude/codex-local.md` **if present** for machine-specific invocation constraints
  (sandbox limitations, scoping flags, plugin path).

*Artifact: verdict + a finding→resolution table. Gate: no plan until findings are resolved.*

## Stage 5 — Plan → implement → verify

1. Enter plan mode; write the Codex-hardened plan (context, changes, files, reuse list,
   verification); get approval.
2. Implement to the CLAUDE.md bar: `flutter analyze` zero issues, `flutter test` all pass, new
   fixture tests per user archetype (beginner / veteran / calisthenics / missing-data) where
   mechanics changed, tokens-only colors, sharp icons.
3. The Codex stop-time review gate fires automatically at turn end; after committing, also run
   `/codex:review --wait` for a diff-grounded review (see `.claude/codex-local.md` for why the
   automatic gate may be weaker than it looks on this machine).
4. Update the affected docs (`docs/stats-mechanics.md`, `docs/PRD.md`) in the same change —
   reconcile against code before writing, per `docs/CLAUDE.md`.
5. **Reflect:** after the final review verdict, distill any *generalizable* failure mode (not
   feature-specific) into the right learnings file — engineering/mechanics findings →
   `.claude/skills/deep-feature/learnings.md`; **UI/UX/motion/copy findings →
   `.claude/skills/ironbit-design/learnings.md`** (through the `ironbit-design` skill). Update an
   existing category over a near-duplicate, and respect each file's line cap. Feature-specific
   findings stay in the plan doc as before.

*Artifacts: approved plan; analyze/test output; review verdict; learnings.md updated or
"no generalizable findings" noted.*
