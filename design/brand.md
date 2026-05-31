# Brand & Visual Identity — Ironbit

> Documentation layer. The machine-readable source of truth is
> [../lib/theme/tokens.dart](../lib/theme/tokens.dart). If this drifts from that, the code wins.

## Aesthetic
Pixel arcade, **dark mode only**. Neon-on-near-black. Sharp 4px corners, monospaced counters,
PressStart2P headings. The feel: a retro RPG/arcade cabinet, earned and a little gritty — not glossy.

## Palette (tokens)
| Token | Hex | Use |
|---|---|---|
| `kBg` | `0xFF11111F` | App background |
| `kCard` | `0xFF1C1C34` | Card/surface |
| `kBorder` | `0xFF36365E` | Borders |
| `kNeon` | `0xFF00FF9C` | Primary accent / FilledButton |
| `kText` | `0xFFE8E8FF` | Primary text |
| `kMutedText` | `0xFF9494B8` | Secondary/muted text, suggestions |
| `kAmber` | `0xFFFFD700` | Highlights / rewards |
| `kCyan` | `0xFF00BFFF` | Secondary accent |
| `kDanger` | `0xFFFF2D55` | Destructive / warnings |

## Class colors
Assassin `0xFF4DE5FF` (cyan) · Bruiser `0xFFFFD700` (gold) · Tank `0xFFFF2D55` (red) ·
Vanguard `0xFFB14DFF` (violet).

## Typography
- **PressStart2P** — headings (`headlineSmall`, `titleLarge`, AppBar).
- **Gotham** — body (everything else).
- **`AppFonts.shareTechMono()`** — monospaced timers/counters (local font, not GoogleFonts).

## Shape & motion
- Radius 4px (`kCardRadius`). Primary card border `1.2` (`kPrimaryCardBorderWidth`).
- Motion: `kMotionFast` 120ms, `kMotionBase` 180ms, `kMotionPop` 220ms, curve `easeOutCubic`.
- `neonGlow()` for accent box shadows.

## Body-neutral mandate
No red/green good-bad framing on bodyweight or deltas. Directional change is shown with muted
indicators only — absence of a bonus is simply absence, never "failure."
