# Haul Cache + Homecoming — Developer Handoff

The **Haul Cache** is the tangible "haul waiting to be claimed" that sits on BIT's
hover pad after an expedition returns — the endowment hook before **COLLECT**. The
**Homecoming** is the ~1.9s beat that plays on app-open when a haul is waiting:
BIT rides the beam home and the dock fabricates the coffer.

Everything here is **pixel-authentic** — code-painted on low-res canvases and
blitted at integer scale (no CSS-shape fakes, no upscaled PNGs, no shimmer).

---

## What's in this folder

```
handoff_haul_cache/
├── README.md            ← you are here (overview + manifest + quick start)
├── IMPLEMENTATION.md    ← the animations: timeline, easing, control APIs, COLLECT, Flutter port
├── PIXEL-SPEC.md        ← the coffer pixel painter, the magenta gem palette, asset specs
├── assets/
│   ├── bit_pad.png      ← the emitter console sprite, 108×40 native (the pad)
│   ├── gem.png          ← THE currency — faceted magenta gem, 32×32 native
│   ├── gem_shield.png   ← streak-insurance variant, 40×40 native
│   └── bit_neutral.png  ← BIT fallback sprite (for the never-crash errorBuilder)
├── engine/
│   ├── coffer-paint.js  ← portable code-painter for the coffer (Option B)
│   ├── bitpad-light.js  ← floor-pool pixel light — cyan⇄magenta tint + intensity handle
│   ├── bitpad-beam.js   ← rising beam pixel light — withdraw + intensity handle
│   └── bit.js           ← the BIT companion engine (mount/setMood/spin/cheer)
└── reference/
    ├── Returned.html    ← FULL runnable reference: Home Room in the returned state
    │                      (homecoming on open, COLLECT ceremony, Tweaks)
    └── Haul Cache.html  ← the 3-option exploration (Strongbox / Coffer / Drop Pod)
```

> **Chosen design:** Option **B — the Banded Coffer**. Options A/C live in
> `reference/Haul Cache.html` for context only.

---

## The three rules that must survive the port

1. **Integer scale only.** The coffer is 28×20 native. Draw it at ×2 (56×40, the
   on-pad size ≈ ⅓ pad width), ×3, etc. — never a fractional multiple. Use
   `FilterQuality.none` / `isAntiAlias:false`. A non-integer upscale shatters the
   grid (the same bug that forced the pad sprite to be repainted). If an integer
   multiple won't fit a layout, **code-paint** at the exact size instead.
2. **BIT wins the eye.** BIT's cyan lens stays the single brightest, most
   saturated point on screen. The coffer's magenta underglow appears only on
   settle and is held *under* his lens (idle intensity ≈ 0.3–0.5). Magenta vs
   cyan is a clean complementary split — keep the coffer diffuse and dim.
3. **Never crash.** Every visual is painted in code. If you later commission a
   richer PNG coffer, keep a painted `errorBuilder` fallback and still display it
   at an integer multiple only.

---

## Currency: it's a MAGENTA gem

The expedition pays out **gems**, and the gem is **magenta** (`gem.png`), *not*
gold coins and *not* the old emerald. Sampled ramp:

| role            | hex       |
|-----------------|-----------|
| core / lit face | `#ff4dcd` |
| mid             | `#e028a0` |
| deep facet      | `#961c8c` |
| violet shadow   | `#9638d6` |
| sparkle / core  | `#ffffff` |

Use `gem.png` directly for UI (wallet, resource counter, store). For the tiny
in-world gem spill on the coffer, code-paint with the ramp above (see
`coffer-paint.js` / `PIXEL-SPEC.md`).

---

## Quick start (web reference)

`reference/Returned.html` is the source of truth for behaviour. It expects the
app's `colors_and_type.css` and the `Home Room/assets/` tree (BIT engine, pad
sprite, decor, icons). Run it from its home location — **`Home Room/Returned.html`**
in the project — where those paths resolve. The copy here is for reading.

Open it and you'll see: the homecoming plays once → the coffer sits sealed with
the magenta underglow + a **COLLECT** chip → tap COLLECT (or the coffer) for the
report ceremony. The **Tweaks** panel exposes route seal, integer scale (×2/×3),
glow mode, and **Replay Haul**.

Read **IMPLEMENTATION.md** next — it has the full animation timeline and the
Flutter port notes.
