# BIT — Side-View Hover-Glide · Developer Handoff

The character layer for the **Adventure route screens**. The route backdrops
(`Adventure Route Backdrops`) ship a 3-layer parallax world per route and a
`walk line` marking where a character's feet land — but no character. **This
package is the character**: BIT, painted in **right-facing profile**, gliding
the route.

## The one design decision that drives everything

**BIT has no legs — he floats.** (See `bit.js`: a screen-faced metal core plus
four detached, hovering plates; idle = hover-bob + ground glow.) So "walking the
route" is **not** a footstep walk cycle — it's a **hover-glide**:

- forward-facing glowing **screen** (eyes look in the direction of travel),
- a broad **back-plate fin** trailing behind,
- **top plate** + **under-vent** framing the core,
- **hover-bob** (±1.5px) with each plate **lagging** the core,
- a cyan **thrust trail** streaming behind while the world scrolls,
- a crisp, **route-tinted hover shimmer** on the walk line.

BIT hovers *in place*; the route scrolls *under* him. He never touches the ground.

---

## What's in this folder

```
handoff_bit_route_walk/
├── README.md            ← you are here
├── IMPLEMENTATION.md    ← the sprite anatomy, motion timings, API, integration + Flutter notes
├── engine/
│   └── bit-walk.js      ← PORTABLE painter — BITWALK.paint() + BITWALK.mount(). No deps.
├── assets/
│   ├── {route}_sky.png     ← layer A, 480×270, opaque, static
│   ├── {route}_far.png     ← layer B, 480×270, transparent, scrolls 0.30×
│   └── {route}_ground.png  ← layer C, 480×96,  transparent, scrolls 1.00×
│        (route = iron_vault | sky_tracer | infini_maze)
└── reference/
    └── BIT-Walk.html    ← live: BIT gliding all 3 routes + 6-key frame breakdown (opens offline)
```

> Open `reference/BIT-Walk.html` and switch routes / drag the **glide** slider /
> toggle the **thrust trail**. The trail only emits while the world is moving.

---

## Sprite at a glance

| | |
|---|---|
| Native canvas | **40 × 32** px |
| Render scale | **integer only** (×2 on the 480×270 scene; nearest-neighbour) |
| Palette | BIT's canonical `METAL` (cool blue-grey) + cyan screen ramp |
| Anchor | feet/contact at native **y ≈ 29** — place the canvas so y29 = the route's walk line |
| Facing | **right** (the direction the world scrolls toward) |

Per-route walk-line (scene Y): Iron Vault **182**, Sky Tracer **180**, Infini Maze **180**.

---

## Three rules that must survive the port

1. **Integer scale only.** The sprite is 40×32 drawn at ×2 on the scene. Never a
   fractional multiple (`FilterQuality.none`, `isAntiAlias:false`) — a non-integer
   upscale shatters the grid.
2. **No soft blur on a pixel sprite.** The under-BIT shimmer is *crisp dashed
   pixels* tinted to the active route accent — it deliberately echoes the route
   walk-line's dashed motif. An earlier soft radial glow was cut because a fuzzy
   gradient fights the nearest-neighbour world (especially the violet route).
3. **BIT owns the cyan.** Screen, eyes, vents and the thrust trail are all the
   cyan family — BIT's identity. The route accent (ember / violet / cyan) only
   tints the *hover shimmer* and the route chrome, never BIT's body.

See **IMPLEMENTATION.md** for the sprite anatomy, exact motion timings, the
`BITWALK` API, and how to drop BIT onto a live route.
