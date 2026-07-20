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
**Compositing a STACK of translucent image layers** (a heat/coverage map of region masks over a base):
apply per-layer intensity through **`Image`'s own `opacity:`** (true alpha scaling, paint-time, no
buffer) — **never the `Opacity` widget** (a `saveLayer` per layer → jank) nor **`BlendMode.modulate`**
(distorts a baked-colour RGBA toward white/dark). **Bake the glow into the art**, don't code a per-layer
blur (`saveLayer` again); wrap the whole stack in a **`RepaintBoundary`** so it composites once and
doesn't repaint with the surrounding scroll; skip a layer at opacity 0. Pre-coloured PNG art is the
documented tokens-only exception (like the BIT sprites) — keep meter/label/bar colours token-driven.
**A single-colour (white-on-transparent) pixel icon recolours to a token via `Image.asset(color:
…, colorBlendMode: BlendMode.srcIn)`** — author one silhouette, tint per-context (keep the *meaningful*
colour, e.g. a verdict glyph, the only one that fires); render at an **integer fraction of the source**
(author 20px → export 80px → render 40/60/80, never 36). **A coloured "accent bar" on one edge can't be
a non-uniform `Border` if the box has a `borderRadius`** — Flutter throws *"borderRadius can only be
given on borders with uniform colors"* at paint; use a **uniform border** (or a separate full-height bar
child / a `Stack`), never mixed per-side colours+widths with a radius.
*Seen: round Train button → pixel keycap (2026-06); a 108→150 (1.39×) pad sprite showed ✕ artifacts
→ repainted as a `CustomPainter` (2026-06); the faceless BIT's plate corners showed black nubs from
an 8-connected outline → 4-connected, matching the already-correct room companion (2026-06); the muscle
body map's region masks → `Image.opacity` + baked glow + `RepaintBoundary`, Codex flagged `modulate`
distortion pre-build (2026-06); the strength-roster lift icons recolour white→slate via `srcIn` at a
40px (80px÷2) integer scale, and a new-best "accent bar" via a non-uniform `Border`+radius crashed paint
→ uniform amber border instead (2026-06).*

