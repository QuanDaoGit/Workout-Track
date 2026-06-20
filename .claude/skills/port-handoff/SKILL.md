---
name: port-handoff
description: Port/adapt an existing design-asset-animation HANDOFF — a folder/package of runnable reference + engine source + spec docs + assets — INTO the Ironbit app faithfully, changing ONLY what the user named. Use whenever the user points you at a handoff/prototype/reference to bring into the app — "port this", "port the folder", "implement what's in <folder>", "adapt this design/sprite/animation into the app", "use the handoff", "I just need to change X (the colour/size), keep everything else" — especially when a complete or runnable reference exists. Direction matters: this CONSUMES a handoff into the app; it is NOT for generating a handoff spec from a design (that is `design:design-handoff`). Exists to counter a documented coding-agent bias — re-building/over-engineering/approximating things the handoff already fully specifies. Routes genuinely-new surface look/feel to `ironbit-design` and the handoff-silent state/data model to `deep-feature`.
---

# Port Handoff

You are **consuming** a handoff (runnable reference + engine source + assets) **into the app** — porting
it. (If instead you're *producing* a spec from a design, that's `design:design-handoff`, not this.) A
complete handoff is a **specification to port**, not inspiration to reinterpret: the design decisions are
**already made**, and your job is **translation fidelity**, not creativity.

## Why this skill exists (read first)

Your **default bias is the failure mode.** Coding agents measurably "over-engineer straightforward
problems" and "write custom code for pre-existing functions instead of reusing" them — re-building what
was handed over, for nothing. On the Ironbit BIT-expedition handoff this fired **three times in a row**
(hand-painted a fake hologram instead of post-processing BIT's *real* sprite; wrote a 1-phase fly-up
instead of the 5-phase launch; *inverted* the beam's control model by guessing it) — each caught only
when the user pointed at the screen. The user asked to change **colours**; everything else was already
correct and should have been ported untouched.

## THE GATE (blocking — this is what actually stops the failure)

**You may not write or edit ANY handoff implementation — rendering, animation, the *control model*,
state/data integration, assets, *or* platform-adaptation code — until the conversation contains both,
in text:**

1. **An inventory table** — every source *file → function/effect/asset/control-parameter* in the
   handoff, each tagged layer 1/2/3/silent (below). Each layer-1 mechanism **cites the source file +
   function** that defines it (e.g. "beam → `bitpad-beam.js` `set({scale,topY01})`").
2. **A delta contract** — *"What the user asked to change: …"* and *"What must stay identical: …"*.

If you're about to implement **any** of it and these two artifacts don't exist yet, **stop and produce
them first.** No mental summary substitutes. All three motivating failures happened in the gap this
gate closes — the agent started coding from an impression instead of the source (and the worst one,
the beam, was *control-model* code, not paint code — which is why the gate covers everything).

## The one stance: translate, don't re-decide

A complete handoff is the **single source of truth that removes the need to ask** (a reference
implementation is the *gold standard you measure your output against*). So:
- The look, motion, timeline, and **control model** are the **spec** → reproduce them.
- If you catch yourself **guessing** a mechanism ("a send-off beam should look like…"), you have not
  yet **found where the handoff defines it** — read the source. It is almost always there.
- **Chesterton's Fence:** do not change/simplify/replace anything until you understand why it is that
  way. The art and motion are the spec, not a starting point.

## The three layers (classify every inventory item — each wants the OPPOSITE mindset)

| Layer | What it is | Mindset | Output |
|---|---|---|---|
| **1 · Design surface** | look · motion · timeline · behaviour · the **control model** | **Translate verbatim** | a faithful port |
| **2 · Platform mechanism** | *how* it's coded (canvas, `rAF`, `getImageData`, CSS) | **Adapt idiomatically + verify equivalence** | same behaviour, app's stack |
| **3 · Named delta** | what the user *explicitly* asked to change | **The only place for a new decision** | the requested change, scoped |
| **(silent)** | what the handoff does **not** cover (e.g. the data/state model) | **Genuine design** → `deep-feature`/`ironbit-design` | a well-designed addition |

- Layer 2 adaptation is **legitimate and required** — `canvas`→`CustomPainter`, the `rAF` loop→an
  `AnimationController`/shared ticker, `getImageData`/`putImageData`→clipped repaint passes,
  `source-atop`→`BlendMode.srcATop`. Faithful ≠ blind transliteration: a literal port can silently
  diverge, so an adapted mechanism is **verified semantically equivalent**, and the source's own
  *removed/"simplified"* bits are honoured (port the **shipped** version, never resurrect removed code).
- **The control model is layer 1**, not layer 3 — a parametric engine (`set({scale, topY01})`) is part
  of the spec; port its parameter *semantics* exactly, never invent your own param. (The beam bug was
  exactly this miscategorisation: a layer-1 control model treated as a free layer-3 decision.)
- The data-model work on the expedition succeeded *because* the handoff was **silent** there — real
  layer-3 design, correctly routed through `deep-feature`. Knowing which layer you're in is the skill.

## Precedence when the handoff conflicts with the app (don't slavishly port into a defect)

Faithful is the default, **not** absolute — but a layer-1 deviation is a **decision the user owns**,
never one you make under a policy banner:
1. **True blockers auto-adapt (and are recorded), no approval needed:** accessibility / reduced-motion,
   determinism, and platform/build/runtime viability. If one *forces* a layer-1 change (the handoff's
   perpetual ticker has no reduced-motion still), adapt to the app's documented pattern and **record
   the deviation** in your notes.
2. **Every OTHER layer-1 visual/control deviation needs explicit user approval** — *including* applying
   a style policy (tokens-only colour, sharp icons) in a way that changes an L1 surface's
   appearance/behaviour. Surface it and **ask**; do not silently re-faithful-fy it behind a
   "compliance" banner (that is the opposite failure — design drift hidden as policy).
3. **Reality:** a referenced asset/font/codec the app lacks, or a verbatim port too costly to run —
   surface it and propose the nearest faithful substitute; don't quietly drop it.
4. **The handoff can be wrong/stale:** if a folder holds multiple versions, or source contradicts docs,
   the **runnable/shipped source is authority** over the prose; a *suspected bug* is surfaced, never
   faithfully reproduced nor silently "fixed".

Everything else (taste, "cleaner", "simpler") is **not** a licence to deviate.

## Pipeline

**0 · Read the SOURCE, not the summary.** Open **every file**, in priority of authority: runnable
reference (open/run it if you can) > engine source (the actual code) > spec docs
(`PIXEL-SPEC`/`IMPLEMENTATION`) > prose `README`. The prose *describes*; the code *defines*. → build the
**inventory** (the gate).

**1 · Classify + bound scope.** Layer-tag the inventory; write the **delta contract** (the gate). Empty
delta ("just port it") = port everything, invent nothing. Ambiguous delta ("make it ours") = **ask**.

**2 · Port + adapt.** Translate layer 1 verbatim via idiomatic layer-2 mechanisms; apply **only** the
layer-3 deltas. Reuse the app's **real asset** for derived effects (a hologram = the real sprite
*post-processed*, not a look-alike redraw; reuse the real beam/light engine + palette). Prefer the
handoff's **own shipped assets** — declare each in `pubspec.yaml` (asset dirs are non-recursive) with an
`errorBuilder` fallback, integer-scale pixel art. Extract shared code only after the original's golden
stays **byte-identical**.

