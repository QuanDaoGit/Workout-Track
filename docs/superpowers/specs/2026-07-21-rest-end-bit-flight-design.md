# Rest-end BIT flight — "BIT banks the exercise" (flight → corner seal → frontier hop)

- **Date:** 2026-07-21
- **Status:** Approved (user: "run everything, including the implementation")
- **Scope:** `ActiveWorkoutPage` + `RestBreakPanel` + one new overlay widget. Builds directly on
  the shipped frontier-BIT spec (`2026-07-21-session-hub-bit-frontier-design.md`).
- **Pipeline:** brainstorming → wide research → TWO Codex adversarial rounds (design: 4 findings;
  choreography: 7 findings — all folded). User override accepted: SKIP REST also flies.

## Problem & insight

The between-exercise rest ends and the rest panel's 96px BIT teleports away while a 44px BIT
teleports onto the frontier card — the same character, discontinuous. Worse: the cleared card's
StrobeFlash celebration currently fires while the rest takeover covers the list — **the
completion celebration has been invisible in every rest path**. The flight sews the two BITs
into one creature and relocates the celebration to the first frame it can actually be seen.

## Evidence (delta over the frontier-BIT entry; full trail in insights.md)

- Duolingo (craft): frequent per-item character celebrations are established practice; big beats
  are rarity-tiered; variation invested. → keep this beat small; the all-clear dock stays the
  bigger moment; variation deferred to v2.
- Juice canon + IJHCS (settled): input never waits for decoration.
- Celebration fatigue (directional): brevity + rarity-tiering over spectacle.
- Settled reuse: container-transform continuity, NN/g repetition, JCR ~400ms, D/A fatigued
  attention, between-sets "boringly efficient" consensus, WCAG vestibular, motion salience model.

## Trigger taxonomy (final)

| Event | Flight? | Celebration (strobe) |
|---|---|---|
| Live natural expiry on the hub (<3s overshoot; incl. −15s-to-zero) | YES — natural profile | At the stamp |
| SKIP REST (user override: "as if user didn't skip") | YES — skip profile | At the stamp |
| Stale/backgrounded expiry (≥3s) | no | On list return (visible) |
| Rest ends while an exercise page covers the hub | no | On next hub visibility |
| Reduced motion (`disableAnimations \|\| accessibleNavigation`) | no | **No strobe** — the static cleared warmth is the designed no-motion signal (also closes a pre-existing RM gap: the strobe used to fire under RM) |
| Final exercise (rest suppressed, no panel) | no | Immediate on return (visible today; now RM-gated) |
| Flight targets unmeasurable / off-viewport | degraded legs (below) | At stamp if it happens, else on return |

## Choreography (~770ms natural / ~690ms skip; all beats overlay-only, list fully settled + interactive from frame 1)

- **Beat 0 — lift-off.** Natural: 90ms inhale using the engine's public `anticipation` param
  (sink ~2px, plates tuck, glow dims) — the window doubles as the post-layout target-measurement
  frame for the restored list. Skip: the panel dismisses on the tap frame; Beat 0 compresses to
  a single-frame coil from the last rendered BIT bounds (no perceived input lag — Codex).
- **Beat 1 — flight (~380ms).** Shallow banked quadratic arc bowed toward the right gutter
  (never crosses card title text). Asymmetric ease: `easeInCubic` first ~35% of the path
  (push-off), `easeOutCubic` after (glide). Scale tied to **path progress** (96→40px,
  perspective read). Face: rest→neutral wake at lift-off. Trail: **phosphor afterimages** — two
  ghost copies of BIT's own silhouette at ~40/80ms delay, alpha ≈0.22/0.10, cyan-cast, Beat-1
  only (the CRT idiom; the generic particle trail was cut by Codex as off-theme).
- **Beat 2 — corner seal (~120ms).** BIT (40px) lands on the finished card's **top-right
  corner** — a width-independent target that exists at every screen size (Codex killed the
  "beside CLEARED" spot with 320dp layout math). One 2px overshoot-settle of BIT only (the card
  never deforms). On contact: the card's StrobeFlash fires (**the single celebration effect** —
  amber sparks were cut per the salience count-dial) and BIT does a single `blink: true` — the
  engine's existing one-shot sign-of-life param (the pose-morph is 900ms, so a cheer-flip was
  infeasible without engine surgery; **no engine changes in v1** is a hard rule).
