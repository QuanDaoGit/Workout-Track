# Ironbit design system — the visual truth + the inventory to reach for

> **`lib/theme/tokens.dart` is the source of truth.** Hex, spacing, radius, and motion constants live
> there; if this file ever disagrees, the code wins. Read it at the start of visual work.

This file is the language, not a template library. It tells you *what the building blocks are and what
each is for* so you can compose. It deliberately contains **no paste-in component code** — copying a
finished widget out of a reference is how things drift and go stale. Read the actual widget and the
nearest existing surface instead.

## Palette (tokens)
| Token | Hex | Use |
|---|---|---|
| `kBg` | `0xFF11111F` | App background (near-black navy) |
| `kCard` | `0xFF1C1C34` | Card / surface |
| `kBorder` | `0xFF36365E` | Borders, dividers |
| `kNeon` | `0xFF00FF9C` | Primary accent, `FilledButton`, "go"/ready |
| `kText` | `0xFFE8E8FF` | Primary text |
| `kMutedText` | `0xFF9494B8` | Secondary/muted text, the app's "guesses" (suggested loads) |
| `kAmber` | `0xFFFFD700` | Rewards, gems, highlights |
| `kCyan` | `0xFF00BFFF` | Secondary accent |
| `kDanger` | `0xFFFF2D55` | Destructive / warning |

**Class colors** (match each class's art): Assassin `0xFFB14DFF` (violet) · Bruiser `0xFFFF2D55`
(red) · Tank `0xFF00BFFF` (blue). Use the class color where a surface is class-specific.

Other useful tokens to look up rather than guess: `kSpace1..kSpace5` (4/8/12/16/24), `kCardRadius`
(4), `kButtonHeight` (48), `kPrimaryCardBorderWidth` (1.2), `kSurface2`, `kCardPadding`,
`kMotionFast/Base/Pop`, and the `neonGlow({color, opacity, blur})` helper. There is also
`ChoiceChip`'s quirk: selected state needs a manual `labelStyle` with `color: kBg` (M3 can't express
different selected/unselected label colors natively).

**Color discipline (the finish-time audit enforces this).** Raw color literals live *only* in
`tokens.dart`. In every other file, import a token; for a lighter/darker variant use
`token.withValues(alpha: …)` — **never** a raw `Color(0x..)`, `Color.fromARGB`/`fromRGBO`,
`.withOpacity`, a `Colors.*` (only `Colors.transparent` is allowed), `Theme.of(context).colorScheme`,
or `CupertinoColors`. A raw-hex tint of neon is still raw hex; it drifts the instant the token changes. If
you genuinely need a shade no token provides, **add a shared token to `tokens.dart`** rather than
inlining a literal or inventing a local constant. Likewise, never guess a token name or a helper's
parameters — grep the definition (`neonGlow`'s real signature is `{color, opacity, blur}`).

## Typography
- **PressStart2P** — headings, AppBar titles, and short ALL-CAPS labels. It's a chunky pixel font, so
  it's used at **small sizes** (≈7–12px for labels, up to ~18 for titles) and with generous
  `letterSpacing`/`height`. Never for paragraphs.
- **Gotham** — body and everything conversational.
- **`AppFonts.shareTechMono()`** — monospaced, for timers, counters, set/rep numbers, anything numeric
  that changes (tabular figures prevent layout shift). It's a local font helper, *not* GoogleFonts.

## Shape
- **4px corners (`kCardRadius`) everywhere.** No rounded pills, no circles. The roundness of a default
  Material component is a foreign tell (see `learnings.md`).
- For a distinctive raised/special element, use a **pixel-staircase cut-corner** geometry (a stepped
  chamfer, e.g. 2 steps of ~4px) drawn with `isAntiAlias = false` so the steps stay crisp — see the
  center Train keycap (`lib/widgets/train_nav_button.dart`) for the canonical example.
- Borders are hairline `kBorder`; primary cards use `kPrimaryCardBorderWidth` (1.2) in the accent.

## Icons
1. **Pixel asset** from `assets/icons/control/` when one exists (`ImageIcon(AssetImage(...))`, tint
   with a token).
2. else **`Icons.xxx_sharp`** — sharp variants only; their angular edges match the pixel theme.
3. **Never** default rounded Material icons; **never** mix rounded + sharp on one screen; **no emoji**
   as icons. If no `_sharp` variant exists for what you need, **ask** before using a default.

## Buttons & inputs
- **`FilledButton`** is the themed primary (neon fill, dark label) — use it, never `ElevatedButton`.
- **`PixelButton`** (`lib/widgets/pixel_button.dart`) is the chunky arcade CTA (the big START button).
- Text-style secondary actions use a muted `TextButton` (see the mission card's "Manual workout").
- Inputs: the arcade text fields in `lib/widgets/motion/` (`arcade_text_field`, `arcade_name_field`)
  carry the themed focus treatment — prefer them over a bare `TextField`.

## The primitive inventory (reach for these before building new)
**Glob `lib/widgets/` and `lib/widgets/motion/` for the current set** — this list is a map of intent,
not exhaustive, and will grow. Read the widget's doc-comment before using it.

Motion / micro-interaction wrappers (`lib/widgets/motion/`):
- `hold_depress` — press-down depress for tactile buttons/cards.
- `phosphor_tap` — a CRT phosphor flash on tap.
- `ambient_drift` — slow ambient particle drift (low-salience "alive" surfaces).
- `power_on` — a CRT power-on reveal.
- `focus_frame` — an animated focus bezel.
- `arcade_text_field` / `arcade_name_field` — themed inputs.

Structure / surface widgets (`lib/widgets/`, representative):
- `pixel_button`, `arcade_chip`, `arcade_progress_bar` — core controls.
- `arcade_route` — the app's page-transition routes (`ArcadeRouteMotion.flow/fade/reveal`); use these,
  not bare `MaterialPageRoute`, so transitions stay in-language.
- `arcade_dialog_button_column` — the dialog action stack.
- `pixel_loader` — the loading indicator (use instead of a stock spinner).
- `neonGlow()` (in `tokens.dart`) — accent box-shadows.
- Identity surfaces: `IronbitAvatar` (procedural pixel face), `loot_avatar_frame`, and the
  class/rank/title widgets — reach for these wherever ownership can be reinforced.

When nothing fits, paint bespoke (`CustomPainter`) — but in the language: tokens-only color, pixel
geometry, `isAntiAlias=false` for crisp edges, motion from `references/motion.md`. The Adventure
dioramas, the avatar, and the Train keycap are all bespoke and all unmistakably Ironbit.
