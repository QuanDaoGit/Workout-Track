# Handoff: Guild Crest — Banner Cloth Fill update

## What this is
A **drop-in asset update** for the 4 guild-crest banner shapes. It assumes the app has
already integrated the previous crest assets (the banner shapes whose cloth interior was
empty/transparent). These 4 PNGs **replace those files** — nothing else changes.

## What changed
Each banner now has its **cloth fill** baked in: the dark-teal vertical gradient + the
inner edge-glow, copied directly from the source reference art. The default **cog emblem**
and the **3 decorative dots** were removed from the center, so the only emblem shown is the
one the player stamps. (Previously these banners were just the outline + rod with a
transparent interior, so the crest looked hollow.)

So: same outline, same rod, same shape — now with a proper filled cloth and a clean center.

## Files (drop-in replacements)
Replace the existing same-named files:

| File | Shape | Notes |
|---|---|---|
| `blank_swallowtail.png` | swallowtail (V-notch) | cloth fill + outline + rod, center cleared |
| `blank_pennant.png` | pennant (single point) | " |
| `blank_draped.png` | draped (soft wavy bottom) | " |
| `blank_notched.png` | notched (square center notch) | " |

Each is RGBA with a transparent exterior (and transparent bottom-notch cut-outs); the cloth
interior is opaque, the outline glows. Sizes ≈ 193–207 px wide.

## Integration notes
- **No code change** beyond swapping the 4 files. The crest composite already draws the
  banner, recolors it, stamps the emblem on top, and sways it.
- **Recolor:** the cloth is teal in these files. The existing tone-preserving recolor tints
  it with the banner color and keeps the gradient/glow (low-saturation rod stays neutral).
  Default (teal) shows the art untinted.
- **Emblem placement:** unchanged — the chosen emblem is drawn centered on the banner body
  (~50% of banner height). The cleared center means it no longer collides with the old cog.
- **Cache-busting:** because the filenames are identical to the previous assets, bump your
  asset version / cache-bust query (e.g. `?v=N`) so clients fetch the new images instead of
  the cached empty ones. (In the prototype this is the `?v=4` suffix on the image loads.)

## How the fill was produced (for reference)
The source banner art had the cloth + a cog emblem + 3 dots. The cog/dots were removed by
reconstructing the center **row by row** from the clean cloth just outside it (sampling each
side at the same height and filling across), so the cloth's vertical gradient and edge glow
carry through where the emblem used to be. The cloth itself was never repainted — only the
emblem footprint was replaced.
