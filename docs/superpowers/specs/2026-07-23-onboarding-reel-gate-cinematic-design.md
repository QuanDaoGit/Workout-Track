# Onboarding reel → Start Gate — cinematic pass (design)

**Date:** 2026-07-23 · **Status:** design (approved via brainstorming; Codex adversarial review run —
needs-attention, 1 high + 4 medium, all folded) · **Pipeline:** `audit` → `brainstorming` (visual
mocks) → `codex` → this spec. **Surfaces:** `charge_ritual_screen.dart`, `charge_ritual_engine.dart`
(guards only), `start_gate_screen.dart`. Refines the shipped Charge Ritual + Start Gate.

## Problem

On-device novice verdict on the shipped reel → gate sequence: the clip is "not cinematic enough",
"too fast", "BIT's dialogue clashes with the clip — I read two things at once", the clip→gate
transition is "too fast", and the Start Gate is "a drop of motivation". A grounded audit (code timing
map; 1fps frame extraction of `charge_ritual_reel.mp4`; a fresh `test/audit/_shots/start_gate.png`
render) traced the four complaints to **three** root causes:

- **R1 — the reel is a triple verbal stream.** The 19.9s asset carries burned-in kinetic captions (a
  new 3–6-word fragment every ~1.7s) plus spoken coach audio. On the SAME screen BIT typewriters two
  lines *during playback* — the second at video-pos 4s, exactly when the captions begin the message
  payload — plus a skip link that onsets at 3s and a filling charge bar. Caption reading is
  near-involuntary and a typewriter onset captures the eye, so both text streams fight for the one
  foveal channel (split-attention / redundancy). "The clip is too fast" is substantially *stolen
  attention*: ~120–180 wpm caption pacing is normal under undivided attention.
- **R2 — the screen is a lit console during what should be cinema.** At 390pt width a full-width 4:3
  monitor is already ~34% of screen height (size is near-maxed), but it sits inside full-brightness
  chrome (CHARGING header, charge bar, BIT + bubble, keycap, skip). Cinema is darkness + one lit
  subject; the missing piece is "lights down", not a bigger picture.
- **R3 — the poured charge never arrives, and the payoff screen is administrative.** The ignition peak
  (100% pour, boom, 700ms collapse, 380ms power-on) hands off to a gray admin card: buried 80px avatar
  thumbnail, "untitled", RECRUIT, an empty XP bar, "0/50 XP", a neutral-pose BIT, and ~55% dead dark
  space. Peak-end: this admin beat becomes the remembered *end* of the entire onboarding. The
  transition's milliseconds are not the fault (≈1.1s of CRT power-cycle) — the emotional cut is what's
  instant: the energy the user poured never lands anywhere.

## Research grounding (`research/insights.md`)

- Peak-end rule (meta-analytic r≈0.58; duration-neglect): make the *end* the peak; one clear peak beats
  a busy montage (2026-06-16 solution-screen entry; 2026-07-23 reel→gate entry).
- The face reveal is the single emotional peak; a revealed face/held gaze drives bonding; the Start
  Gate "stays the user-hero's bigger embodiment" (acceptance criterion) — yet today it buries the face
  (2026-06-16).
- Heavy/slow easing reads as gravitas; avoid bouncy `easeOutBack` for the power-up (2026-06-16).
- Subtitle reading is near-mandatory + motion onsets capture saccades → captions and a typing bubble
  can't share the foveal channel (2026-07-23).
- Extra black time after the collapse reads as *frozen/lost-tap* on Android, not breath — carry visible
  continuity across the cut instead (2026-07-23, per Codex F3).

## Change A — the reel becomes a theater (BIT silent during playback)

BIT speaks only when the reel is **not** playing.

