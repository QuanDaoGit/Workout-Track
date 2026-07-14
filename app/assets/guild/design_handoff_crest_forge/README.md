# Handoff: Ironbit — Guild Crest Forge

## Overview
The **Crest Forge** lets a player build their guild's crest from three choices:

- **Banner shape** — one of 4 cloth silhouettes (swallowtail, pennant, draped, notched)
- **Emblem** — one of 4 symbols (sword, shield, gem, bolt) or none, centered on the cloth
- **Color** — banner and emblem are colored **independently**; six curated Ironbit
  swatches plus a free "any color" picker

The finished crest is the guild's earned-identity asset. It **hangs in the Guild Hall**
(the diorama backdrop) and also appears wherever the guild is represented (roster,
legends, etc.). The cloth has a constant **gentle sway** so the hall feels alive.

This bundle is a **design reference** — a working HTML/Canvas prototype plus the source
pixel-art. Reproduce it in the target stack (React `<canvas>`, Flutter `CustomPainter`,
a game engine, …) using the algorithms, coordinates, and assets documented below. The
PNGs and the math are what you reproduce exactly; the `.dc.html` is the reference build.

## Fidelity
High-fidelity. Shapes, the recolor math, the sway, and the layout are final. The crest
should look pixel-for-pixel like the included art and move exactly as described.

---

## 1 · Placement on the Guild Hall

The Guild Hall backdrop has an intentionally **empty center bay**. The crest hangs there,
**in front of** the wall art and **behind** the ambient FX (torch glow, embers, dust).
See `placement.png`.

Coordinates are given against the hall's runtime canvas (the hall renders at **540×324**
internally — see the separate Guild Hall handoff; its native art is 320×192 ×1.6, and the
full-res plate is `guild_hall.png` 1619×971):

| Property | Value (on the 540×324 hall canvas) |
|---|---|
| Crest height | ~196 px (≈ 60% of hall height) |
| Horizontal | centered (`x = hallW/2`) |
| Top (rod) | ~26 px from the top of the hall |
| Layer order | hall wall → **crest** → torch glow / embers / dust |

The crest's own rod sits just below the hall's top edge; the cloth + emblem fall into the
bay between the two wall torches. Scale the crest by height and center it; never stretch.

> The crest is the SAME asset the Forge produces. In-app, render the player's chosen
> shape+emblem+color (with the sway) into the bay. A static fallback (no sway) is fine for
> low-end devices / reduced-motion.

---

## 2 · The crest model

A crest = **one banner layer** + **one emblem layer**, each independently colored, drawn
on top of each other. The emblem is centered on the banner body.

### Assets (`assets/guild/crest/`)

| File | ~size | What it is |
|---|---|---|
| `blank_swallowtail.png` | 207×274 | Banner shape, **cloth interior transparent**, cog+dots removed |
| `blank_pennant.png` | 207×274 | " (single point bottom) |
| `blank_draped.png` | 207×274 | " (soft wavy bottom) |
| `blank_notched.png` | 207×274 | " (square center notch) |
| `icon_sword.png` | ~73×143 | Emblem, isolated on transparency (shading + glow kept) |
| `icon_shield.png` | ~90×112 | " |
| `icon_gem.png` | ~87×136 | " |
| `icon_bolt.png` | ~81×126 | " |

All are **teal** as authored (`#37d2cf` family). The interior of each banner is
transparent — on a dark stage it reads as a glowing outlined banner; the recolor + the
dark backdrop give it body. (These were extracted from source renders: backgrounds
flood-keyed out, the default cog emblem and the 3 header dots painted out, emblems
split from the banner outline by connected-components.)

### Composition geometry
Given a target draw box, fit the banner by height into the stage and center it:

```
bScale = min(W/banner.w, H/banner.h) * 0.90      // contain, with margin
bw = banner.w*bScale;  bh = banner.h*bScale
bx = (W - bw)/2                                   // centered
by = (H - bh) * 0.42                              // biased slightly UP (clearance for tails)
// emblem: centered horizontally, centered on the banner BODY
emblemH = bh * 0.30
es = emblemH / emblem.h;  ew = emblem.w*es; eh = emblem.h*es
emblemX = W/2 - ew/2
emblemY = by + bh*0.50 - eh/2
```

`by` is biased up (×0.42, not ×0.5) so the swallowtail/notched **tail tips never clip or
fade** at the bottom. Do **not** add a darkening bottom gradient over the stage — it eats
the tail tips and reads as "cut off".

---

## 3 · Animation — the cloth sway (the "warp your own pixels" technique)

The banner is **not** redrawn or re-skinned to animate. The already-rendered, already-
recolored crest is **displaced row-by-row** each frame, like cloth in a breeze — pinned at
the rod, swaying more toward the hem. This is the same technique used for the hall's torch
flames, so it stays coherent.

**Performance split (important):** recoloring is expensive (per-pixel), the sway is cheap
(blits). So:

- **Build layers only when shape/emblem/color changes.** Render the banner to an offscreen
  canvas (recolored with bannerColor) and the emblem to another offscreen canvas (recolored
  with emblemColor). Cache both. (A running signature string `shape|emblem|bannerColor|
  emblemColor` gates the rebuild.)
