# Handoff: Ironbit — Home Room

> The Core chamber. A single coherent scene the user calls home — *not* a stack of
> widget cards. The procedural **face/BIT** is the centerpiece, projected as a holo
> companion hovering over a neon **emitter pad**, in a lit room whose every surface
> maps to a game system (training → Core/XP, Quests → Gems, BIT scouts → haul, VIT
> recharges). Body-neutral, anti-guilt, calm. Return is *earned and inviting*, never
> a guilt-trip.

---

## 1. What this bundle is

The files here are a **design reference built in HTML** — a working prototype showing
the intended look, motion, and behavior of the Home screen. **They are not production
code to paste in.** Your job is to **recreate this screen in the app's real
environment** (the codebase is Flutter — see `colors_and_type.css` header which points
to `lib/theme/tokens.dart`), using its established widgets, theme tokens, and patterns.

Treat the HTML/CSS/JS as the **source of truth for layout, proportion, color, motion,
and the light/beam art** — and reproduce that fidelity with native equivalents.

The three JavaScript engines (`bit.js`, `bitpad-light.js`, `bitpad-beam.js`) render
**pixel-art light on `<canvas>`** procedurally. They are the *canonical art* — port the
algorithm (the cell grid + Bayer dither + cyan ramp), or render them to sprite-sheets /
APNG and play those, but **do not** approximate them with smooth gradients. (See
`GUARDRAILS.md` — this is the #1 rule.)

## 2. Fidelity

**High-fidelity.** Final colors, typography, spacing, motion timings, and the pixel-art
light are all locked. Recreate pixel-perfectly. Exact values are in `colors_and_type.css`
(design tokens) and `LAYOUT-SPEC.md` (positions, sizes, z-order).

## 3. How to read this folder

| File | What it's for |
|---|---|
| **`preview.html`** | Open in a browser — the live, self-contained screen. This is the spec made real. |
| **`LAYOUT-SPEC.md`** | The room's coordinate system, every element's position/size, the full z-index map, the day/night + scroll behavior. |
| **`IMPLEMENTATION.md`** | Step-by-step build order, the three engines' public APIs + exact init configs, how the pieces compose. |
| **`GUARDRAILS.md`** | Hard rules — salience, anti-guilt, performance, accessibility, what NOT to do. Read before coding. |
| **`components/`** | One doc per component (Room shell, BIT, Hover pad, World window, Identity + Resources, Bottom nav, Feed cards). Each has purpose, anatomy, exact styling, states. |
| **`colors_and_type.css`** | The design tokens (palette, type ramp, spacing, motion, glow). Mirror of `tokens.dart`. |
| **`assets/`** | Every sprite, icon, window APNG, and engine the screen references. |
| **`fonts/`** | The three families (PressStart2P, ShareTechMono, Gotham). |

## 4. The six product principles (why this screen exists)

1. **Home is a place, not a stack of cards.** Old mission/character/quest cards become
   *things in the room*. The scene carries the information.
2. **The face is the centerpiece, projected.** Identity rests on BIT, rendered large as
   the single brightest thing on screen. You open Home and the first thing you see is you.
3. **BIT is the life and the explorer.** The hovering companion makes the room feel alive
   (the Tamagotchi "reacting creature" pull, minus the guilt) and is who you fuel + send
   scouting. One character, both jobs.
4. **The room is wired to the lore.** Every surface maps to a system. The room is the
   economy made visible, not decoration.
5. **It pulls you back without pressure.** World-window shifts by time of day; the room
   *rests* (never sulks) when away; BIT's "returns in 2h" creates anticipation. Calm,
   body-neutral, anti-guilt.
6. **It's built to grow.** The wall is a modular collection grid from day one — furniture,
   trophies, loot slot in over time without re-layout. (Not built yet; reserve the wall.)

> **Scope of THIS handoff:** the room shell, BIT on his pad with the full light system,
> the world-window with time-of-day, identity + resource HUD, bottom nav, and the first
> feed card. The modular collection wall, Quests/Logs terminals, and Expedition flow are
> *future* — the layout reserves room for them (see `LAYOUT-SPEC.md` §7).

## 5. Asset inventory

All under `assets/` (paths are exactly as referenced by `preview.html`).

**Engines (canonical procedural art — JS):**
- `assets/bit/bit.js` — BIT companion engine. `window.BIT.mount(host, opts)`.
- `assets/bit-pad/bitpad-light.js` — pad floor-pool light. `window.BitPadLight.init(canvas, cfg)`.
- `assets/bit-pad/bitpad-beam.js` — rising hover beam. `window.BitPadBeam.init(canvas, cfg)`.

**Sprites / art:**
- `assets/bit-pad/bit_pad.png` — emitter console, **108×40 native**, transparent, shown ~1.4×.
- `assets/decor/window_{morning,noon,afternoon,evening}.png` — **animated APNG**, 90×75 native, 28 frames. World-window by time of day.

**Icons** (12–13px, used as CSS masks tinted by token color):
- `assets/icon_coin.png` (Gems), `assets/icon_drop.png` (VIT) — resource HUD.
- `assets/icon_map.png` (Home), `assets/icon_character.png` (Hero), `assets/icon_sword.png` (Train), `assets/icon_scroll.png` (Quests), `assets/icon_bag.png` (Bag) — bottom nav.

**Type:** `fonts/pressstart2p`, `fonts/sharetechmono`, `fonts/gotham`.

## 6. Source files in the live project

- `Home Room/index.html` — the screen (this `preview.html` is a copy with one path fixed).
- `colors_and_type.css` — tokens (project root).
- `Home Room/assets/…` — engines + sprites (mirrored here under `assets/`).

---

*Built body-neutral and anti-guilt by design. When in doubt, the calmer option wins.*
