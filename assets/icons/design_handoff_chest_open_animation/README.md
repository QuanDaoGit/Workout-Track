# Handoff: Ironbit Chest — Open Animation

## Overview
A loot-claim animation for **Ironbit** (the workout-RPG): a treasure chest plays
**closed → anticipation shake → pop open** with a pixel-art reward burst, then
settles open while BIT says a line. It is built around **two provided pixel-art
sprites** (a closed chest and an open chest) used as a two-frame swap, with all
motion and FX generated procedurally on a `<canvas>`.

## About the Design Files
The files in this bundle are **design references created in HTML** — a working
prototype that shows the intended look and motion. They are **not** production
code to ship as-is. The task is to **recreate this animation in the target
codebase's environment** using its established patterns. Ironbit ships as a
**Flutter** app, so the natural port is a `CustomPainter` + `AnimationController`
(see *Implementation Notes*). If you are targeting web instead, the canvas
approach in the prototype can be lifted almost directly.

## Fidelity
**High-fidelity.** Final sprites, colors, timings, easing, and FX are specified
exactly below. Match them.

## Screens / Views

### Stage (single view)
- **Purpose:** play the chest-open sequence; loops automatically and replays on
  tap / button press (a real claim flow would play it once on reward).
- **Layout:** a fixed **300 × 341 px** logical stage. In the prototype it sits in
  an `ArcadeCard` (amber 2px border, `box-shadow:0 0 22px -6px rgba(255,215,0,.4)`)
  with a header above and a "source frames" reference card + an `OPEN CHEST`
  `PixelButton` below. **Only the 300×341 stage is the deliverable** — the
  surrounding chrome is prototype scaffolding.
- **Stage box:** background `#0B0B16`, 1px border `#36365E`, radius 4px,
  `overflow:hidden`. A **CRT scanline** overlay sits on top: a 1px black line every
  3px (`repeating-linear-gradient(0deg, rgba(0,0,0,.22) 0 1px, transparent 1px 3px)`),
  ~40% opacity, `mix-blend-mode:multiply`.
- **Chest:** drawn `contain` to fill the stage. Two frames only —
  `chest_closed.png` and `chest_open.png` — both 770×875 transparent PNGs that are
  already width-matched and bottom-aligned (the body stays put; the lid lifts).
- **Canvas:** sized to `300·DPR × 341·DPR` and scaled by DPR for crispness; all
  drawing happens in 300×341 logical coordinates.

## Interactions & Behavior

A single wall-clock drives everything; phase + local time are derived from
`(now − start) mod 4450ms`. **No per-frame app state** — it paints straight to the
canvas via `requestAnimationFrame`.

| Phase  | Window (ms)  | Behavior |
|--------|--------------|----------|
| closed | 0 – 1200     | Closed sprite, gentle **vertical** idle bob: `±2px`, `sin`, ~560ms period. |
| rattle | 1200 – 1850  | Closed sprite, **horizontal-only, pixel-stepped shake**. Amplitude ramps `1→4px` (integer); direction flips every **70ms** (square wave). **No rotation.** |
| open   | 1850 – 4450  | Swap + pop + burst + settle (details below). |

**Open phase** (local time `0–2600ms`):
- `0–110ms`: closed sprite alpha `1→0` (fast cross-out).
- **Open-sprite pop** — stepped scale about the **bottom-center** (so it "rises"):
  `<90ms → .9`, `<185ms → 1.12`, `<285ms → .98`, else `1.0`. Alpha ramps `0→1` over 100ms.
- **Emissive bloom** on the open sprite: canvas shadow, amber
  `rgba(255,215,0, 0.28 + 0.16·sin(t/240))`, blur 16.
- **Pixel burst** (all hard-edged squares — *no soft CSS gradients/rings*):
  - **Expanding ring** `0–540ms`: 12 blocks (8px) on a circle centered `(150,138)`,
    radius steps **+9px every 52ms**, alternating amber `#FFD700` / neon `#00FF9C`,
    alpha fading to 0.
  - **Light beams** `0–620ms`: 3 columns at x = 112 / 150 / 188, six stacked squares
    each rising from y≈130, width `7→3px`, amber, flicker every 55ms.
  - **Plus-sparkles**: 6 "+" sparkles (5 squares each) at scattered points, staggered
    0–175ms, triangle scale `0→4px→0` over 330ms, colors white / amber / neon.
  - **Flat flash** `0–140ms`: full-stage `#FFE680`, `globalCompositeOperation:'screen'`,
    alpha `.26→.05` stepped.
