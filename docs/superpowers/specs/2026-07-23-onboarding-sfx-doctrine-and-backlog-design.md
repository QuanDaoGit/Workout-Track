# Onboarding SFX — doctrine & per-beat workflow backlog

**Date:** 2026-07-23
**Status:** design approved (ceiling + default); backlog pending user review
**Type:** foundational grammar decision (parent) → spawns per-beat `deep-feature` workflows (children)
**Evidence:** `research/insights.md` → "Onboarding SFX ceiling — bespoke EVENT-SFX at the peaks, NO
music bed, budgeted density (2026-07-23)" (WebSearch + Codex adversarial evidence review, 7 findings
folded).

---

## 1. The decision

Onboarding is a ~16-beat first-run cinematic that is **mostly silent** except the tail (charge-ritual
reel + gift-reveal already bespoke; a couple of chip taps click via the structural kit). The fork was:

- **A** — bespoke narrative EVENT-SFX only, no music bed.
- **B** — full scoring: event SFX + an ambient/music bed under the whole intro that ducks for beats.
- **C** — minimal: reuse only existing interaction-kit + ceremony sounds.

**Approved: A-hybrid.** Author bespoke event-SFX at the **narrative peaks**, layered over the existing
interaction kit (which already covers functional taps), **no music bed for v1**. Each peak's sound is
**crafted as its own full `deep-feature` workflow** — "make sense / fit / emotional / retention / hook,"
not a dropped-in blip.

**Approved default:** audio **ON** at first-run, **with an early discoverable mute affordance inside
onboarding** (Settings isn't reachable during first-run).

### Why (the load-bearing evidence)

1. **A music bed (B) fights the app's own `audioFocus=none` doctrine — decisive.** The app never ducks
   the user's music, so a continuous bed would play *simultaneously over their Spotify* (two tracks at
   once). Short event SFX layering over their music is fine (notification-blip model); a persistent bed
   is not. The charge-ritual reel is already the one contained musical moment — a bed is redundant with
   it and would collide. → **Reject B for v1, not forever:** the strongest B (a bounded cinematic-audio
   mode that requests transient ducking for the ~60–90s intro + restores on skip/background) is
   legitimate; revisit only if user-testing shows the uplift is worth the doctrine exception.
2. **"Half your users are on silent" mostly evaporates — but isn't a green light.** Android silent/ringer
   mode does **not** mute media-stream app audio (separate volume stream). Use this to reject "silent =
   inaudible," **not** to infer users *want* audio → sound stays enhancement-not-essential + instantly
   muteable.
3. **The peaks deserve authored sound; reuse-only (C) recycles generic ticks → reads "half-baked"** (a
   documented prior failure mode). But this is design judgment, not "the web proves C fails," and it
   applies **only to the peaks** — taps still reuse the kit.

---

## 2. The doctrine (every child workflow inherits this)

- **Beat budget (the density discipline).** Bespoke sound only at the **~4–6 peaks**. Transition/crossfade
  beats stay **quiet or interaction-kit only**. Not every beat gets sound — density is the trap; the
  budget is the discipline.
- **Taps reuse the kit** — chips → `select`, buttons → `tick`, already structural. No new bespoke sounds
  for functional taps.
- **No music bed** (v1). The reel is the single contained musical moment.
- **Mix boundaries.** Loudness hierarchy `interaction < event < ceremony`. **No tonal tails bleeding into
  the reel or the gift-reveal ceremony**; silence / sparse SFX at the reel's edges. Every new beat SFX is
  auditioned against the adjacent beats, not in isolation.
- **Co-design with the already-specified haptics** (`research/insights.md`, 2026-06-23 haptics onboarding
  map: BIT boot = slow `selection` ticks; BIT cheer peak = ~400–600ms burst). Audio pairs with those, per
  Android's audio+haptic+visual co-design — never a desynced third channel.
- **Default-ON + early mute affordance** (W0). The mute control is discoverable *before* the audio
  escalates (before the reel) and persists to the master **Sound** setting.
- **Enhancement-not-essential + reduced-motion.** Sound never carries essential info. Audio is not a
  vestibular trigger, so it **may still play under reduced motion** (it can carry the beat when the
  visual cinematic is stilled) — each child workflow states its reduced-motion audio behavior.
- **Craft (reuse-validated).** Self-generated CC0 (bfxr/jsfxr/sfxr — output rights clear); reward =
  impact + bright tonal tail; **vary-on-repeat** (audio fatigues faster than visuals); band-limited
  C-major, on the existing loudness ladder; primary semantic cue ≥ ~700 Hz (phone-speaker floor).
- **Performance.** Do **not** preload the whole onboarding SFX set at first launch (AudioPool jank risk on
  low-end Android) → lazy / deferred pooling per screen.
- **On-device audition is a HARD GATE.** Every peak sound is auditioned on device (over a music/podcast
  bed, at phone-speaker + earbud) before it's called done — feel calls don't pass on code alone.

---

## 3. The per-beat workflow backlog

Peaks (W1–W5) each run the **full `deep-feature` pipeline** (audit the beat's animation timeline →
research the *specific* sound's emotional craft/fit → opinion → Codex → plan → implement → on-device
audition). W0 is a small `ironbit-design` UI workflow; W6–W7 are lighter batches. Ordered by
emotional/retention leverage.

