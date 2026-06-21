# Ironbit design learnings — recurring UI/UX failure modes

Maintenance gate (per task): read this before designing; after, add **at most one** learning, and only
if it would have prevented a concrete defect or a repeated review finding. **Generalize, never
transcribe** — an entry is a reusable category. Search the headings first and **update the matching
category over appending a near-duplicate**; include the date/trigger. Cap ~40 content lines below this
header; when over, prune the least-recently-fired category **in the same edit**. End the task by
stating "No new design learning" or the category you touched.

### Foreign-shape tells & pixel crispness
**Rule:** A perfect circle, a smooth diagonal bevel, a stock rounded-rect, or any Material-default
shape reads as *foreign* in a pixel-arcade app (a circle in particular screams "Material FAB"). For
distinctive shapes use a **4px / pixel-staircase cut-corner** geometry painted `isAntiAlias = false`
so the steps stay crisp. **Render pixel sprites at an integer multiple of their native size — or
paint them (resolution-independent)**; a *non-integer* nearest-neighbour upscale shatters the grid
into artifacts. **Outline painted sprites 4-connected (orthogonal only), never 8-connected** — a
diagonal pass grows protruding black nubs at convex/bevel corners (they catch against any glow).
*Seen: round Train button → pixel keycap (2026-06); a 108→150 (1.39×) pad sprite showed ✕ artifacts
→ repainted as a `CustomPainter` (2026-06); the faceless BIT's plate corners showed black nubs from
an 8-connected outline → 4-connected, matching the already-correct room companion (2026-06).*

### Raw color & alpha literals
**Rule:** Raw color belongs only in `tokens.dart`. Everywhere else, import a token and express tints as
`token.withValues(alpha: …)` — a raw `Color(0x..)` / `.withOpacity` tint of a token is *still* raw hex
and drifts when the token changes. At finish-time grep for **every colour spelling** — `Color(0x`,
`Color.fromRGBO`/`fromARGB`, named `Colors.x`, *and* token refs (`kCyan`) — not one; ripgrep has **no
negative lookahead**, so write plain alternations (a `(?!…)` clause silently matches nothing). Add a
shared token/const if no shade fits, don't inline. *(Procedural sprite-engine palettes — `_metal`,
`TIERS`, `RAMPS` — are the documented raw-`Color` exception.)* *Seen: `Color(0x0A00FF9C)` vs
`kNeon.withValues(0.04)` (2026-06); a BIT recolour grepped only `kCyan` and missed the boot UI's
`Color.fromRGBO(94,232,255)` cyan lamps (2026-06).*

### Motion salience & organic timing
**Rule:** Distraction ≈ velocity × contrast × size × count — match the dials to the role: focal events
can be loud; an ambient "ready" cue keeps **all dials low** (one slow dim element beats a sweep/bob/
marching border; a looping scale-pulse is a lazy "notice me"). A **focal** move also needs **duration
sized to its distance** — a full 360°/long travel in ~500ms whips regardless of the curve; give it ~2×
the time + a strong ease (cubic+), and **drop motion-blur trails on a deliberately slow move** (trails
read as *speed*). **Continuous idle** must be **sub-pixel** — `.round()`-ing a bob/float snaps it into
visible steps — a **painted** sprite floats truly sub-pixel, but a **raster** sprite must **snap its
float to whole device pixels** (a fractional sample shimmers the grid) and **breathe via its glow, not a
sprite scale** (scaling resamples) — and a flat raster of a **multi-part subject can't animate its sub-parts at
all** (baked into one image): a per-part motion (plate breathing) needs the **procedural painter**
(parts as separate shapes), so route a surface that must move sub-parts through the painted engine,
never a raster that silently can't honour the doctrine; breathe on a *decoupled* slow sine, and **resume a paused idle via an
amplitude ramp**, never a hard unfreeze (a live-sine resume pops). A **"weighty announcement"** needs an explicit **anticipation** wind-up (ease-in coil) + a brief
peak **hold**, not a cold `easeOutBack` launch — and build the coil as an **in-domain input**, not blend
**curve-extrapolation** (it throws unrelated fields out of range). Reach for the CRT/phosphor idioms,
don't pick a louder shape. **Scroll/parallax on a pixel diorama:** drift only the **soft (gradient)
layers** — fractionally translating a *crisp sprite* shimmers it (same grid-break as a non-integer
upscale); keep sprites at scroll rate, clip + over-paint (a wall-colour underlay) so the drift never
exposes a gap, and **gate the whole effect off under reduced motion** (WCAG 2.3.3 — it's a delight, not
usability). *Seen: armed-Train motes; cold-open spin robotic at 500ms/easeInOutQuad →
~1s/easeInOutCubic, ghosts removed; BIT's idle stepped from a `.round()`ed bob & the cheer reveal felt
abrupt (cold easeOutBack, no wind-up/hold) → sub-pixel float + decoupled breathe + ramp-resume +
explicit anticipation coil & peak hold; Home room parallax drifts only the soft `_RoomShellPainter`,
sprites untouched; the quiz/start-gate/loader BIT was raster (glow-breathe only, plates frozen) → moved to the painted
`BitMoodCore` so its plates breathe like the cold-open/solution, retiring the raster `BitIdle`; then BIT
placed on the **quest board** as a single *damped* faced briefing (scroll-not-pin, cheer only on claim) — a
companion on a surface the user *reads* stays **single-placement + state-reactive**, never pinned/per-row (2026-06).*

