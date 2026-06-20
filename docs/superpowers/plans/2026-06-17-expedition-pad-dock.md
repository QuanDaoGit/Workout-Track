# Expedition pad dock — increment 1 (2026-06-17)

Wire the shipped Expedition mechanic (`AdventureService`) into the home-room **pad**, making it the
in-room **dispatch dock**. Presentation-only — no service/persistence/economy change. Ran through the
`/deep-feature` pipeline (audit → `research` → opinion → Codex adversarial review → implement).

## Scope (this increment)
`idle/ready → console → SEND → launch → out`, plus a **minimal** on-pad `returned → COLLECT`.
Deferred to increment 2 (art in progress elsewhere): the full **on-pad homecoming + haul-coffer
ceremony**.

## The dock state machine (`HomeRoomScene`)
Phase is the **sole authority** (`adventureUiStateOf`, re-derived every build via
`RoomAdventureView`, never cached — Codex). BIT presence is derived from it.

- **idle/ready** (`canDispatch`): BIT home; a dark **DISPATCH readout** (neon label + charge pips)
  folded onto the dock below the pad. No charge → no caption (don't nag), pad still tappable → nudge
  "TRAIN TO EARN A CHARGE".
- **console**: `ExpeditionDispatchSheet` — arcade bottom sheet (3 route rows + `SEND BIT · {ROUTE}`).
  SEND disables on tap; calls `dispatchExpedition`; the service's **null is the source of truth**
  (→ snackbar). Modal, so it blocks the Home auto-reveal underneath (no reveal-beneath race).
- **launch** (~1.4 s): a **non-authoritative cosmetic overlay** (controller created only when motion
  is on; fires on the `idle→out` phase flip; rebuilds on completion). BIT coils, rides the surging
  beam (`BitPadBeamPainter.launch`) up and out, fading. Reduced motion → no fly-up; instant cut to
  `out`.
- **out**: BIT absent; chamber dims (pool to 0.5, beam hidden) *because he's away*. A still outbound
  **beacon** (route accent up-arrow, **not** a BIT silhouette — avoids a ghost/death reading) +
  `SCOUTING · {ROUTE} · BACK IN ~Nh`, placed where BIT floats (place-held = "coming back"). Tap →
  read-only status (the existing `AdventurePage`); never re-dispatch (`canDispatch=false`).
- **returned** (the reveal-blocked edge): BIT home + a calm amber `HAUL READY · TAP TO COLLECT`; tap
  → the existing `settleAndPeekReport → ExpeditionReportPage → acknowledge` ceremony
  (`_maybeRevealExpeditionReport(fromUserTap: true)` bypasses the ongoing-session guard).

## Codex-hardened decisions
1. Console rebuilds from live state; SEND disables on tap; launch only after a non-null dispatch.
2. `adventureUiStateOf` is the only persisted phase; launch is cosmetic + cancellable; legacy/malformed
   `returnsAt:null` is handled by the existing service (revealable) and just reflected as `returned`.
3. Reduced motion gates controller **creation** (not just opacity); no perpetual launch ticker.
4. Send-from-pad ships **with** a legible on-pad return affordance (no half-loop).
5. Absence reframed **away** from a BIT-silhouette → reserved dim chamber + outbound beacon + warm copy.

## Files
- `lib/widgets/room/bit_pad_beam.dart` — `launch` (0→1) surge/extend param.
- `lib/widgets/room/room_scene.dart` — `RoomAdventureView` + callbacks; phase-aware dock; launch
  overlay; dark **readout backdrop** behind captions (luminance contrast over the bright pool).
- `lib/widgets/room/expedition_dispatch_sheet.dart` — the console bottom sheet.
- `lib/pages/home.dart` — builds the view-model, owns all `AdventureService` calls + the console +
  COLLECT.
- Tests: `test/expedition_dock_test.dart` (state/Semantics/tap/reduced-motion),
  `test/expedition_dock_golden_test.dart` (ready/out/returned rendered artifacts).

## Open verification gap (blocking sign-off)
The **`out`-state comprehension** ("empty-but-place-held dock reads *coming back*, not *he left*") is
execution-dependent and untested with users (Codex #5 / research `[risk]`). Needs on-device / hallway
sign-off before this is considered done. Goldens prove it renders cleanly, not that it *reads* right.

## Not done here
- On-pad homecoming + haul-coffer ceremony (increment 2).
- `AdventureCard` retained for now (taps to `AdventurePage` for history/orders); revisit once the pad
  fully owns the loop.