- **Beat 3 — frontier hop (~180ms).** Parabolic hop (up ~8px, over, down) into the frontier
  card's reserved BIT slot, 40→44px, `easeOut`, NO trail (slow leg). The slot stays reserved
  (invisible placeholder) during the flight so the landing shifts no layout. Overlay's final
  frame == the in-card BIT's rest position; same-frame swap; the in-card idle amplitude ramps
  0→0.55 over ~400ms (no-pop resume rule).
- **Soundtrack: zero new audio/haptics.** Natural: the existing restGoExercise chorus spans the
  sequence. Skip: the existing skip release covers lift-off.

## Contracts

- **Perceived readiness:** the list renders in its final state (statuses, warmth, enabled
  controls) on the first frame after rest ends; the flight is additive decoration above it.
- **Interruption:** the overlay is `IgnorePointer` + `ExcludeSemantics`. Any state-changing
  action — opening ANY exercise (incl. re-opening an old one), END EARLY, idle-timeout reveal,
  save/quit paths, app pause — calls `settleNow()`: overlay disposed, in-card BIT shown,
  pending celebration resolved per its path. Input never waits.
- **Stale targets (Codex):** origin measured synchronously at trigger (panel still mounted);
  card/slot targets measured only post-layout after the restored list reaches final geometry;
  each beat revalidates its target key's RenderBox — moved → retarget, gone/off-viewport → skip
  that leg; both gone → settle. Overlay works in its own local coordinates.
- **Single-owner celebration:** `_pendingCelebrationId` is set where `_restAfterFinish` is set
  (the finish pop), claimed exactly once by: the stamp callback (flight paths), the list-return
  consumer (no-flight paths), or the immediate final-exercise path. Re-opening the pending
  exercise clears it (celebration cancelled). All strobe bumps gate on `!_reduceMotion`.
- **No double BIT:** the in-card frontier BIT is suppressed (slot reserved, widget absent)
  while the flight owns BIT; restored on landing/settle.

## Files

- `app/lib/widgets/session_bit_flight.dart` — NEW: `SessionBitFlight` overlay (state machine,
  one controller, beats via Intervals, ghosts, settleNow), fully self-contained.
- `app/lib/widgets/rest_break_panel.dart` — add `bitKey` (origin measurement) + `onNaturalEnd`
  (fired in the existing live-finish branch, before `cancel()`).
- `app/lib/pages/Workout session/active_workout.dart` — pending-celebration owner, trigger
  wiring, `_reduceMotion` union getter, flight layer in a Stack over the body, frontier-slot
  reservation, settleNow hooks, idleAmp ramp wrapper.
- Tests: `app/test/active_workout_flight_test.dart` (taxonomy + contracts) + additions to the
  frontier test where behavior shifted.

## Test contract

1. Natural expiry (short `restSeconds`) → overlay flies, in-card BIT absent during flight,
   strobe trigger bumps exactly once at stamp, overlay gone + in-card BIT present after.
2. SKIP REST → panel gone on tap frame + flight runs; same single strobe bump.
3. Stale expiry (snapshot forced >3s past) → no overlay; strobe bumps once on return.
4. Reduced motion → no overlay, **no strobe bump**, warmth present.
5. Mid-flight tap on an exercise card → navigation happens, overlay settles, no strobe
   double-fire; re-opening the pending exercise cancels its celebration.
6. Final exercise → immediate strobe (no flight), still exactly once; RM variant silent.
7. No `pumpAndSettle` anywhere the hub is mounted (bounded pumps).

## Verification & named gap

`flutter analyze` 0; suite green minus the flaky env baseline; finish-time greps. **On-device
gap:** the flight's feel (arc/ease/ghost readability at DPR, the corner-seal legibility, chorus
sync) cannot be judged in this environment — needs the user's Android device.
