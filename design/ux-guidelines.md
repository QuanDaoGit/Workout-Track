# UX Guidelines — Ironbit

> Conventions for building coherent screens. Mirrors the root [CLAUDE.md](../CLAUDE.md) rules.

## Components
- Buttons: **`FilledButton`** only (theme styles it neon-on-dark). Never `ElevatedButton`.
- `ChoiceChip` selected state needs a manual `labelStyle` with `color: kBg` (M3 can't express
  different selected/unselected label colors natively).
- Cards/buttons: 4px radius (`kCardRadius`) throughout.
- Reusable arcade components live in `lib/widgets/`; micro-interactions in `lib/widgets/motion/`
  (hold-depress, phosphor-tap, ambient-drift).

## Icons
1. Pixel asset from `assets/icons/control/` when one exists.
2. Otherwise `Icons.xxx_sharp` (sharp variants only — angular edges match the pixel theme).
3. Never default rounded Material icons. Never mix rounded and sharp on one screen.
4. No `_sharp` variant for what you need? **Ask before using the default.**

## Motion
Use the token durations/curve (`kMotionFast/Base/Pop`, `easeOutCubic`). Micro-interactions should
feel tactile (depress on hold, phosphor flash on tap) but never block input.

## Interaction patterns worth preserving
- Suggested loads pre-fill Set 1 in `kMutedText` ("the app's guess"); tapping brightens to `kText`.
  Logging Set 1 copies its values into empty subsequent rows.
- Destructive actions (e.g. class respec) require explicit confirmation (type-to-confirm).
- `PopScope(canPop: false)` on the workout summary prevents accidental loss of an unsaved session.

## Review checklist (run on any UI change)
1. Theme coherence — only `tokens.dart` colors/fonts/radii.
2. Icons — sharp/pixel only, consistent within the screen.
3. Body-neutral — no good/bad color framing on metrics.
4. Capture a screenshot into `screenshots/` for the record.
