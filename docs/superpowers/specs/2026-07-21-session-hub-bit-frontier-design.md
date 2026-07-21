# Session hub — "BIT rides the session" (frontier companion + cleared warmth + all-clear dock)

- **Date:** 2026-07-21
- **Status:** Approved design (user picked Option A from a three-option mock); spec pending user review
- **Scope:** `ActiveWorkoutPage` (the session hub) ONLY. The set-logging screen and the rest takeover
  are explicitly out of scope.
- **Pipeline:** brainstorming → wide research pass (Standard tier, token-frugal) → combined Codex
  adversarial review of evidence + opinion (*needs-attention*, 5 findings, all folded in) → this spec.

## Problem

The session hub is the mid-workout anchor screen and it reads "empty, kinda sad, kinda 1 color":
a header card + a flat exercise list + a disabled button, everything neon-on-dark, with dead space
below. Users are here while fatigued. The user directive: make it livelier **through BIT woven into
the session's mechanics** — not a pasted mascot with dialogue — subtle, non-distracting, not a new
feature.

## Evidence base (summary — full trail in the conversation + insights.md entry to follow)

- **Companion presence works when RESPONSIVE, never as a comparator.** Köhler motivation-gain with
  software partners is meta-analytically real, but a fixed non-responsive ghost partner produced a
  null result, and pace/comparison pressure violates the anti-guilt doctrine (settled in the guild
  research: BIT is never a pace-partner). BIT must be a **witness that reacts to what the user did**.
- **Fatigued attention is glance-only.** Association/dissociation research: past a fatigue threshold
  attention is captured interoceptively; required cognition mid-workout is hostile. Anything added
  must be readable in zero words.
- **Aliveness = reactivity, not existence** (game-companion craft + the Haptic Creature finding: the
  *animated* robot, not mere presence, produced effects). BIT's established idle (sub-pixel float +
  plate breathing) + state-reactive mood is the mechanism.
- **Clippy family (contrary, load-bearing):** an agent fails when overeager/interrupting/chatty →
  BIT is reactive-only, never proactive, nothing modal, zero new taps.
- **Between-sets competitor consensus (contrary, load-bearing):** lifters resent mid-workout
  distraction → the utilitarian core (list, statuses, finish) keeps identical function and tap cost.
- **Goal-gradient:** motivation rises near the goal; the carrier here is the companion's position and
  mood, not another progress bar.
- **Honest gap `[assumption]`:** no direct evidence for a companion on a *tracker* mid-session, and
  no long-horizon novelty-decay research. Mitigations: BIT already lives mid-session on every rest
  takeover (in-product precedent), the change is presentation-only (trivially removable), the idle is
  calm-only with a single once-per-session event state, and the pre-launch prototype gate is the
  product owner's on-device sign-off.

## Codex findings → resolutions

| # | Finding (severity) | Resolution in this design |
|---|---|---|
| 1 | No direct companion-on-tracker evidence; novelty-decay unknown (high) | Tagged `[assumption]`; presentation-layer only; on-device sign-off is the prototype gate; calm idle only. |
| 2 | Frontier underspecified for out-of-order use (high) | Deterministic frontier state machine below; identical to the existing NEXT semantics; calm pose, no beckoning. |
| 3 | Left gutter steals width on the failure-prone layout (med) | Gutter + rail **cut**. BIT lives inside the single frontier card; narrow-width + large-text acceptance criteria below. |
| 4 | All-clear travel beat conflicts with motion doctrine (med) | Travel **cut**. BIT appears statically docked; the final card's existing StrobeFlash is the flash beat. |
| 5 | Rail duplicates the progress bar (med) | Rail **cut**. Progress stays the header bar's job. |

## Design

### 1. Frontier BIT (the companion rides the list)

A small faced `BitMoodCore` sits as the **leading element inside the frontier exercise card** —
the first exercise in list order whose status is not `done`. It is the exact "next" concept the
rest panel's `NEXT · <name>` line already uses, derived from one shared getter so the two can
never disagree.

- **Widget:** `BitMoodCore(pose: BitPose.neutral, reveal: 1, size: 44, idleAmp: 0.55)` —
  `reveal: 1` is mandatory (the constructor defaults to faceless; the learnings file's
  progressive-disclosure trap) and pinned by a widget test. `idleAmp: 0.55` is the quest-board
  header's damped value (`quests_page.dart:417`) — a calm presence, not a bouncing one.
- **Layout:** leading in the card's existing `Row`, `kSpace2` gap to the text column. Only the
  frontier card pays any width. Name text keeps its existing 2-line ellipsis behavior.
- **Reactivity:** the card's status text (READY amber / ACTIVE cyan) is untouched; BIT's presence
  IS the frontier marker. Mood stays `neutral` — company, not command (anti-guilt: no pointing,
  no beckoning, no glow-pulse).

### 2. Cleared-card warmth (banked work stays lit)

A `done` exercise card swaps its border and gains a faint wash so finished work reads as banked
energy instead of going inert:

- Border: `kNeon.withValues(alpha: 0.38)` (quiet — well below the action-neon of the enabled
  Finish button; colour-hierarchy discipline: this is a receded state, not an accent).
