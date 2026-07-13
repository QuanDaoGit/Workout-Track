# Port-handoff learnings — recurring porting failure modes

Maintenance gate (per task): read this before porting; after, add **at most one** learning, and only if
it would have prevented a concrete defect or a repeated review finding. **Generalize, never
transcribe** — an entry is a reusable category. Search the headings first and **update the matching
category over appending a near-duplicate**; include the date/trigger. Cap ~36 content lines below this
header; when over, prune the least-recently-fired category **in the same edit**. End the task stating
"No new handoff learning" or the category you touched.

### Source over summary
**Rule:** Read the **engine source + the runnable reference** before forming any plan — never decide
from the prose `README`/`IMPLEMENTATION` alone. The summary *describes* an effect; the code *defines*
it (exact params, palette, timing, draw order). Open every file; **notice commented-out / "removed" /
"simplified" sections and port the *shipped* version**, never resurrect removed bits. *Seen: the away
hologram + send-off were built from the summary docs → approximations; re-ported only after reading
`holo-bit.js` / `playLaunch` (2026-06).*

### Translate, don't reinterpret (reuse the real asset)
**Rule:** A complete handoff is the spec — reproduce the look/motion/timeline, don't paint your own
version. For a **derived effect, post-process the app's REAL asset** (a hologram = the real sprite
tinted/scanlined, not a hand-redrawn lookalike; reuse the real light/beam engine + palette), and replay
a multi-phase beat **beat-for-beat**, not as a simplified single move. When the handoff **cites a shared
value as "matching" another component** (a token / colour / coord), honour the *intent* and **reuse the
app's ACTUAL value** — verify the citation, the author may have mis-referenced it. *Seen: a hand-painted
hologram blob → BIT's real sprite post-processed; a 1-phase fly-up → the full 5-phase launch; the
quest-board's "cyan = pad LED #30bee8" cited a stale hex → used the real pad `bitGlow` #17D6CC so the
board reads as one system (2026-06).*

### Read the control model, don't guess it
**Rule:** When the handoff ships a **parametric engine** (e.g. `beam.set({scale, topY01})`), port its
parameter *semantics* exactly — `topY01:0` was the beam's *max* height (fades before BIT); guessing
"launch = extend to full height" **inverted** it. If you're inventing how a control behaves, you haven't
found where the source specifies it. *Seen: the send-off beam shot up the screen on a guessed `launch`
param → replaced with the real `scale`(brighten-in-place)/`topY01`(retract) model (2026-06).*

### Scope to the named delta (the delta contract)
**Rule:** Write down *what the user asked to change* and *what must stay identical* before editing;
everything outside the delta list is preserved verbatim (Chesterton's Fence). A request to "change the
colour" is **not** licence to re-decide placement, form, timing, or mechanism. Re-deciding a settled
thing = the over-scope bias firing. **Check the app's *existing* port first** — a handoff beat may be
**partly shipped already**; add only the **missing dynamic as a superset that collapses to the shipped
static at its rest value** (the existing golden then stays **byte-identical**, proving you added without
disturbing), never re-port the whole engine. *Seen: "just the colours / drop the per-route seal" treated
as a from-scratch rebuild across coffer/hologram/send-off/beam; the hologram **ignition** was added as a
superset over the already-shipped steady projection (`ign=1` ⇒ identity, golden unchanged), `DELAY 2000→
1000` the only delta (2026-06).*

### Adapt idiomatically + verify equivalence against the reference
**Rule:** Platform translation is legitimate (`canvas`→`CustomPainter`, `rAF`→`AnimationController`,
`getImageData/putImageData`→clipped repaint passes, `source-atop`→`BlendMode.srcATop`) — but a literal
transliteration can silently diverge, so **verify the adapted mechanism is semantically equivalent** and
**compare the output against the runnable reference, not against your own prior frame** (fidelity = match
the source). Extract shared art behind one entry point and prove the original golden stays
**byte-identical** before building on it. **Even a "same" stdlib primitive can differ** — verify its
exact semantics, don't assume. **An effect defined in a sprite's NATIVE pixel coords** must be overlaid
on the **same display box** as the host sprite (so it scales by the *identical* mapping and tracks 1:1
even under a non-integer stretch) **and use the handoff's OWN sprite those coords were measured against**
— a divergent app copy of the asset drifts the effect off its target. **A celebration handoff authored
for a LARGE stage, placed at a small inline slot (a placement delta), keeps fidelity by painting in the
design-space + `canvas.scale` (FX track the sprite 1:1) — but its fine pixel FX won't *read* at icon
scale, so the spectacle must come from a robust app-level effect (reuse the real gem-flight/particle
layer), not the shrunk burst; and DON'T anchor a transient full-size overlay to a scrolling list
position (it detaches under scroll / when the anchor is off-screen) — animate IN-PLACE tied to the
widget (`RepaintBoundary`, one-shot `AnimationController`).** **A rAF prototype's per-frame ORDER is
part of the spec:** it computes the frame's transform in `evaluate(t)` *before* `stepFX` spawns
particles at that position; splitting the port so the transform lands in Flutter's *build* while the
spawner runs in the *tick* reads a stale/zero position (a corner-spawned spark) — keep evaluate-order
side effects together in the ticker callback, and let build only consume their stored results
(2026-07, session ceremony thrust trail). *Seen: the glitch slice ported as
three clipped passes (band shifts, no double-draw); the sprite extraction gated on a byte-identical
companion golden; Dart `.round()` (ties away from zero) silently diverged from JS `Math.round`
(ties → +∞) at the hover-bob trough → ported as `(x+0.5).floor()`; the pad charge-meter (native
x25–82) overlaid on the pad box + the pad swapped to the handoff's own sprite so the LED lands on the
strip (2026-06); the 300×341 chest-open ported into a ~30px end-of-bar slot — design-space +
`canvas.scale`, the gem-flight (not the burst) carries the moment, in-place not a scroll-anchored
overlay (Codex F5, 2026-06). Porting a per-pixel canvas recolour to `dart:ui`
(`toByteData`→recolour→`decodeImageFromPixels`) is an **async** layer build; a golden of a widget
**gated behind a parent's async load** (so it mounts only at the post-`runAsync` pump) renders it
**invisible while the test still passes** → pump INSIDE `runAsync` *after* the parent settles, so the
gated child mounts and its engine callbacks fire within the real-async window (2026-06). **A ported
self-contained timer/clock stays AUTHORITATIVE + gets a watchdog — never re-couple it to an app async
resource (a video's end-event) as the source of truth, or a stall/failed load soft-locks the flow**:
the Charge Ritual reel drives the charge from an independent bounded clock (video position = best-effort
visual sync) + `finishReel()` on end/error/watchdog, so a degraded reel can't trap onboarding (Codex
F2, 2026-07).*
