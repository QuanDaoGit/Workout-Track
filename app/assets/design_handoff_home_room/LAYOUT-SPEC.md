# LAYOUT-SPEC — Home Room

Exact coordinate system, positions, sizes, and z-order of every element. All values
are taken **verbatim** from `preview.html`. The design canvas is a phone screen; the
room is the top of one vertical scroll.

---

## 1. Frame & coordinate system

- **Screen:** the `.screen` is the phone viewport (the preview wraps it in a `.phone`
  mock with a notch — drop that; use the device's real safe-area in-app).
- **Scroll model:** `.content` holds a single vertical `.scroller`. Inside it, top to
  bottom: **`.room`** (the scene), then **`.feed`** (cards), then the screen-pinned
  **`.topbar`** (resource HUD) overlay. Below the screen sits the fixed **`.nav`**.
- **Room height:** `height: calc(100% - 58px); min-height: 520px`. Deliberately just
  shy of full height so the **first feed card peeks above the fold** — the Finch scroll
  cue. Preserve this peek.
- **Room internal coordinates:** the room is `position: relative`; children are absolutely
  placed against it. Width tracks the device (~340px design width — the wall panel seams
  fall at x = 91 / 182 / 273). The numbers below are in that ~340-wide room space; treat
  them as **ratios**, not fixed px, when the device is wider/narrower.

## 2. Depth planes (back → front)

| Plane | Element | Color / note |
|---|---|---|
| Background | `.room` | `#11111F` — the darkest base |
| Back wall | `.wall` | `#1C1C36` — a clear shade **lighter** than bg, top-lit |
| Floor | `.floor` | darker than wall; bottom 30% of room |
| Vignette | `.vignette` | edge darkening over everything in-room |

> **The lighting read is non-negotiable:** wall is the lightest plane (lit from the
> ceiling fixture), bg + floor are darker. This is what makes it a *room* and not a flat
> card. See `components/01-room-shell.md`.

## 3. The wall

- `.wall`: `top:0; bottom:30%` (so the floor occupies the lower 30%).
- **Panel seams:** vertical, every **91px** (`repeating-linear-gradient(90deg …)`), plus
  one **horizontal seam at 43%** of wall height. These define the modular grid the future
  collection wall snaps to.
- **`.ceiling-fixture`:** a thin lit bar at `top:42px`, height `4px`, glowing down — the
  room's key light. Its `::after` is the soft downward spill.
- **`.mount` points:** 6 small markers at seam intersections (x = 91/182/273 × top 0% & 44%).
  These are *future hang-points* for collection items — keep them (can be invisible until
  edit mode).

## 4. Element register (position · size · z-index)

Coordinates are `left` / `top` of the element's own box unless noted.

| Element | left | top | size | z | Anchor / notes |
|---|---|---|---|---|---|
| `.window` (world-window) | 182px | 56px | 91 × 76 | 4 | Snapped to panel-3 seam (182–273). Holds APNG + glow. |
| `.identity` | 16px | 56px | auto | 8 | Top-left. Name / LV / title stack. |
| `.pad-glow` (floor pool canvas) | 185px* | 354px | 228 × 192 | 3 | *centered via translateX(-50%). BEHIND the pad. |
| `.pad-contact` (dark shadow) | 185px* | 470px | 130 × 11 | 4 | *centered. Grounds the pad. |
| `.pad` (emitter sprite) | 185px* | 414px | 150 × 56 | 5 | *centered. Sprite is 108×40 native, shown ~1.4×. |
| `.pad-beam` (rising beam canvas) | 185px* | 366px | 64 × 64 | 6 | *centered. Additive (`mix-blend: screen`). |
| `.bit-anchor` → `#bit` | 185px | 340px | 92 × 92 host | 7 | **Hover-center is a FIXED point.** BIT canvas is translate(-50%,-50%) on it. |
| `.feed` first card | — | below room | — | 1 | Peeks above the fold. |
| `.topbar` (resource HUD) | screen-pinned | — | — | (overlay) | Name + LCK / Gems / VIT. |
| `.nav` (bottom nav) | fixed bottom | — | 58px tall | — | 5 items, raised center TRAIN. |

### The hover geometry (the heart of the scene)

```
                 ┌─ #bit hover-center  ……  y = 340  (z7, brightest thing)
                 │   (BIT canvas 92×92, centered on the anchor)
   ~80px gap     │
   tethered ─────┤   .pad-beam rises here, FADES OUT before reaching BIT (dark gap)
                 │
   pad top  ……  │   y ≈ 414  (.pad sprite top)
   emitter   ────┤   .pad-glow pools wide on the floor BEHIND the pad
                 │
   floor     ……  └─ .pad-contact dark shadow  …  y = 470  (grounds it)
```

- BIT's center sits **~80px above the emitter**; his body clears the pad with an
  unmistakable gap. He is *tethered* by the beam but **never touches** it — the beam
  fades to zero before BIT (clean dark gap) so BIT keeps salience.
- The pad is **~150px wide ≈ 44%** of room width.

## 5. Z-index map (authoritative)

```
0   .room background
—   .wall, .floor, .vignette (in-room planes)
2   .ceiling-fixture
3   .pad-glow (floor pool) · .window backing
4   .window · .pad-contact
5   .pad (emitter sprite)
6   .pad-beam (rising beam)
7   .bit-anchor / #bit       ← BIT
8   .identity
1   .feed (below the room in flow)
—   .topbar (screen overlay) · .nav (below screen)
2147483646  .twk (Tweaks panel — DEV ONLY, strip in prod)
```

BIT at **z7** sits above the entire pad stack but below the identity text; the beam (z6)
is directly under him, the pad sprite (z5) under that, the floor pool (z3) furthest back.

## 6. Time-of-day & rest behavior

- **World-window** (`components/04-world-window.md`) swaps among 4 APNGs by time of day:
  `morning / noon / afternoon / evening`, each with a matching wall-glow color. Drive
  this from the device clock in-app (not a manual picker — the picker in `preview.html`
  is a dev Tweaks affordance).
- **Room rests when away:** on long absence, set BIT to `REST` mood (dimmer, eyes lowered,
  plates tucked) — the room *rests, never sulks*. No guilt copy, ever (see GUARDRAILS).
- **BIT "returns in 2h":** when BIT is out scouting, show his absence + a calm countdown.
  Anticipation, not pressure.

## 7. Reserved space for future systems (don't fill yet)

The layout intentionally leaves room — **do not** add placeholder content:
- **Collection wall:** the `.wall` panel grid (91px columns × the 43% horizontal seam)
  and the 6 `.mount` points are the slots. Furniture/trophies/loot dock here later
  without re-layout.
- **Quests / Logs terminals:** wall panels (left/right of the window) are reserved as
  recessed terminal surfaces.
- **Expedition:** the pad doubles as BIT's launch/return dock for scouting.

Build the shell so these slot in; ship only what §4 lists.
