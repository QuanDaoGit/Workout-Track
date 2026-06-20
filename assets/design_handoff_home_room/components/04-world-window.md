# Component · World Window

The room's window to the outside, mounted on the wall. It **shifts by time of day** — the
quiet, pressure-free pull that makes returning feel alive. Animated pixel-art APNG + a
matching colored glow spilling onto the wall.

## Markup & CSS

```html
<div class="window">
  <div class="window-glow" id="window-glow"></div>
  <img class="window-img" id="window-img" src="assets/decor/window_afternoon.png" alt="World window">
</div>
```
```css
.window      { position:absolute; z-index:4; left:182px; width:91px; top:56px; height:76px; }
.window-glow { position:absolute; inset:-16px; z-index:0; border-radius:8px;
               background: radial-gradient(ellipse at center,
                 var(--win-glow, rgba(120,150,220,.32)) 0%, transparent 68%);
               filter: blur(3px); opacity:.55; pointer-events:none; }
.window-img  { position:relative; z-index:1; display:block; width:100%; height:100%;
               image-rendering: pixelated; }
```

Snapped to the **panel-3 seam** (left edge on the 182px wall seam). The glow sits behind
the frame and tints the surrounding wall the color of the current sky.

## The four states

Each is an **animated APNG** (`assets/decor/window_*.png`, **90×75 native, 28 frames**)
with a matching `--win-glow` wall tint:

| id | label | sub | `--win-glow` | motion in the APNG |
|---|---|---|---|---|
| `morning` | EARLY MORNING | sunrise | `rgba(255,176,96,.38)` | warm sun, drifting cloud |
| `noon` | NOON | clear sky | `rgba(127,182,232,.40)` | bright sky, slow cloud, shimmer |
| `afternoon` | AFTERNOON | sunset | `rgba(224,104,42,.42)` | warm sun, embers |
| `evening` | EVENING | starry | `rgba(111,144,216,.36)` | twinkling stars, moon |

Shared APNG motion: a moving scanline/flicker, sun/moon shimmer, and idle-pulsing cyan
frame lights, so the glass always feels alive.

## Behavior

- **In-app: drive by the device clock.** Map the local time into the four buckets and swap
  the `<img src>` + the `--win-glow` custom property. Cross-fade is nice-to-have.
- The picker in `preview.html` (the 2×2 Tweaks grid) is a **dev affordance only** — it
  proves the four states. **Do not ship the picker**; the window follows real time.

## To swap (web reference)

```js
img.src = WIN[id].src;
glow.style.setProperty('--win-glow', WIN[id].glow);
```

## Rules

- Pixel art: `image-rendering: pixelated`; never upscale-blur the APNG.
- The window is **ambient**, not interactive at launch — it sets mood, nothing more.
- Pause APNG playback when Home is off-screen / backgrounded (perf, GUARDRAILS #9).

## Native notes

Play the APNG (an APNG package, or a 28-frame sequence). The wall glow is ambient light —
a `RadialGradient` `Container` is fine here (it's not the pad's pixel light). Pick the
state from `DateTime.now()`; rebuild on a low-frequency timer / on resume.
