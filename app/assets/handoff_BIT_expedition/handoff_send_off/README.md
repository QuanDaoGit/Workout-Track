# Send-off + Hologram — Developer Handoff

The companion to the *Haul Cache + Homecoming* handoff. This package covers the
**other half** of the expedition loop:

- **Launch / Send-off** — the beat that plays when you send BIT out on an
  expedition: charge → pad burst → BIT accelerates up the beam → beam-exit pop →
  the beam collapses and the dock rests.
- **Hologram (away state)** — while BIT is gone, the empty dock shows a
  pixel-authentic **holographic projection** of him, held in a structured
  projection rig (emitter field + containment brackets + scan-planes).

Everything is **pixel-authentic** — code-painted on canvases, ordered-dither,
integer-scaled. No CSS-shape fakes, no upscaled PNGs.

---

## What's in this folder

```
handoff_send_off/
├── README.md            ← you are here
├── IMPLEMENTATION.md    ← the animations: launch timeline + hologram rig, control APIs, Flutter port
├── assets/
│   ├── bit_pad.png      ← emitter console sprite, 108×40 native
│   ├── gem.png          ← the magenta gem currency, 32×32 native
│   └── bit_neutral.png  ← BIT fallback sprite (never-crash errorBuilder)
├── engine/
│   ├── holo-bit.js      ← PORTABLE hologram + projection-rig reference module
│   ├── bitpad-light.js  ← floor-pool pixel light — cyan⇄magenta tint + intensity handle
│   ├── bitpad-beam.js   ← rising beam pixel light — withdraw + intensity handle
│   └── bit.js           ← the BIT companion engine (mount/setMood/spin/cheer + .el live canvas)
└── reference/
    ├── Returned.html            ← FULL source: Home Room with all four states + Tweaks
    └── Returned-standalone.html ← self-contained, opens offline (double-click)
```

> Run the loop from the **Tweaks** panel in either reference file:
> **↑ SEND BIT** plays the launch → away/hologram · **↺ BRING HOME** plays the
> homecoming → returned · tap the coffer to **COLLECT**.

---

## The expedition state machine

```
  ┌─────────────┐   SEND BIT    ┌──────────────────────┐
  │  RETURNED   │ ────────────▶ │  LAUNCHING (~2.0s)    │
  │ (haul on    │               │  charge·burst·ascent  │
  │  the pad)   │ ◀──────────┐  └──────────┬───────────┘
  └──────┬──────┘            │             ▼
         │ COLLECT           │      ┌──────────────┐
         ▼                   │      │   AWAY       │  ← BIT's HOLOGRAM
  ┌─────────────┐  BRING     │      │ (hologram in │    projected on the
  │  CLAIMED    │  HOME      └──────│  the rig)    │    empty dock
  │ (empty,cyan)│ ◀── homecoming ──└──────────────┘
  └─────────────┘     (~1.9s)
```

`localStorage.ib_haul` persists `collected`; everything else is presentation that
can be skipped or interrupted without losing/double-paying rewards.

---

## Three rules that must survive the port

1. **Integer scale only.** The hologram draws BIT's sprite at ×2; the coffer is
   28×20 drawn at ×2. Never a fractional multiple (`FilterQuality.none`,
   `isAntiAlias:false`) — a non-integer upscale shatters the grid.
2. **BIT (and his hologram) own the cyan.** Cyan is BIT's identity — beam,
   underglow-home, launch bursts, and the hologram are all the cyan family.
   Magenta is the haul/currency. Keep them complementary, never competing.
3. **Never crash.** All visuals are painted in code. Keep a painted fallback
   (`bit_neutral.png`) for the companion sprite.

See **IMPLEMENTATION.md** for the full timelines, the control-handle APIs on the
two light engines, and the Flutter port notes.
