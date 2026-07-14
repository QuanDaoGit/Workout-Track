# Handoff: Body Map — muscle coverage (volume → intensity)

## Overview
A front/back body silhouette where each muscle region's **brightness encodes weekly training volume** against that muscle's MEV/MAV landmarks. It replaces the Muscle Balance bars in **WorkoutLogsPage**. This bundle is a **design reference** (built in HTML/Canvas as a Design Component) — recreate it in the Flutter app using the existing Ironbit widgets/tokens. Do **not** ship the HTML. Fidelity: **hi-fi** (final colors, math, motion).

The data engine, 6-bucket mapping, MEV/MAV defaults, and zone names already exist on your side. This handoff supplies: the **assets in the right shape**, the **ramp + motion + token numbers**, the **runnable reference**, and the **production layout spec**.

---

## 1. Assets

### Bases (untrained layer) — `source/base_front.png`, `source/base_back.png`
Grey body + neon outline, **1024×1536**, pixel-registered. This is the "0 sets / untrained" layer, always visible. In production it is shown **dimmed** (see *Compositing*) so lit muscles read against it.

### Region masks — `masks/front/*.png`, `masks/back/*.png`
**Flat, uncolored, transparent white-alpha silhouettes**, one muscle per file, **registered to the base at 1024×1536**. RGB is pure white; the **alpha channel is the muscle's lit shape**. No baked color, no baked glow — you apply `kNeon`, the ramp opacity, and the glow **in code**, so you can vary brightness across the ramp and recolor on tap.

> **Only `masks/front/delts.png` is pre-rendered (sample).** The sandbox couldn't batch-export all 18, so generate the rest locally — it's deterministic and takes seconds:
> ```
> cd handoff && npm i sharp && node build_flat_masks.mjs
> ```
> This reads `source/{front,back}/*.png` (the registered colored extractions) and writes the full flat-mask set to `masks/{front,back}/*.png`. The exact transform is in the script header; tune `FLOOR` for tighter/softer shapes.

### Sizing / scaling
Masters are **1024×1536**. Render target is your call — recommend **512×768 (÷2)**. **Scale by integer factors only** with nearest-neighbour for the **base** (pixel-art linework shatters on non-integer NN). The **masks** are soft shapes and tolerate area-average downscale fine. Tell me your real in-app body height and I'll export both pre-scaled to clean divisors (÷2 = 512×768, ÷3 ≈ 341×512, ÷4 = 256×384).

### Naming — normalized as you asked
`back_` prefix dropped, `lower_backs→lower_back`, `hamstring→hamstrings`. Note: front inner-thigh is exported as **`adductors.png`** (anatomically correct; it was `abductors.png` in the audit — confirm you want adductors).

---

## 2. Runnable reference — `prototype/Body Map.dc.html`
The source of truth for glow, ramp math, mask compositing, pulse, and the FRONT/BACK toggle. It's a Design Component (single file). The load-bearing logic lives in the `<script>` class at the bottom (`opacityOf`, `zoneOf`, `applyGlows`, `renderVals`). Port that verbatim rather than re-deriving. To run it standalone it needs the Ironbit `_ds` bundle + `assets/` — but everything you need to port is documented below, so the README is self-sufficient.

---

## 3. Colors → tokens
Everything is **kNeon** at varying opacity/treatment — there is **no good→bad hue shift**. HIGH is **not** amber (kAmber is reward/XP; using it here reads as caution). HIGH = same neon as OPTIMAL, capped, with a neutral marker only.

| Use | Value | Token (tokens.dart) |
|---|---|---|
| Lit fill (all zones) + glow | `#00FF9C` | **kNeon** |
| Glow color | kNeon @ **0.42 α**, blur ~6px @512 (~12px @1024) | kNeon |
| Untrained body | the base PNG's grey | (asset) |
| Base dim scrim (legibility) | `#080C22` @ **0.50 α** over the base | **add `kCoverageScrim`** |
| Meter — BUILDING bar | `#2F8F6E` | **add `kVolBuild`** |
| Meter — BUILDING label | `#5FD0A8` | **add `kVolBuildText`** |
| Meter — OPTIMAL/HIGH bar + label | `#00FF9C` | kNeon |
| Meter — MEV tick | `#E8E8FF` @ 0.55 α | kText |
| Meter — optimal band tint | kNeon @ 0.12 α | kNeon |
| REST label | `#555577` | kDim |
| HIGH "over-ceiling" ▲ marker | `#9494B8` | kMutedText |

---

## 4. Ramp + motion (exact)

