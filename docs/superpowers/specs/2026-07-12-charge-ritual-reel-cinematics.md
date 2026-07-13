# Charge Ritual — reel entry/exit cinematics (design + plan)

Date: 2026-07-12 · Status: **implemented** (analyze + tests green; on-device feel sign-off pending) ·
Pipeline: `/deep-feature` (thinking-first-principles
→ ironbit-design → research ×2 web-cited → Codex needs-attention → resolved). Refines the shipped
`lib/pages/onboarding/charge_ritual_screen.dart`.

## 1. Problem
The reel autoplays the instant the screen mounts (no setup) and ends by snapping a scrim + `HOLD TO
CHARGE UP`. Both ends feel rushed/cheap. This section is the cinematic + motivational climax; entry &
exit are the load-bearing moments.

## 2. Principles (research, both briefs convergent)
- **Peak-end**: the *ending* dominates remembered value → invest the exit more than the entry; the prompt
  is the reel's **exhale**, not a new screen.
- **Anticipation, capped**: entry is a wind-up, one coiling gesture, **≤1.5s, always moving** (never a
  static black hold >~350ms).
- **Audio**: never slam — **lead** on entry (J-cut), **tail** on exit; ramp both.
- **CRT power-on**: beam-line expand → **1–2 frame** bloom → scanlines settle; restraint = premium.

## 3. Beat map (revised for Codex F2/F6)

| Phase | Beat | ~ms | What |
|---|---|---|---|
| **Entry** | A · power-on | 350 | dark monitor → bright beam-line expands to fill → 1–2-frame phosphor bloom + one RGB-split → scanlines settle (adapt `_BootTransitionPainter` power-on, scoped to the monitor rect). Optional CRT riser SFX leads. |
| | B · held frame | 500 | the **poster** (frame-0 bitmap, verified bright) shown dimmed ~30%, motionless — the anticipation hold. **Not** the raw video surface (F6: frame 0 may be black pre-`play`). |
| | C · ease-in + go | 350 | brightness 30%→100% (emphasized-decelerate) **cross-fading poster→live video**; audio volume 0→1 in parallel; `play()` at Beat-C start, `engine.beginReel()` at its end. |
| **Reel** | plays | ~15s | charge 0→0.9; delayed skip ~3s into playback; **tap-to-pause** (reel phase only). |
| **Exit** | X · recede | ~700 | starts **after the final line is readable** (F2): picture opacity/brightness fades to scrim on an S-curve while audio **tails** (clamped to 0 before `duration`). |
| | Z · prompt | ~300 (delay ~200) | `HOLD TO CHARGE UP` eases up (fade + scale 0.96→1.0, ease-out) + CRT-bloom bookend; bar ready-pulse + BIT line arrive. Fused exhale. |

## 4. Engine change (`charge_ritual_engine.dart`)
- Add phase **`preroll`** (before `reel`); charge stays 0 during the entry cinematic.
- `beginReel()` — **idempotent** — transitions `preroll→reel`.
- **Watchdog (F1):** `prerollMs` cap (default ~2000). `tick()` accumulates preroll elapsed; if it exceeds
  the cap, force `beginReel()` (playable) — clock-driven safety, independent of the entry animation.
- `pause()` / `resume()` — freeze/resume the charge fill for **tap-to-pause** (F4).
- Reduced motion: skip preroll (start via `finishReel()` → hold, as today). Soft-lock watchdog (video-init
  fail → `finishReel`) intact. Existing 9 engine tests stay green; add: preroll→reel, preroll watchdog
  timeout, `beginReel` idempotent, pause/resume.

## 5. Interaction state table (F4)
| Phase | Monitor tap | Mute icon | Skip | Keycap |
|---|---|---|---|---|
| preroll | inert | hidden | hidden | disabled |
| **reel** | **pause/resume** (video + charge clock + skip-timer + reel anim/audio, together) | own hit region (no bubble) | reveals ~3s in | disabled |
| exit/hold/pouring | inert | hidden | visible | active |
Mute + skip get **exclusive hit regions** that don't bubble to the monitor pause. Pause is a single
coherent freeze (nothing desyncs); a pause glyph shows while paused.

## 6. Audio (F3)
- Entry: `setVolume(0)` at `play()`, ramp →1 over ~400ms.
- Exit: ramp →0 over the reel's final ~600ms, **clamped to 0 before `duration`** (no end-slam even if
  ExoPlayer quantizes). Audio finishes with/just after the picture.
- **On-device gap:** `setVolume()` ramp smoothness on ExoPlayer is unverified here → flagged for device
  sign-off; fallback = a tiny baked audio-only fade if stepping is audible.

## 7. Reduced motion / a11y (F5, union gate `disableAnimations || accessibleNavigation`)
Deterministic RM path: **no preroll wait, no entry/exit controller starts**; poster shown; advance via the
same idempotent engine methods to hold. Controllers created **eagerly in `initState`** (documented
dispose-crash avoidance), never forwarded under RM. Tap-to-pause moot (RM doesn't autoplay). Reel is >5s
motion → tap-to-pause satisfies WCAG 2.2.2 in the motion path.

## 8. Asset
Re-crop the **un-faded** `..._human_edit.mov` (16:9) center-crop → 4:3 `assets/onboarding/
charge_ritual_reel.mp4` (no baked fades; first & last frames verified bright). **Regenerate the poster
from frame 0** (`-ss 0.05`) so the held-frame poster matches the video's opening for a seamless cross-fade.

## 9. Files
- **`charge_ritual_engine.dart`** — `preroll` phase, `beginReel`, watchdog, `pause/resume`.
- **`charge_ritual_screen.dart`** — `_entry` (~1200ms) + `_exit` (~1500ms, replaces `_darken`)
  controllers (eager); poster-held-frame + cross-fade; power-on overlay (scoped `_BootTransitionPainter`
  idiom); position-driven exit recede; phase-gated tap-to-pause + pause glyph; audio ramps; RM path.
- **`charge_ritual_reel.mp4` + `_poster.webp`** — re-cut from the un-faded source.
- Optional: `SfxService` CRT power-on riser.

## 10. Verification
- **Engine tests** (extend): preroll→reel via `beginReel`; **preroll watchdog** force-advances on timeout
  (soft-lock guard, mutation-proven); `beginReel` idempotent; pause/resume freezes/resumes fill.
- **Widget tests**: RM path (poster→hold, no dead control, no dispose crash, no `pumpAndSettle` hang);
  tap-to-pause pauses engine + skip-timer + resumes; entry completes → reel; exit fires → prompt;
  mute/skip don't trigger pause.
- **Golden**: entry mid-beat (power-on/held) + exit mid-beat (recede) states.
- `flutter analyze` 0; `flutter test` green; `tap_haptic_coverage_test` green.
- **Blocking on-device gaps** (no working device here — emulator broken, `video_player` no Windows): the
  *feel* — power-on look, exact recede-start timing vs the final line, audio-ramp smoothness — needs your
  device sign-off. Named, not silently passed.

## 11. Acceptance criteria
Entry reads as an authored power-on (never instant, never a frozen-black hang); the reel starts from a
held frame and eases into motion; **no playback failure or entry interrupt soft-locks** (preroll
watchdog); the final line stays readable, then the image recedes and fuses into the prompt (no snap);
audio never slams or crashes; tap-to-pause works and desyncs nothing; RM lands on a still legible hold.
