# Ironbit surface playbooks — the common screen types

The primitive inventory tells you *what* to reach for; this tells you *how the app builds the bigger
surface types*, so you don't copy an unrelated screen or fall back to Material. Each section: the
approved primitives, the forbidden defaults, the accessibility must-haves, and **one canonical
existing surface to read** before you build. Always confirm the canonical file still exists (glob) —
this is a map, not a guarantee.

## Forms & validation (weight/reps, settings, name entry)
- **Reach for:** the arcade inputs (`widgets/motion/arcade_text_field`, `arcade_name_field`),
  `ArcadeChip`/`ChoiceChip` for selects, `FilledButton`/`PixelButton` to submit; a row pattern like
  Profile's `_SettingsRow`/`_SettingsToggleRow` for option lists.
- **Voice/feel:** the app's "guess" idiom — a suggested value pre-fills in `kMutedText` and brightens
  to `kText` on touch (suggested loads). Validate on blur / at submit, error near the field in
  `kDanger` with a recovery path; never placeholder-only labels.
- **Forbidden:** stock `TextField` with Material underline, `DropdownButton`, validation only at the
  top.
- **A11y:** label every field; numeric fields use the right keyboard; mono for the numbers.
- **Read first:** `lib/pages/Workout session/exercise_session.dart` (set logging) or `profile_page.dart`
  settings rows.

## Lists & long scrolls (history, exercise picker, loot)
- **Reach for:** `ListView.builder` (lazy by default) for long/unbounded lists; the app's card row
  patterns; `arcade_chip` filters; `pixel_loader` while the page loads.
- **Forbidden:** building a giant `Column` of 100+ children; a stock `RefreshIndicator` spinner.
- **A11y/perf:** keep row build cheap; reserve space so content doesn't jump; one primary tap target
  per row with a ≥44px height.
- **Read first:** `workout_page.dart` (the Logs list) and the exercise picker in `start_workout.dart`.

## Charts & data-viz (stats, volume, body-weight trend)
- **Reach for:** `fl_chart` (already a dependency) styled with tokens — neon/cyan/amber lines on
  `kBg`, `kBorder` gridlines, mono axis labels, `kMutedText` ticks. The radar stat chart is the house
  style.
- **Body-neutral:** no red/green good-bad encoding; trend lines are muted, the *number* is honest
  (EWMA trend, not noisy raw). Direction is data, never judgment.
- **Forbidden:** default fl_chart colors, gradient fills that obscure data, pie charts for >5
  categories, color-only series distinction.
- **A11y:** every chart needs a text/`Semantics` summary of its key insight; interactive points ≥44px.
- **Read first:** the radar stat surface and the body-weight trend in `workout_page.dart`.

## Tables / dense data
- Prefer **stacked rows or a compact 2-column grid** over a true scrolling table on a phone; mono for
  aligned numbers; `kBorder` hairlines; one accent column max. If genuinely tabular, fixed column
  widths so cells don't reflow. Forbidden: a wide horizontally-scrolling Material `DataTable`.

## Dialogs & bottom sheets
- **Reach for:** the themed `AlertDialog` shape (kCard bg, 4px radius, an accent `BorderSide`,
  PressStart2P title, `arcade_dialog_button_column` / a `TextButton` + `PixelButton` action pair);
  `showModalBottomSheet` with a token background + a strong scrim. Confirm dialogs name the act and
  label both buttons (`NOT YET` / `LET'S GO`); destructive ones use `kDanger` and type-to-confirm for
  the irreversible.
- **Forbidden:** a default Material dialog (rounded, M3 colors), OK/Cancel labels.
- **A11y:** a clear dismiss/escape; `PopScope` to guard unsaved work; focus the primary action.
- **Read first:** `showStartWorkoutConfirmDialog` in `start_workout.dart`; `idle_session_dialog.dart`.

## Onboarding & multi-step flows
- One concept per screen, cinematic but skippable; carry the same primary action placement across
  steps; a clear back/escape; create the character/state at the committing step, not before. Reduced
  motion must still let the flow complete (reveals skip to their end). **Read first:** the
  `lib/pages/onboarding/` sequence.

## Navigation & IA
- Bottom-nav destinations are top-level only; the center Train is the verb. Keep the primary action
  reachable and consistent; migrate off positional indices to a **semantic destination** API before
  remapping; re-run reloads + re-arm idle/expired reveals on pop from a pushed page. **Read first:**
  `root_page.dart` and `docs/superpowers/plans/2026-06-13-app-area-restructure-ia.md`.

## The loading / empty / error trio (design all three, every data surface)
- **Loading:** `pixel_loader`, space reserved.
- **Empty:** in-world, calm — what it is, why it's empty, the one action ("No expedition is going on" /
  "Do a workout to earn a charge"). Consider a *preview of what awaits* over a bare message (the guild
  forge-bench).
- **Error:** cause + recovery; never a dead/blank surface.

## A brand-new screen type (no close precedent)
When nothing in the app matches, don't invent a new visual language — **derive** from the closest
*primitives*: token surfaces + `neonGlow`, 4px/pixel geometry, PressStart2P labels + mono numbers +
Gotham body, sharp/pixel icons, `arcade_route` transitions, motion from `motion.md`, and the soul
hook it serves. Sketch the loading/empty/error states up front. The dioramas, the avatar, and the
keycap were all "new" and all unmistakably Ironbit because they derived from the language, not a
catalog.
