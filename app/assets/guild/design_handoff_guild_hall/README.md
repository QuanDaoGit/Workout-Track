# Handoff: Ironbit — Guild Hall (animated room backdrop)

## Overview
The **Guild Hall** is the ambient backdrop that sits at the top of the Ironbit "Guild"
screen — a dark, retro-arcade stone hall with two wall torches and teal "powered"
indicator lights. It exists to make the guild feel like a *place*, not a list. The UI
(guild crest, BIT the companion, the Weekly Cache / Guild Legends cards) is layered
**in front** of this backdrop; the center of the wall is intentionally left empty for
the crest.

The art is authentic pixel art. The motion is produced **without redrawing any art** —
it animates the existing pixels (sprite-warp + brightness-cycling). That is the core
idea the implementation must preserve.

## About the design files
The files in this bundle are **design references created in HTML/Canvas** — a working
prototype showing the intended look and motion, not production code to ship verbatim.
Recreate this in the target codebase's environment (e.g. a React `<canvas>` component, a
Flutter `CustomPainter`/`Ticker`, a Unity/Godot sprite scene, a WebGL layer, etc.) using
that project's established patterns. The PNG assets, the coordinate tables, and the
per-frame math below are the parts you reproduce exactly.

If a game engine is available, the most natural production form is: ship the **static
base image** + a small **flame sprite** (or a flame sprite-sheet) and drive the same
warp/flicker logic in the engine's update loop.

## Fidelity
**High-fidelity.** Colors, pixel positions, animation timings and easing are all final.
The room should look pixel-for-pixel like the included `guild_hall.png` at rest, and move
exactly as described.

---

## The one view: Guild Hall backdrop

- **Name:** Guild Hall backdrop
- **Purpose:** Living background for the Guild screen. Static-looking stone hall that
  subtly breathes — torches flicker, indicator lights stutter, dust drifts.
- **Aspect / size:** Source art is **1619×971** (≈5:3). The runtime renders on a
  **540×324** canvas (the source downscaled ×1/3). Display it scaled to the container
  width with **nearest-neighbour** scaling (`image-rendering: pixelated`,
  `imageSmoothingEnabled = false`). In the app it occupies roughly the **top third** of
  the screen; the dark lower band of the art is where the UI cards float.
- **Layout of the art (left→right):** outer frame border; far-left column; **left torch**
  (in the bay); a wide column; the **empty center bay** (crest goes here, in front);
  a wide column; **right torch** (in the bay); far-right column; a **tiled ledge** across
  the full width with bright teal end-caps; a large dark **foreground** below the ledge.
- **What was removed from the source:** the hanging **guild banner** (center) and the
  **console panel** (right column) were inpainted out, because the crest is rendered in
  front and the panel was unwanted. The provided base images already have both removed.

---

## Assets (in `assets/guild/`)

| File | Size | What it is | Runtime use |
|---|---|---|---|
| `guild_hall.png` | 1619×971 | Full hall, banner + panel removed, **with** the two static flames. Reference / fallback still. | Static fallback (e.g. `prefers-reduced-motion` or low-end) |
| `guild_hall_base.png` | 1619×971 | Same hall but **flame-less** (flames removed, their warm glow kept). | Source for the runtime base |
| `guild_hall_base540.png` | 540×324 | `guild_hall_base.png` downscaled ×1/3. **The runtime background.** | Drawn every frame as layer 0 |
| `flame_diff540.png` | 540×324 | The **extracted flame light** = `original − flame-less base`. Mostly black; two warm flame blobs at the torch cups. | Warped + added over the base for the live fire |
| `reference/original_reference.png` | 1619×971 | The original supplied art (banner + panel still present). Provenance only. | — |

> **How the flame asset was made (so you can regenerate at any resolution):** downscale
> both the with-flame and flame-less images to the target size, then per pixel compute
> `flame = max(0, original − base)` per channel. The result is pure additive flame light
> on black. Adding it back over the base reproduces the original exactly; warping it
> animates only the fire. In production you can instead crop the two flame blobs into a
> small sprite (or author a proper flame sprite-sheet) — the warp logic is identical.

---

## Rendering setup

- Canvas internal resolution **540×324**; CSS `width:100%; height:auto;
  image-rendering:pixelated;`. Context `imageSmoothingEnabled = false`.
- All blending of light/fire/dust uses **additive** compositing
  (`globalCompositeOperation = 'lighter'`); the base image is drawn `'source-over'`.
- **Frame clock:** a frame counter `t` (integer "tick") increments once per rendered
  frame, and the loop is **throttled to ~14 fps** (render only when `now - last ≥ 70ms`).
  Every sine/`hash` below uses `t` directly, so all speeds assume this ~14 fps cadence.
  To be frame-rate independent, drive `t = elapsedMs / 70` instead of a raw counter.
