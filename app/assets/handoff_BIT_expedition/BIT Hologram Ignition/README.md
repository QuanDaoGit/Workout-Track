# BIT — Hologram Ignition

An isolated demo of one beat: **BIT's hologram showing up.** When BIT sets out on
an expedition he leaves an empty dock; **~2 seconds later** his holographic
projection **flickers on** — a struggling-fluorescent-tube ignition that stutters,
then catches and holds. Not a smooth fade.

Open **`BIT Hologram Ignition.html`** (double-click — works offline). It auto-plays
and **loops**; use **▶ REPLAY** to re-trigger, **⟲ LOOP** to stop/resume the cycle.

```
BIT Hologram Ignition/
├── README.md
├── BIT Hologram Ignition.html   ← the demo (self-contained, loops)
├── engine/
│   ├── holo-bit.js   ← the hologram + projection-rig painter (owns the ignition)
│   └── bit.js        ← BIT's sprite engine; the holo samples his LIVE canvas
└── assets/
    └── bit_pad.png   ← the emitter console BIT projects from
```

## The sequence

| Time | Beat |
|---|---|
| 0.0s | BIT departs — dock is empty |
| 0–2.0s | empty-dock beat (`scheduleHolo`'s delay) |
| 2.0s | **flicker ignition** — stutters on (~0.9s) |
| ~2.9s | hologram online, holds, then the loop recycles |

## How it works (drop-in)

```js
const holo = HoloBit.create({
  holoCanvas, fxCanvas,                 // BIT layer · rig layer (behind)
  bitCanvas: () => window.__bit.el,      // BIT's live sprite canvas (sampled each frame)
  ax: 185, emY: 390, topY: 286,          // projection axis x · emitter y · volume top
  reduceMotion: matchMedia('(prefers-reduced-motion: reduce)').matches
});
holo.start(2000);   // empty dock 2s, THEN flicker-ignite
holo.stop();        // tear down (also cancels a pending delay)
```

- **Ignition shape** is one tunable: `igniteEnv(ms)`'s `K` keyframes (`[ms, level]`,
  0..1 over ~900ms) in `engine/holo-bit.js`. The **gap** is the `start()` argument.
- The stutter rides the engine's **~20fps** loop — the coarse frame rate is what
  makes it read as an authentic tube catching, not a dimmer.
- **Reduced motion** → no gap, no stutter: the hologram appears as a static still.

> This is the same engine used in the Home Room / send-off handoff; this folder
> just isolates the show-up beat so it's easy to review and tune.
