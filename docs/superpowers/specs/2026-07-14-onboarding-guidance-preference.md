# Onboarding "Workout guidance" step — surface Simple Mode with an experience-derived default

Date: 2026-07-14 · Status: **as-built** · Pipeline: `/deep-feature` (+ `/research`; `ironbit-design`
for the card/preview; Codex adversarial review of the plan). Extends the shipped `SimpleModeService`
(insights.md 2026-06-28) — does **not** re-open the "don't fork the app" doctrine.

## Intent
Let a new user choose, during onboarding, how much pre-workout guidance they get — which simply flips
the **existing** Simple Mode on/off (no new key, no new stripping). Smart default from self-reported
experience; still changeable in Settings; a lightweight preview so the choice is informed.

## Decisions (user-confirmed)
- **Host:** embedded in the existing `RemindersPrimerPage` (not a new screen) — the single mandatory
  funnel every new user passes through.
- **Default:** `simpleModeDefaultForExperience(exp)` → intermediate/advanced = **Compact** (Simple Mode
  ON); novice/beginner = **Extra suggestions** (OFF). (Same two-tier cut as the reel gate, inverted.)
- **Labels:** **Compact** / **Extra suggestions** — behavior-framed (content density), not skill
  ("Simple/Advanced" reads as a competence ranking — research).
- **Scope:** Simple Mode exactly as-is (warm-up card + TRY prompts + curated first-run loadout). The
  step only toggles it — nothing added to what it strips.
- **Preview:** a tappable "SEE THE DIFFERENCE" that reveals a static mock workout card swapping between
  the two states (mirrors the real `_WarmupCard` "W"/"Warm up" chip + `_TryLine` "TRY:" chip).

## Research (why these choices) — reused + extended insights.md 2026-06-28
- **Not a mode fork; a reversible preference.** Tesler's Law / NN/g Modes: a mode needs a distinct
  prolonged task + persistent state, else hidden-state + double-maintenance. It writes the one key
  Settings owns; the RPG layer is never stripped.
- **Derive → pre-fill → show → let them nudge** (not a silent default, not a blank forced choice).
  A visible pre-filled default keeps the default's pull while preserving the commitment a silent
  switch forfeits (enhanced-active-choice). Self-reported experience is a **weak prior** → the
  guardrail is easy visible reversal, not a load-bearing branch.
- **Lightweight, user-triggered preview**, text-first; "change anytime in Settings" does most of the
  anxiety reduction. A heavy side-by-side would add drop-off for a low-stakes reversible toggle.

## Codex adversarial review (plan) → resolutions
| # | Finding | Resolution |
|---|---------|-----------|
| F1 (high) | Seeding Compact at the NameScreen commit persists a first-workout reduction **before the card is shown** (hidden state) | Dropped the NameScreen seed. Persist **only when the guidance card is displayed** (`initState` post-frame) + on every flip. Kill-before-display fails **safe → OFF**. |
| F2 (high) | Deriving the shown value from `exp` while the store holds another can show one / store another | `SimpleModeService` is the single source of truth: every visible change writes, so shown == stored. Flow also blocks recreation (`PopScope(canPop:false)` + `pushReplacement` + onboarding-complete-at-NameScreen). |
| F3 (high) | Defaulting **intermediate** to Compact is aggressive (weak prior; experienced tolerate *more* richness) | **Kept** (explicit user instruction outranks research) — de-risked by F1/F2: visible, one-tap-reversible, fail-safe-OFF pre-selection. Flagged, not overridden. |
| F4 (med) | Guidance + notification on one screen makes NOT NOW ambiguous | Guidance is a self-contained titled card committed by its **own** radio options; TURN ON / NOT NOW stay purely the notification decision (pinned footer, top divider). |

## Files
- `lib/services/simple_mode_service.dart` — `simpleModeDefaultForExperience(Experience)` pure helper.
- `lib/pages/onboarding/reminders_primer_page.dart` — the `_GuidanceCard` (radio `_GuidanceOption`s,
  `_SeeDifferenceToggle`, `_GuidancePreview` → `_PreviewWorkoutCard`/`_PreviewWarmup`/`_PreviewTry`/
  `_PreviewSetRow`); `initState` persist-on-display; `_setCompact`/`_togglePreview`; layout refactored
  to a scrolling content area + pinned reminder footer. **No** NameScreen change.

## Verification
- `flutter analyze` — 0 issues (full project). Finish-time audit: 0 off-brand hits, all icons sharp,
  all taps via `HoldDepress` (selection tick fired once on change).
- Tests: `simple_mode_test` (+`simpleModeDefaultForExperience`), new `reminders_primer_test`
  (preselect per tier · seed-on-display · flip persists both ways · preview reveal + swap · reminder
  actions coexist), `name_screen_test` / `gift_reveal_screen_test` / `charge_ritual_*` /
  `onboarding_*` / `tap_haptic_coverage_test` — all green.
- Rendered artifact: `test/audit/reminders_primer_frames_test.dart` → `_shots/primer_{compact,extra,
  preview_extra,preview_compact}.png` (under `--update-goldens`), eyeballed on the 390-wide render.

## Residual on-device sign-off
- The reduced-motion still-vs-`AnimatedSize` preview reveal + the selection haptic feel want a device
  glance; the render was verified in the golden harness (fonts real, no live device here).
