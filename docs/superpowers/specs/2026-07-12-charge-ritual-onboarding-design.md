# Charge Ritual — onboarding screen (design + implementation plan)

Date: 2026-07-12 · Status: plan, awaiting approval (do not implement yet)
Pipeline: `/deep-feature` (routed `port-handoff` + `ironbit-design` + `research`). Handoff source:
`assets/design_handoff_charge_ritual/` (runnable `Charge Ritual.html` + `README.md`).

## 1. Intent & soul hook
A once-only, first-run "climax" screen before the character reveal: a ~15s 4:3 motivational reel
plays and auto-charges a console meter to 90%; the user then **press-and-holds** to pour the final
10% themselves — BIT visibly channels the energy — and the 100% ignition fires a cinematic
transition into the Start Gate. Hook = **ritual return** + **identity** (the charge is *earned, not
elapsed*; you physically light your own first session). Shown once; inherently first-run (onboarding
runs once).

## 2. Placement & routing (single edit)
Tail today: `program selection → name → RemindersPrimerPage → StartGateScreen`.
New: insert between the primer and the gate.
- `RemindersPrimerPage._continue()` currently `pushReplacement → StartGateScreen(character,
  avatarSpec)`. Change it to `→ ChargeRitualScreen(character, avatarSpec)`.
- `ChargeRitualScreen`, on ignition **or** skip, `pushReplacement → StartGateScreen(character,
  avatarSpec)` via the cinematic transition (§8). Character/avatar thread straight through.
- Persist `charge_ritual_done_v1` (bool) on ignite/skip — cheap insurance beyond the onboarding gate;
  no `MigrationService` change (new key).

## 3. Screen composition (the decorated call — "phosphor grade")
Dark radial field (`kBgGradientTop → kBg → kBgGradientBottom`, as `solution_page`). Top→bottom:

1. **Charge header** — `CHARGING` (amber, blinking LED + 3 arcade "typing" dots) → `CHARGED` (neon,
   dots gone). The **sole** status source (the handoff's redundant PLAY/READY plate-LED is removed).
2. **The reel monitor** — the 4:3 video **full-bleed** into the 16px gutters, **no bezel/rivets/
   plate**. Framed *with light, not metal*:
   - inner **vignette** (corner/edge darkening) so it seats in the screen;
   - a soft **phosphor edge-bloom** — a low-alpha `neonGlow`-style bleed at the video's edge. **Tint =
     `kCyan` (BIT's chamber color), not `kNeon`** — resolves the "neon = action only" self-contradiction
     Codex F7 raised; the edge reads as *screen light*, the neon stays reserved for the meter/keycap;
   - faint **static** scanlines screen-wide — reuse `solution_page`'s `_CrtScreenPainter` (extract to a
     shared `widgets/motion/crt_overlay.dart`, verify its golden stays byte-identical).
3. **Charge bar** — the canonical `ArcadeBar(value:, height:16, accent:)` (continuous fill). Accent
   **amber → neon** at the pour. Now the *only* console/bevel element → nothing competes. Ready pulse
   (amber, 800ms) at 90%; pour pulse (neon, 520ms) while charging.
4. **BIT + speech** — painted `BitMoodCore` (pose **neutral → cheer**; no `alert` pose exists). Pour
   energy = an amped neon glow + the **pour stream** (square packets rising BIT→bar), NOT a pose. Four
   `BitSpeechBubble` lines (typewriter, `[bracket]` emphasis, tail down), verbatim from the handoff.
5. **Action zone** — the **hold keycap** (primary) + a **quiet always-visible secondary** "or tap —
   BIT pours it" (§6). At 100% both are replaced by the ignition + the (transitioning-away) gate.
6. **Skip** — delayed-reveal (§6), truthful copy.

Contrast ladder (external ⋂ internal doctrine): **video (brightest hero) → meter/keycap (neon action)
→ BIT + speech (muted) → bg**.

## 4. Charge engine (ported layer-1 + the soft-lock fix)
State machine (verbatim): `reel → hold → pouring ⇄ hold → ignited`; frame `dt` clamped ≤64ms; drain
never below 0.90.

**Codex F2 fix — decouple from the video (authoritative independent clock):**
- The 0→0.90 fill is driven by an **independent bounded ritual clock**, duration = the video's
  reported duration when known, else a **15s default**. The video *position* is **best-effort visual
  sync** only (keeps the bar tracking the picture), never the source of truth.
- A **watchdog**: if the video errors, stalls, or never fires `ended`, the clock still completes and
  the screen advances to `hold`. Video-error → poster + proceed. Backgrounding pauses both; resume
  cannot regress or wait indefinitely. **No playback state can soft-lock onboarding.**
- Healthy path still lands 90% at video end; the darken beat (§5) fires on `min(clock-end,
  video-end)` with the clock authoritative.

## 5. The darken → HOLD beat
At reel end: video **darkens to a ghost** (scrim ~0.7 over ~400ms easeOut — never full black, keep the
last frame faintly visible so it reads *authored*, not *broken*), then `HOLD TO CHARGE UP` fades up
~120ms later, paired with a **haptic tick** (`HapticService.selection`). Reduced-motion → cross-fade
straight to the dimmed+prompt state (omit the animator, don't zero it).

## 6. Interaction
- **Hold (primary):** `HoldDepress`-style keycap; pointer-down pours 0.90→1.00 over **~1.4s** (FILL
  trimmed from the handoff's 1700ms, evidence-backed comfort — recorded deviation); release before
  100% drains toward 0.90 over 2.6s. Live fill + pour stream + haptic while held. Label `HOLD TO
  CHARGE UP` (ready) / disabled `BIT IS CHARGING YOU…` (reel).
- **Quiet always-visible tap (Codex F1 / a11y requirement):** a small, never-hidden secondary
  affordance under the keycap — "or tap — BIT pours it." A single tap auto-fills ~1s → ignite. Hold
  stays the ceremony; the tap is the WCAG-2.5.1/Game-Accessibility escape hatch for *everyone*
  (tremor/pain/switch/SR), not gated to OS settings.
- **Skip (delayed-reveal):** hidden ~3s, then soft fade-in (never past 5s); reachable, small,
  low-contrast; **truthful copy** — `skip — continue without charging` (anti-guilt, no false "later"
  promise, no loss framing). Skip → same cinematic route to the gate.

## 7. Audio (Codex F5)
Audio **ON** (`setVolume(1.0)` = no attenuation; **device media volume governs** — not force-loud).
The reel's **captions are burned in** → visual equivalence. BIT's opening line **telegraphs** sound is
coming. A small **mute toggle** on the monitor. Reduced-motion does not autoplay (§9).

## 8. Ignition + cinematic transition
At 100%: a **single soft neon bloom** (not a white strobe — WCAG 2.3.1) + the 8-shard pixel burst
(ported), then `arcadeRoute(ArcadeRouteMotion.reveal)` — a ~300–450ms fade-through / centered iris
into `StartGateScreen` (reuse the flow's existing iris painter idiom), ease-out on the incoming reveal.
Reduced-motion → a straight crossfade/cut that still lands on the character reveal.

## 9. Reduced-motion & a11y policy (Codex F3 — one policy, designed first)
Gate on the union `disableAnimations || accessibleNavigation` (shared `_reduceMotion` getter). Then:
- video shows a **still poster** (no autoplay, no forced audio); scanlines static; **no** edge-bloom
  breathe / pour stream / bloom flash / ignition shards;
- the darken+`HOLD TO CHARGE UP` state + the **tap CTA** are shown **immediately** and legibly;
- completion via the always-visible **tap** (no sustained hold required); transition is a
  crossfade/cut that still delivers the character reveal;
- controllers created **eagerly in `initState`** (never lazily in a reduced-motion `build` that
  `dispose()` then touches — the documented `late final` crash); implicit animators **omitted**, not
  zeroed (`AnimatedSize`/`AnimatedSwitcher` branched out).
- Semantics: the screen node announces the state ("Charging your first session… hold or tap to
  complete"); the keycap + tap + skip each carry a `Semantics(button, label)`.

## 10. Assets & wiring
- Transcode the finalized 4:3 reel → `assets/onboarding/charge_ritual_reel.mp4` (H.264 + AAC,
  480–720p, ~3MB). Declare **that one file** in `pubspec.yaml` (never the `motivation_reel/` working
  dir). A poster still (first frame) for the reduced-motion + pre-play state.
- Reuse the `bit-sprites`? No — BIT is the **painted** `BitMoodCore` (no raster).
- Optional new SFX via `SfxService`: transmission-boot, pour hum, ignition thunk (don't-limit-assets).

## 11. Delta contract & acceptance criteria (Codex F6)
**Ported verbatim (layer-1):** the state machine, drain-forgiveness, pour-stream effect, ignition
burst, `ArcadeBar` fill, `ChargeHead`, BIT's 4 lines + `[bracket]` emphasis.
**Sanctioned, user-approved deviations (recorded):** (a) reel-console bezel/rivets/plate-LED →
phosphor grade; (b) skip always-visible → **delayed-reveal** + truthful copy; (c) added
**always-visible tap** completion path; (d) raster `BitSprite` → painted `BitMoodCore` (neutral/cheer,
glow-pour); (e) `FILL` 1700→**1400ms**; (f) charge decoupled from video (soft-lock fix); (g) audio
device-volume + mute + captions.
**Acceptance criteria (the "feel" is verifiable):**
- reel→90%→hold→pour→ignite→gate completes; drain never < 0.90; ignite fires once.
- **No playback failure soft-locks** (error/stall/no-duration all still reach hold within the clock).
- reduced-motion path completes with **no** animation/audio surprise and a legible tap CTA.
- tap completes for everyone; hold is the default; skip appears ~3s and routes out.
- neon appears **only** on meter + keycap; video edge is cyan/low-alpha.

## 12. Files
**New:** `lib/pages/onboarding/charge_ritual_screen.dart` (screen + engine); a bespoke 4:3
video-monitor widget (phosphor grade) + pour-stream painter + ignition burst (in-file or
`widgets/onboarding/`); `assets/onboarding/charge_ritual_reel.mp4` + poster.
**Edit:** `reminders_primer_page.dart` (`_continue` target); `pubspec.yaml` (asset); extract
`_CrtScreenPainter` → `widgets/motion/crt_overlay.dart` (byte-identical golden gate); `SfxService`
(optional).
**Reuse:** `ArcadeBar`, `BitMoodCore`, `BitSpeechBubble`, `PixelButton`/`HoldDepress`/`PhosphorTap`,
`arcade_route`, `neonGlow`, `HapticService`, tokens, the `ExerciseDemoPlayer` video pattern (loop
off, volume 1.0, position listener, poster fallback, lifecycle pause).

## 13. Verification strategy
- **Unit:** `charge_ritual_engine_test` — state machine, drain floor 0.90, dt clamp, **watchdog/
  soft-lock** (video-error & no-duration still reach hold), tap auto-fill, FILL≈1.4s.
- **Widget:** reduced-motion (poster + immediate tap CTA, no dead control, no crash on dispose);
  hold-completes + tap-completes; skip appears after the delay; Semantics labels.
- **Golden:** the two states (reel-playing, pour) at a phone size × text-scale matrix; the extracted
  CRT overlay golden stays byte-identical for existing callers.
- **analyze/test:** `flutter analyze` zero issues; `flutter test` green; `tap_haptic_coverage_test`
  stays green (all taps via wrappers).
- **⚠ Blocking visual gap:** per `ironbit-design`, a visual change needs a *rendered* artifact.
  Flutter web preview can't screenshot in this env; goldens render but are a human-oracle. → the look
  (phosphor edge strength, vignette, darken ghost, transition drama) requires **on-device sign-off**;
  named as a residual, not silently passed.

## 14. Residual risks
- On-device *feel* of the phosphor edge / darken timing (tune live).
- Reel transcode fidelity at 4:3 (captions legible at device size).
- Two BIT emotional peaks (Solution + this) — accepted (8+ screens apart, different in kind).

## 15. As-built notes (deviations found during implementation)
- **Aspect: the supplied `.mov` was 16:9 (`1920×1080`, square pixels — verified via ffprobe DAR).**
  Per user decision it was **center-cropped to true 4:3** (`crop=1440:1080:240:0` → `960×720`); a
  caption-frame contact sheet confirmed the burned-in captions sit inside the crop and **do not clip**.
  Bundled as `assets/onboarding/charge_ritual_reel.mp4` (4:3, ~1.8MB) + `_poster.webp`; the monitor's
  fallback aspect is `4/3` but stays **aspect-adaptive** to `controller.value.aspectRatio` if swapped.
- **Hero height is capped via `LayoutBuilder`** (available height × 0.36), not `MediaQuery.sizeOf`
  (which is `Size.zero` under a test's `MediaQueryData` override — it silently collapsed the monitor
  while the widget test still passed; caught by a golden render). Only bites on short viewports.
- **Persistence flag dropped** (YAGNI): nothing reads a `charge_ritual_done` flag (onboarding runs
  once; no replay route, per the truthful-skip decision) — an unused write would be dead code.
- **Phosphor edge tint = `kCyan`** (BIT's chamber colour), resolving the "neon = action only" rule
  (Codex F7); neon stays on the meter + keycap.
- **BIT** = `BitMoodCore` neutral→cheer; the "pouring" energy is a neon glow + pour stream (no `alert`
  pose exists) — a recorded, user-approved layer-1 deviation.
- **Charge engine decoupled from the video** (Codex F2): an independent bounded clock is authoritative,
  video is best-effort sync, `finishReel()` on end/error advances — no playback failure can soft-lock.
  Proven by `charge_ritual_engine_test` (incl. a mutation check on the soft-lock guard).
- **Verification:** `charge_ritual_engine_test` (9, mutation-proven), `charge_ritual_screen_test` (3:
  a11y tap→ignite→gate, delayed skip→gate, full-motion build), updated `name_screen_test`,
  `tap_haptic_coverage_test`, `flutter analyze` (0 issues). **Blocking gap:** the on-device *look* +
  motion (phosphor strength, darken timing, ignition→gate drama, audio) still needs your sign-off — the
  golden here is a layout oracle only (faked fonts, no live video).
