# Charge Ritual climax cinematics — power-cycle transition + breathing lure + boost SFX

Date: 2026-07-15 · Status: **design (approved via selection)** · Pipeline: `superpowers:brainstorming`
(SFX) + `/deep-feature` for the transition, `ironbit-design` for motion, `codex` adversarial review.
Extends the shipped Charge Ritual (`lib/pages/onboarding/charge_ritual_screen.dart`).

## Context
The hold-to-charge → ignition → Start Gate climax felt underwhelming: a small 560ms button-burst
(`_ignition`) into the generic `ArcadeRouteMotion.reveal` route, a ~1s fill, a static keycap, and no
sound during the hold. This adds the cinematic layer the moment deserves. Two timing tweaks already
shipped this session; three new pieces below.

## Already shipped (this session, verified)
- **Thank-you read dwell:** the post-reel `thank you for the message, coach.` holds ~3s after typing
  (`_kHoldThankYouMs = 3800`) with **tap-the-BIT-area to skip** (`_thankYouSkipped`).
- **3s boost:** `ChargeRitualEngine(fillMs: 3000, autoFillMs: 3000)` (was ~1–1.4s).

## 1. Transition A — CRT power-cycle (asymmetric)
Replace the button-ignition + `reveal` route with a bespoke full-screen power-cycle:
- **Beat 1 · overload** — amber→white bloom flash at ignition.
- **Beat 2 · collapse (LONGER)** — the boost screen "powers off" like a CRT: content dims while a
  bright horizontal line collapses vertically, then contracts to a center dot and winks to near-black.
  This is the dwelt beat (~650–750ms).
- **Beat 3 · power-on (SHORTER)** — the Start Gate fires up from the dot: a horizontal line expands
  then blooms vertically to full, scanlines settle (~350–400ms).
- **Asymmetry is deliberate** (collapse > power-on) — a cinematic override of the app's usual
  "exits run faster than enters" rule, per the user. Exact durations tuned on-device.
- **Implementation:** the collapse is a full-screen CRT power-off overlay (`_PowerCyclePainter`) driven
  by the extended `_ignition` controller over the charge screen (a stylized collapse, not a live-frame
  capture — dim scrim + a shrinking bright bar → dot → flash). On its completion, `_goToGate(...)` with
  a **new `ArcadeRouteMotion.powerOn`** in `arcade_route.dart` that reveals the Start Gate via a CRT
  power-on bloom (reuse the `power_on` / `_MonitorPowerOnPainter` vocabulary), forward duration =
  the short power-on beat. Reduced motion → the existing fade (no collapse).

## 2. Breathing-halo lure (hold-to-charge keycap)
Port the `_StartBoostButton` breathing neon-glow onto `_HoldKeycap` while it's **enabled** (armed at the
hold gate) to invite the press: pulse the `neonGlow()` blur/opacity (~1.5s ease-in-out), **breathe the
halo, not the geometry** (doctrine forbids a scale-pulse as the "notice-me"). Static under reduced
motion (a steady glow). Stops the instant the pour begins.

## 3. Boost SFX (V2 riser + E2 ignition + release)
Three procedural cues — `ops/gen_boost_sfx.py` (pure-Python, deterministic, 44.1k WAV, same pipeline as
`gen_ceremony_sfx.py`) → `assets/audio/boost_*.wav`:
- **`boost_charge.wav`** — V2 **detuned-saw riser** (~3s), two detuned saws + sub square + rising energy
  sweep, amplitude swelling into ignition.
- **`boost_ignite.wav`** — E2 **boom + release whoosh** (~0.95s): sub-bass ignition boom + a descending
  filtered-noise whoosh, voiced to the longer collapse.
- **`boost_release.wav`** — a short descending power-down blip (~0.35s) if released before 100%.

