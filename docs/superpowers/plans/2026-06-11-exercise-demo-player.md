# Exercise Demo Player — proper video playback, hide/unhide, fullscreen fixes

**Status:** Spec approved (design + plan reviewed in chat, 2026-06-11) — implementation in
progress in the same session.

## Context

The shipped demo-cabinet (animated WebP via `Image.asset`) has two audited defects and one
structural limitation:

1. **Fullscreen "can't zoom out" bug (crash):** in `_ExerciseDemoFullscreen`
   ([exercise_demo_cabinet.dart:268](lib/widgets/exercise_demo_cabinet.dart)), the bottom-left
   `Positioned(left:, bottom:)` gives its child **unbounded width** (Flutter only bounds a
   positioned child's width when both `left` and `right` are set). The `Row` inside contains a
   `Flexible` → "non-zero flex but incoming width constraints are unbounded" layout exception → a
   route with broken layout also breaks hit-testing → **every tap dies, including the ✕**. The
   widget test only pumped the cabinet, never the fullscreen viewer, so it slipped through.
2. **Dead zones (latent, even after fixing #1):** the dismiss `GestureDetector` uses default
   `HitTestBehavior.deferToChild`; the black letterbox bars around the `BoxFit.contain` clip are
   not hit-testable, so taps there would not dismiss.
3. **No playback control:** animated WebP through `Image.asset` exposes no pause/play — the loop
   runs forever. User wants a proper player with stop/play.

**Research (category patterns):** exercise demos in trackers (Hevy, Strong, Fitbod, Gymshark) are
short, **muted, auto-looping clips** — autoplay loop is the standard for form-reference material;
chrome when present is minimal (pause; sometimes slow-mo in fullscreen). Full player chrome belongs
to guided-workout video (Nike/Peloton), a different use case. Technically, `video_player`
(ExoPlayer) hardware-decodes — cheaper on battery than CPU-decoding 60–76 WebP frames per loop.

## Locked decisions (user)

- **Approach A: `video_player` plugin + normalized mp4 assets** (rejected: custom WebP frame-ticker;
  poster-swap fake pause).
- **Inline = autoplay loop** (muted), tap on clip toggles pause/play.
- **Chrome = play/pause only.** No scrub bar, no slow-mo, no sound.
- **Hide/unhide toggle on the cabinet**, persisted globally — hidden stays hidden across sessions.
- Fullscreen rebuilt with both bug fixes; tap clip = pause/play, tap black = dismiss, ✕ = dismiss.
- Posters stay for thumbnails; the animated `.webp` loops are deleted; source mp4s stay undeclared.

## Design

### 1. Assets + ops — `ops/generate_exercise_demos.py` (rework)
- Replace WebP-loop generation with mp4 normalization into `assets/exercises/demos/`:
  `ffmpeg -y -i SRC -vf "scale=480:-2" -c:v libx264 -profile:v main -crf 27 -preset slow -an
  -movflags +faststart <slug>.mp4`. Poster extraction (`<slug>_poster.webp`) unchanged.
- Same 5 slugs. Delete the 5 old `<slug>.webp` animated loops from the folder. Expected shipped
  size ~1.5–2.5 MB total (less than the 2.8 MB WebPs).
- `pubspec.yaml`: folder `assets/exercises/demos/` already declared — no asset change. Add
  dependency `video_player` (current 2.x stable). Asset videos need no permissions.

### 2. Registry — `lib/data/exercise_demos.dart` (small edit)
- `ExerciseDemo(this.video, this.poster)` — rename `loop` → `video`, paths now `.mp4`.
- `exerciseDemoFor` / `hasExerciseDemo` / `exerciseThumbAsset` (poster-or-photo) unchanged.
- `allDemoAssetPaths()` covers video + poster (drift guard).

### 3. Player — `lib/widgets/exercise_demo_player.dart` (new)
`ExerciseDemoPlayer(demo, {fit = BoxFit.contain, autoPlay = true})`, stateful:
- Owns `VideoPlayerController.asset(demo.video)`; async init → `setLooping(true)`, `setVolume(0)`,
  then `play()` if `autoPlay` && `!MediaQuery.disableAnimations` (reduced motion → start paused).
- Pre-init: render the poster (`Image.asset(demo.poster)`) so there is never a black flash.
- Tap = toggle. **Paused state:** dim scrim (`kBg` ~0.45) + centered play glyph
  (`Icons.play_arrow_sharp` in a small bordered pixel box — no pixel play asset exists in
  `assets/icons/control/`). **Playing state:** chromeless.
- `WidgetsBindingObserver`: app backgrounded → `pause()` (remember `wasPlaying`, resume on
  foreground if it was playing). Dispose controller in `dispose()`.
- Exposes its controller to the cabinet so fullscreen can share it.

### 4. Cabinet — `lib/widgets/exercise_demo_cabinet.dart` (rework)
- Stage swaps `Image.asset(loop)` → `ExerciseDemoPlayer`. Frame/strip/corner ticks unchanged.
- Strip gains a **HIDE / SHOW** text toggle (PressStart2P ~8, `kMutedText`) at the far right.
  Collapsed = strip only (`AnimatedSize`), player unmounted/disposed — truly stopped, zero decode.
  `LOOP ⤢` (fullscreen) only shown when expanded.
- Persistence: new `WorkoutDefaultsService` key `exercise_demo_hidden_v1` (bool, default false),
  getter/setter mirroring existing keys; cabinet reads it on init, writes on toggle.

### 5. Fullscreen — rebuilt in `exercise_demo_cabinet.dart`
- **Bug fix 1:** bottom name row `Positioned(left: kSpace4, right: kSpace4, bottom: kSpace5)` —
  bounded width, `Flexible` is now legal.
- **Bug fix 2:** backdrop `GestureDetector(behavior: HitTestBehavior.opaque, onTap: pop)`.
- Layering: backdrop (tap dismiss) → centered video wrapped in its own `GestureDetector`
  (tap = pause/play) → name row + `FormDemoTag` → ✕ (`Icons.close_sharp`) top-right.
- **Shares the cabinet's controller** (cabinet owns/disposes; the cabinet route stays mounted
  beneath the fullscreen route, and collapse can't happen while fullscreen is open — safe). The
  loop carries through the Hero transition (two `VideoPlayer` widgets on one controller render the
  same texture). Pre-init fallback: poster Hero, as today.

### 6. Detail hero — `lib/pages/exercise_detail.dart` (small edit)
- Full-bleed `ExerciseDemoPlayer(fit: BoxFit.cover)` replaces the WebP `Image.asset`; keeps
  `FormDemoTag` overlay; tap behavior comes from the player (pause/play); the existing expand →
  fullscreen affordance moves to a small `⤢` pill next to the tag (hero owns its own controller).
- Static-photo and custom-exercise branches unchanged.

### 7. Tests
- **Update `test/exercise_demos_test.dart`:** every demo id in catalog; `.mp4` + poster files exist
  on disk; folder declared; thumb logic unchanged.
- **New `test/exercise_demo_player_test.dart`:** uninitialized player renders the poster + (when
  not autoplaying) the play affordance. No platform mock needed — never call `initialize()`.
- **Cabinet:** HIDE collapses to strip only and writes the pref (SharedPreferences mock); SHOW
  restores; FORM DEMO label present.
- **Fullscreen regression (the bug):** pump the viewer, tap the backdrop → route pops; tap ✕ →
  route pops. This test would have caught today's crash (layout exceptions fail widget tests).
- Existing suites stay green (known `StatEngine` baseline errors in untouched files excluded).

## Verification
1. `python ops/generate_exercise_demos.py` → 5 `.mp4` + 5 `_poster.webp` in `assets/exercises/demos/`,
   old `.webp` loops gone, sane sizes.
2. `flutter pub get` → **full restart** (new dependency + assets).
3. `flutter analyze` — zero new issues (pre-existing `StatEngine`/profile baseline excluded).
4. `flutter test` — all demo/player/cabinet tests + related suites green.
5. Manual (Android): Day-1 lift → cabinet autoplays muted loop; tap → pauses with play glyph; tap →
   resumes; HIDE collapses to strip, survives app restart, SHOW restores; `⤢` → fullscreen, loop
   carries over; **tap black / tap ✕ both dismiss (bug fixed)**; tap clip in fullscreen pauses;
   background the app → player paused, foreground → resumes; reduced-motion (TalkBack/remove
   animations) → starts paused; FULL BODY B lift (no demo) unchanged static photo everywhere.

## Out of scope
Scrub bar, slow-mo, sound, captions; demos beyond the 5 Day-1 lifts; chewie or any chrome package;
network/streaming video; animating thumbnails; pinch-zoom in fullscreen.