**Per-region opacity** as f(sets, MEV, MAV) — applied as the tinted mask's opacity over the dimmed base:
```
sets <= 0            → 0.0                                   // REST: base only
1 <= sets < MEV      → 0.18 + 0.26 * (sets / MEV)            // BUILDING: ~0.18→0.44 (dim)
MEV <= sets <= MAV   → 0.78 + 0.22 * ((sets-MEV)/(MAV-MEV))  // OPTIMAL: 0.78→1.0 + glow
sets > MAV           → 1.0                                   // HIGH: capped, no brighter
```
**Glow/bloom**: apply only when `sets >= MEV` (OPTIMAL + HIGH). Neon, ~6px blur @512. BUILDING has **no** bloom — the bloom is the second cue that separates dim from bright.

**Base dim**: composite `kCoverageScrim @0.50` over the base, **under** the region layers. This is the legibility fix — without it, the bright base washes all levels to the same brightness. Exposed in the prototype as `restDim` (0–0.75, default 0.5); ship at 0.5.

**Zones** (labels are the non-color carrier — required for a11y; never rely on hue/brightness alone): `REST · BUILDING · OPTIMAL · HIGH`.
```
sets<=0: REST   sets<MEV: BUILDING   sets<=MAV: OPTIMAL   else: HIGH
```
HIGH marker: small neutral **▲** at the MAV end of the meter (kMutedText) + the word "HIGH". No recolor, no amber/red.

**Motion**
- Region opacity + meter-fill width: **240–260ms, easeOutCubic** (`cubic-bezier(0.33,1,0.68,1)`).
- Pulse (optional, OPTIMAL/HIGH only): period **2.6s ease-in-out**, brightness 1.0→1.22, glow blur 6→10px. **Under reduced-motion: freeze to the static lit frame** (no animation, hold full).
- FRONT/BACK toggle: prototype display-swaps; recommend a **180ms** cross-fade.

---

## 5. Production layout (the shipped surface — NOT the preview harness)
The HTML has steppers + FILL OPTIMAL/RESET — those are a **preview harness only**. Production is **read-only, data-driven**:

- **Phone width, inside the WorkoutLogsPage scroll** (not the wide two-pane desktop layout).
- **Body** (base + region layers) on top, sized for phone (e.g. ~300–360px tall, integer-scaled).
- **Panel = a per-muscle list** replacing Muscle Balance bars. Each row, **read-only**: muscle name (PressStart2P) · weekly set count (mono) · volume **meter** (fill + MEV tick + optimal band) · **zone label** (REST/BUILDING/OPTIMAL/HIGH). No steppers/buttons.
- **Keep**: FRONT/BACK toggle, the **"last 7 days"** window label, the **rollup line** (total weekly sets + zone tally, e.g. "4 optimal · 2 building · 1 high").
- **Tap a muscle** → drill into that muscle's sets + contributing exercises (per our last call — confirm).
- **Type**: PressStart2P for labels (display theme, ~8–10px), Share Tech Mono for numbers.

---

## 6. Region → bucket map (please confirm)
Each mask is driven by its **bucket's** weekly-set count. Buckets + MEV/MAV (your defaults):
`Chest 10/20 · Back 10/20 · Shoulders 8/18 · Arms 8/18 · Legs 8/18 · Core 6/16`

| Mask | Bucket | | Mask | Bucket |
|---|---|---|---|---|
| front/chest | Chest | | back/traps | Back |
| front/delts | Shoulders | | back/lats | Back |
| front/biceps | Arms | | back/lower_back | Back |
| front/forearms | Arms | | back/rear_delts | Shoulders |
| front/abs | Core | | back/triceps | Arms |
| front/obliques | Core | | back/forearms | Arms |
| front/quads | Legs | | back/glutes | Legs |
| front/adductors | Legs | | back/hamstrings | Legs |
| front/calves | Legs | | back/calves | Legs |

---

## Compositing model (how one region renders)
```
layer 0: base_{front|back}.png                      (grey body + outline)
layer 1: kCoverageScrim @ 0.50                       (dim the untrained body)
for each muscle in view:
  tint mask_{muscle}.png → kNeon
  opacity = opacityOf(sets, MEV, MAV)                (§4)
  if sets >= MEV: add neon glow (blur ~6px@512, kNeon@0.42)
  draw over the stack
```
Masks are registered, so every region draws at the same transform as the base — no per-muscle positioning.

## Files
- `masks/{front,back}/` — flat white-alpha region masks (run the generator to fill).
- `source/{front,back}/`, `source/base_*` — registered colored extractions + bases (generator inputs / base assets).
- `build_flat_masks.mjs` — source → flat masks.
- `prototype/Body Map.dc.html` — runnable reference (port the `<script>` logic).
