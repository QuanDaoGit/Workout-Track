# Component · Hover Pad (emitter + light system)

BIT's neon plinth: a front-view pixel-art emitter console on the floor, a wide dithered
floor-pool of light behind it, a dark contact shadow grounding it, and a rising energy
beam that tethers up toward BIT (fading out before it reaches him). Four layers, one
emitter read.

## The four layers (back → front)

```html
<canvas class="pad-glow" id="padGlow"></canvas>   <!-- z3  floor pool (engine) -->
<div class="pad-contact"></div>                    <!-- z4  dark grounding shadow -->
<div class="pad">                                  <!-- z5  emitter sprite -->
  <img class="pad-sprite" src="assets/bit-pad/bit_pad.png" alt="">
</div>
<canvas class="pad-beam" id="padBeam"></canvas>    <!-- z6  rising beam (engine) -->
<!-- BIT (z7) mounts above this whole stack -->
```

## Exact CSS

```css
/* floor pool — pixel-art canvas, scaled up chunky, BEHIND the pad */
.pad-glow {
  position:absolute; z-index:3; left:185px; top:354px; width:228px; height:192px;
  transform: translateX(-50%); image-rendering: pixelated;
  mix-blend-mode: screen; pointer-events:none; opacity:.8;
}
/* dark contact shadow grounding the pad */
.pad-contact {
  position:absolute; z-index:4; left:185px; top:470px; width:130px; height:11px;
  transform: translate(-50%,-50%); border-radius:50%; pointer-events:none;
  background: radial-gradient(ellipse at center,
    rgba(3,3,8,.6) 0%, rgba(3,3,8,.3) 55%, transparent 80%);
  filter: blur(1.5px);
}
/* the metal console sprite (108×40 native, shown ~1.4×) */
.pad        { position:absolute; z-index:5; left:185px; top:414px; width:150px; height:56px;
              transform: translateX(-50%); }
.pad-sprite { display:block; width:100%; height:100%; image-rendering:pixelated; }
/* rising energy beam — additive, fades before BIT */
.pad-beam {
  position:absolute; z-index:6; left:185px; top:366px; width:64px; height:64px;
  transform: translateX(-50%); image-rendering: pixelated;
  mix-blend-mode: screen; pointer-events:none;
}
```

> The floor pool is held at **opacity .8** and the whole cyan family is kept dimmer than
> BIT's lens — salience rule (GUARDRAILS #2).

## The two engines

### Floor pool — `BitPadLight.init(canvas, cfg)`
```js
BitPadLight.init(padGlow, { cols:68, rows:60, cx:34, cy:40, rx:30, ry:22, ryUp:10, fps:14 });
```
- Chunky Bayer-dithered cyan radial. `rx:30` wide so the pool reads **wider than BIT**;
  `ryUp:10` (tighter than `ry:22`) so it **pools on the floor**, not up the pillars.
- Slow breathing fade + occasional pixel-dropout flicker. ~14fps (chunky on purpose).
- Reduce-motion → static at 0.85 intensity.

### Rising beam — `BitPadBeam.init(canvas, cfg)`
```js
BitPadBeam.init(padBeam, {
  cols:20, rows:26, apexX:10, apexY:22, topY:9,
  halfBase:3.0, spread:-0.05, edgeFlat:1.7, vfade:1.1,
  bandSpeed:5, bandPeriod:4.5, fps:14 });
```
- A point-source cone: bright ~3-cell focus at the emitter (`apexY:22`), fanning up to
  `topY:9` where it has **fully faded to zero** — *below* BIT, leaving a clean dark gap.
- `spread:-0.05` ≈ a near-column (barely fans); `vfade:1.1` holds the column then drops to
  nothing before BIT. Travelling energy **bands** climb upward (`bandSpeed/bandPeriod`).
- Same cyan ramp + Bayer dither as the floor pool → pad + beam read as **one** emitter.
- `mix-blend-mode: screen` (additive). Reduce-motion → static.

## The sprite

`assets/bit-pad/bit_pad.png` — **108×40 native**, transparent PNG, front-view console:
beveled metal body, a dim segmented cyan LED strip across the front, two lit side posts, a
chevron emblem on top (the beam visually rises from it). Shown at ~1.4× (`150×56`),
`image-rendering: pixelated`.

## Rules

- **Beam fades out before BIT.** If it touches him, lower `topY` or raise `vfade`. The dark
  gap is what keeps BIT salient and reads as "floating, tethered" (GUARDRAILS #3).
- **Pad cyan stays subordinate** to BIT's lens. The floor pool's `.8` opacity and the dim
  LED strip are tuned for this — don't brighten without re-checking salience.
- Floor pool and beam are **pixel art** (dither, nearest-neighbour) — never smooth
  gradients (GUARDRAILS #1).
- The pad is grounded by `.pad-contact`; **BIT is not** grounded (he floats).

## Future role

The pad is also BIT's **Expedition dock** — where he launches to scout and returns with a
haul. Reserve the interaction; not built in this pass.

## Native notes

Two `CustomPainter`s (no AA) implementing the same `field()` + Bayer dither, or pre-rendered
pixel frame loops. Both layers `BlendMode.screen`. Sprite via `Image` with
`FilterQuality.none`. Contact shadow can stay a real (blurred) gradient — it's a shadow,
not the pixel light.
