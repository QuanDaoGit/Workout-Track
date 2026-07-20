# Home-room micro-interactions — design spec

Date: 2026-07-20 · Status: user-approved (mock reviewed) · Pipeline: deep-feature (research + two Codex adversarial passes folded in)

## Intent

Make the home room feel physical at the moment of interaction: tapping a room fixture moves the
camera toward it (spatial continuity), and pressing BIT produces a tactile creature response. All
four pieces are user-triggered feedback — never ambient decoration (NN/g repeated-animation
evidence; salience model).

Evidence anchors: container-transform element→page continuity (Material canon); IJHCS 2024 —
click-response delay is the fluency killer, so motion starts on tap and never runs serially before
the push; WCAG 2.3.3 — zoom is a vestibular trigger, reduced motion falls back to today's exact
behavior; JCR 2025 — haptic reward response peaks ~400ms (the purr sits under it).

## Scope — 4 keeps, 2 cuts, 1 deferral

Keeps:
1. **Quest-board dolly** (travel): board tap → camera dollies into the board, quest page reveals
   over it; pop plays a settle pull-back.
2. **Pad focus-push** (focus): dispatch-path pad tap → subtle whole-room lean toward the pad while
   the dispatch sheet rises; reverses on any dismissal.
3. **BIT purr**: a shaped ~280ms haptic envelope on BIT press — the tactile twin of the existing
   cheer orbit. No new visual animation.
4. **Press-light pass**: board + pad answer pointer-down with a paint-level brightness step
   (press feedback via light, never per-fixture transforms — the room stays one depth plane).

Cuts: overscroll room stir (motion on a high-frequency accidental gesture); time-of-day room tint
(WorldWindow already carries timeOfDay; palette headroom is thin).
Deferral: BIT gaze tracking → future BIT-presence feature.

## Two-tier camera grammar

**Page = travel (dolly), sheet = focus (push).** The dolly is reserved for navigation to a full
page from a room fixture; the push is a lean that stays under a sheet. Different weights make the
destination class legible pre-consciously.

## 1 · Quest-board dolly

- **Forward (board tap, quests unlocked, motion on):** HomePage starts a 280ms zoom
  (1.0 → ~1.12, `Curves.easeOutCubic`-family, focal point = board center) and calls the push in the
  same tick. The quest route uses a new `ArcadeRouteMotion.dolly`: the incoming page is
  **invisible for the first ~40%** of its 280ms transition (the travel beat — the room visibly
  dollies alone), then the existing CRT-signal band reveal composes over the zoomed room.
  (Codex F1: without the held-back reveal the fade swallows the zoom.)
- **Raster zoom, not geometry zoom:** the zoom scales the room's rendered layer
  (`Transform.scale` around a `RepaintBoundary` child) — a photographic camera move. Sprites are
  never re-sampled per-frame at fractional geometry scale (pixel-shimmer doctrine). Magnitude is
  capped modest (~1.12) so mid-motion softening stays sub-cell (Codex F5).
- **Stateless while covered (Codex F2):** once the route is fully opaque, the zoom resets to
  identity silently. No transform is held as route state. Any non-standard return path (tab
  switch, rotation, background) finds the room at identity.
- **Pop settle:** HomePage is `RouteAware` (existing `appRouteObserver`); on `didPopNext` with a
  pending board-return flag (+ motion on), it sets the zoom instantly to ~1.06 (still covered) and
  eases to identity over ~190ms as the route's 190ms reverse fade plays. Flag cleared on fire;
  any covering route that isn't the board push never sets it.
- **Locked path (Codex F4):** HomePage checks `_questsUnlocked` first. Locked → today's
  feature-gate notice, zero zoom. The zoom can only start when a push will actually happen.
- **Reduced motion:** exactly today's behavior — plain fade route, no zoom (the route's existing
  reduced-motion branch + the lens returning its child unchanged).
- **Unchanged:** board haptic (coalesced selection) + degauss SFX; the Weekly Quests card path
  keeps the plain fade; quest page itself untouched.