- **Per-frame draw order:**
  1. `clearRect`, then `drawImage(base540, 0,0, 540,324)` (`source-over`).
  2. For each torch: additive **glow** then the **warped flame** rows.
  3. **Embers** (additive).
  4. **Teal indicator lights** (additive).
  5. **Dust** (additive).
- **Reduced motion** (`prefers-reduced-motion: reduce`): do **not** run the loop. Draw a
  single static frame — flame drawn un-warped at brightness `0.96`, indicator lights at a
  steady `p = 0.6`, no embers, no dust. (Or just show `guild_hall.png`.)

### Helper: additive radial light `rGlow(cx, cy, R, "r,g,b", alpha)`
Radial gradient, color stops: `0 → alpha`, `0.45 → alpha*0.45`, `1 → 0`; fill the
`2R×2R` box centered on `(cx,cy)` with `globalCompositeOperation='lighter'`.

### Helper: `hash(a, b)` (deterministic pseudo-random 0..1)
`frac( sin(a*12.9898 + b*78.233) * 43758.5453 )`.

---

## Torches (the fire)

Two torches, coordinates in the 540×324 space. Each samples a rectangle of
`flame_diff540.png` and draws it back **row by row**, with each row shifted horizontally
(more at the top) — that horizontal per-row displacement is what makes it "lick".

```
flames = [
  { sx: 60,  sy: 64, w: 30, h: 44, cx: 76,  phase: 0.0 },
  { sx: 450, sy: 64, w: 30, h: 44, cx: 466, phase: 3.1 },
]
```

Per torch, each frame:
```
// brightness flicker (also the static value when motion is off)
flick = flameOn ? 0.8 + 0.2*(sin(t*0.9 + phase)*0.5 + 0.5) : 0.96

// breathing glow, additive
gr = (11 + 5*(sin(t*0.7 + phase)*0.5 + 0.5)) * glow       // glow = 'glow' prop, default 1
rGlow(cx, sy + h*0.42, gr, "255,140,64", 0.16 * glow * flick)

// warped flame: copy each source row to a horizontally offset dest row
globalAlpha = flick
for r in 0..h-1:
    topness = 1 - r/h
    off = round( sin(t*0.45 + phase + r*0.42) * 2.0 * topness
               + sin(t*0.95 + phase)          * 1.0 * topness )
    drawImage(flameImg,  sx, sy+r, w, 1,        // source row from flame_diff540
                         sx+off, sy+r, w, 1)    // dest, shifted by `off`
globalAlpha = 1
```
(`flameOn = !reducedMotion && flicker-prop !== false`. When off, draw the rows with
`off = 0` at `flick = 0.96`.)

### Embers
8 shared particles; each spawns from a random torch.
```
spawn:   x = cx + rand(-3..3);  y = sy + 10 + rand(0..12)
         vx = rand(-0.3..0.3);  vy = -(0.25 + rand(0..0.4))
         life = 0; max = 18 + rand(0..22); top = sy
update:  x += vx; y += vy; life++; vx += rand(-0.08..0.08)
         respawn when life > max OR y < top - 18
draw:    k = 1 - life/max
         color = k>0.6 ? #ffe9b0 : k>0.3 ? #ffc24a : #ff9a3a
         1×1 px, additive
```

---

## Teal indicator lights (the "technology" lights)

