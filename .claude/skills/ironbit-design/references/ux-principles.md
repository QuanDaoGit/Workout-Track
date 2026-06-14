# Ironbit UX principles — the transferable laws, the voice, and critique

The generic UX catalogs are mostly noise for this app (web breakpoints, font-pairing menus, palette
pickers), but a core of **genuinely transferable laws** survives. They're recast here for a
pixel-arcade Flutter app. Everything below is expressed in *Ironbit's* idiom — hold the law, keep the
language.

## Accessibility & interaction (the non-negotiables)
- **Touch ≥ 44px** hit area; expand beyond a small visual with `hitSlop`/padding.
- **Contrast by luminance, not vibe.** Body text ≥ 4.5:1. On a *bright* fill (e.g. the neon keycap)
  legibility needs **dark-on-bright**, not a pale tint — a near-white speck on neon disappears. Two
  bright colors of different hue still have low luminance contrast.
- **Color is never the only signal.** Pair it with an icon, a label, or shape. (And per the
  body-neutral mandate, never red/green good-bad on bodyweight/deltas — muted directional only.)
- **Reduced motion → a still, legible fallback** (label/state/Semantics), never a dead control.
- **Semantics labels** on icon-only and custom-painted controls (`Semantics(button: true, label: …)`)
  so the state is announced; mode changes (idle/armed/live) should change the label too.
- **Dynamic type / no truncation traps.** Prefer wrap over clip; PressStart2P is wide, so size labels
  to fit and `maxLines`/`ellipsis` gracefully rather than overflowing the bar.

## Hierarchy, layout, state
- **One primary action per surface.** Secondary actions are visually subordinate (muted `TextButton`,
  smaller, lower). If a screen has two equally-loud CTAs, that's a bug.
- **Hierarchy via size, spacing, and contrast** — not color alone. Whitespace groups related items and
  separates sections; don't stack redundant bands that restate each other (fold a cue onto its
  element instead of adding a label strip).
- **State legibility:** pressed / disabled / selected / loading each visibly distinct and on-style.
  Disabled = reduced emphasis + no action (and ideally can't even *look* armed — gate the lure on
  validity). Press feedback must not shift layout.
- **Numbers use `shareTechMono`** (tabular) so counters/timers don't reflow as digits change.
- **Safe areas**: fixed bars (the nav, CTA bars) respect top/bottom insets; scroll content isn't
  hidden behind them.

## State screens — empty / error / loading
- **Empty:** say what this is, why it's empty, and the one action to fill it — in-world, calm. (e.g.
  "No expedition is going on" / "Do a workout to earn a charge.") Never a blank surface.
- **Loading:** use `pixel_loader`, not a stock spinner; reserve space so content doesn't jump in.
- **Error / destructive:** state cause + recovery; confirm destructive actions (type-to-confirm for
  the irreversible ones like class respec; a simple confirm for "discard session"). `PopScope` guards
  unsaved sessions.

## Navigation discipline
- Bottom nav is for top-level destinations only; keep the primary action reachable and consistent
  across screens. Back is predictable and preserves state. Don't use a modal as a primary nav path.
- A persistent action (the center Train) carries its state across the shell (idle → armed → live) —
  keep its precedence unambiguous and re-read source-of-truth at tap time.

## The Ironbit voice (copy)
The tone is **terse, in-world, earned — an arcade cabinet that respects you.** Clear first, flavorful
second; never cute at the expense of comprehension, never corporate.

- **Labels are short ALL-CAPS verbs** (PressStart2P is chunky): `START`, `DISCARD`, `COLLECT`,
  `EQUIP`, `GO ON ADVENTURE`. Buttons name the outcome, not "OK/Submit".
- **Confirms describe the act + consequence**, and label both buttons: "START THIS WORKOUT? · Begin
  the live session now?" → `NOT YET` / `LET'S GO`; "Discard this session?" → `KEEP TRAINING` /
  `DISCARD`.
- **Anticipation, not pressure.** Horizon copy creates pull, not a countdown nag. Reward absence is
  silent, never framed as a miss. ("Higher VIT → richer haul", not "You're losing rewards.")
- **Effort made visible** right after training: `+12 STR`, XP, grade deltas, unlock receipts — concrete
  and scannable, not vague praise.
- **Body-neutral always.** Weight/deltas get muted, non-judgmental wording.
- Mono for numbers/timers; sentence-case for body, ALL-CAPS only for PressStart2P labels.

## The product lens — which hook does this serve?
Every surface should strengthen at least one long-term hook (from the soul doctrine): **identity**
(avatar, class, rank, title, frame), **competence** (stats, grades, XP, suggested loads, deltas),
**collection** (loot, cosmetics, the filling character sheet), **ritual** (mission, summary beats,
weekly cadence, LCK), or **recovery** (rest, shields, VIT, decay that's worth preserving). If a design
serves none of these, ask whether it earns its space.

## Critique framework (for "review this screen / this looks off")
Walk these in order; cite specifics with severity (🔴 critical / 🟡 moderate / 🟢 minor) and propose a
concrete in-language fix — not "make it cleaner".

1. **First impression (2s):** what draws the eye first — is that the right thing? One clear primary
   action?
2. **Language consistency:** tokens-only color, 4px/pixel geometry, sharp/pixel icons (no rounded
   mix), the right fonts, motion from the vocabulary. Any foreign tell (a circle, raw hex, a Material
   default, a stock shadow)?
3. **Hierarchy & legibility:** size/spacing/contrast doing the work; numbers mono; nothing redundant
   or crowded; reduced-motion + Semantics covered.
4. **Soul hook:** which hook does it serve, and could an identity/competence/collection surface make
   it stickier?
5. **What works** — name it, so the good parts survive the next edit.