Single-player `SfxService` (a new cue interrupts the last, so the riser *resolves into* the ignite,
mirroring the `boostSwell`→`boostClimax` haptics). New methods `playBoostCharge/Ignite/Release`
(volume ~0.65). Wiring at the edges already in `_onTick`/`_onIgnited`:
- pour-start (`phase→pouring`, covers hold **and** the accessible auto-fill tap) → `playBoostCharge()`.
- ignition (`_onIgnited`) → `playBoostIgnite()`.
- release (`pouring→hold`, distinct from `pouring→ignited`) → `playBoostRelease()`.
`enabled=false` / reduced-SFX → all no-ops (haptics carry it).

## Verification
- `flutter analyze` (0 issues); extend `charge_ritual_screen_test` — SFX cues fire on the right phase
  edges (inject a spy/fake so no real audio in tests), the transition's reduced-motion fallback, the
  lure's reduced-motion static state.
- Rendered artifacts: golden frames of the collapse (line/dot), the power-on beat, and the lure glow.
- **Codex** adversarial review of the plan + diff (anti-mistake).
- **On-device sign-off (required, can't verify here):** transition motion fidelity + the asymmetric
  feel, SFX↔fill↔ignition sync, the haptic swell across the longer 3s hold, volume against the reel mix.

## Files
- `lib/pages/onboarding/charge_ritual_screen.dart` — collapse painter + `_ignition` reshape, SFX wiring,
  keycap lure.
- `lib/widgets/arcade_route.dart` — new `ArcadeRouteMotion.powerOn`.
- `lib/services/sfx_service.dart` — 3 boost play methods.
- `ops/gen_boost_sfx.py` (new) + `assets/audio/boost_{charge,ignite,release}.wav`.
- `test/charge_ritual_screen_test.dart` + the golden harness.

## As-built (2026-07-15)
Implemented via `/deep-feature`, safest-first (SFX → lure → transition), each verified.
- **Codex plan review** (ran, `needs-attention` → 4 findings, all adopted): dedicated `_collapse`
  controller (not `_ignition`, which is retired with the button-burst `_IgnitionPainter`); a dedicated
  `_boost` channel in `SfxService` so the ignite survives the route; **dark-to-dark seam** at the
  collapse→`powerOn` handoff; a nullable `SfxService.debugOnPlay` test hook (not a persistent static
  list). **Codex diff-review is non-functional on this machine** (sandbox can't read the working tree;
  two attempts punted on the empty branch diff — matches `.claude/codex-local.md`); did a documented
  **manual adversarial self-review** against the challenge list instead (no blocking issues).
- **Collapse refinement** (caught in golden review): the bright band **concentrates** — a dim wash
  while wide → bright as it collapses to a line — instead of a full-screen bright flash early on.
- **Verified:** `flutter analyze` 0 issues (full project); 42 tests green (charge screen + engine +
  onboarding flow/nav + haptic-coverage), incl. new `boost SFX fire on … edges` and `tap-to-skip`
  tests; golden frames rendered + eyeballed (`transition_collapse_line/dot`, `transition_poweron`
  [confirms the dark seam], the dialogue frames now showing the keycap lure glow).
- **Residual on-device sign-off:** the `powerOn` route's Start-Gate bloom + its own entrance (a golden
  can't drive it past the dark seam), the asymmetric *feel* (collapse ~700 vs power-on ~380), SFX↔fill
  sync + volume against the reel mix, and the haptic swell across the longer 3s hold. A 1-frame empty
  ActionZone at the ignite instant is cosmetic (overlay paints the next frame).

## Decisions / rationale
- **SFX = hybrid V2 + E2** (user-auditioned): detuned-saw riser bridges the cinematic reel and the 8-bit
  app; a boom+whoosh ignition avoids a "beep" and carries the power-cycle.
- **Procedural Python** over an external generator: consistent with the codebase, deterministic,
  offline, no new dependency.
- **Layered cues, not one baked file:** the fill is variable (release/re-grab), and the single-player
  model makes riser→ignite a clean resolve while `release` handles letting go.