### Raw color & alpha literals
**Rule:** Raw color belongs only in `tokens.dart`. Everywhere else, import a token and express tints as
`token.withValues(alpha: …)` — a raw `Color(0x..)` / `.withOpacity` tint of a token is *still* raw hex
and drifts when the token changes. At finish-time grep for **every colour spelling** — `Color(0x`,
`Color.fromRGBO`/`fromARGB`, named `Colors.x`, *and* token refs (`kCyan`) — not one; ripgrep has **no
negative lookahead**, so write plain alternations (a `(?!…)` clause silently matches nothing). Add a
shared token/const if no shade fits, don't inline. *(Procedural sprite-engine palettes — `_metal`,
`TIERS`, `RAMPS` — are the documented raw-`Color` exception — but the exception covers only NON-token
art hexes: a literal whose value IS a token (`0xFFFFA500` = kAmberDark) must still be the token, even
inside an art palette; `color_hygiene_test` polices exactly this.)* *Seen: `Color(0x0A00FF9C)` vs
`kNeon.withValues(0.04)` (2026-06); a BIT recolour grepped only `kCyan` and missed the boot UI's
`Color.fromRGBO(94,232,255)` cyan lamps (2026-06); the session + unlock ceremonies' spark/dust
palettes inlined kAmberDark/kBorderVariant values until the hygiene test flagged both (2026-07).*

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
usability). **A user-triggered content/layout change MUST animate the transition** (show-more/less,
expand/collapse, filter, paginate → `AnimatedSize` / `AnimatedCrossFade` / `AnimatedSwitcher`), never
snap — the motion *is* the feedback that the tap registered; an instant content jump reads as broken /
unresponsive. This is a floor, not a flourish (distinct from ambient decoration, which stays restrained);
pair it with the reduced-motion rule (omit the animator, don't zero it). *Seen: the body-map groups
animated their expand but the Logs SHOW MORE/LESS snapped the session list → wrapped the tiles in
`AnimatedSize` (kMotionPop, branched out under reduced motion), the user flagged the missing motion as a
UX rule-of-thumb (2026-06); armed-Train motes; cold-open spin robotic at 500ms/easeInOutQuad →
~1s/easeInOutCubic, ghosts removed; BIT's idle stepped from a `.round()`ed bob & the cheer reveal felt
abrupt (cold easeOutBack, no wind-up/hold) → sub-pixel float + decoupled breathe + ramp-resume +
explicit anticipation coil & peak hold; Home room parallax drifts only the soft `_RoomShellPainter`,
sprites untouched; the quiz/start-gate/loader BIT was raster (glow-breathe only, plates frozen) → moved to the painted
`BitMoodCore` so its plates breathe like the cold-open/solution, retiring the raster `BitIdle`; then BIT
placed on the **quest board** as a single *damped* faced briefing (scroll-not-pin, cheer only on claim) — a
companion on a surface the user *reads* stays **single-placement + state-reactive**, never pinned/per-row (2026-06).
**A cinematic VIDEO reveal is a sequence, not an autoplay:** CRT power-on → a held **poster** frame (the
frame-0 bitmap, NOT the raw video surface — frame 0 can decode black pre-`play()`) → an eased picture +
**audio** ramp-in; the **exit recedes and fuses into the follow-on** (peak-end: the ending dominates
memory, so invest it *more* than the entry), driven off **video position** not a fixed timer, keeping the
payoff caption readable *before* the recede. **Audio never slams** — ramp it in (leads the picture, a
J-cut) + tail it out clamped to 0 *before* the hard asset end (bake fades out of the clip so the app owns
them). A phase whose exit depends on an animation callback needs a **clock-driven watchdog in the pure
engine** or it soft-locks. All gated on reduced-motion — omit the animators but **keep the audio fades**
(a fade isn't "motion") (2026-07, Charge Ritual reel entry/exit).* **A cross-SCREEN cinematic handoff
(outgoing collapse → incoming reveal — a CRT power-cycle) must meet at a MATCHED seam:** end the collapse
at near-black and start the reveal's route from the same near-black (`ColoredBox(kBg)`) so no flash frame
shows between the two routes; a **shrinking bright element must CONCENTRATE** — dim while large → bright as
it thins to a line/dot — never a solid full-screen bright fill (max size×contrast reads as a screen
*flash*, not a collapse). **Asymmetric timing is a legitimate cinematic override** (a longer power-*off*
collapse than power-*on*, against the usual "exits faster") when the user asks for weight. Each concurrent
effect gets its **own controller** (a reused one couples its timing onto unrelated readers), and a cue that
must survive the route (the ignition SFX) needs its **own audio channel**, not the shared single-player a
next-screen sound would cut. *(2026-07, Charge Ritual power-cycle climax — Codex plan review + a golden
caught the solid-bright-fill flash.)*

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
`ArcadeCard` primitive, weighted under PATH (2026-06). **De-chroming a prestige cue can silently sink
it below the noise:** collapsing the profile's two stacked LV/RANK chips into one typographic stamp
line nearly demoted CHAMPION into level-metadata — fix is to keep the *meaning-bearing* cue (rank) the
**sole accent + a size/weight lead** and mute the detail (level), not average both peers to equal-grey
(2026-06).*

### No redundant chrome bands
**Rule:** Don't add a label/hint strip that restates what an adjacent surface already shows — it
stacks a third band between content and chrome. Fold the cue **onto its element** (e.g. a caption that
changes state) instead. *Seen: the "READY · TAP TRAIN" hint bar removed; cue moved to the keycap
caption TRAIN→START (2026-06).*

### Transient feedback must not block the action area
**Rule:** The canonical transient notice is the ONE shared center-screen overlay
(`showArcadeNotice`) — never a per-surface SnackBar (three styles had grown for one concept). Its
mechanics are the reusable pattern: content in `IgnorePointer`; the tap-anywhere-dismiss observer is
a full-screen `Listener(behavior: translucent)` — translucent **receives every pointer event while
returning FALSE from hit-testing**, so overlay entries/routes beneath still get the same tap
(dismissal is observation, never consumption; the notice can't block or steal any tap — a bottom
SnackBar over bottom-anchored controls did both). Non-stacking (new replaces current). *Seen: a
"Rest timer started" SnackBar covered +ADD SET and broke a row-add test (2026-06); the user flagged
bottom placement + no in/out motion → all 18 snack sites migrated to the CRT center notice, and a
global-pointer-route dismiss variant proved flaky in tests where the translucent Listener is exact
(2026-07).*

### Sibling field baseline alignment vs decoration asymmetry
**Rule:** Two fields in one row mis-align when only one carries a prefix/suffix `Icon`: Flutter's
`InputDecorator` sizes the input row to the (taller) icon and baseline-aligns the text inside it, so
the icon-less sibling sits a few px off — matched outer height, `contentPadding`, **and even
`textAlignVertical: center` all fail to fix it** (center moves the whole block, not the text relative
to a no-icon field). Give the bare field a **zero-width height-spacer** of the icon's exact extent
(one shared const, density-pinned via `VisualDensity.standard` so the rendered button height can't
drift from the spacer) so both decorations resolve the same input-row height while the bare field
keeps full text width. Prove it with a **geometric `EditableText`-center test** (font-independent, so
it works in the test env where fonts are boxes), not a golden, and mutation-check it. *Seen: the
weight field's plate-calc `suffixIcon` pushed "55" ~3px above the reps "15" → 0-width 28px spacer on
the reps field (2026-06).*

### Inserting content above a focused field (keyboard occlusion)
**Rule:** Adding a tall block **above** a text field on a screen with `resizeToAvoidBottomInset:
false` (the pattern when a bottom CTA floats above the keyboard via manual `viewInsets` padding)
pushes the field below the keyboard line — it gets typed-into but unseen. Don't flip the whole
screen to `resize: true` (it double-pads a manual-viewInsets button). Instead make the upper content
a `SingleChildScrollView` and, on focus gain, `Scrollable.ensureVisible(fieldContext, alignment:
0.1)` (reduced-motion → `Duration.zero`) so the field lifts above the keyboard while the inserted
context scrolls away; keep a bottom scroll pad ≥ the floating CTA's height so the field never hides
behind it. Existing field/counter/CTA tests keep passing (they render in the scroll); a live
companion ticker added above means **non-reduced page-pumps must avoid `pumpAndSettle`** (test the
panel in isolation under reduced motion). *Seen: the onboarding Name screen gained a BIT "starter
readout" panel above the prompt → field slid under the keyboard until scroll + ensureVisible-on-focus
(2026-06).*

### Reduced-motion needs a non-motion fallback
**Rule:** Freezing an animation under `disableAnimations` must leave a **still, legible signal** — a
label, a static frame, a Semantics announcement — never a dead/ambiguous control. Design the
no-motion state first, then add motion on top. **For a whole motion *feature* (a video reel, a long
cinematic), the reduced-motion default is to SKIP it to the still/interactive state — a user-gated or
reward-framed entry ("YES, see the gift") is NOT consent to long motion; the OS setting outranks the
framing (Codex high, 2026-07 — the charge-ritual "gift" beat funneled RM users into the 17s reel via
a START-BOOSTING press until RM was reverted to the still hold).** **Disable an implicit animator by OMITTING it, not by
zeroing its duration** — an `AnimatedSize` with `Duration.zero` re-dirties itself during layout
(`RenderAnimatedSize was mutated in its own performLayout` assertion → every test that pumps it throws);
branch `_reduce ? child : AnimatedSize(child:)` instead. **A `late final AnimationController = …` that the
reduced-motion `build()` never reads is lazily constructed inside `dispose()` — an unsafe
deactivated-ancestor `TickerMode` lookup that throws. "Eager" means the ASSIGNMENT lives in
`initState` (`late final _c;` declared bare, `_c = AnimationController(…)` in initState) — a
`late final _c = expr` FIELD INITIALIZER is itself lazy, so writing one with an "eager" comment is
the same bug (a sibling like `_LevelFloat` only survives because its build always references the
controller). An entrance/FX WRAPPER inserted around an existing child must also be
**layout-transparent** — a bare `Stack` shrink-wraps + top-left-pins, yanking centered rows to the
edge; use `StackFit.passthrough`.** *Seen: collapsible body-map groups crashed all
meter-row tests under reduced motion until the AnimatedSize was branched out (2026-06); the XP-meter
`_LevelPunch`/`_BarSurge` juice widgets (early-return `build` under reduced motion) crashed every summary
test on dispose until their `late final` controllers moved to `initState` (2026-07); SECOND fire:
ScanWipe/CrtExpand/_SlamIn shipped the initializer form under an "eager" comment and all three crashed
reduced-motion dispose, and their bare Stacks de-centered the XP label + stat row — caught only by the
rendered capture (2026-07).* **The reduced-presentation trigger is the *union*
`disableAnimations || accessibleNavigation` — gate on it consistently across sibling surfaces; a
screen that checks only `disableAnimations` strands a screen-reader/switch-access user in the full
cinematic while its neighbours settle (prefer the shared `bool get _reduceMotion` idiom over an
inline `disableAnimations` check so the gate can't drift).** A **perpetual** full-bleed scene (ambient ticker that
never settles) must freeze for correctness *elsewhere* too: page-level `pumpAndSettle` tests hang if
it never stops, and a hero sized by a raw width-ratio overflows short/odd viewports — **clamp the
ratio** (size it from a `LayoutBuilder`'s available height, **not** `MediaQuery.sizeOf` — which is
`Size.zero` under a test's `MediaQueryData(...)` override, silently collapsing the hero to 0 while the
widget test still passes; 2026-07). **An overlay that masks a sprite's stale baked art must follow that sprite in *every* state** — hiding
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
single-pump files + poll until the loader clears, never a fixed delay (2026-06). **A sub-widget
golden wrapped in a bare `ColoredBox`/`Container` (no `Material`/`Scaffold` ancestor) paints the
"no-Material" yellow debug underline under every `Text`** — it silently corrupts the visual proof
while the test still passes; wrap the golden subject in a `Material` (a full-page golden inherits it
from the page's own `Scaffold`) (2026-06).* **A custom chip that
supplies its own `Semantics(label:)` as the accessible name must set `excludeSemantics: true`** — else
the child `Text` node merges in, doubling the screen-reader announcement *and* breaking
`find.bySemanticsLabel` (exact-match) in tests. **A gesture-only affordance (long-press / swipe) is
both hidden AND inaccessible** — switch-access / keyboard users can't long-press — so pair it with a
**`customSemanticsActions` entry** on the same node (a labelled "Pin to top" action the a11y layer
exposes without the gesture) **and a persistent visible hint** (a "PINNED N/3 · hold a lift to add"
status line), not a hint that vanishes after first use (stranding someone who forgot the gesture).
**A gesture is a two-way contract: if a hold/swipe performs an action on one surface (hold a row to
PIN), the *inverse* surface must accept the SAME gesture for the inverse action (hold the pinned card
to UNPIN)** — once a user learns "hold to pin", their instinct is "hold to unpin"; don't make one
direction a gesture and the other an icon-only tap. Keep the explicit affordance (the pin icon) too —
the gesture is the discovered shortcut, not the only path. *Seen: weekday-picker chip's "MON training day, on"
label found 0 until the inner "MON" `Text` was excluded (2026-06); the onboarding shell/solution/
quiz/cold-open/option-list gated on `disableAnimations` only → a screen reader sat through the intro
cinematics → unified to the `||accessibleNavigation` contract via shared `_reduceMotion` getters (2026-06);
strength-roster pin-via-long-press got a `CustomSemanticsAction('Pin to top')` + a persistent "PINNED N/3"
hint so switch/SR users + forgetful users keep a path, Codex F2; then the user caught that hold-to-pin
implies hold-to-unpin → the pinned card took the same long-press to unpin (2026-06).*

### Reach for the app's own primitive first (and port reference source verbatim)
**Rule:** Before painting anything new, glob `lib/widgets/` + `widgets/motion/` and read the **nearest
existing surface** — the best style reference is the app's own code, not a generic catalog. Compose
from primitives (`PixelButton`, `ArcadeChip`, the motion wrappers, `arcade_route`, `neonGlow()`);
paint bespoke only when nothing fits, and then in the language. **When a handoff/reference ships actual
engine source for an effect, port it *verbatim* — reuse the REAL asset (the actual sprite/painter) for
a derived effect (a hologram = the real BIT post-processed, not a hand-redrawn lookalike) and replay
the real timeline beat-for-beat; a hand-rolled approximation reads as generic/off and the user will
catch it.** Extract shared sprite art behind one entry point (verify the original golden stays
byte-identical first). **Two private widgets with the same role/name in different files silently
drift** — render the *one* concept through *one* shared widget + one mapping fn, never a per-screen
copy (a copy gets restyled on one surface and not the other, and the user catches the mismatch).
**Extending a shared primitive used across many flows** (e.g. `BitSpeechBubble`
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
shared `cancel()`, with an overshoot guard so a stale post-background resume stays silent. Scaling that channel
**app-wide**: be generous with **COVERAGE** but disciplined with **INTENSITY/DURATION** — the broad
layer is the *subtlest* tick (`selection`) via opt-in wrappers (default **silent**; never on passive
scroll / informational chrome / disabled taps), heavier intents reserved for confirm/reward/destructive;
**and NEVER ship the channel partially** — a few wired sites among many silent ones reads as *broken*,
not restrained (the SFX v1 on-device verdict: "half baked, a little here a little there"); design the
channel as a complete ROLE GRAMMAR (select/tick/confirm/warn/skip/toggle/…) fired structurally
(wrapper defaults + drop-in button wrappers + a CI ban on the raw bypass class), with one owner per
gesture + an arbiter window so specific sounds replace, never stack under, generic ones (2026-07);
**"continuous" = a SHORT pulse-train ridden off the `AnimationController`'s own listener** (threshold
cursor, forward-only, **≤3 pulses**) — never a parallel `Timer` (drift) or a multi-second drone (the
reward feel peaks ~400ms per JCR); **rate-coalesce the broad layer** (drop repeats <30ms); reduced-motion
**suppresses *ambient* trains** and fires a single pulse only on an explicit action / visible state
change.** *Seen: keycap/motes/dioramas reused the motion + token vocabulary; the away
hologram was first a hand-painted blob + the send-off a bare fly-up → re-ported from `holo-bit.js`/
`playLaunch` to render BIT's real sprite + the full 5-phase launch; BIT's home-room voice extended
`BitSpeechBubble` additively (`child`/`emphasisColor`, then `downTailDx`/`downApexFrac` for the leaning
tail) — capped to ~85% width + re-stacked above the world window so a 2-line balloon paints over it,
proven against the onboarding/quest goldens (2026-06); `PixelButton` gained an optional `haptic` intent
(default `tap`, `none` on the handler-owned CLAIM button) centralizing haptics across 74 buttons + a Settings
toggle, and the rest-done haptic fired from `RestTimerBar`'s existing dispose-managed ticker, not a new
service timer (2026-06). Then the app-wide pass: opt-in `haptic` on `ArcadeTap`/`HoldDepress`/`PhosphorTap`
(default silent) + `ArcadeChip` default `selection` + `HapticService.fireCoalesced` + a reusable
`HapticPulseTrack` (controller-coupled train) for BIT boot/cheer + the quest gem-flight (≤2 stream ticks)
+ a capped summary stat-reveal — generous coverage, subtle intensity (2026-06). **Per-call-site
opt-in is forgettable** — a whole new surface (the Crest Forge) shipped silent on every pick because
its taps used a raw `GestureDetector`; coverage is now **structurally enforced** by
`tap_haptic_coverage_test` (a raw `GestureDetector(onTap:)`/`InkWell` outside the wrappers fails CI; a
legit raw gesture carries `// haptic-ok: <reason>`), the wrappers' by-role defaults (button→`tap`,
chip→`selection`) keeping restraint — coverage and restraint enforced by two mechanisms, neither
compromised (2026-06).*

### Discoverability & the false bottom
**Rule:** An **optional step or secondary control buried at the bottom of a scrolling list under a pinned
CTA is effectively invisible** — the first screen looks complete (false bottom) and the always-visible CTA
says "you're done here", so users never scroll. Don't fix it by **auto-scrolling on load** (removes user
control, disorienting) or by making the **primary CTA scroll instead of advance** (label↔action mismatch —
an anti-pattern; the only honest CTA-scrolls case is *submit→first validation error*). Instead **hoist the
optional control into the pinned action area** as a compact, always-visible summary-affordance (`LABEL ·
value ▸`) that opens the full editor (a bottom sheet reusing the same primitives), and **surface a
below-fold pre-selection by ordering it into view** (recommended-first), not by animating the page. Prove
it with a phone-size page golden + a "summary visible without scroll / opens editor" widget test. **And
reorganizing a flat list into a CONTEXTUAL/grouped browser** (by anatomy, by room, by category — soulful
over a "page of cards + search") **silently loses what the new grouping can't reach**: items with no
home (un-mappable), items with several homes (a bench under chest *and* triceps), and the plain
"show me *all* of them" workflow. Keep a **quiet flat completeness net** beside the contextual hero (an
"ALL …" route, every item once), and confirm every item is reachable. *Seen: the onboarding weekday step
stranded under 3 tall program cards → pinned `TRAINING DAYS ▸` summary; the strength surface moved from a
flat list to a tap-your-body dossier (Concept #1) but a body-only browser dropped bodyweight/un-mapped
lifts + the "all lifts" intent → kept a secondary "ALL LIFTS" net, each lift filed under its primary
muscle once (Codex, 2026-06).*

### Progressive-disclosure widget defaults at new call sites
**Rule:** A shared widget whose constructor DEFAULTS to its pre-reveal/dormant state (`BitMoodCore`
`reveal: 0` = faceless) silently renders that dormant state at every new call site that forgets the
live-state param — and nothing fails: analyze is clean, layout tests pass, only the pixels are wrong.
When adding any new surface hosting such a widget, (1) copy the param set from an existing
post-onboarding call site, not from the constructor signature, and (2) pin the live-state param in the
surface's widget test (`tester.widget<T>(...).reveal == 1`) so a regression can't slip back. Applies to
any staged-reveal/poweredness prop (`reveal`, `powered`, `unlocked`). *Seen: the rest-day Recovery
Briefing sheet shipped `BitMoodCore(size: 72)` from plan code — faceless BIT on every rest day, caught
only by a reviewer diffing against the 10 existing `reveal: 1` call sites (2026-07-18).*

### Domain jargon vs the plain verdict
**Rule:** A surface driven by a computed metric must show the **plain-language verdict**, never the
engine's internal units. The science (MEV/MAV, e1RM, percentile, kg-volume) *drives the math* but is
**not the label** — a beginner can't act on "MEV 8". Lead with a plain word that says what it means and
what to do (`RESTED / LIGHT / ON TRACK / PLENTY`, body-neutral — no good/bad alarm), let a visual carry
"am I doing enough" (a target band on the bar, not a number), and **progressive-disclose the raw
numbers** behind a tap for the few who want them. Same axis as hierarchy: the verdict is the hero, the
count is secondary, the jargon hides. **Cross-surface coherence:** a browsable index/scan surface must
plot the **same metric** as the detail it links to (compute both from one source) — a divergent teaser
(a top-weight sparkline → an e1RM detail chart) **misranks and visibly contradicts** the page it
promotes. **And a status/warning badge calibrated for a *curated few* turns hostile at scale** — carrying
a `PLATEAU`-style flag from a 3-card hook onto an all-items list reads as repeated failure (the rule is
usually too naive: a flat stretch is often maintenance/deload), so drop or soften it on the dense
surface (body-neutral). *Seen: the muscle-map meter showed `19 · HIGH · MEV 8 · MAV 18` per row — the
user couldn't read it → plain zone words + a tap-to-reveal "ideal range", MEV/MAV hidden; the strength
index plots the **same Epley e1RM** the detail chart does (not the Load-Trends top-weight) and drops the
PLATEAU flag on the all-lifts list (Codex, 2026-06).*