- Background wash: `kNeon.withValues(alpha: 0.05)` over `kCard`.
- The existing ✓ + CLEARED status text and the on-clear `StrobeFlash` are unchanged.

### 3. All-clear dock (the goal-gradient peak)

Finishing the last exercise suppresses rest (existing behavior), so the list is immediately
visible. In that state there is no frontier — BIT appears **statically docked, centered, between
the list and the Finish Workout button**: `BitMoodCore(pose: BitPose.cheer, reveal: 1, size: 56)`.
The cheer pose carries its own amber register (reward semantics); the enabled neon Finish button
stays the single action accent. No travel animation, no extra glow, no new sounds/haptics — the
final card's StrobeFlash plus the button enabling are the event; BIT's cheer is the witness.

### 4. Hard boundaries

- **Wordless.** No speech bubble, no copy on the hub (the rest panel owns mid-session voice).
- **Zero new taps, zero function changes** to header, timer, cards, statuses, or Finish.
- **No new haptics or sounds.**
- **Rest takeover:** the list (and with it the hub BIT) is structurally unmounted while the
  `RestBreakPanel` shows — its big rest-pose BIT is the only BIT on screen. Never two.
- **Reduced motion:** `BitMoodCore` internally renders a still home under `disableAnimations`;
  positions are already instant (no travel exists). No further gating needed; a reduced-motion
  widget test proves BIT renders still and legible.
- **Large text:** the frontier BIT is omitted from the card when
  `MediaQuery.textScalerOf(context).scale(14) >= 14 * 1.3` (the card reverts to today's
  full-width layout — legibility outranks charm). The all-clear dock sits in its own vertical
  slot and shows at all scales.
- **Decorative semantics:** BIT (both placements) is wrapped in `ExcludeSemantics`. The status
  texts remain the assistive-tech carrier; the screen's semantics are byte-identical to today.

## Frontier state machine (Codex F2)

| Situation | BIT position |
|---|---|
| Fresh session | First exercise card |
| First N cleared, in order | First non-`done` card |
| User works out of order (e.g. clears #3 first) | Still the first non-`done` card (#1) — same signal the rest panel's NEXT line already gives; calm neutral pose keeps it company-not-command |
| Exercise opened + backed out with partial sets (`inProgress`) | No special case — it is the frontier iff it is the first non-`done` |
| Rest takeover active | List unmounted → no hub BIT |
| All cleared (`_allDone`) | Dock (cheer) above Finish |
| Resume from checkpoint | Same rules over the restored statuses |

The frontier id derives from one new getter beside `_nextUndoneExerciseName` (or that getter is
refactored to expose the exercise, consumed by both) — one source of truth.

## Non-goals (rejected on evidence)

Telemetry/body-map hub (fatigue cognition), pure ambience pass (doesn't answer "empty/sad"),
BIT dialogue on the hub (user directive + Clippy), BIT as pace partner (ghost-null + anti-guilt),
route rail + travel animation (Codex F3/F4/F5).

## Files

- `app/lib/pages/Workout session/active_workout.dart` — frontier getter, card leading BIT,
  cleared-card decoration, all-clear dock. All additions private to the page.
- New test file `app/test/active_workout_bit_frontier_test.dart` (+ one assertion in
  `active_workout_rest_panel_test.dart`: exactly one `BitMoodCore` during the takeover).
- Docs at implement time: `docs/PRD.md` shipped entry, `CLAUDE.md` session-flow row,
  `research/insights.md` dated entry (findings + the `[assumption]` tag).

## Test contract

1. Frontier BIT present exactly once, hosted in the first non-`done` card; `reveal == 1` and
   `pose == neutral` pinned.
2. Frontier advances: page built with a `resumeFromSession` marking exercise 1 done → BIT on
   exercise 2's card.
3. All-done resume → no BIT in any card; dock `BitMoodCore` with `pose == cheer` present;
   Finish enabled.
4. Cleared card border/wash asserted on a `done` card's `DecoratedBox`.
5. `textScale 1.3` MediaQuery override → no frontier BIT; card layout intact (no overflow at
   320 dp width).
6. Reduced-motion pump → BIT still present (static) with unchanged semantics.
7. Rest takeover → exactly one `BitMoodCore` (the rest panel's).
8. Existing suites stay green; `flutter analyze` zero issues.

Harness notes (from learnings): the page owns a 1 s periodic timer — bounded `pump`s, never
`pumpAndSettle`; follow the existing `active_workout_*_test.dart` harness; multiple scenarios per
file are fine for this page (the one-per-file rule is the HomePage/KeyedLock hazard).

## Verification & the named gap

`flutter analyze` 0 issues; full `flutter test` (baseline env failures excepted); the finish-time
audit greps over changed files; two page goldens (mid-session + all-clear) as the rendered
artifact, plus a live web capture if the harness cooperates. **Blocking on-device gap:** the feel
of the idle at 44 px inside a card, and whether the cleared-wash reads at real brightness, need
the user's Android device sign-off — this environment cannot render device-true pixels.