- **BIT line** fades in after **640ms**: `"Good haul today, warrior."` ("warrior" in
  amber `#FFD700`), opacity `(local−640)/340`, clamped 0–1.

**Triggers:** tapping the stage or the `OPEN CHEST` button sets `start = now − 1200`
(jump straight to *rattle*), which plays rattle→open and resumes the loop.

**Reduced motion:** under `prefers-reduced-motion`, render a **static open frame**
(no loop, no shake, no flashing) and show the BIT line.

## State Management
- One number: `start` (loop origin timestamp). Phase + `local` are computed each
  frame; nothing else is stateful.
- `trigger()` rewinds `start` to begin the rattle.
- The render loop is `requestAnimationFrame`-driven and independent of the app's
  render cycle.

## Design Tokens (Ironbit)
**Surfaces:** field `#11111F`, gradient `#15152C → #0E0E1B`, stage `#0B0B16`,
card `#1C1C34`, border `#36365E`.
**Signals:** neon (brand/primary) `#00FF9C`, **amber (reward)** `#FFD700` /
`#FFE680`, cyan (rest) `#00BFFF`, magenta (currency/gems) `#FF4DCD`.
**Text:** primary `#E8E8FF`, muted `#9494B8`, dim `#555577`.
**Type:** *Press Start 2P* (display, ALL-CAPS, 7–19px) for labels/headings;
*Share Tech Mono* for body/numerals (BIT's line). **Radius:** 4px.
**Motion:** `easeOutCubic` `cubic-bezier(0.215,0.61,0.355,1)`; base durations
120 / 180 / 220ms; overshoot/flashing reserved for celebration (this is one).
**Chest sprite green ramp** (from the provided art, for matching effects/recolors):
outline `#161616`, interior `#04230F`, shadow `#1F4A2C`, mid `#2F7A46` / `#43A866`,
bright `#66CF80`, light `#93EA9F`, hilite `#BDFFC4`.

## Assets
All pixel art; render with nearest-neighbour (`image-rendering: pixelated`) when
shown at icon scale.
- `assets/chest_closed.png` — the **provided** closed chest. The original upload had
  a baked checkerboard (no alpha); it was keyed to transparent, cropped, then
  **width-normalized and bottom-aligned** onto a 770×875 canvas to match the open
  frame.
- `assets/chest_open.png` — the **provided** open chest, same treatment, same canvas.
- `assets/icon_chest_original_16px.png` — the existing in-app 16×16 chest glyph (a
  flat `#8EEF97` silhouette) for reference; the new sprites are fully shaded and do
  not match its style.
- *Not used:* magenta gems (`icon_gem.png`, 32×32) were requested then removed — the
  burst is currently amber/neon only. Re-adding them is straightforward (draw the
  gem sprite nestled in the opening + a couple arcing out on open).

## Files
- `chest-open-animation.html` — **self-contained offline build**; open in any
  browser to see the final animation (all assets + runtime inlined).
- `Chest Open Animation.dc.html` — the **prototype source** (template + the canvas
  animation class). Note: it references the project's design-system bundle and
  runtime, so it runs inside the original project, not standalone — use the bundled
  HTML above to view it in isolation.
- The animation logic is the `draw(T)` method (state machine + pixel FX) plus the
  `_attach`/`_run` canvas/rAF setup.

## Implementation Notes (Flutter port)
- Add `chest_closed.png` and `chest_open.png` to `assets/` (or your chest art set).
- Drive with an `AnimationController(duration: 4450ms)..repeat()`; map its value to
  phase + local time exactly as the table above.
- Paint in a `CustomPainter`: `drawImageRect` for the chosen chest frame (apply the
  pop scale around bottom-center and the closed→open alpha cross), then the burst
  with `canvas.drawRect` squares (ring / beams / plus-sparkles) and a `MaskFilter`/
  blurred amber layer for the bloom. Keep the rect FX **un-antialiased** so they read
  as pixels.
- The BIT line is ordinary text (Share Tech Mono) with the `[warrior]` token in amber.