| # | Workflow | Beat / file | Type | Rationale |
|---|----------|-------------|------|-----------|
| **W0** | Onboarding **mute affordance** | early sound control (before the reel) | UI · `ironbit-design` | Default-ON is only safe *with* this — lands before/with the first shipped sound |
| **W1** | **BIT face-reveal power-up** | `solution_page.dart` (the emotional peak) | Peak · bespoke | Mascot-bonding moment; highest retention lever; haptic beat already exists to pair with. **Flagship — proves the grammar** |
| **W2** | **Name / character birth** | `name_screen.dart` (name commit) | Peak · bespoke | Identity attachment — the character is *created* here |
| **W3** | **Class reveal** | `class_reveal_screen.dart` | Peak · bespoke | Identity — "who you are" |
| **W4** | **CRT boot power-on** | welcome bloom → cold open (`onboarding_flow_page.dart` `_BootTransitionPainter`) | Peak · bespoke | The first sound the app ever makes; sets the arcade tone / hook |
| **W5** | **Rank assessed** | `rank_assessed_page.dart` | Peak · bespoke | Competence signal |
| **W6** | Loaders | `calibration_loading_page.dart`, `program_loading_page.dart` | Supporting · light contained "computation" cue (budgeted, not a bed) | Loaders are a distinct texture; keep it small |
| **W7** | Quiet transitions + mix audit | crossfades / handoff iris / cold-open entrance + **reel & gift-reveal edges** | Kit-reuse batch | Enforce mix boundaries; keep transitions quiet; no collisions around existing tail audio |

**Already covered (leave, audit only for collisions):** calibration quiz chips (`select`), program
selection (`select`/`tick`), reminders primer (`select`/`tick`), charge-ritual reel (bespoke),
gift-reveal (ceremony).

---

## 4. Open questions / risks (carried into the child workflows)

- `[risk]` **On-device audition** is the single biggest unknown for every peak — feel, loudness vs the
  reel, phone-speaker vs earbud. Gate before "done."
- `[risk]` **Reel-edge collision** — W1/W4 sit near the reel and gift-reveal; W7 owns the boundary audit.
- `[risk]` **Preload perf** on low-end Android at first launch — lazy pooling; measure.
- `[open, product]` **Where the mute affordance lives** (a corner sound glyph? on the first CTA screen?)
  — resolved in W0 via `ironbit-design`.
- `[open]` **Welcome bloom** — folds into W4's power-on, or its own tiny cue? Decided in W4.
- `[deferred]` **B (ducking bed)** stays a future tested option, not a permanent rejection.

---

## 5. Next step

Each child workflow is its own `deep-feature` cycle producing its own spec under
`docs/superpowers/specs/`. Recommended start: **W0 (mute affordance) paired with W1 (BIT face-reveal)** —
the affordance makes default-ON safe, and W1 is the flagship that proves the whole grammar before the
rest of the backlog inherits it.

---

## 6. Implemented — 2026-07-23

Shipped in ONE deep-feature pass (audit → design workflow → synthesis → Codex → wire → verify), not
the staged one-beat-at-a-time rollout §5 anticipated — the user directed "build all of it."

**Finalized picks (from the audition):** every onboarding beat ships its **V1** cue; the class-reveal
seal plays the **Tank voicing for all three classes** (`playOnbClassSeal` hardcodes
`onb_class_seal_tank`); the **flight/land** (session-complete ceremony + gift reveal) = **V5 "arcade
dash" flight + V4 "servo latch" land**, regenerated into `ceremony_flight.wav` / `ceremony_land.wav`.

**Root place for flight/land (reusable):** `ops/gen_flight_land_sfx.py` generates the assets;
`SfxService.playFlight()` / `playLand()` are the canonical reusable API — `playCeremonyFlight/Land`
now delegate to them, so both existing call sites *and* any future "BIT flies to a seat" surface reuse
one primitive.

**SfxService:** onboarding cues are ceremony-grade one-shots via `_playOnb` (the `_play` channel,
volume 0.8 — the WAV peaks carry the loudness ladder). Added an `_isFlutterTest` guard to `_play` so
every ceremony/onboarding cue is test-safe (`debugOnPlay` still fires).

**Wiring (each on the animation edge, guarded fire-once, reduced-motion-correct):** crt_boot
(onboarding_flow boot transition; the welcome GET STARTED keycap tick is silenced so the boot is the
first *sound*), face_reveal (solution inhale edge + settled path), class seal + gate tick, name arm +
committed (replacing the keycap tick, one owner per gesture), calibration boot/confirm×4/resolve,
program boot/confirm×3/seek/ready (**confirm-4 dropped — seek owns the "Matching…" beat**, Codex),
rank stamp (unconditional — its only non-visual signal).

**W0 mute affordance:** a discoverable sound toggle on the welcome screen (`ArcadeIconButton`,
persisted to the master `sound_enabled_v1` key) — default-ON stays safe before Settings is reachable.

**Flow-map corrections (from the audit's own mistakes):**
- `rank_assessed` is a **post-first-(calibration)-workout** beat (pushed from the workout summary on
  the calibration run), NOT part of the pre-workout onboarding cinematic — its preceding neighbor is
  the summary's BIT ceremony, not silence.
- The real tail order is **Reminders → Gift reveal → Charge ritual → Start gate** (gift *before*
  charge), not charge-before-gift as §3's table implied.

**Verification:** `flutter analyze` 0 issues (full app); 66 targeted tests pass (wired screens +
ceremonies + tap-haptic coverage + reduced-motion a11y); Codex adversarial review of the
implementation → 2 should-fixes (confirm-4 drop **applied**; seek→ready margin already covered by the
seek asset's built-in 0.45s tail silence). **On-device gate:** perceived loudness / timing feel and the
welcome mute glyph need an ears-and-eyes pass on a real device (audio is not screenshot-verifiable).