### Contrast by luminance, not hue
**Rule:** Legibility of particles/text/icons on a fill is driven by **luminance** contrast. On a
*bright* surface, a pale/near-white tint washes out — go dark-on-bright (and vice versa). Two bright
hues still have low luminance contrast (neon-on-glow is the trap). A caption that *must* sit over a
bright emissive layer (light pool, beam) needs a **dark readout backdrop** (the `_pill` pattern,
`kBg` α≈0.66), not a brighter hue. **A code-painted object placed *over a same-palette surface* (a
sprite on a sprite) camouflages — figure-ground needs a luminance/position break: lift it clear of the
host, offset its silhouette, or outline it; shared accent pixels alone don't separate it.** **Perceived
DEPTH in a dark scene is bought with *luminance* cues too, not saturation: lead with AO (corner +
horizon-settle darkening), contact/grounding shadows below wall fixtures (key light is from above), and
value plane-tiering — the aerial *veil* (desaturate/cool a far object) has almost no headroom in a near-
monochrome dark room, so it's optional last polish. A *self-luminous* focal element (BIT) separates from
its backdrop by **casting LIGHT (a faint bloom "pedestal" behind it), never a drop-shadow** — a glow with
a shadow on the same side reads as wrong physics. Keep it all **static** (paint-once, reduced-motion-
identical) and **function overrides recession** (a claimable amber cue must punch through any veil).**
*Seen: near-white motes invisible on the neon keycap → dark-green motes, denser; the pad's neon DISPATCH
caption vanished on the cyan light-pool → dark readout pill; the haul coffer in the pad-metal palette
merged into the pad → re-seated on the pad's lip + sized to read as a distinct chest; the Home-room depth
pass added corner-AO + horizon-settle + contact shadows under window/board + a `bitGlow` cast-light bloom
behind BIT, all in `_RoomShellPainter`/room_scene, sprites untouched (2026-06).*