- **Relocate the intro lines to the self-paced held-frame wait.** The two pre-reel lines ("say hi to
  our coach, jack mercer." → "let's listen to his message together.") play on the START BOOSTING held
  frame — the user reads them at their own pace before the clip, nothing competing. During `reel` phase
  the bubble is **hidden** and BIT sits still, watching.
- **START cancels BIT text atomically.** Pressing START BOOSTING must clear/complete any in-progress
  typewriter in the same frame it begins playback, so a mid-character bubble can never bleed into the
  reel (Codex F4). Fast-tap, double-tap, and tap-mid-character are covered by tests.
- **Post-reel flow unchanged.** The thank-you → boost dialogue (thank-you dwell, tap-to-skip, hyped
  boost line) is already post-playback and stays as-is.

## Change B — lights down on the reel, back up on the hold

The decorative chrome dims so the monitor is the only lit object, then the user's effort restores it.

- **Gradual down on reel start:** as playback begins, a `_chromeLight` factor eases the *decorative*
  widgets (CHARGING header, BIT + bubble region, ambient glow, the charge-bar's glow shell) from full
  to ~30% over ~500ms.
- **Gradual up on the hold:** while `pouring`, `_chromeLight` eases back toward full — mapped to charge
  (0.90→1.00) so pouring visibly brings the lights back; at ignition the room is fully lit under the
  collapse.
- **Between reel-end and the hold** (exit recede + ~4s thank-you dwell) `_chromeLight` **stays at the
  dim floor** — the cinema mood holds until the user's hold earns the lights back (on-device tunable;
  the alternative "warm up at reel-end" is the fallback if the dim beat reads dead).
- **Escape controls are exempt (Codex F1, high).** `skip`, the pause hit-region + pause glyph, `mute`,
  the HOLD keycap, and the "HOLD TO CHARGE UP" prompt keep full contrast, stable placement, and normal
  perceived availability throughout. Only decoration rides `_chromeLight`. Skip is pre-armed with the
  held frame (not a raw 3s timer that pops in mid-reel).
- **Charge bar** stays visible but its glow shell dims with the decoration (the "watching charges you"
  read survives); the bar fill/track stays legible.

`_chromeLight` is a derived value (phase + charge), not a new controller where avoidable; reduced
motion pins it to 1.0 (no dimming — the reduced path has no reel).

## Change C — Start Gate becomes a hero reveal (Option 1 composition)

Restructure the gate around the character as the focal hero, filling the dead space for good.

- **Large centered avatar** as the focal point owning the vertical center (echoes the shipped Profile
  hero card: a large centred framed pixel face). This is the "user-hero's bigger embodiment" the
  research set as this screen's acceptance criterion.
- **Identity strip beneath the portrait:** name · RECRUIT · LV.1 · the XP bar · "0/50 XP · 1 QUEST
  ACTIVE" · the First Forge quest line — the same information as today's card, compressed under the
  hero rather than around a thumbnail.
- **BIT** is the guide line below the strip; the two CTAs (START WORKOUT / EXPLORE FIRST) stay anchored
  at the bottom.
- The staged reveal (`_scheduleSequence`) is **re-ordered payoff-first**: the avatar + name land first
  (the peak), then the identity details stagger in, then the CTAs. Tap-to-fast-forward, reduced-motion
  skip-to-end, and the strobe-free "system online" beats are preserved.
- No information is added or removed; this is a re-composition, not a new data surface (keeps the
  "smallest legible panel; Start Gate is the sole full reveal" doctrine).

## Change D — the charge arrives on the hero

Riding the **existing** `powerOn` route + the staged reveal (no new route timing, no added black time):

- As the gate powers on, a brief neon charge-trail rises **into** the hero portrait; the avatar frame
  and name **ignite** in neon, then cool to their resting colors (name → white). Heavy easing (gravitas,
  not bounce).
- The XP bar gets **one** left-to-right shimmer sweep as it reveals — the charge conducting *through* —
  but the bar **stays 0/50 and does not fill**. No fake/unearned reward (doctrine); the shimmer is
  energy passing, not XP granted.
- BIT arrives **hyped** (cheer pose), continuing the ritual's thread — e.g. "fully charged, <name>." —
  before settling into the existing "What should we do first, <name>?" prompt. (Today BIT arrives cold
  neutral.)
- **Arrival intensity = medium** (frame surge + name ignite + one XP shimmer; not a hard full-card
  flash) — on-device tunable.
- **Visible continuity, not dead air (Codex F3):** the charge carries across the collapse→powerOn seam
  as light landing on the hero. **No** extra black hold is added after the collapse.

## Codex adversarial-review resolutions (needs-attention → all folded)

- **F1 (high) — dimming could bury the escape controls during the longest forced segment.** Resolved:
  Change B dims *decoration only*; skip/pause/mute/keycap/prompt keep contrast, placement, and
  perceived availability. Add contrast/golden checks for reel, paused, skipped, and dimmed states.
- **F2 (medium) — pre-arming skip creates an underspecified phase edge.** Resolved: skip stays the
  single phase-independent **whole-ritual** escape (its existing `_goToGate(flow)` semantics); its
  *appearance* is keyed to the held-frame beat so it never pops in mid-reel, but a tap before `play()`
  still routes to the gate via the existing path — never a jump into post-reel copy with an
  uninitialized controller. Tests: skip before start, at reel start, during exit, after reel.
- **F3 (medium) — extra black hold reads as lag.** Resolved: Change D adds no black time; continuity is
  the visible charge landing on the hero (D above). Any residual hold would be reduced-motion-gated +
  watchdogged — but the design adds none.
- **F4 (medium) — moving BIT's lines could reproduce the clash.** Resolved: lines live only on the
  self-paced held frame; START **atomically cancels** any in-progress typewriter before playback; the
  reel-phase bubble is hidden. Tests: fast tap, double tap, tap mid-character.
- **F5 (medium) — the proposal prematurely rules out the asset.** Resolved: treated as a hypothesis.
  The asset (caption dwell / density / small-monitor legibility) is **not** touched in this build; a
  longer-dwell / fewer-fragment re-cut is the **named measured fallback** if the clip still reads fast
  on-device after the theater pass.

## Phase invariants (the regression surface — must all hold)

Route fires **once** (`_routed`/`_goToGate` guard); engine watchdogs (preroll cap, video-fail
`finishReel`, `_maxDtMs` clamp) and the reel/hold/pouring/ignited state machine are **untouched**;
pause/resume still freezes video + charge clock + skip timer together; skip always reaches the gate
from any phase; the typewriter cancel is atomic with playback start; reduced-motion paths are
byte-identical to today.

## Reduced motion / accessibility (union gate `disableAnimations || accessibleNavigation`)

Byte-identical to today: no reel (poster → hold), `_chromeLight` pinned to 1.0 (no dimming), no charge
surge, the Start Gate opens on its sustained state instantly (`_skipToEnd`). The hero re-composition
(Change C) is a **static layout** change, so it applies under reduced motion too (still legible, no
motion); only its *reveal timing* is motion-gated. No strobe (WCAG 2.3.1); typewriter stays gated on
the union flag at 22ms/char.

## Not doing

- No change to the reel asset in this build (Change D-of-the-audit; F5 fallback only).
- No new route timing, no extra black hold, no change to the asymmetric collapse>power-on grammar.
- No fake XP / unearned rewards; the XP bar stays 0/50.
- No new sounds/haptics — existing boost/ignite/power-cycle cues carry the beats. (Onboarding-SFX
  authoring is a **separate** parallel workstream; do not fold it in here.)
- No full-body avatar sprite (Option 2 was rejected for this reason); the hero is the existing framed
  pixel face at a larger size.

## Testing

- **Reel dialogue:** during `reel` the BIT bubble is absent; the two intro lines render on the held
  frame; pressing START clears an in-progress typewriter (fast/double/mid-char tap) with no bleed.
- **Lights:** `_chromeLight` reaches the dim floor during `reel` and returns toward full during
  `pouring`; skip/pause/mute/keycap/prompt remain at full opacity in every reel/paused/dim state
  (golden + widget assertion).
- **Skip phase edges:** skip before `play()`, at reel start, during exit, after reel — each routes to
  the gate once, no post-reel-copy jump, no controller-after-dispose throw.
- **Start Gate composition:** hero avatar is the central focal element; identity strip renders all of
  name/RECRUIT/LV.1/0-50 XP/quest; payoff-first reveal order; tap-fast-forward + reduced-motion
  skip-to-end land the sustained state.
- **Charge arrives:** on the powerOn reveal the frame/name ignite then settle; XP bar shimmers once and
  stays 0/50 (assert value unchanged); BIT arrives cheer then settles to the prompt; reduced motion
  shows the static charged-but-still gate.
- **Regressions:** existing `charge_ritual_engine_test`, `charge_ritual_screen_test`, onboarding
  flow/nav, tap-haptic-coverage stay green. Golden frames: reel-dim, reel-paused, gate-arrival-mid,
  gate-settled. `flutter analyze` 0.

## On-device sign-off (can't verify here — named, not silently passed)

The dim depth + ramp feel; the between-reel-and-hold dark beat (Change B tunable) vs the warm-up
fallback; arrival intensity (Change D medium tunable); the hero portrait size/balance at real device
sizes; and — the F5 gate — whether the clip still reads too fast once BIT is silent and the lights are
down (→ asset re-cut only if so).

## Files

- `lib/pages/onboarding/charge_ritual_screen.dart` — BIT-silent reel (bubble gating + intro relocation
  + typewriter cancel on START); `_chromeLight` dim/undim on decorative widgets with control exemption.
- `lib/pages/onboarding/charge_ritual_engine.dart` — **guards/asserts only** if needed; no phase-machine
  behavior change.
- `lib/pages/onboarding/start_gate_screen.dart` — hero-portrait re-composition + payoff-first reveal
  order + charge-arrival surge (frame/name ignite, one XP shimmer, hyped BIT arrival).
- Test + golden harness updates per the Testing section.

## Acceptance criteria

During playback the user reads one thing (captions), not two — BIT is silent and the room dims to a
single lit monitor; holding the boost brings the lights back. The Start Gate opens on a large hero
character (no dead space), the poured charge visibly lands on that hero, the XP bar never fabricates
progress, and BIT arrives hyped. Nothing soft-locks, skip always escapes, no strobe, reduced motion
lands on a still legible gate, and the reel asset is untouched pending the on-device fast-read check.