- **Composite every frame** by blitting those cached layers in **2px-tall horizontal
  strips**, each shifted horizontally by the sway offset for its row.

```
// per animation frame (throttled to ~30fps):
clear(canvas)
band = 2
A    = 2.6                                   // max sway amplitude (px), at the hem
for (y = 0; y < H; y += band):
    yn  = clamp((y - bannerTop) / bannerHeight, 0, 1)   // 0 at rod, 1 at hem
    off = round( A*yn*sin(t*0.0019 - yn*3.0)            // travelling primary wave
               + 0.9*yn*sin(t*0.0011 + 1.3) )           // slow secondary drift
    drawImage(bannerLayer, sx=0, sy=y, sw=W, sh=band,  dx=off, dy=y, dw=W, dh=band)
    drawImage(emblemLayer, sx=0, sy=y, sw=W, sh=band,  dx=off, dy=y, dw=W, dh=band)
```

- `t` is `performance.now()` in ms. Primary wave period ≈ 3.3 s — slow and subtle.
- `yn` makes the rod (`yn=0 → off=0`) a **fixed pin**; sway grows linearly to the hem.
- The emblem rides the **same per-row offset** as the cloth under it, so it stays locked to
  the banner.
- Round the offset to whole pixels and blit with image-smoothing **off** to keep crisp
  pixel edges (the layers were already rendered smooth at build time).
- **Reduced motion / static fallback:** set `off = 0` (renders the crest perfectly still).
  Stop the rAF loop when the view unmounts / leaves the viewport.

---

## 4 · Color — independent banner & emblem recolor

Two separate controls: **BANNER COLOR** and **EMBLEM COLOR**. Each = 6 curated swatches +
a custom picker. Because banner and emblem live on **separate layers**, each is recolored
independently before compositing.

**Recolor is tone-preserving** (not a flat fill): the art's light→dark structure maps onto
the chosen hue, so highlights/shadows/glow survive. It is also **saturation-aware** so the
neutral metal rod stays metal.

```
recolor(layerPixels, targetHex):                    // skip when target == default teal #37d2cf
  T = rgb(targetHex)
  for each pixel with alpha>0:
     mx=max(r,g,b); mn=min(r,g,b)
     S = mx==0 ? 0 : (mx-mn)/mx                       // source saturation
     Y = (0.299r + 0.587g + 0.114b)/255               // source luminance 0..1
     ramp = (Y < 0.5)                                 // dark→base→near-white ramp of T
          ? mix(T*0.20, T,           Y/0.5)
          : mix(T,      white*0.82,  (Y-0.5)/0.5)
     amt = clamp((S - 0.18) * 1.7, 0, 1)              // low-sat (metal rod) stays neutral
     pixel = mix(pixel, ramp, amt)
```

Curated swatches (Ironbit accents): teal `#37d2cf` (default), neon green `#00FF9C`,
amber `#FFD700`, cyan `#00BFFF`, magenta `#FF4DCD`, red `#FF2D55`. The custom picker
accepts any hex. Default crest is all-teal (matches the source art); recolor is skipped
entirely at teal so the original pixels show through untouched.

---

## 5 · State & persistence
Crest state is `{ shape, emblem, bannerColor, emblemColor, name, motto }`, saved to
`localStorage` under `ironbit_crest_forge` and restored on load. `name` + `motto` are
free-text (guild identity), shown under the crest. No backend.

## Design tokens
- Field / stage: `#0c0d15`, page gradient `#13142a → #0b0c16`, stage radial `#1b1d33 → #0c0d16`
- Tile / card: `#11111f` fill, `#24243e` border, selected border `#00FF9C` on `#16261f`
- Fonts: **Press Start 2P** (labels/headings, ALL-CAPS, 6–17px), **Share Tech Mono** (body, motto)
- The crest art itself uses no fonts — pure canvas + the PNGs.

## Files in this bundle
- `README.md` — this document.
- `Crest Forge.dc.html` — the working reference build (shape/emblem/color pickers + animated
  canvas preview). The crest logic is the `class Component` script: `buildLayers()` (render +
  recolor the two layers), `composite()` (per-frame sway blit), `recolor()` (tone-preserving
  tint). `support.js` is its runtime (only needed to open the file standalone).
- `assets/guild/crest/blank_*.png` — the 4 banner shapes (transparent interior).
- `assets/guild/crest/icon_*.png` — the 4 emblems.
- `assets/guild/guild_hall.png` (1619×971) and `guild_hall_base540.png` (540×324) — the hall
  backdrop, for placement reference.
- `preview.png` — a built crest on the stage.
- `placement.png` — the crest hung in the hall's center bay.
- `Guild Hall.dc.html` — bonus: the hall backdrop build (its own torch/ember animation), so
  you can see exactly how the crest layers into the bay.

> Note: the `.dc.html` files reference Ironbit token stylesheets under `_ds/` that are not
> included (they only style the demo chrome). The canvas crest renders without them.
