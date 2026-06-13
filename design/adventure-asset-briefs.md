# Adventure — asset generation briefs

> Companion to [docs/superpowers/plans/2026-06-12-adventure-design.md](../docs/superpowers/plans/2026-06-12-adventure-design.md).
> These briefs are written to be pasted into an image generator. Palette anchors mirror
> [lib/theme/tokens.dart](../lib/theme/tokens.dart) — generation needs literal hexes, but the
> implementation truth stays in `tokens.dart`.

## Universal style header (prefix EVERY prompt)

> 16-bit pixel art, flat 2D side-view, very dark nocturnal scene. Near-black indigo base palette
> (#11111F background, #1C1C34 midtones, #36365E edges), one accent color only, 8–12 colors
> total. Strong silhouettes, subtle dither, crisp single pixels, no anti-aliasing, no daylight,
> no text, no characters, no lens effects.

The **single-accent rule** is what keeps generated art looking like the app: every Ironbit screen
is dark indigo + one neon. Reject any generation with a colorful sky.

## 1. Route backdrops — 3 sets × 3 layers

Author at **480×270 native** (the app integer-upscales with nearest-neighbor — do NOT export
pre-upscaled). Generate the full scene first, then re-prompt per layer ("only the X layer,
transparent background"). The **ground strip must tile seamlessly horizontally** — it loops.

| Layer | Canvas | Role |
|---|---|---|
| A — Sky | 480×270, opaque | static backdrop: gradient + faint stars/haze |
| B — Far silhouettes | 480×270, transparent | scrolls slow (~30%) |
| C — Ground strip | 480×96, transparent, **tileable** | scrolls full speed; character walks on it |

### IRON VAULT — STR (accent: ember red-orange, `kDanger 0xFFFF2D55` → orange family)
> Industrial forge canyon at night. Sky: near-black with faint ember glow on the horizon.
> Far layer: silhouetted blast-furnace stacks, hanging chains, a colossal sealed vault gate.
> Ground: cracked iron plating with glowing seams, anvil debris. Mood: heat sleeping under metal.

### SKY TRACER — AGI (accent: violet `0xFFB14DFF`, Assassin)
> Vertiginous night sky-run above the clouds. Sky: deep indigo, thin violet jetstream lines,
> scattered pinprick stars. Far layer: silhouetted floating platforms and antenna needles
> descending into cloud haze. Ground: a narrow rail/beam path with gaps of cloud beneath, faint
> violet edge-light. Mood: speed at altitude, one wrong step.

### INFINI MAZE — END (accent: cyan `kCyan 0xFF00BFFF`, Tank)
> Endless labyrinth corridor at night, walls vanishing to the horizon. Sky band: near-black with
> a faint cyan grid-glow above the maze rim. Far layer: silhouetted maze walls layered into the
> distance, identical archways repeating. Ground: worn flagstones with hairline cyan rune-seams,
> occasional corner markers. Mood: no exit but forward — repetition as a monument.
> (An endless repeating maze is ideal for the seamless ground tile.)

## 2. Route emblems — 3 icons

**48×48, transparent background**, accent matching the route. They sit on the orders screen and
report card next to PressStart2P labels.

> Pixel sigil/badge style: heavy 2px outline (#36365E), dark fill (#1C1C34), accent used only
> for the glowing core element.

- **Iron Vault:** a vault door / anvil-lock hybrid, ember core
- **Sky Tracer:** a needle arrow tracing a violet contrail arc
- **Infini Maze:** a square spiral / greek-key maze glyph, cyan center

## 3. Find/loot icon sheet — 10–12 items

**24×24 each, transparent** (sheet or individual files). Flavor items the character brings back
("found: a rusted forge key"). Mostly neutral palette; **rarity decides the accent**: common =
none, uncommon = neon green #00FF9C, rare = cyan #00BFFF, epic = violet #B14DFF, legendary =
amber #FFD700.

> Tiny pixel relics, readable at a glance: a rusted key, a cracked ember stone, a coil of chain,
> a spire shard, a road token, a waterskin, an old banner scrap, a phosphor moth, a compass
> without a needle, a forge rivet, a folded map, a beacon lens.

Keep them **lore-flavored junk, not equipment** — collection charm, never power.

## 4. Code-drawn — no art needed (inventory for completeness)

- **Walking character** — user's avatar face on a procedural pixel body (avatar grid language),
  2-frame walk + 1px bob, class-color trim.
- **Ambient particles** — embers / jetstream motes / rune dust (existing `widgets/motion`).
- **Report chrome** — scanline/CRT pass, gem count-up, strobe/shake (existing widgets).
- **Parallax scroller** — `AnimationController` + `CustomPaint`; no game engine.

## Generation tips

- Most generators won't hold a strict pixel grid: generate at 2–4× and **downscale to native res**
  in a pixel editor, then **palette-quantize** (Aseprite or any free tool, one step).
- Judge every piece **in-app behind the scanline overlay** — the CRT pass forgives a lot of
  style drift; daylight or extra accent colors are the only hard rejects.
- Export indexed-color PNG. Expected total budget ≈ ½MB for everything above.

## Target asset paths

```text
assets/adventure/routes/iron_vault/layer_{a,b,c}.png
assets/adventure/routes/sky_tracer/layer_{a,b,c}.png
assets/adventure/routes/infini_maze/layer_{a,b,c}.png
assets/adventure/emblems/{iron_vault,sky_tracer,infini_maze}.png
assets/adventure/finds/<item>.png
```