8 lights, each an additive teal `rGlow`. Color is always `"55,214,207"` (#37D2CF).
Two behaviours: **breathe** (smooth sine) and **flicker** (mostly-on with irregular
electronic stutters). `fl: 1` marks a flicker light.

```
lights = [
  { x: 15,  y: 220, r: 8, ph: 0.0, sp: 0.10, base: 0.14, amp: 0.22 },          // L ledge end-cap  (breathe)
  { x: 524, y: 220, r: 8, ph: 1.7, sp: 0.11, base: 0.14, amp: 0.22 },          // R ledge end-cap  (breathe)
  { x: 137, y: 37,  r: 6, ph: 2.4, base: 0.05, amp: 0.32, fl: 1 },             // L column top     (flicker)
  { x: 403, y: 37,  r: 6, ph: 0.8, base: 0.05, amp: 0.32, fl: 1 },             // R column top     (flicker)
  { x: 36,  y: 201, r: 5, ph: 3.1, base: 0.05, amp: 0.28, fl: 1 },             // base stud        (flicker)
  { x: 157, y: 201, r: 5, ph: 1.1, sp: 0.14, base: 0.08, amp: 0.14 },          // base stud        (breathe)
  { x: 384, y: 201, r: 5, ph: 2.0, base: 0.05, amp: 0.28, fl: 1 },             // base stud        (flicker)
  { x: 504, y: 201, r: 5, ph: 0.4, sp: 0.13, base: 0.08, amp: 0.14 },          // base stud        (breathe)
]
```

Per light, each frame:
```
if reducedMotion:           p = 0.6
else if light.fl:           p = techFlicker(t, light)
else (breathe):             p = 0.5 + 0.5*sin(t*sp + ph)

rGlow(x, y, r*(0.8 + 0.35*p), "55,214,207", base + amp*p)
```

```
techFlicker(t, L):                          // mostly-on, occasional slow stutter
    v = 0.74 + 0.26*sin(t*0.09 + L.ph)      // slow base breathe
    g = hash( floor(t/4) + L.ph*7, L.ph*3.3 + 1 )   // re-rolls ~every 4 ticks
    if g > 0.90:  v *= 0.18                  // hard blink-down
    elif g > 0.82: v *= 0.55                 // partial dip
    v *= 0.9 + 0.1*sin(t*1.4 + L.ph*2)       // tiny fast jitter
    return clamp(v, 0.08, 1)
```
Result per light: sits mid/high brightness, drops to a brief near-off blink a few times
every couple seconds, each light on its own timing (so they never blink in unison). Keep
the end-caps on **breathe** and stagger which studs flicker, or it reads as "broken"
rather than "powered".

---

## Dust (ambient motes in the firelight)

16 faint warm motes drifting slowly upward near the torches.
```
spawn:   x = cx + rand(-40..40);  y = 56 + rand(0..78)
         vx = rand(-0.15..0.15);  vy = -(0.04 + rand(0..0.12))
         life = 0; max = 130 + rand(0..130); a = 0.10 + rand(0..0.16)
         (seed initial life randomly so they don't all fade together)
update:  x += vx; y += vy; life++; vx += rand(-0.025..0.025)
         respawn when life > max OR y < 28
draw:    alpha = a * sin(pi * min(1, life/max))   // fade in then out
         color #ffd9a0, 1×1 px, additive
```

---

## Props / tweaks (optional runtime toggles)
- **Fire:** `flicker` (bool, default on) — flame warp + brightness flicker (also gates
  embers); `embers` (bool, default on); `glow` (0–1.6, default 1) — torch glow strength.
- **Room:** `lights` (bool, default on) — teal indicator lights; `dust` (bool, default on).

## Interactions & behavior
None — this is a non-interactive ambient backdrop. No click/hover/focus. It loops
forever. The only conditional behavior is the `prefers-reduced-motion` static fallback
and the optional prop toggles above.

## State management
No app state. Internal only: a frame `tick`, the ember array (8), and the dust array
(16). Stop the `requestAnimationFrame` loop when the backdrop unmounts / leaves the
viewport, and on `prefers-reduced-motion`.

## Design tokens (colors used)
| Role | Value |
|---|---|
| Flame core / hot | `#ffe9b0` |
| Flame mid | `#ffc24a` |
| Flame low | `#ff9a3a` |
| Torch glow (additive) | `rgb(255,140,64)` |
| Teal indicator (additive) | `#37d2cf` → `rgb(55,214,207)` |
| Dust | `#ffd9a0` |
| Page field / behind canvas | `#0d0f17`; page gradient `#13142a → #0b0c16` |

These sit inside the **Ironbit Beta** design system (dark retro-arcade RPG console:
field `#11111F`, neon green `#00FF9C`, amber `#FFD700`, cyan `#00BFFF`, magenta
`#FF4DCD`). Fonts are **Press Start 2P** (display/labels) and **Share Tech Mono** (body)
— used by surrounding UI chrome, **not** by the room art itself (the room is pure
canvas + the PNGs, no font/CSS dependency). Use the codebase's existing Ironbit tokens
for any chrome around the backdrop.

## Files in this bundle
- `README.md` — this document (self-sufficient).
- `Guild Hall.dc.html` — the reference prototype. The room logic is the
  `class Component` script block (look at `componentDidMount` for the constants and
  `draw()` for the per-frame algorithm). It paints onto a single `<canvas>`; the rest of
  the file is just demo chrome (title/legend) and is not part of the room.
- `support.js` — runtime needed only to open `Guild Hall.dc.html` directly in a browser.
- `assets/guild/*.png` — the art (see the Assets table).
- `assets/guild/reference/original_reference.png` — original supplied art (provenance).

> Note: `Guild Hall.dc.html` references Ironbit font/token stylesheets under `_ds/` which
> are **not** included (they only style the demo's title/legend text). The canvas room
> renders correctly without them; those `<link>`s will simply 404 if you open the file
> standalone.
