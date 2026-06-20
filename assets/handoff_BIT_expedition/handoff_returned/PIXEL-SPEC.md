# PIXEL-SPEC — the coffer painter & palettes

Native canvas: **28 × 20 px**. All coordinates below are in native pixels.
Reference painter: `engine/coffer-paint.js` (`paintCoffer`).

---

## Palettes

### Pad metal family (sampled from `bit_pad.png`) — the coffer reads "the dock made this"
| token | hex       | use |
|-------|-----------|-----|
| OUT   | `#0b0c16` | 1px outline / deepest shadow |
| D2    | `#15172a` | dark body / seam shadow |
| D1    | `#212439` | mid-dark |
| M     | `#2e3150` | body fill (main surface) |
| L1    | `#3d4262` | light bevel / straps |
| L2    | `#525879` | bevel highlight |
| L3    | `#6b72a0` | top highlight rim |

### Magenta gem currency (sampled from `gem.png`)
| token | hex       | use |
|-------|-----------|-----|
| gHi   | `#ff96e6` | gem highlight (top-left facet) |
| g     | `#ff4dcd` | gem core / lit face |
| gMid  | `#e028a0` | gem mid |
| gDk   | `#961c8c` | gem deep facet (bottom-right) |
| —     | `#9638d6` | violet shadow facet (full gem.png only) |
| —     | `#ffffff` | sparkle / specular |

### Route-seal tints (the latch gem only)
| route  | dk        | md        | hi        |
|--------|-----------|-----------|-----------|
| none   | `#961c8c` | `#ff4dcd` | `#ff96e6` | ← default = the magenta currency |
| tracer | `#1c6e92` | `#2bb2dc` | `#aeeeff` |
| maze   | `#5e2a9c` | `#B14DFF` | `#E0B8FF` |
| iron   | `#8e1430` | `#FF2D55` | `#FF93A9` |

---

## Coffer build order (Option B — Banded Coffer)

Drawn back-to-front. Each `bevelBox(x,y,w,h, fill, lit, shade [,top])` lays an
outlined block with top/left lit and bottom/right shadowed.

1. **Wide base** — `bevelBox(2,12, 24,7, M, L1, D2)`
2. **Stacked top tier** — `bevelBox(5,6, 18,7, M, L2, D1, top=L3)`
3. **Step seam shadow** — `hline(5,12, 18, D2)`
4. **Straps** (two) — `bevelBox(7,12, 3,7, L1, L3, D2)` and `bevelBox(18,12, 3,7, …)`
5. **Slat vents** (4) at `sx = 8,11,14,17`: a 3px `OUT` shadow gap, then a vertical
   **gem-bleed** `gDk → g → gMid` down rows 8,9,10 (magenta light leaking out).
6. **Route latch** — `sealPlate(14,15, routeTint)`: recessed dark plate + a 5px
   diamond gem core in the route colour.
7. **Gem spill** over the rim — three `gem()` at (11,4)(14,3)(16,4) plus accent
   pixels `gHi`(13,5) `g`(18,5) `gDk`(10,5). Each `gem(x,y)` is the 2×2 facet.

`gem(x,y)` = `px(x,y,gHi) · px(x+1,y,g) · px(x,y+1,g) · px(x+1,y+1,gDk)`.

---

## Scaling

- Native 28×20. On-pad display = **×2 → 56×40** (≈ ⅓ pad width). ×3 = 84×60.
- Blit with `imageSmoothingEnabled=false` (Flutter `FilterQuality.none`,
  `isAntiAlias:false`). **Integer multiples only.**
- The contact/underglow is NOT part of the sprite — it's the `bitpad-light.js`
  pool, tinted magenta when the haul is present (see IMPLEMENTATION.md §1).

---

## Asset specs

| file | native | notes |
|------|--------|-------|
| `gem.png` | 32×32 | the currency. Transparent PNG. Use directly in wallet / resource counter / store. |
| `gem_shield.png` | 40×40 | streak-insurance variant of the gem. |
| `bit_pad.png` | 108×40 | emitter console sprite; shown ~1.4× in the room (its odd scale is why the coffer is code-painted, not matched to it). |
| `bit_neutral.png` | — | BIT fallback still for the never-crash errorBuilder. |

The coffer itself ships as **code** (`coffer-paint.js` → Flutter `CustomPainter`),
not a PNG — resolution-independent and shimmer-free. Commission a PNG only if you
want richer detail, and keep the painted fallback either way.

---

## The other two options (context only)

`reference/Haul Cache.html` also renders **A — Strongbox** (`paintStrongbox`) and
**C — Drop Pod** (`paintPod`) with the same palette and the same integer-scale
rules. They were the exploration; **B — Coffer** is the shipped silhouette.