## 2 · Pad focus-push

- **Dispatch path only** (`AdventurePhase.idle`, canDispatch flow that opens the sheet). The
  status path (pushes AdventurePage) and the collect path (haul ceremony) are untouched — a held
  scale under a covering route is exactly the state hazard Codex F2 named, and collect owns its
  own ceremony.
- Motion on: zoom to ~1.05 toward the pad over ~180ms (`kMotionBase`) as the sheet rises;
  `try { await sheet } finally { reverse; }` so every dismissal path (drag, scrim, back,
  programmatic) reverses it (Codex F6). Re-entry blocked while active. Reduced motion: sheet only.

## 3 · BIT purr

- New `HapticService.bitPurr()` — lives inside the service so the enabled-gate, fail-open guard,
  and doctrine apply (Codex F3):
  - Amplitude control: one gap-free rise-fall envelope ≈280ms (e.g. segments
    60/60/60/60/40ms at intensities ~50/105/80/45/20 — soft, peak ≪ the reward tier).
  - No amplitude control: a designed soft **double-pulse** (~25ms + ~30ms, ~60ms apart) — never a
    flat sustained buzz (no-drone doctrine).
  - No vibrator: existing `selectionClick` fallback.
  - **In-flight guard:** a fresh call within the envelope window (~300ms, via the service's
    `nowProvider`) is dropped — the motor never cancel-restarts mid-envelope.
- `BitCompanion._onTap` fires `bitPurr()` instead of the coalesced selection tick. The spam-rest
  gag path is untouched (a resting BIT stays silent — `_onTap` already early-returns). The chirp
  SFX and cheer orbit are unchanged; reduced motion keeps the purr (action-tied haptic, own
  Settings toggle — insights doctrine).

## 4 · Press-light pass

- **QuestBoard:** pointer-down brightens the board's screen one visible step (paint-state via the
  existing painter, ~90ms hold then release); works in both powered states.
- **Pad:** pointer-down brightens the pad (a light overlay step on the pad sprite / LED strip).
- Paint only — no per-fixture transform (room one-depth-plane doctrine, Codex F7). A brightness
  step is state feedback, not motion — it stays under reduced motion.
- BIT excluded: the orbit is his press response.

## Seams / architecture

- `RoomZoomLens` (new, `lib/widgets/room/room_zoom_lens.dart`): wraps the room container in
  HomePage; `Transform.scale` around a `RepaintBoundary`; identity (returns child subtree
  unchanged in effect) at value 0 and under reduced motion — goldens and standalone uses
  unaffected. Composes **outside** `_RoomParallax` (camera over parallax).
- RoomScene exposes board/pad focal alignments derived from its own layout math (single source of
  truth — no duplicated rect constants in HomePage).
- HomePage gains `onViewQuestsFromBoard` (RootPage wires it to the quest push with
  `ArcadeRouteMotion.dolly`); the room's board tap routes through HomePage's gate-checking
  handler. The card path keeps the existing `onViewQuests`.
- `ArcadeRouteMotion.dolly` added to `arcade_route.dart`: forward 280ms (reveal held to
  ~t>0.4, then the CRT-signal composition), reverse 190ms; reduced-motion branch already falls to
  plain fade for every motion.

## Verification contract

- `flutter analyze` zero issues; full `flutter test` (7 pre-existing env failures baseline).
- New tests: purr in-flight-guard unit test (via `nowProvider`); `RoomZoomLens` identity /
  reduced-motion / active-transform widget tests; dolly route reveal contract (incoming page not
  visible at an early pump, visible after); board locked-path = no zoom contract; press-light
  state test on QuestBoard.
- Frame-capture pass on the web build (Playwright) for the dolly + settle; screenshots to
  `design/screenshots/`. On-device shimmer check flagged for user sign-off (env cannot run
  Android).
- Finish-time audit (ironbit-design): token-only colors, sharp icons, no raw gesture regressions
  (`tap_haptic_coverage_test` green).
