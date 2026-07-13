# Charge Ritual finale — gift-reveal beat, boost gate, 0.85× reel, hold haptic

Date: 2026-07-12 · Status: **as-built** (shipped) · Pipeline: `/deep-feature` (+ `/deep-research`,
`/brainstorming`; `ironbit-design` for the fly, `research` + Codex for the evidence/adversarial pass).
Builds on `2026-07-12-charge-ritual-onboarding-design.md` and `…-reel-cinematics.md` (do not rewrite
those — this is the third iteration on the same finale).

## Intent
Five user-requested changes to the onboarding finale, so the reel lands harder and reads clearer:
1. **Gift-reveal beat** before the reel — BIT (huge, neutral) offers a gift; **YES** flies him into
   the Charge Ritual, **skip** flies him to the Start Gate.
2. **BIT fly-in/out** — the Session-Complete ceremony's banked-arc flight (pull-back → accelerate →
   4% overshoot → settle, thrust trail), reusing the ceremony's exact flight beat: **`playCeremonyFlight`
   dash-fwoosh SFX + `flightSwell` haptic** at launch, **`stopBuzz` + `landThump` + `playCeremonyLand`**
   at the landing. BIT stays **neutral** throughout (no cheer burst).
3. **Reel no longer autoplays** — after the power-on reveals a held poster frame it STOPS; a slowly
   **flickering "START BOOSTING"** button appears; only on press does the reel play (existing slow
   fade-in) and the charge begin.
4. **Reel slowed to 0.85×** (words were too fast to catch).
5. **Strong continuous hold-boost haptic** while the user press-holds to pour.

## Placement / routing (as-built)
`name → RemindersPrimerPage → [novice/beginner] GiftRevealScreen → [YES] ChargeRitualScreen /
[skip] StartGateScreen`  ·  `[intermediate/advanced] → StartGateScreen` (no gift, no reel).
- **Experience gate (`RemindersPrimerPage._continue()`):** the reel — offered via the gift beat —
  is for the two LOWEST tiers only (`Experience.novice`/`beginner`). Seasoned lifters
  (`intermediate`/`advanced`) don't need the hype video → they `pushReplacement → StartGateScreen`
  directly, skipping the gift + reel. The primer is the single unconditional funnel from `name`, so
  this one point gates every path into the reel. (User call, 2026-07-13.)
- `GiftRevealScreen` flies BIT, fades through black (see below), then `pushReplacement → Ritual`
  (YES) or `→ StartGate` (skip). Character/avatar thread straight through. `PopScope(canPop:false)`.

## Key files
- **`lib/pages/onboarding/gift_reveal_screen.dart`** (new) — BIT huge/neutral + `_Offer` (amber
  "A GIFT BEFORE YOU BEGIN", `BitSpeechBubble` "I saved you something, {name}…", green `PixelButton`
  YES, muted `ArcadeTap` skip). Within-screen banked-arc `_flight` (1300ms) reusing the ceremony's
  `_flightProg`/easing; soft **radial** thrust glow + amber trail painted behind BIT; a `_blackout`
  (240ms) fade-to-`kBg` at the landing → then navigate.
- **`charge_ritual_screen.dart`** — `_StartBoostButton` (breathing pulse) shown when `boostReady`
  (poster reached + video initialized + not yet started, full-motion only); `_startBoost()` plays the
  video + `beginReel()` + Beat-C fade-in. Preroll watchdog disabled (`prerollMs:600000`) since the
  wait is user-gated; the delayed **skip** (`_elapsedMs>=3000`, no longer phase-gated) is the escape.
  Hold-boost buzz fired **once** on pour-start; `boostClimax` on ignite.
- **`charge_ritual_engine.dart`** — unchanged from the cinematics iteration (`preroll → reel → hold →
  pouring → ignited`, `beginReel`/`pause`/`resume`/`finishReel`).
- **`haptic_service.dart`** — `boostSwell()` (one pre-baked gap-free rising waveform, 10×140ms,
  40→230) replaces the per-frame `boostBuzz(progress)`; `boostClimax()` unchanged.
- **Asset** — `assets/onboarding/charge_ritual_reel.mp4` re-encoded at 0.85× (ffmpeg
  `setpts=PTS/0.85` + `atempo=0.85`, pitch-preserved; 960×720, ~17.7s, crf 18) + poster regenerated.

## Codex adversarial review (design/integration) → resolutions
| # | Finding | Resolution |
|---|---------|-----------|
| F1 (high) | RM users funneled into a 17.7s motion reel after a gift prompt (weak WCAG initiation) | Reduced motion goes straight to the **still hold** — the reel is skipped (it's motion the OS asked to avoid); the charge/boost interaction is the RM "gift". Reverted an over-corrected earlier RM-plays-reel attempt. |
| F2 (high) | Too many sequential gates (gift YES → START BOOSTING → HOLD) | **Kept** — the gift beat + the paused-video/START-BOOSTING gate are the user's explicit, deliberate ceremonial design. Friction tradeoff accepted, not collapsed. |
| F3 (med) | Within-screen fly + short crossfade could reveal a ~14%-height BIT position pop (untestable) | **Fade through black** (`_blackout` → `kBg`) at the landing before the route swap; both destinations start dark, so there's no A/B position comparison. |
| F4 (med) | Per-frame `boostBuzz` re-issue may stutter (Android cancel-restarts vibration) | **Pre-baked** `boostSwell()` — one shaped rising waveform fired on pour-start, cancelled on release; no per-frame churn. |

## Research (why these choices)
- **0.85× via ffmpeg atempo, not Remotion** — the reel is a locked, caption-burned clip; atempo
  retimes it pitch-preserved without a full re-render or a lowered voice.
- **Rising haptic envelope, not a flat drone** — a changing amplitude reads as "power building" and
  dodges motor-numbing; the pre-baked waveform (F4) delivers it in one call.
- **Within-screen fly + fade-through-black, not a cross-screen Overlay/Hero** — robustness in an env
  where the flight can't be visually tested beats a pixel-exact but unverifiable cross-route overlay;
  the black seam removes the only thing the approximate seat-matching could get wrong.

## Verification
- `flutter analyze` — 0 issues (full project).
- `gift_reveal_screen_test` (4: offer renders; RM YES→Ritual; RM skip→Gate+name; full-motion
  YES→fly→blackout→Ritual), `charge_ritual_screen_test` (3), `charge_ritual_engine_test` (13),
  `name_screen_test` (7), `haptic_service_test`, `tap_haptic_coverage_test` — all green.
- Rendered artifact: `test/audit/gift_reveal_frames_test.dart` → `_shots/gift_offer|flight|
  flight_late.png` (run under `--update-goldens`). Offer + fly composition eyeballed on the 390×844
  render (BIT huge/neutral, amber headline, green YES, soft radial thrust glow, lands at the seat).

## Residual on-device sign-off gaps (this env has no working device / no desktop `video_player`)
- The **START BOOSTING → fade-in → play** beat and the **0.85× reel** (caption legibility, audio
  atempo quality) render only with a real video backend — untested here.
- The **fly-through-black → destination** seam and BIT's landing-vs-destination position match need a
  device eyeball (the fade is designed to mask it, but the exact seat fractions — ritual ~0.60h, gate
  ~0.46h — are tune-on-device).
- The **hold-boost `boostSwell` feel** (amplitude curve, motor behavior) needs a physical Android.
- Both destinations' dark-start assumption (for the black seam) holds in code; confirm visually.
