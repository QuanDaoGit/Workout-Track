# IMPLEMENTATION — the animations & how to build them

Source of truth: `reference/Returned.html` (search the `HOMECOMING` block in the
last `<script>`). This doc is the spec; the file is the working web reference.

There are **two distinct beats**, room first:

- **Homecoming** (presentation): "BIT comes home" — plays on open when a haul is waiting.
- **Report ceremony** (the receipt): "here's what he found" — fires on COLLECT.

The data is safe by construction: gems are already settled durably on open
(`settleAndPeekReport`). The report stays *unviewed* until COLLECT actually shows
it — so skipping the beat or killing the app mid-animation loses/double-pays
nothing. The room beat is pure presentation on top of the existing settle/reveal split.

---

## 1 · The two pad-light engines now take a control handle

Both engines still run their own ~14fps auto-loop (chunky on purpose). The change
for the homecoming: `init()` now **returns a handle** so a sequencer can drive them.
The existing cyan auto-behaviour is the default — other screens are unaffected.

### `bitpad-light.js` — the floor pool (the "underglow signature")
```js
const light = BitPadLight.init(canvas, {cols,rows,cx,cy,rx,ry,ryUp,fps});
light.set({ tint: 0..1, scale: 0..1 });   // tint 0=cyan (home), 1=magenta (haul); scale dims it
light.reset();                            // back to cyan auto
```
`tint` lerps the dither ramp **cyan → magenta** (magenta ramp keyed to `gem.png`:
`[150,28,140] · [224,40,160] · [255,77,205] · [255,150,230]`). `scale` multiplies
the auto flicker so the pool stays **under BIT's lens**.

### `bitpad-beam.js` — the rising beam
```js
const beam = BitPadBeam.init(canvas, {cols,rows,apexX,apexY,topY,...});
beam.set({ scale: 0..1, topY01: 0..1 });  // scale=intensity; topY01=1 retracts the beam INTO the emitter
beam.reset();
```
`topY01` pulls the beam's fade-top down toward the apex (the emitter), so the beam
**withdraws into the pad** instead of merely dimming. `scale` is the brightness.

> Reduced-motion: both engines freeze to a lit still and `set()` redraws that
> still — the handle still works, there's just no loop.

---

## 2 · Homecoming timeline (~1.9s, skippable, reduced-motion → instant)

Mirrors the launch in reverse (down-and-home ↔ up-and-away). One `requestAnimationFrame`
loop reads `elapsed` and drives every layer. Phase windows (ms):

| phase | window | what happens |
|---|---|---|
| **0 · Anticipation** | 0–200 | Empty, lit "out" dock. A faint brighten at the ceiling fixture (`brightness()` pulse) — "something's coming." Beam dim cyan, coffer hidden, BIT off-screen above. |
| **1 · Descent** | 200–1000 | BIT drops from `dy −230 → 0` with **ease-out cubic** (`1−(1−t)³`), opacity `0→1` over the first 150ms. The beam stays cyan but **withdraws** (`topY01 0 → 0.65`) as he rides it down. A bright **magenta payload mote** travels with BIT. *No bouncy easeOutBack — a landing with gravitas.* |
| **2 · Deposit** | 1000–1500 | First ~36%: the mote drops from BIT to the emitter mouth (ease-out), beam finishes withdrawing (`scale→0, topY01→1`). Then: a **magenta bloom** (ring of pixel sparks + core flash) and the dock **fabricates** the coffer **bottom-up** (reveal `BUILD` blocks over progress). Underglow **tints cyan→magenta** (`light.set({tint: fp})`). A **1px seat dip** as it seats. |
| **3 · Settle + hold** | 1500–1900 | Coffer fully built & sealed, magenta bleeding through its vents. BIT holds his float (his own idle bob takes over). The **COLLECT** chip fades in (`opacity 0→1`). |

Then it rests in the static returned state.

**BIT** is driven by two CSS vars on his host (`--bit-dy`, `--bit-op`) so his
internal idle/blink/bob keep running inside the canvas while the host translates.
On settle, call nothing special — the engine's idle hover continues.

**Skippable:** a capture-phase `pointerdown` on `document` during the beat jumps
straight to the settled state (`setSettled`). A 400ms guard stops that same tap
from also triggering COLLECT.

**Reduced motion:** skip phases 1–2 entirely — render the settled state
immediately (BIT floating, coffer on pad, magenta underglow, COLLECT visible) and
push a polite `aria-live` announcement: *"BIT has returned with a haul."*

---

## 3 · COLLECT → report → coffer-gone (reverses the homecoming)

On COLLECT (tap the coffer hit-area or the chip), in parallel over ~620ms:

1. **Dissolve** the coffer: drop its 2×2 blocks in random order (chunky pixel
   dropout), lift `translateY(−10·t)` and fade out over the last 45%.
2. **Magenta gem particles** burst upward from the coffer.
3. **Reverse the pad signature** as it dissolves: `light.set({tint: 1−t})`
   (magenta→cyan) and `beam.set({scale: t, topY01: 1−t})` — the **cyan beam
   re-emerges** from the emitter. This is the "beam crossfade" toggle: haul shown
   → beam 0 + coffer at emitterY; collect → beam returns.
4. **Report ceremony:** the "HAUL CLAIMED · +15 ◇ GEMS · +120 XP" toast fades in
   (~1.7s), the gem resource counter **counts up** 0→15.
5. **BIT** spins/cheers (`bit.spin()`).
6. On finish: coffer + chip are removed (`room.collected`) — **nothing lingers
   empty** — and the pad rests on its cyan home signature.

Persisted in `localStorage.ib_haul` (`'collected'` vs anything else = waiting), so
a reload shows the right state; **Replay Haul** clears it and re-runs the beat.

---

## 4 · Flutter port notes

- **Coffer:** port `engine/coffer-paint.js` to a `CustomPainter` — the `drawRect`
  ops map 1:1 (every `p.px/rect` is a `canvas.drawRect` in native cells; scale the
  cell size by an **integer** factor). Key it on `(routeSeal, dropped blocks)`.
  Provide a painted `errorBuilder` even if you later add a PNG.
- **Two pad lights:** the dither algorithm in `bitpad-light.js` / `bitpad-beam.js`
  is the spec — port it to a `CustomPainter` (ordered Bayer dither, 4 tiers) or
  play pre-rendered pixel frames. Drive `tint`/`scale`/`topY01` from your
  `AnimationController`s. **Do not** swap them for a `BoxDecoration` radial
  gradient — that reads as generic glow and breaks the arcade look.
- **Sequencer:** one `AnimationController` (1900ms) with an `Interval` per phase,
  ease-out cubic on the descent. Gate phases 1–2 behind
  `!MediaQuery.disableAnimations`; otherwise jump to settled + a `Semantics`
  announcement.
- **Tokens:** pull magenta/cyan/amber, radius, fonts, timings from
  `tokens.dart` / `colors_and_type.css`. Add the magenta gem ramp to tokens if
  it isn't there yet, then reference it — don't hardcode duplicates.
- **Throttle** the light loops to ~14fps and pause them when Home is off-screen /
  backgrounded.
