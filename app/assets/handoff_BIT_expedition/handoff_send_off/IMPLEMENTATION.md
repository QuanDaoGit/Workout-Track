# IMPLEMENTATION — Send-off & Hologram

Source of truth: `reference/Returned.html` (search `LAUNCH / SEND-OFF` and
`BIT HOLOGRAM` in the last `<script>`). Portable hologram module:
`engine/holo-bit.js`.

Scene coords used below (room-space px): emitter axis `EX = 185`, emitter mouth
`EY ≈ 392`, BIT rest centre `BY = 340`.

---

## 1 · The two pad-light engines take a control handle

Unchanged from the homecoming package — repeated here because the launch drives
them. Both still run their own ~14fps auto-loop; `init()` returns a handle:

```js
const light = BitPadLight.init(canvas, {…});
light.set({ tint: 0..1, scale: 0..1 });  // tint 0=cyan(home) 1=magenta(haul); scale dims
const beam  = BitPadBeam.init(canvas, {…});
beam.set({ scale: 0..1, topY01: 0..1 }); // scale=intensity; topY01=1 retracts beam INTO emitter
```

---

## 2 · LAUNCH / SEND-OFF timeline (~2.0s, skippable, reduced-motion → instant away)

One `requestAnimationFrame` loop reads `elapsed` and drives every layer. The
ascent is **ease-IN** (the mirror of the homecoming's ease-out descent) so it
reads as a launch, not a fall.

| phase | window (ms) | what happens |
|---|---|---|
| **0 · Charge** | 0–350 | Emitter spins up: the pixel pool brightens (`light.scale 0.6→1.1`), beam ramps. BIT eases into a **6px wind-up crouch**. Charge sparks are pulled *inward* toward the emitter. |
| **1 · Pad burst / ignition** | 350–520 | A cyan **radial burst** rings off the emitter mouth (+ core flash). BIT springs out of the crouch. Pool **flares** (`scale→1.3`). The **pad takes a 1px recoil kick** (`translateY` sine). |
| **2 · Ascent** | 520–1250 | BIT **accelerates up the beam**: `dy = −490·a²` (ease-in), fading out over the last 30%. Vertical **speed-streaks** + a **vapor trail** follow him. Beam holds bright; pool dims as he leaves. |
| **3 · Beam-exit pop** | 1250–1450 | BIT is gone off the top. A **burst** pops where he exits; the beam shows a bright band, then begins to collapse (`topY01→0.6`). |
| **4 · Collapse + rest** | 1450–2000 | Beam withdraws into the emitter (`scale→0, topY01→1`); pool settles to a dim, calm **rest** level. End state = **AWAY** (empty lit dock) → the hologram starts. |

- **Skippable:** a capture-phase `pointerdown` jumps to the away state.
- **Reduced motion:** skip phases → `setAway()` immediately + an `aria-live`
  announcement *"BIT has set out on an expedition."*
- On `setAway()`: the real BIT host is hidden (`--bit-op:0`), the coffer/pill are
  hidden (`room.away`), the gravity beam is withdrawn, and **`startHolo()`** runs.

---

## 3 · HOLOGRAM (away state) — `engine/holo-bit.js`

While BIT is away the dock shows a holographic projection of him. It is **not** a
glowing cone — it's a structured **projection rig** plus a post-processed BIT.

### Two canvases, layered
- `holoCanvas` (≈112×112, **z above** the rig): the hologram of BIT.
- `fxCanvas` (room-sized, **z below** the hologram): the rig.

### The projection rig (`drawRig`, on fxCanvas)
All ordered-dither (Bayer 4×4), cyan tiers `#1c6e92 · #2bb2dc · #57dbff`, framed
by `#7cf2ff` brackets. Volume runs `emY → topY` with half-width `30 → 38`.
1. **Emitter field** — a dithered, pulsing data-band at the pad mouth (the source).
2. **Containment brackets** — pixel corner frames top & bottom with cyan ticks and
   a faint cross-rule (the "rig" that frames the projected volume).
3. **Scan-planes** — two horizontal dithered lines sweeping **up** the volume,
   brightest mid-travel — the hologram being continuously refreshed.

> Earlier iterations also had a center scan-axis, a convergence node, and a
> waveform crest at the base; these were **removed** to simplify. If you want them
> back they're in git history / the homecoming-era notes — but the shipped look is
> just field + brackets + scan-planes.

### The hologram of BIT (`drawBit`, on holoCanvas)
Built by sampling BIT's **live** sprite canvas (`window.__bit.el`) every frame, so
his idle bob/blink keep playing inside the hologram. Then, in order:
1. Draw BIT at **integer ×2**, transparent (~0.44) with a breathing flicker.
2. **Cyan tint** via `source-atop` (BIT pixels only).
3. **CRT scanlines** every 2px.
4. A sweeping **roll bar**.
5. Occasional **glitch slice** — a horizontal band offset by a few px
   (`getImageData`/`putImageData`).
+ subtle vertical **jitter**.

### Power / lifecycle
- `start()` — show + power-on **fade** over ~450ms, begins the ~20fps loop.
- `stop()` — tear down (called by homecoming/launch/collect when leaving away).
- **Reduced motion** → a single static holographic still (no flicker/glitch/roll).
- Loop is **~20fps** (chunky on purpose) — throttle further / pause off-screen.

```js
const holo = HoloBit.create({
  holoCanvas, fxCanvas,
  bitCanvas: () => window.__bit.el,
  ax: 185, emY: 390, topY: 286,
  reduceMotion: matchMedia('(prefers-reduced-motion: reduce)').matches
});
holo.start();   // on entering AWAY
holo.stop();    // on BRING HOME / SEND / COLLECT
```

---

## 4 · Flutter port notes

- **Hologram:** render BIT's sprite to an offscreen image each tick, then run the
  post-process as layered `Canvas` ops (or a fragment shader for tint/scanline/
  roll — the glitch slice is a per-band src-rect offset). Draw at an **integer**
  scale. The rig is a `CustomPainter` (ordered-dither emitter field + bracket
  rects + sweeping scan-plane rects), painted **behind** the hologram.
- **Launch:** one `AnimationController` (~2000ms) with an `Interval` per phase;
  **ease-in** (`Curves.easeInQuad`/`a²`) on the ascent. Particles in a lightweight
  pool. Gate phases behind `!MediaQuery.disableAnimations`; else snap to away +
  `Semantics` announcement.
- **Lights:** port the two dither engines as `CustomPainter`s driven by your
  controllers (`tint`/`scale`/`topY01`). Don't swap them for `BoxDecoration`
  gradients — that reads as generic glow and breaks the arcade look.
- **Throttle** every loop to ~14–20fps and pause when Home is backgrounded.
- **Tokens:** pull cyan/magenta, fonts, timings from `colors_and_type.css` /
  `tokens.dart`; don't hardcode duplicates.
