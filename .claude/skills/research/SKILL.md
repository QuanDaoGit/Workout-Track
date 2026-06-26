---
name: research
description: Field-detecting research engine for the Ironbit workout app — you are the primary researcher, Codex is the evidence reviewer. Use when the user asks to research / look into / find evidence or precedent for something, asks "is there science on X", "how do other apps (Strong / Hevy / Duolingo) do Y", or needs domain / competitor / behavioral / UX / technical / safety evidence to ground a decision. It auto-detects which field(s) the question belongs to and how deep to go, so the user doesn't have to specify the field or the technique. This is also the engine `deep-feature` Stage 2 routes to. Defers in-app visual questions to `ironbit-design`.
---

# Research (Ironbit)

You are the **primary researcher**; **Codex is the adversarial reviewer of the evidence** (not the
author). This skill is tuned to a **workout / RPG app**, not generic academia — it knows the app's
recurring fields, their best sources, and their evidence bars. Be **token-efficient** by picking the
lowest *defensible-up-front* tier, but never trade away accuracy or breadth on a decision that matters.

Two reference files hold the bulk (load on demand, keep this file lean):
- `references/field-map.md` — the field router: signals → field → sources → query idioms → evidence bar.
- `references/techniques.md` — the craft: operators, SIFT/lateral reading, decomposition, the
  contrary-evidence guardrail, saturation/satisficing.

## Before anything — reuse check
Check what we already know first: `research/insights.md`, prior `docs/` plan/spec docs, and memory.
**Don't re-research a settled fact.** Cite the existing finding and move on.

## Stage 0 — Scope & classify
1. **Restate** the question in one line.
2. **Detect field(s)** by matching the problem against `references/field-map.md`. Most app questions
   **blend 2+** fields — weight effort across them. **Safety/clinical is an overlay** that can fire
   alongside any field.
3. **Pick a depth tier by an up-front, observable rule** (not "lowest that answers accurately" —
   that's only knowable after the fact and biases toward false-Quick):
   - **Quick** — *only* a non-persistent fact check answerable from repo docs or **one** primary
     source (e.g. "typical beginner bench 1RM?"). Quick still runs a **cheap integrity check** (see
     Stage 6). **Auto-upgrade to Standard** the instant a durable decision, a Safety/clinical
     implication, or contrary evidence appears.
   - **Standard** *(default)* — **any** feature-shaping, persisted, competitor, behavioral, or
     cross-field question.
   - **Deep** — **required** for Safety/clinical, contested evidence, core-loop / progression /
     habit-loop decisions, monetization, architecture, or a claim meant to justify a doctrine change.

## Stage 1 — Decompose (Standard / Deep) — a bounded, hypothesis-pruned issue tree
The output is **3–7 field-tagged searchable leaves**. Get there by *pruning* a tree, not *completing*
one — efficiency comes from the prune, never the coverage (see `references/techniques.md`).

**Skip the tree** when the question already yields **≤3 directly searchable leaves** — just tag them
and go (most shallow/blended app questions). Otherwise:
1. **Expand one level** — list the question's candidate dimensions (e.g. "appearance" → silhouette /
   simplicity / reuse). Don't recurse yet.
2. **Score & prune each**, one line of reason: **known** (→ reuse, don't search) · **not
   load-bearing** to the decision (→ drop) · **uncertain *and* decision-relevant** (→ keep).
   Concept-completeness is *not* the goal — decision-relevance is.
3. **Deepen only** a kept branch that **can't be settled by one targeted query/source pass**, and
   **at most one recursion by default**. A leaf is *done* when it names a specific
   artifact / behavior / user-segment / decision-criterion **+ one searchable evidence type**.
4. **Coupled branches:** if dimensions clearly interact, add a **cross-cutting leaf** rather than
   forcing a clean split (decomposition assumes separable parts — an analogical caution, not a law).
5. **Show the work:** the candidate dimensions, each keep/prune decision, and the final field-tagged
   leaves. (This visible delta is what keeps it from being a renamed sub-question list.)

## Stage 2 — Search
Per sub-question: formulate **operator-aware queries** (`references/techniques.md`) and **route to the
right tool**:
- **context7 MCP** → Flutter / library / package / platform-API docs (precise, cheap — prefer over crawling).
- **WebSearch** → web/domain knowledge; lean on the result *summaries*.
- **App stores / Reddit / the product itself** → competitor teardowns (the app is the primary source).
- **WebFetch** → only to read a full page for a **load-bearing or contested** claim.

Search **breadth-first**, then **depth** on the thread that matters. **Parallelize** independent
searches in one message. Iterate queries from what the last results taught you.

## Stage 3 — Evaluate (SIFT-first)
**SIFT:** Stop → Investigate the source → Find better coverage → Trace to the original. Apply the
**field's evidence bar** (exercise-science → review/RCT over a blog; competitor → the app itself;
behavioral → peer-reviewed over pop-sci). **Lateral-read** anything shaky. **Never single-source a
load-bearing claim — triangulate ≥2 independent.**

