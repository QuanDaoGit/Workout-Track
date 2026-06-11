# design/ — Agent operating brief

You are working in **design**: visual identity, UX conventions, and design references for Ironbit's
pixel-arcade world. This folder *documents and references* design; the **implementation truth is
[lib/theme/tokens.dart](../lib/theme/tokens.dart)** — never fork the palette here.

## Purpose
Keep the visual/UX rules in one readable place, store screenshots and visual audits, and brief any
agent doing UI work so screens stay coherent.

## What lives here
- `brand.md` — identity: palette, fonts, the arcade aesthetic, class colors. Points to `tokens.dart`.
- `ux-guidelines.md` — component, icon, motion, and interaction conventions.
- `screenshots/` — UI screenshots and visual-audit captures (e.g. the migrated `ui_audit_*`).

## Non-negotiable design rules (mirrored from the root CLAUDE.md)
- **Palette:** import [lib/theme/tokens.dart](../lib/theme/tokens.dart). Never hard-code hex.
  `kBg 0xFF11111F`, `kCard 0xFF1C1C34`, `kBorder 0xFF36365E`, `kNeon 0xFF00FF9C`,
  `kText 0xFFE8E8FF`, `kMutedText 0xFF9494B8`, `kAmber 0xFFFFD700`, `kCyan 0xFF00BFFF`, `kDanger 0xFFFF2D55`.
- **Fonts:** PressStart2P (headings), Gotham (body), `AppFonts.shareTechMono()` (mono).
- **Shape:** 4px radius (`kCardRadius`) everywhere. `FilledButton` only (never `ElevatedButton`).
- **Icons:** sharp variants only (`Icons.xxx_sharp`); prefer pixel assets in `assets/icons/control/`.
  Never mix rounded and sharp on one screen. If no `_sharp` exists, ask before using a default.
- **Body-neutral:** no red/green good-bad on weight/deltas; muted directional indicators only.
- **Class colors:** Assassin `0xFFB14DFF` (violet), Bruiser `0xFFFF2D55` (red), Tank `0xFF00BFFF` (blue).

## Common tasks
- *Review a screen* → check against `ux-guidelines.md` + the rules above; capture before/after into `screenshots/`.
- *Add a token* → it goes in `lib/theme/tokens.dart` first, then document it in `brand.md`.

## Do NOT
- Introduce a color/font/radius that isn't in `tokens.dart`.
- Keep design screenshots scattered at the repo root — they belong in `screenshots/`.
