# GUARDRAILS — read before coding

Hard rules. These encode the product's soul and the visual physics. Breaking one breaks
the screen even if it "looks fine" in isolation.

---

## A. Visual / art

### 1. Pixel-art light is pixel art — never a smooth gradient
The floor pool and beam are rendered on a **low-res canvas, scaled up nearest-neighbour**
(Bayer-dithered, chunky cells). This is the single most important visual rule. Do **not**
replace them with CSS/`BoxDecoration` radial gradients — they will read as generic glow
and shatter the arcade aesthetic. Port the dither algorithm, or play pre-rendered pixel
frames. Same goes for BIT and the window APNGs: pixel grid, `FilterQuality.none`.

### 2. BIT wins the eye — always
BIT's lens is the **single brightest, most saturated point on screen.** Everything cyan
near him (pad strip, floor pool, beam) is deliberately held **dimmer and cooler** so it
reads as "powered" but never competes. If you brighten the pad, you must re-dim it until
BIT leads again. The whole composition is a salience hierarchy with BIT at the top.

### 3. BIT floats — he is not grounded
He hovers ~80px above the emitter with a **clean dark gap**; the beam **fades to zero
before touching him.** No shadow/glow clings to his underside (`groundGlow: false` —
we removed it precisely because it looked like a shadow on a floating body). The pad has
its own contact shadow; BIT does not.

### 4. The room reads as a lit space
Wall **lighter** than bg and floor, lit from the ceiling fixture. If the planes flatten
to one value it stops being a room and becomes a card. Keep the three-plane value
separation and the top-light.

### 5. One world, not eight widgets
Information lives as **things in the room**, not stacked cards. When you add a system
(Quests, Logs, Expedition, collection), make it a *surface in the scene* — a wall panel,
the pad, a shelf — not a new card. The feed below is a minimal companion, not the home.

## B. Product / tone

### 6. Anti-guilt, body-neutral, always
- **No guilt-trips.** Never "You missed a day", streak-shaming, red warnings, or
  loss-framed nudges. Absence is **rest**: the room rests, BIT rests — calm, dim, content.
- **Body-neutral.** No body-composition framing, no before/after, no weight/calorie guilt.
  Training mints Core/XP/Gems; that's the language.
- **Return is invited, not demanded.** Anticipation (BIT "returns in 2h", a shifting
  window, a haul waiting) — never pressure. When in doubt, the **calmer** option wins.

### 7. Copy style
Terse, arcade, declarative. `PressStart2P` for headers/labels, `ShareTechMono` for
meta/values, `Gotham` for any longer body text. Uppercase short labels (`HOME`, `TRAIN`,
`UPPER BODY`). No emoji unless it's already an in-game glyph.

## C. Motion / accessibility

### 8. Respect reduced-motion
Every engine checks `prefers-reduced-motion` and **freezes to a lit still** — no strobe,
no infinite decorative loops. Mirror this in-app (`MediaQuery.disableAnimations`). The
pixel-dropout flicker especially must stop.

### 9. Performance
Three `requestAnimationFrame` engines run at **~14fps** (throttled on purpose — chunky is
the look *and* cheaper). Keep them throttled; pause when Home is off-screen / app
backgrounded. Don't run them at 60fps "for smoothness" — it's wrong artistically and wastes
battery. The window APNGs are tiny (~63KB, 28 frames) — fine to keep playing, but pause
when not visible.

### 10. Hit targets
Bottom-nav items and the raised TRAIN button must be **≥44px** touch targets. BIT's tap
area is his canvas (92px) — generous, good.

## D. Engineering hygiene

### 11. Strip the dev scaffolding
`preview.html` contains things that are **prototype-only** — remove them in the app:
- The `.phone` + `.notch` device mock (use the real device frame / safe areas).
- The entire `.twk` **Tweaks panel** and its postMessage/host protocol — it's a design
  tool, not a feature. The world-window must be driven by the **device clock**, not the
  picker.
- The `9:41` fake status bar (`.sysbar`).

### 12. Don't fill the reserved space
The collection wall, Quests/Logs terminals, and Expedition are **future**. The layout
leaves room for them on purpose. Do **not** add placeholder furniture, dummy quests, or
filler stats to "complete" the screen. Empty, calm, and correct beats full and noisy.
Every element must earn its place.

### 13. Tokens are the source of truth
Pull every color, size, font, and timing from `colors_and_type.css` / `tokens.dart`. Don't
hardcode hexes that duplicate a token. If a value isn't in the tokens but is in this spec,
add it to the tokens, then reference it.