**3 · Verify against the REFERENCE, not yourself.** Fidelity = *does it match the handoff*. If the
reference runs **here**, compare side-by-side. If it can't, do **conformance against the source's exact
values** — diff your ported constants/draw-order line-by-line. **For animation that's not enough:**
build a **timeline matrix** — per phase, the *timestamps · easing · state transitions · draw order ·
control-param ranges · expected visual checkpoints* — and reconcile each against the source. Goldens
prove static frames *render*, not that motion *matches*; any motion you couldn't verify is a **named
residual risk + on-device sign-off gap**, not "passed". Re-read the delta contract; confirm nothing
outside it drifted.

**4 · Reflect** any generalizable porting failure into `learnings.md`.

## Red flags — the over-scope bias firing (STOP and re-read the source)

| Thought | Reality |
|---|---|
| "I'll make it a bit cleaner / better" | Re-deciding a settled thing. Not your call here. |
| "This is roughly what the handoff means" | Approximating. Open the actual source. |
| "A {beam / burst / …} should look like X" | Guessing a mechanism the handoff already defines. |
| "I'll simplify / drop this part" | The handoff already chose. Port the shipped version. |
| "Let me paint this effect from scratch" | Can you post-process the **real** asset instead? |
| "The summary says enough" | The summary describes; the code defines. Read the code. |
| "It looks fine in my golden" | Fine ≠ matches the reference, and a golden can't see motion. |

## Relationship to other skills
- **`deep-feature`** is the pipeline; **`port-handoff`** is the **discipline for its implement stage
  when a handoff is the input.** Codex reviews the **port plan** — the inventory + layer table + delta
  contract + the adaptation choices — not just the diff. (`design:design-handoff` is the *opposite*
  direction — generating a spec *from* a design — and is never used for porting *into* the app.)
- **`ironbit-design`** owns the look/feel of **layer-3 / silent** surfaces (genuinely new design). Hand
  it those; never let it (or yourself) re-style a layer-1 surface the handoff already specified.
- A handoff that is only a loose mockup/screenshot (not code-backed) is **mostly layer-3** — interpret
  via `ironbit-design`, but still inventory it and hold the delta contract.

## Learn from past mistakes
Read `learnings.md` before porting; check the work against every category. End the task stating
**"No new handoff learning"** or the category you touched.
