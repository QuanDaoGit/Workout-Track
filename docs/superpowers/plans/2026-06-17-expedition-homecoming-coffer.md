# Expedition homecoming + coffer + collect — increment 2 (2026-06-17)

Applies the BIT-expedition handoff art + the locked **"coffer = curtain, single reveal on the
report, no in-room numbers toast"** flow to the home-room pad. Built through `/deep-feature`
(audit → research-reuse → opinion → Codex adversarial review → plan). Increment 1 (the text-beacon
dock) shipped earlier; this replaces its `returned` text + `out` beacon with the coffer + homecoming
+ collect + away-hologram art.

## The locked flow
open → **homecoming** plays in-room → **coffer** sits on the pad with a COLLECT chip → tap → coffer
**dissolves (curtain)** → routes into the existing **`ExpeditionReportPage`** (the single reveal:
diorama + flavor + find + gem count-up) → CONTINUE pops → clean room. No in-room numbers. Magenta-only
coffer latch. Collect cheer reuses BIT's existing tap-spin. BIT identity turquoise `#17D6CC`; haul/gem
magenta.

## Codex-hardened authority model (the spine)
**Persisted state is the SOLE authority for "is there an uncollected haul."** Never a volatile held
field (Codex finding #1/#5).

- New pure helper `AdventureService.hasUncollectedHaul(AdventureState, DateTime now)` =
  `history.any((e) => !e.viewed) || (pending != null && _isRevealable(pending, now))`. Used by BOTH
  the room view-model and (implicitly) consistent with `settleAndPeekReport`, so they can't disagree.
- `RoomAdventureView.haulReady` is derived every `_loadData` from the loaded `_adventureState` via that
  helper. **Coffer visibility depends only on this** — survives kill/reopen, deferred reveal, and the
  service auto-settling a pending on a charge-grant between opens.
- `canDispatch` = `ui.canDispatch && !haulReady` → single-track pad (coffer XOR dispatch XOR out).
  Defers the dispatch *spend* one tap; never blocks the *earn* (charges still accrue).
- **Fail-open** (finding #2/#3): the coffer is always tappable; collect re-peeks via
  `settleAndPeekReport()` (idempotent, covers pending-returned AND unviewed-history). If a peek ever
  returns null while `haulReady`, reload (re-derive from fresh persisted state) — never a silent
  permanent dispatch block.
- **Backlog = a queue over persisted unviewed history** (finding #4): always oldest-unviewed,
  acknowledge only the shown id, reload after pop, next coffer shows until the queue drains. The
  **homecoming animation fires only on a fresh settle this open** (a one-shot `homecomingTick` from
  Home); backlog/static hauls show a still coffer.

## Changes by file

### Service / model (data authority)
1. `lib/services/adventure_service.dart` — add `static bool hasUncollectedHaul(AdventureState, DateTime)`
   (pure; reuses `_isRevealable`). No change to settle/ack/ledger semantics (idempotency intact).

### Room art (cosmetic, never gates correctness)
2. `lib/widgets/room/coffer.dart` (NEW) — `CofferPainter` porting `coffer-paint.js paintCoffer` with
   `ROUTE.none` (magenta) only. Native 28×20, integer cell paint, `isAntiAlias:false`. Params:
   `double build = 1` (bottom-up fabricate per `BUILD` order), `Set<int> dropped = {}` (2×2 blocks for
   the dissolve). Pad-metal + magenta-gem palettes are local consts — the documented procedural
   sprite-palette raw-`Color` exception (same status as `bit_companion._metal`, beam/`_tiers`).
3. `lib/widgets/room/bit_pad_light.dart` — add `double tint = 0` (0 turquoise → 1 magenta); lerp the
   `_tiers` ramp toward the magenta ramp; `shouldRepaint` compares `tint`.
4. `lib/widgets/companion/bit_companion.dart` — add `int cheerTick = 0`; extract `_fireCheer()` from
   `_onTap`; in `didUpdateWidget`, a changed `cheerTick` fires the SAME `_spin`/`_retract` path
   (reduced-motion → brief cheer flash). Lets COLLECT reuse the exact flare→orbit→stutter.
5. `lib/widgets/room/bit_hologram.dart` (NEW) — the away-state turquoise hologram of BIT in a
   containment rig (scanlines/rollbar/glitch). Gated: animates only when `TickerMode.of(context)` is
   active + motion on; **static still** under reduced motion and in tests/goldens. Replaces the up-arrow
   beacon for `phase == out`.
6. `lib/widgets/room/room_scene.dart` —
   - `RoomAdventureView`: add `bool haulReady`; add `int homecomingTick`.
   - Coffer rendered on the pad when `haulReady` (homecoming `build` + collect `dropped`/lift/opacity);
     pool `tint`→magenta when `haulReady`.
   - `_homecoming` controller (cosmetic, motion-gated, fired on `homecomingTick` change): BIT descends
     (mirror of `_launch`) + magenta payload mote + bloom + coffer fabricates + pool tint 0→1 + COLLECT
     chip fade-in. Reduced motion → snap to coffer present.
   - Collect state machine `_Collect { idle, dissolving }` (finding #4): coffer tap → re-entry guard →
     bump BIT `cheerTick` + run `_collect` dissolve → on controller **status.completed** (not
     postFrame), `mounted` + `route.isCurrent` check → `widget.onCollect()`. Reduced motion → call
     `onCollect` immediately. Deterministic teardown on dispose/deps-change.
   - Away: render `BitHologram` instead of the beacon when `phase == out`.

### Home wiring (no auto-push)
7. `lib/pages/home.dart` —
   - On open: capture `willSettle = pending revealable` BEFORE; call `settleAndPeekReport()` to keep
     **gems durable on open**; do **NOT** push; `_loadData()` to refresh `_adventureState`. If
     `willSettle`, bump `_homecomingTick` (one-shot homecoming). Remove the auto-`Navigator.push`.
   - `_buildRoomAdventure()`: set `haulReady = AdventureService.hasUncollectedHaul(state, now)`,
     `canDispatch = ui.canDispatch && !haulReady`, pass `homecomingTick`.
   - `onCollect` stays wired to the existing `_maybeRevealExpeditionReport(fromUserTap: true)` body
     (re-peek → push report → acknowledge by id → reload) — already the fail-open, idempotent path.
   - The on-open ongoing-session precedence is unchanged; with no auto-push there's nothing to defer —
     the coffer simply renders statically behind any idle-session modal.

## Tests
- `test/adventure_service_test.dart` — `hasUncollectedHaul`: unviewed-history true; pending-returned
  true; all-viewed false; empty false; **kill/reopen after settle** (unviewed history → still true);
  **auto-settle on grantCharge** between opens (pending→history unviewed → still true).
- `test/expedition_dock_test.dart` — coffer shows when `haulReady` (idle+unviewed and returned-pending);
  `canDispatch` false while `haulReady`; collect routes to the report; reduced-motion → still coffer +
  immediate route; **double-tap during dissolve fires onCollect once**.
- `test/expedition_dock_golden_test.dart` + `room_scene_golden_test.dart` — regenerate: returned→coffer,
  out→hologram (static frames; perpetual tickers frozen so goldens don't hang).
- `test/bit_companion_test.dart` — `cheerTick` change drives the cheer (reduced-motion safe).

## Reduced-motion / a11y
Coffer + COLLECT chip is the still legible fallback; hologram → static still; collect routes without
the dissolve; Semantics: pad reads "BIT has returned. Collect the haul." Announce "BIT has returned
with a haul" on the fresh settle.

## Verification
`flutter analyze` (0) · `flutter test` · regenerate + eyeball goldens · finish-time color grep ·
on-device sign-off for the homecoming/collect *feel* + the hologram *comprehension* (does the ghost
read as "away", not "gone") — the blocking visual gap.

## Plan-review resolutions (Codex pass 2)
- **Arrival trigger** is a monotonic `homecomingTick`; the room plays homecoming when
  `tick > _playedTick && haulReady`, checked in **both `initState` and `didUpdateWidget`** (cold open
  has no previous widget). Home bumps it **only on a fresh settle** → backlog = static coffer.
- **Dispatch guard centralized**: `_onPadDispatch` re-reads persisted state and blocks on
  `hasUncollectedHaul`; the room's `_onPadTap` routes to **collect when `haulReady`** regardless of phase.
- **Collect re-entry** = "dissolve controller animating"; completion **synchronously** pushes the
  full-screen report (occludes the reload window). Fail-open: null peek → reload leaves coffer tappable.
- **Foreground expiry**: one `_settleAndRefreshExpedition()` routine called on open +
  `AppLifecycleState.resumed` + a one-shot `Timer` to `pending.returnsAt` while out.
- **Reduced-motion collect**: `cheerTick` is a no-op under reduce; no dissolve; `onCollect` called
  synchronously (report occludes immediately).
- **Controller lifecycle**: lazy/motion-gated one-shots (file precedent); `didChangeDependencies`
  stops+snaps `_homecoming`/`_collect`; `status.completed` gated `mounted` + `route.isCurrent`; dispose all.

## Faithful-port correction (2026-06-17, pass 2)
The first pass *approximated* the away hologram (a hand-painted blob) and the send-off (BIT just flew
up). Re-audited the handoff engines (`holo-bit.js`, `bit.js`, the `playLaunch` script) and ported them
verbatim — everything identical to the handoff **except** the colour (cyan → app turquoise) and the
already-removed per-route coffer seal.
- **Shared sprite art:** lifted `drawBitGrid`/`drawBitScreen` to top-level in `bit_companion.dart` +
  added `paintBitSprite` (byte-identical companion golden verified first, per Codex).
- **Hologram** (`bit_hologram.dart`): now renders **BIT's real sprite** post-processed exactly like
  `holo-bit.js` — alpha flicker, jitter, turquoise tint + scanlines + roll bar all `srcATop`
  (BIT-pixels-only), glitch slice via **three clipped passes** (above/below normal + band translated),
  inside the dithered rig (emitter field + brackets + scan-planes).
- **Send-off** (`launch_fx.dart` + `room_scene.dart`): the full **2000ms, 5-phase** `playLaunch` —
  P0 charge crouch + inward sparks · P1 ignition **burst + core flash** + pad recoil · P2 ascent
  (`-490·a²` ease-in) with **vapor trail + speed-streaks** · P3 **exit-pop** at the top · P4 collapse.
  Particles are **pre-generated once per launch** (seeded), positions a **pure function of elapsed**
  (Codex: never RNG in `paint`). New goldens: `bit_hologram(_glitch)`, `launch_fx_*`.

## Send-off beam correction (2026-06-17, pass 3)
Re-read `bitpad-beam.js`: the beam is driven by **`scale`** (brightness) + **`topY01`** (retract into
the emitter), and `topY01:0` is the beam's **maximum** height (its normal top, which fades *before*
BIT). The first port instead used a `launch` param that *flattened the vfade so the beam extended to
full height past BIT* — wrong; the beam shot up the screen. Replaced `launch` with the real
`scale`/`topY01` model and drove it verbatim from the `playLaunch` `beam.set()` calls: charge
ramps `scale 0.4→1.0`; ignition+ascent hold `scale 1.15, topY01 0` (brightens **in place** while BIT
rises above it); exit-pop + collapse dim and **withdraw into the emitter** (`scale→0, topY01→1`).
Homecoming/collect now also drive `scale`/`topY01` (withdraw on deposit, re-emerge on collect) instead
of an opacity hack. Idle beam is byte-identical (`scale:1, topY01:0`). New golden: `beam_*`.

## Open risks carried (Codex)
- Hologram comprehension (ghost vs beacon) — on-device check (finding #9).
- The homecoming-on-fresh-settle one-shot must not replay for backlog items (finding #4) — covered by
  `homecomingTick` only bumping when `willSettle`.
