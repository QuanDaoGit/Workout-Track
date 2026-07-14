# Component · BIT (the companion)

The centerpiece. A procedural pixel-art machine companion — core + four detached plates +
a glowing screen-face — that hovers over the pad. **The single brightest thing on screen.**
He is both the *life* of the room (reacting creature) and the *explorer* (you fuel him with
Core and send him scouting).

Rendered by `assets/bit/bit.js` onto a `<canvas>`. Do not re-draw him by hand — port the
engine or play its frames.

## Mount (exact, as shipped)

```js
BIT.mount(document.getElementById('bit'),
          { mood: 'NEUTRAL', px: 92, groundGlow: false });
```

Host markup:
```html
<div class="bit-anchor"><div id="bit" class="bit-host"></div></div>
```
```css
.bit-anchor { position:absolute; z-index:7; left:185px; top:340px; width:0; height:0; }
.bit-host   { position:absolute; left:0; top:0; width:92px; height:92px;
              transform: translate(-50%,-50%);
              filter: drop-shadow(0 0 5px rgba(0,191,255,.28)); }
```

**Anchor rule:** the hover-center (`left:185 top:340`) is a **fixed point**; the canvas is
centered on it with `translate(-50%,-50%)`. Swapping moods/poses never shifts his position.
He sits **~80px above** the pad emitter (pad top ≈ y414).

## Options that matter here

| opt | value | why |
|---|---|---|
| `px` | `92` | render size |
| `mood` | `NEUTRAL` | default calm-alert face |
| `groundGlow` | **`false`** | **critical** — his built-in under-glow read as a shadow stuck to a floating body. Off. The pad supplies all light below him. |
| `scanlines` | default on | CRT face texture |

## Moods

`NEUTRAL · CHEER · ALERT · REST` — each is a color ramp + glow + eye/mouth pose + plate
spread (see `bit.js` `RAMPS`, `GLOW`, `EYES`, `MOUTH`, `MOOD_SPREAD`).

- **NEUTRAL** — default. Cyan ramp `#0A5E72→#7CF2FF`, glow `#00BFFF`.
- **CHEER** — green, wide grin, plates spread; used on reward/press.
- **ALERT** — amber; for attention/notifications (e.g. BIT has returned).
- **REST** — dim teal, eyes lowered, plates tucked; **the away/idle state** (room rests).

## Behavior

- **Idle:** two out-of-phase sine waves — hover-bob + plate-breathe — plus an occasional
  blink. This copy is tuned to bob **2× faster, 1.5× larger range** than the canonical
  boot screen (intentional for the hero placement).
- **Press → spin (auto-wired):** `mount()` adds `click → spin()`. The reaction = flip to
  **CHEER** + orbit the four plates exactly **one full revolution** (950ms, ease-in-out),
  then settle back to the prior mood. This is the core "reacting creature" delight.
- **API:** `setMood(m)`, `spin()`, `cheer()` (one-shot flash), `replay()` ("BIT online"
  power-on), `destroy()`.

## How BIT maps to game systems

- **Fuel:** training mints **Core** → you spend it on BIT. Reflect fueled/cheerful vs.
  low-energy states via mood.
- **Explorer:** send BIT scouting → he leaves the pad; show a calm "returns in 2h"; he
  comes back with a haul (→ docks into the collection wall later). Use `ALERT`/`CHEER` on
  return. **No guilt while he's away.**
- **Life:** his idle + press reaction are what make the room feel alive (Tamagotchi pull,
  minus the guilt — he rests, never sulks).

## Rules

- BIT is the **brightest** element — never let pad cyan rival his lens (GUARDRAILS #2).
- He **floats** — no underside shadow; beam fades out below him (GUARDRAILS #3).
- Reduced-motion: idle + spin freeze to a lit pose (engine handles it).

## Native notes

Port the cell-grid renderer to a `CustomPainter` (core + 4 plate transforms + face ramp),
or pre-render mood/idle/spin frames (Rive fits the plate-orbit well). Tap target = the
92px canvas. Keep `groundGlow` off. Keep his `drop-shadow` rim glow.
