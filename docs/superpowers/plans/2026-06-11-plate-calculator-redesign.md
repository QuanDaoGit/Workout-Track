# Plate Calculator Redesign — Design Spec

**Date:** 2026-06-11
**Status:** Approved
**Surface:** `lib/widgets/plate_calculator_sheet.dart` (+ its widget test)

## Critique findings

- No animation anywhere in the chrome: the mode toggle flips color instantly, the mode body is
  a hard content swap, the sheet height jumps, the TOTAL snaps.
- The forward-mode barbell is decorative — plates carry no weights, so the long breakdown
  sentence (`45 lbs + 10 lbs = 55 lbs per side`) is both the noisiest line and the only
  informative one.
- The empty reverse-mode bar (bar + centered sleeve, no plates) reads as a Material slider.
- Label noise: `LOAD PER SIDE`, `ON THE BAR`, and a shouting `TAP TO ADD (PER SIDE)` header.
- The two modes don't share a visual skeleton, so switching feels like two different tools.

## Decisions (locked in brainstorming)

1. **Labeled plates (Option A):** chunkier plates with the weight printed vertically inside.
   Self-describing bar in both modes; kills the breakdown sentence; plates become real tap
   targets in reverse mode. (Rejected: compact count line, tiny labels under plates.)
2. **Full motion package:** sliding toggle thumb, body cross-fade + height easing, TOTAL pulse,
   PhosphorTap on small controls. APPLY / USE WEIGHT stay stock `FilledButton` for app-wide
   consistency.

## Design

### Layout

- **Plates:** width ≈ 16 + fraction × 6, height ≈ 40 + fraction × 34, weight rendered
  vertically inside (RotatedBox, ShareTechMono ~9, kNeon). Same visual in both modes.
- **Forward:** TARGET + BAR row → barbell with labeled plates → muted caption
  `55 lbs per side` → APPLY. The `LOAD PER SIDE` header and breakdown sentence are deleted;
  the cannot-load / below-bar / empty hints remain.
- **Reverse:** BAR half-width with CLEAR right-aligned in the same row (visible only with a
  non-empty effective stack) → quiet ShareTechMono `TAP TO ADD · PER SIDE` header → chips →
  barbell → `tap a plate to remove it` hint (plates present only) → TOTAL → USE WEIGHT.
  `ON THE BAR` is deleted.
- **Ghost slots:** with zero plates the reverse bar renders one dashed plate outline per side
  beside the sleeve (custom dashed-RRect painter, kBorder) so it stops reading as a slider.

### Motion

- **Toggle:** single bordered track; an `AnimatedAlign` neon thumb slides between halves
  (`kMotionPop`, `kMotionCurve`); labels cross-fade color via `AnimatedDefaultTextStyle`;
  halves are `PhosphorTap`s.
- **Body swap:** `ClipRect > AnimatedSize > AnimatedSwitcher` (`kMotionBase`), fade + small
  horizontal slide in the direction of travel.
- **TOTAL pulse:** number keyed by value, scale 1.12 → 1.0 over `kMotionFast` on each change.
- **Reduced motion:** all of the above collapse to instant; plate add/remove animations keep
  their existing behavior.

## Out of scope

- APPLY / USE WEIGHT custom press treatment.
- Any change to the solver, return-value contract, or the exercise-session call site.

## Testing

Update stale finders (`LOAD PER SIDE` gone; forward marker = TARGET field / per-side caption);
assert plate labels render on the bar (scoped to the barbell subtree — chips share the text);
assert ghost slots in empty reverse mode; all existing behavior tests (add/remove/CLEAR/USE
WEIGHT/APPLY/lb/reduced-motion) stay green.

## Verification

`flutter analyze` zero issues; `flutter test` full suite green; on-device: thumb slides, bodies
cross-fade with smooth height change, plates show weights, no sentence in forward mode, ghost
slots when empty, TOTAL pulses, halos on CLEAR/toggle; instant under reduced motion.
