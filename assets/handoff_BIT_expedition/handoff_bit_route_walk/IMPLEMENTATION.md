# Implementation — BIT Side-View Hover-Glide

Everything is in **`engine/bit-walk.js`** (no dependencies, ~280 lines). It paints
BIT cell-by-cell, the same way `bit.js` paints the front-facing mascot, and
exposes two entry points: `BITWALK.paint()` (one static frame) and
`BITWALK.mount()` (self-animating on a canvas).

---

## 1. Sprite anatomy (40 × 32 native)

Built from bevelled rounded-rect metal blocks (`bevelBlock`) with an auto 1px
outline (`outlinePass`) — identical helpers to `bit.js`, so the profile and the
front sprite share a surface language.

| Part | Block | Role |
|---|---|---|
| **Core** | 15×15, screen well at local (5,4) 7×7 | body; mostly screen + thin metal bezel; left metal = "back of the head" |
| **Screen** | 7×7 radial cyan ramp | the face — eyes shifted to the forward (right) half, mouth glint, blink |
| **Top plate** | 13×4, two cyan dots | floats above |
| **Back plate** | 5×11, two cyan dots | the broad **trailing fin** (reads the facing + motion) |
| **Under-vent** | 10×3, two cyan dots | beneath the core; the cyan vents live here |

The screen well and the drawn screen are sized from the **same** `SCRX/SCRY/SCRW/SCRH`
constants, so the glow always lands inside the bezel regardless of scale.

Core top-left sits at native **(13, 8)**; the contact/walk-line is **y = 29**.

---

## 2. Motion (all sin-based, period `PER = 300ms`, amplitude `A = 1.5px`)

```
bobAt(t, lag) = round( A * sin((t - lag) / PER) )
```

| Element | Phase lag | Effect |
|---|---|---|
| Core + screen | 0 | the hover-bob everyone follows |
| Top plate | 140 ms | trails the core's rise |
| Under-vent | 90 ms | trails slightly |
| Back plate | 200 ms + x-sway | floats furthest behind; `x` sways ±1px |
| Blink | — | random 2.6–6.6s gap, 110ms closed |
| Hover shimmer | — | pulse `0.55 + 0.45·sin(t/300)`, route-tinted |

**Thrust trail.** Motes spawn behind the under-vent **only when the world is
moving** (`speed > 4`), every ~70ms, drift left + slightly down, fade over ~520ms.
Spawn rate is fixed but mote velocity scales with `speed`, so faster glide = a
longer streak. Cyan (`#5EE8FF` hot → `#00BFFF` cool) — never the route accent.

All motion is gated by `prefers-reduced-motion`: `mount()` freezes on the t=0
pose (still fully painted, trail empty).

---

## 3. API

```js
// One static frame — thumbnails, print, PDF, the frame-breakdown strip.
BITWALK.paint(ctx, scale, t, {
  accent: '#FF6A3D',   // hover-shimmer tint (route accent). default cyan.
  blink:  false,
  motes:  [{x,y,life}, …],   // optional thrust motes (native coords)
  shadow: true,        // false → omit the ground shimmer (off-route thumbnails)
});

// Self-animating on a canvas (own rAF loop).
const w = BITWALK.mount(canvas, {
  accent: '#FF6A3D',   // route accent
  speed:  40,          // px/s the WORLD scrolls — gates + scales the trail
  trail:  true,
  static: false,       // true → freeze (auto when prefers-reduced-motion)
});
w.setAccent('#B14DFF');  // on route change
w.setSpeed(0);           // world stopped → BIT idles, no trail
w.setTrail(false);
w.setPlaying(false);     // pause the whole sprite
w.destroy();             // cancel rAF
```

`BITWALK.NATIVE` = `{w:40, h:32}`. `BITWALK.METAL` / `.RAMP` expose the palettes.

---

## 4. Dropping BIT onto a live route

The route screen already has the scaled `.scene` (480×270 → ×2) with the three
parallax layers. Add one canvas as a sibling **on top**:

```html
<div class="scene" style="transform:scale(2);transform-origin:0 0">
  <div class="layer sky"></div>
  <div class="layer far"></div>
  <div class="layer ground"></div>
  <canvas id="bit" width="40" height="32"
          style="position:absolute;image-rendering:pixelated;z-index:5;pointer-events:none"></canvas>
</div>
```

```js
const w = BITWALK.mount(document.getElementById('bit'), { accent: route.accent, speed: route.scroll });
// place feet (native y29) on the walk line; the scene's scale handles the ×2:
bit.style.left = '210px';
bit.style.top  = (route.walkY - 30) + 'px';   // 30 = native y29 + 1
```

Because the canvas lives **inside** the scaled `.scene`, its 40×32 native pixels
upscale ×2 exactly in step with the backdrop — no per-sprite scaling needed.
Keep BIT's `left` fixed and scroll the layers' `background-position`; he reads as
gliding forward. (`reference/BIT-Walk.html` is the working version of this.)

---

## 5. Flutter port notes

- Paint into a `PictureRecorder` / `CustomPainter` at native 40×32, draw to screen
  with `FilterQuality.none`, `isAntiAlias:false`, integer dst rect. Same bevel +
  outline passes; same `bobAt` phase-lag table.
- Drive `t` from a `Ticker`; gate on `MediaQuery.disableAnimations` for the
  reduced-motion freeze.
- Trail = a small fixed-capacity particle list updated per tick; spawn gated on
  the world scroll speed, identical to `emit()`.
- Hover shimmer = dashed `drawRect`s at the walk line, alpha-pulsed, tinted to the
  route's class color. **Do not** substitute a `RadialGradient` — keep it crisp.
- Reuse `bit_neutral.png` as a never-crash fallback if the painter is unavailable.