### Colour hierarchy & accent discipline
**Rule:** The palette is **semantic** (neon = the one *action*, cyan = the chamber/BIT, amber = reward/
XP, red = VIT, white = identity) — but meaning isn't hierarchy. If every semantic colour fires at full
saturation/size at once they **fight** (keep ≈2–3 active accents; one "hot-action" colour earns the eye).
Reserve **neon for the primary action only** (not brand labels or "+today" info), keep one hue per zone,
and make reward/identity accents **quieter** (muted border, slimmer bar) so they recede. (Carrying state
in motion — a live timer/sweep over decoration — is the same restraint applied to motion.) **Hierarchy
needs *isolation + weighted tiers*, not uniform treatment** — flattening every element to one muted grey
(or boxing every component equally) kills the differentiators just as badly as everything-bright does.
Pick ONE hero, isolate it (whitespace/size/position), rank the rest; group related items in a *few*
weighted common-region panels, never one box per element ("cage of rectangles"). **Section-consistency:**
peers at the *same* tier must share a grouping treatment (all framed or all not) — a lone unframed peer
beside framed ones reads as *accidental*; weight differs *across* tiers (a hero sub-label may stay
unframed), never *within* one. *Seen: Home muted brand vs neon CTA (2026-06); the mission card then
over-corrected to one flat grey → re-tiered to a white hero + framed PATH panel + neon action; a bare
NEXT row beside the framed PATH read orphaned → gave NEXT a lighter common-region panel via the same
`ArcadeCard` primitive, weighted under PATH (2026-06).*

### No redundant chrome bands
**Rule:** Don't add a label/hint strip that restates what an adjacent surface already shows — it
stacks a third band between content and chrome. Fold the cue **onto its element** (e.g. a caption that
changes state) instead. *Seen: the "READY · TAP TRAIN" hint bar removed; cue moved to the keycap
caption TRAIN→START (2026-06).*

### Reduced-motion needs a non-motion fallback
**Rule:** Freezing an animation under `disableAnimations` must leave a **still, legible signal** — a
label, a static frame, a Semantics announcement — never a dead/ambiguous control. Design the
no-motion state first, then add motion on top. **The reduced-presentation trigger is the *union*
`disableAnimations || accessibleNavigation` — gate on it consistently across sibling surfaces; a
screen that checks only `disableAnimations` strands a screen-reader/switch-access user in the full
cinematic while its neighbours settle (prefer the shared `bool get _reduceMotion` idiom over an
inline `disableAnimations` check so the gate can't drift).** A **perpetual** full-bleed scene (ambient ticker that
never settles) must freeze for correctness *elsewhere* too: page-level `pumpAndSettle` tests hang if
it never stops, and a hero sized by a raw width-ratio overflows short/odd viewports — **clamp the
ratio**. **An overlay that masks a sprite's stale baked art must follow that sprite in *every* state** — hiding
it in one state (e.g. a launch recoil transform) re-exposes the old baked layer underneath; give the
overlay the *same* transform and keep it shown, don't hide it. **A surface is robust only against the
axes you *prove*:** a dense in-world HUD readout
beside a *centred* anchor (narrow side-gutters) clips under **large text** — **clamp its `textScaler`**
(the element's Semantics stays the screen-reader path) and **accept it via a width × text-scale golden
matrix** (e.g. 320/360/411 dp × {1.0, 1.3}), not a single happy-path golden. *Seen: armed Train falls
back to the START caption + Semantics label (2026-06); the Home Room's BIT/pad tickers hung a HomePage
`pumpAndSettle` test and a `520×k` hero overflowed the 800×600 test surface until clamped + frozen; the
"TAP TO DISPATCH" callout would clip at 320 dp × 1.3 → textScaler-clamped + accepted across a
320/360/411 × {1.0,1.3} matrix; the Profile hero card's **dual XP readout** (two unflexed `Text`s in a
`spaceBetween` Row) overflowed at 320×1.3 → `Flexible`+ellipsis on each. **Golden-ing a full
service-loaded page: one heavy page-pump per test *file*** — two `ProfilePage` pumps in one isolate
raced the ~10-service async load (the 2nd intermittently showed only the loader); split into
single-pump files + poll until the loader clears, never a fixed delay (2026-06).* **A custom chip that
supplies its own `Semantics(label:)` as the accessible name must set `excludeSemantics: true`** — else
the child `Text` node merges in, doubling the screen-reader announcement *and* breaking
`find.bySemanticsLabel` (exact-match) in tests. *Seen: weekday-picker chip's "MON training day, on"
label found 0 until the inner "MON" `Text` was excluded (2026-06); the onboarding shell/solution/
quiz/cold-open/option-list gated on `disableAnimations` only → a screen reader sat through the intro
cinematics → unified to the `||accessibleNavigation` contract via shared `_reduceMotion` getters (2026-06).*

