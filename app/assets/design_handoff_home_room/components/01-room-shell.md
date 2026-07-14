# Component · Room Shell

The lit space everything sits in. Three value planes + a key light. This is what makes
Home a *place*, not a card.

## Anatomy (back → front)

| Layer | Element | Value | Purpose |
|---|---|---|---|
| Base | `.room` | `#11111F` | darkest base behind everything |
| Back wall | `.wall` | `#1C1C36` | **lighter** plane, top-lit — the dominant surface |
| Floor | `.floor` | darker than wall | lower **30%** of the room |
| Key light | `.ceiling-fixture` | blue-white | thin lit bar at top, spills down |
| Edge | `.vignette` | black, soft | darkens room edges |

## Exact styling

**Room** — `position: relative; height: calc(100% - 58px); min-height: 520px;
background:#11111F`. The `-58px` keeps the first feed card peeking above the fold.

**Wall** — `position:absolute; left/right:0; top:0; bottom:30%; background-color:#1C1C36`,
with three stacked background layers:
1. **Vertical panel seams** — `repeating-linear-gradient(90deg …)` every **91px**
   (a dark line + a 1px highlight). Defines the modular collection grid.
2. **Horizontal seam** at **43%** of wall height (same dark+highlight treatment).
3. **Ceiling-lit gradient** — top→bottom: a blue tint at the top fading to transparent
   mid-wall, then darkening to the floor. This is the "lit from above" read.

**Ceiling fixture** — `left/right:0; top:42px; height:4px; z-index:2`, a horizontal
blue-white gradient bar with `box-shadow: 0 0 16px 1px rgba(120,150,255,.22)`. Its
`::after` is a downward radial spill (`ellipse 64% 100% at 50% 0%`, ~120px tall). This is
the room's key light — the reason the wall top is brightest.

**Floor** — the lower 30%; darker than the wall, subtle gradient toward the front.

**Vignette** — full-room overlay, soft black at the edges; keeps focus center-stage.

**Mount points** — 6 `.mount` markers at seam intersections (x = 91/182/273 × top 0% &
44%). Future hang-points for the collection wall. Keep them; they can be invisible until
an edit/decorate mode.

## Rules

- **Value separation is mandatory:** wall lighter than bg & floor. Don't flatten.
- The **91px seam grid + 43% horizontal seam** are the collection wall's slots — preserve
  the geometry even though the wall is empty at launch (GUARDRAILS #12).
- Top-light direction is fixed (from the ceiling fixture). All in-room shading agrees with
  it.

## Native notes

`Stack` of `Positioned.fill` layers. Wall seams = a tiling `CustomPainter` or a 9-patch.
Ceiling fixture glow = a `Container` with gradient + `BoxShadow` (this one *may* be a
gradient — it's ambient room light, not the pixel-art pad light). Vignette = a
`RadialGradient` overlay with `IgnorePointer`.
