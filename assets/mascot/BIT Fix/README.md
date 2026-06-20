# BIT — Colour Fix (export)

Everything corrected in the BIT colour pass, in one folder. The **only** thing
that changed is hue assignment — geometry, sprites' shapes, dither, beam cone,
and every animation are untouched.

## The principle

BIT's light is a **readout**, not a vibe. It either **echoes an active system
signal** (amber = reward, cyan = recovery) or shows BIT's **own reserved
turquoise identity** (`#23D6CC` family). It never lights up in the tap-target
green or burns the celebration amber on a nudge — and BIT's *machine light*
(pad pool, beam, lamps) is turquoise, not recovery-cyan.

Turquoise sits deliberately between recovery-cyan (`#00BFFF`) and tap-green
(`#00FF9C`), so BIT finally owns a hue no status uses.

---

## 1 · Screen-face moods  (`RAMPS` / `GLOW` / `EYECOL`)

Drop-in replacement for the three tables in `BIT Companion.html` (and the same
names wherever the sprite engine is ported — `bit-boot`).

```js
const RAMPS = {
  NEUTRAL: ["#0A5A5E", "#0F9EA0", "#23D6CC", "#73F2E8"], // BIT turquoise — identity
  CHEER:   ["#7A5200", "#C99400", "#FFD21F", "#FFEC8C"], // amber — echoes reward
  ALERT:   ["#0B3A40", "#0E6E70", "#16A39A", "#46D0C4"], // dim turquoise — low power
  REST:    ["#06303E", "#0A5570", "#117CA8", "#2C9AD8"], // dim cyan — echoes recovery
};
const GLOW   = { NEUTRAL: "#17D6CC", CHEER: "#FFD700", ALERT: "#0E6E70", REST: "#0E4F74" };
const EYECOL = { NEUTRAL: "#FFFFFF", CHEER: "#FFFDF0", ALERT: "#DFF7F2", REST: "#CFEAF7" };
// metal accent lamps → turquoise so BIT's body owns the hue:
//   METAL.c = "#15B8B0";  METAL.C = "#5EE8DD";
```

| Mood    | Fires on            | Was (collision)        | Now            |
|---------|---------------------|------------------------|----------------|
| NEUTRAL | briefing · default  | cyan = recovery        | BIT turquoise  |
| CHEER   | level-up · reward   | green = tap-target     | amber          |
| ALERT   | idle nudge          | amber = celebration    | dim turquoise  |
| REST    | recovery day        | dim cyan = recovery    | dim cyan (kept)|

Regenerated sprites live in **`sprites/`** (`bit_<mood>_1x.png` + `_8x.png`,
44×44 / 352×352, transparent — glow is a separate layer, as before).

---

## 2 · The hover pad  (light + beam + sprite)

The pad pool and the rising beam shared one **recovery-cyan** ramp. Both now use
BIT's turquoise emitter ramp — pool and beam still read as one emitter.

```js
// bitpad-light.js & bitpad-beam.js — TIERS (rgb, base alpha)
const TIERS = [ null,
  { c: '26,150,142',  a: 0.24 },   // deep turquoise   (was 30,130,178 cyan)
  { c: '40,206,194',  a: 0.46 },   // bright turquoise (was 48,190,232 cyan)
  { c: '128,240,228', a: 0.70 },   // light turquoise  (was 132,232,255 cyan)
  { c: '210,255,250', a: 0.88 },   // near-white core  (was 214,250,255 cyan)
];
```

Both engines now also:
- accept an optional **`tiers`** override in their config (so the emitter colour
  is configurable without editing the file), and
- **auto-stop** their animation loop when the canvas is removed
  (`canvas.isConnected` guard) — no stacked rAF loops on re-init.

**`bit_pad.png`** — the console sprite's baked-in cyan emitter lamps
(`#57DBFF` / `#2BB2DC` / `#1C6E92` / `#AEEEFF`) were hue-rotated to turquoise.
The dark blue-grey metal body is untouched. (`bit_pad_current.png` is the
original cyan sprite, kept only for the demo's before/after toggle.)

---

## 3 · Demo

**`BIT on Pad (fixed).html`** — BIT floating on the fixed pad with the live
turquoise pool + beam. Switch moods (NEUTRAL / CHEER / ALERT / REST) and flip the
emitter **CURRENT cyan ↔ FIXED turquoise** to see the change in motion.
(Links `../colors_and_type.css` for tokens/fonts.)

---

## Files

```
BIT Fix/
├─ README.md                  ← this file
├─ BIT on Pad (fixed).html    ← live demo (mood switch + current/fixed toggle)
├─ bitpad-light.js            ← floor-pool engine, turquoise TIERS + tiers override
├─ bitpad-beam.js             ← rising-beam engine, turquoise TIERS + tiers override
├─ bit_pad.png                ← console sprite, emitter lamps recoloured turquoise
├─ bit_pad_current.png        ← original cyan sprite (demo toggle only)
└─ sprites/
   └─ bit_<mood>_<1x|8x>.png  ← four moods regenerated with the fixed palette
```

## To apply across the system

1. Paste the three tables (§1) into `BIT Companion.html` and any port (`bit-boot`).
2. Replace `bitpad-light.js` + `bitpad-beam.js` with these, or just swap the
   `TIERS` array in your copies.
3. Replace the pad sprite and the Home Room mood PNGs with the recoloured /
   regenerated versions here.

> Keep all three render copies in sync — the same hue tables must apply to the
> Companion engine, the boot port, and the baked Home Room PNGs, or they'll drift.