### Reach for the app's own primitive first (and port reference source verbatim)
**Rule:** Before painting anything new, glob `lib/widgets/` + `widgets/motion/` and read the **nearest
existing surface** — the best style reference is the app's own code, not a generic catalog. Compose
from primitives (`PixelButton`, `ArcadeChip`, the motion wrappers, `arcade_route`, `neonGlow()`);
paint bespoke only when nothing fits, and then in the language. **When a handoff/reference ships actual
engine source for an effect, port it *verbatim* — reuse the REAL asset (the actual sprite/painter) for
a derived effect (a hologram = the real BIT post-processed, not a hand-redrawn lookalike) and replay
the real timeline beat-for-beat; a hand-rolled approximation reads as generic/off and the user will
catch it.** Extract shared sprite art behind one entry point (verify the original golden stays
byte-identical first). **Extending a shared primitive used across many flows** (e.g. `BitSpeechBubble`
in onboarding/quest/loader): keep its public path **byte-stable** — add only *optional* params that
default to the current behaviour — and gate on **every existing caller's** golden staying identical,
never just a new one. **An in-world speech balloon that can grow (wraps to 2 lines) and overlap a
sibling wall object must be drawn *after* it in the Stack (paint order = z) — and a dead-centre down-tail
reads stiff; the comic convention slides the tail slightly off-centre and *leans its apex back toward the
speaker* (offset + apexFrac, both additive/defaulted), so it points at the character instead of straight
down.** **A cross-cutting feedback channel (haptic/sound) wires the same way: give the shared primitive a
semantic-*intent* param (`selection`/`tap`/`success`/`reward`/`warning`) defaulting to the light case, with
a `none` opt-out for a button whose handler already owns its beat (avoids a double-fire), tiered by event
meaning — and, being tactile/auditory not *vestibular*, do NOT gate it on reduced-motion; it carries its own
toggle. A completion event detected by polling (no callback) fires its beat from the single dispose-managed
observer (never a service-owned `Timer` — that leaks as a flutter_test "pending timer"), de-duped via the
shared `cancel()`, with an overshoot guard so a stale post-background resume stays silent.** *Seen: keycap/motes/dioramas reused the motion + token vocabulary; the away
hologram was first a hand-painted blob + the send-off a bare fly-up → re-ported from `holo-bit.js`/
`playLaunch` to render BIT's real sprite + the full 5-phase launch; BIT's home-room voice extended
`BitSpeechBubble` additively (`child`/`emphasisColor`, then `downTailDx`/`downApexFrac` for the leaning
tail) — capped to ~85% width + re-stacked above the world window so a 2-line balloon paints over it,
proven against the onboarding/quest goldens (2026-06); `PixelButton` gained an optional `haptic` intent
(default `tap`, `none` on the handler-owned CLAIM button) centralizing haptics across 74 buttons + a Settings
toggle, and the rest-done haptic fired from `RestTimerBar`'s existing dispose-managed ticker, not a new
service timer (2026-06).*

### Discoverability & the false bottom
**Rule:** An **optional step or secondary control buried at the bottom of a scrolling list under a pinned
CTA is effectively invisible** — the first screen looks complete (false bottom) and the always-visible CTA
says "you're done here", so users never scroll. Don't fix it by **auto-scrolling on load** (removes user
control, disorienting) or by making the **primary CTA scroll instead of advance** (label↔action mismatch —
an anti-pattern; the only honest CTA-scrolls case is *submit→first validation error*). Instead **hoist the
optional control into the pinned action area** as a compact, always-visible summary-affordance (`LABEL ·
value ▸`) that opens the full editor (a bottom sheet reusing the same primitives), and **surface a
below-fold pre-selection by ordering it into view** (recommended-first), not by animating the page. Prove
it with a phone-size page golden + a "summary visible without scroll / opens editor" widget test. *Seen: the
onboarding weekday step was stranded under 3 tall program cards (user never saw it) → reordered recommended
program to top + a pinned `TRAINING DAYS · MON·WED·FRI ▸` row above START THIS PATH (2026-06).*