**Contrary-evidence guardrail (Standard / Deep):** for every load-bearing claim, run **≥1 targeted
dissent/limitation query** and trace **≥1 primary source** (not a summary echo) — agreement across
similar *secondary* sources is **not** saturation. For exercise/behavioral studies, capture
**demographic validity** (trained vs untrained, sex, age) and **recency**.

## Stage 4 — Stop at saturation / aspiration
Stop **only after** the contrary searches are recorded and new searches stop adding load-bearing
facts (or the tier's bar is met). Name the diminishing-returns call — but **never declare saturation
before the dissent query exists.**

## Stage 5 — Synthesize
Findings **grouped per sub-question**. Each = a **markdown-linked claim + evidence grade + confidence
+ the tension/caveat**. Separate **established / contested / single-source**. Surface conflicts and
the recurring **accuracy-vs-hook** tension. Judge every finding against the app's lenses (body-neutral
mandate, soul doctrine, offline/private wedge — see `references/field-map.md`, which points to the
canonical docs).

## Stage 6 — Codex review of the evidence
- **Standard / Deep:** hand Codex the **synthesis + a compact search audit** so it challenges
  *coverage*, not just wording. The audit lists **queries run, source types inspected, sources
  rejected (with reason), summary-only/unfetched claims, known gaps**. Ask it to CHALLENGE: missing
  fields, source bias/quality, overgeneralized claims, ignored conflicting evidence, stale recency,
  weak query coverage, conclusion-doesn't-follow. Per `.claude/codex-local.md`: carry **all** findings
  in the prompt (sandbox can't read the repo), scope `--scope branch --base HEAD`, end with a numbered
  CHALLENGE list. Resolve gaps → maybe one more search loop.
- **Quick:** skip Codex; instead run the **cheap integrity self-check** — list assumptions, the source
  count, flag any single-source claim, and pose one "what would change my mind?" query. If a durable
  decision, safety implication, or contrary evidence surfaces, **upgrade to Standard** and run Codex.

> This pass reviews the **evidence**. It does **not** replace `deep-feature` Stage 4, which reviews
> the **opinion/plan**. The two passes never substitute for each other.

## Stage 7 — Output & persist
Deliver a **research brief** (the Stage-5 synthesis) that either feeds `deep-feature` Stage 2 or
stands alone. Then persist per the resolved default:
- **Durable competitive/behavioral findings →** `research/insights.md`, tagged
  `[validated]`/`[assumption]`/`[risk]` and **tied to a decision** (per `research/CLAUDE.md`).
- **Cross-cutting facts →** memory.
- **Ephemeral feature-research →** stays inline / in the feature's plan doc.

## Token-efficiency (a goal, not an afterthought)
- **Tier-gate** — never deep-dive a Quick lookup; satisfice to the tier's bar.
- **Reuse before search** — insights.md / plan docs / memory first.
- **Right-tool routing** — context7 for libs over crawling; WebSearch summaries over WebFetch unless load-bearing.
- **Breadth-first, shallow** — parallel searches; fetch deep only on the thread that matters.
- **Triangulate to ~2–3 strong sources** per claim, not ten; stop at real saturation.

## Relationship to other skills
- **`deep-feature`** is the feature *pipeline*; **`research` is its Stage-2 evidence engine.** Research
  owns field routing, evidence grading, the Codex-review-of-evidence, and persistence candidates;
  deep-feature may add product acceptance criteria but **must not redefine the evidence bar.**
- **`ironbit-design`** owns in-app visual/UX *look*. Hand it anything about how a surface should look
  or feel; this skill researches UX *evidence/precedent*, not the pixels.

## Reflect — the self-growth engine (gated; this is what makes each use better)
The skill compounds the way effective agents do — verbal self-critique persisted across runs
(Reflexion) + an ever-growing reusable store (Voyager's skill library) — **without churning noise**.
Growth is **conditional**: most runs add little, and stating that is itself the gate that stops the
stores from rotting.
- **Persist durable findings →** `research/insights.md` (tagged, tied to a decision + doctrine).
  **Reuse-first** at Stage 0 next time is the actual compounding — later questions start from
  accumulated knowledge, not zero.
- **Distill a *generalizable* failure mode →** `learnings.md` — update an existing category over a
  near-duplicate, respect the cap, prune the least-recently-fired when full; generalize, don't
  transcribe.
- **Grow the field map** (`references/field-map.md`) **structurally only** — a genuinely new field, a
  routing rule, or a question template; the auditing brain gets richer over time, but **never** add
  dated sources or stale-flags here (that decays the reusable menu into a time-sensitive registry —
  dated evidence lives in `insights.md`). Most runs touch nothing here, and that is correct.
- **Self-score the run** — coverage · recency · app-grounding · contrary-evidence · Codex-resolution ·
  decision-tied — and name the **single weakest dimension + one concrete fix** as next time's focus.
  Anchor the score to the **Codex 2.3 / Stage-6 findings** (an external signal), not a vanity
  self-grade — the rubric's only job is to surface the weakest link to improve, never to congratulate.
- End with **"no growth this run"** when nothing qualified — the visible gate is the point.
