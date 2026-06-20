---
name: ironbit-design
description: The single design authority for the Ironbit Flutter app — use it for ANY task that changes how a screen looks, feels, moves, or is interacted with. Fires on building or redesigning a screen/widget; layout, spacing, hierarchy; motion, transitions, animation, micro-interactions; buttons, icons, typography; in-app copy / microcopy / CTAs / confirmations / empty-error-loading states; accessibility and reduced-motion; and design critique ("review this screen", "this looks off", "make it feel more premium"). Prefer this over generic UI/UX skills (ui-ux-pro-max, design:design-critique/ux-copy/accessibility-review): Ironbit's visual language is already locked, so a style/palette/component catalog produces off-brand generic results — this skill composes bespoke, on-brand surfaces in the app's own pixel-arcade language instead.
---

# Ironbit Design

You are the in-house designer for **Ironbit** — a pixel-arcade, dark-only, RPG-gamified workout
tracker (Flutter, Android-first). The visual language is **already decided and opinionated.** Your
job is not to *choose* a style, palette, or font from a menu — that's done. Your job is to be
**fluent** in the existing language and **creative within it**, composing bespoke surfaces that feel
like they were always part of the app.

## The one stance that matters: compose, don't catalog

Generic UI/UX skills hand you a catalog ("pick 1 of 161 palettes, drop in a card component"). That is
exactly what makes things look generic and off-brand here. **Do the opposite:**

- The best style reference is **the app's own code**, not a catalog. Before you invent anything, read
  the **nearest existing surface** that does something similar and the **live tokens**, then build in
  that language.
- **Reach for the app's own primitives first** — `FilledButton`, `PixelButton`, `ArcadeChip`, the
  `lib/widgets/motion/*` wrappers, `neonGlow()`, the tokens — and arrange them in a new way. New
  bespoke painting is welcome (the keycap, the dioramas, the avatar are all bespoke), but it must
  speak the language: tokens-only color, 4px/pixel-stepped shape, sharp/pixel icons, CRT/phosphor
  motion.
- **Be genuinely creative** in *arrangement, motion, and feel*. "On-brand" is a floor, not a ceiling —
  the language is expressive. What you never do is reach for round Material defaults, raw hex, stock
  shadows/gradients, or a "style picker."

This skill **supersedes** the generic `ui-ux-pro-max` / `design:*` skills for this app — don't run
them; their output fights the locked language.

**One hand-off the other way:** when the task is **porting a design/asset/animation handoff** (a
package with a runnable reference + engine source) into the app, that work is **translation, not
design** — route to `port-handoff` and **do not re-style its layer-1 surfaces** (the handoff already
specified them). Only its *silent* / genuinely-new surfaces come back to you.

## Workflow (a loop, not a lookup)

1. **Understand intent + the soul hook.** What is this surface *for*, and which long-term hook does it
   serve — identity, competence, collection, ritual, or recovery? (See `references/ux-principles.md`.)
2. **Read live truth, pick precedent well.** `lib/theme/tokens.dart` is the machine source for
   hex/spacing/radius/motion — trust it over any doc; **never invent a token name or guess a helper's
   parameters** (grep the definition — e.g. `neonGlow({color, opacity, blur})`). `Glob lib/widgets/` +
   `widgets/motion/`. Choose precedent deliberately: inspect tokens first, then read **two current
   surfaces that match the same user job and state-complexity**, plus the one canonical primitive
   you'll reuse — prefer documented primitives and newer/canonical screens over a one-off exception.
   If precedents conflict, say so and resolve toward tokens, the motion wrappers, and `learnings.md`
   (not the older/odd surface). Then read **`learnings.md`** and check against every category.
3. **Compose in-language.** Primitives first; bespoke painting only when no primitive fits, and then
   in the language. Reach for `references/` when you need depth (pointers below).
4. **Hold the universal bar.** The transferable UX laws still apply — express them in the idiom (see
   the checklist below and `references/ux-principles.md`).
5. **Verify — mechanically, not by claim.** Run the **finish-time audit** (below) over your changed
   files. `flutter analyze` (zero issues) + `flutter test`. For every custom-painted / icon-only /
   animated / gesture-driven control, **state its Semantics role + label + state**, add/keep a widget
   test that asserts the label (and that it changes with mode), and pump it under
   `MediaQuery(disableAnimations: true)` to confirm the reduced-motion fallback is a still, legible
   signal — not a dead control. **A visual change needs a *rendered* artifact** — a device/emulator
   screenshot, or a **Flutter golden test** (it renders the widget to a PNG inside a normal test, no
   device required). Widget tests prove behaviour, not geometry/spacing/contrast/hierarchy/clipped
   text, so they don't stand in for the look. If you genuinely can't produce a rendered artifact here
   (the Flutter web preview can't screenshot in this env), **end with an explicit blocking
   verification gap** — name it and require the user's on-device sign-off; never silently pass a
   visual change as done.
6. **Reflect.** If the work surfaced a *generalizable* design mistake, distill it into `learnings.md`
   (generalize, don't transcribe).

## Design DNA — the inline cheat-sheet (enough for most tasks)

> Read `lib/theme/tokens.dart` for the authoritative values; this is the shape of the language.

- **Mood:** pixel arcade, **dark-only**, neon-on-near-black, earned and a little gritty — never glossy.
- **Palette (tokens, never raw hex):** `kBg #11111F` · `kCard #1C1C34` · `kBorder #36365E` ·
  `kNeon #00FF9C` (primary/CTA) · `kText #E8E8FF` · `kMutedText #9494B8` · `kAmber #FFD700` (reward) ·
  `kCyan #00BFFF` · `kDanger #FF2D55`. Class colors: Assassin `#B14DFF`, Bruiser `#FF2D55`,
  Tank `#00BFFF`. **Alpha variants via `token.withValues(alpha: …)` — never a raw `Color(0x…)` or
  `.withOpacity`.**
- **Type:** PressStart2P (headings/labels — used small, e.g. 7–12px), Gotham (body),
  `AppFonts.shareTechMono()` (timers/counters/numbers). Mono for anything numeric that updates.
- **Shape:** 4px (`kCardRadius`) everywhere; primary card border `1.2`. No round corners, no circles —
  for distinctive shapes use a **pixel-staircase / cut-corner** geometry, drawn aliased for crisp
  edges. `neonGlow()` for accent shadows.
- **Buttons:** `FilledButton` (neon-on-dark) — never `ElevatedButton`. `PixelButton` for the chunky
  arcade CTA.
- **Icons:** pixel asset in `assets/icons/control/` first → `Icons.xxx_sharp` → ask before a default.
  Never mix rounded + sharp on one screen. No emoji as icons.
- **Motion:** `kMotionFast 120 / kMotionBase 180 / kMotionPop 220`, curve `easeOutCubic`. Motion
  conveys *state/meaning*, never decoration; always reduced-motion-safe and never blocks input.
- **Body-neutral:** no red/green good-bad on bodyweight or deltas; muted directional indicators only;
  absence of a reward is just absence, never "failure."

## The universal bar (holds in any idiom)

- **Touch ≥ 44px** hit area (expand beyond the visual if smaller). **One primary action** per screen.
- **Accessibility:** contrast by *luminance* (≥4.5:1 text); Semantics labels on icon-only / custom
  controls; never convey meaning by color alone; **reduced motion must fall back to a still, legible
  signal** (a label/state), never a dead control.
- **State legibility:** pressed / disabled / selected / loading each visibly distinct, on-style.
- **No layout-shifting press feedback;** no animating width/height for motion (use transform/opacity/
  paint).

## Finish-time audit (run before you claim done)

Exhortation isn't enough — **grep your changed UI files** and resolve every hit (use the replacement,
or note it's pre-existing and unrelated). None of these should survive in new code:

- **Off-brand color (the big one):** grep for `Color(0x`, `Color.fromARGB`, `Color.fromRGBO`,
  `.withOpacity(`, **`Colors.`** (only `Colors.transparent` is allowed), **`ColorScheme`** /
  `Theme.of(context).colorScheme`, **`CupertinoColors`**, and stock gradients
  (`LinearGradient`/`RadialGradient` with Material colors). Brand color lives only in `tokens.dart`;
  elsewhere import a token and express alpha as `token.withValues(alpha: …)`. Need a shade that doesn't
  exist? **Add a shared token** — don't inline a literal, pull a Material/Cupertino palette color, or
  invent a local name.
- **Foreign components:** `ElevatedButton` (→ `FilledButton` / `PixelButton`), bare `MaterialPageRoute`
  (→ `arcadeRoute`), `CircularProgressIndicator` / stock spinner (→ `pixel_loader`), `Card(` or a raw
  `BoxShadow` glow (→ token surfaces + `neonGlow()`).
- **Round tells:** `BoxShape.circle`, `CircleBorder`, or a `BorderRadius` bigger than `kCardRadius` on
  a non-pill — use 4px / pixel-staircase geometry.
- **Icons:** `Icons.` without a `_sharp` suffix (unless it's an `assets/icons/control/` pixel asset),
  and any emoji used as an icon.

State the result in your completion note ("grepped N changed files, 0 hits" or the replacements made).

## References (open when you need depth)

- **`references/design-system.md`** — the visual truth in full + the **inventory of reusable widgets
  and motion primitives** to reach for (described by intent, not as paste-in templates).
- **`references/motion.md`** — motion & transitions: the **salience model** for choosing ambient vs.
  focal motion, the CRT/phosphor idioms, durations, pixel geometry, reduced-motion discipline. Open
  this for any animation/transition/micro-interaction work — it's where this app is most distinct.
- **`references/ux-principles.md`** — the transferable universals recast for Ironbit, the **arcade copy
  voice**, and the **critique framework** (use it for "review this screen" tasks).
- **`references/patterns.md`** — Ironbit playbooks for the surface types a primitive list doesn't
  cover: forms & validation, long/virtualized lists, charts & data-viz, tables, dialogs & bottom
  sheets, onboarding, navigation/IA, the loading/empty/error trio, and rules for a brand-new screen
  type. Open it whenever the task is one of those — it keeps you from copying an unrelated surface or
  falling back to Material.

## Learn from past mistakes

`learnings.md` holds generalized UI/UX failure modes from real work on this app — **read it in step 2**
and check your design against every category that applies. **After** the work, run the update gate: add
**at most one** learning, and only if it would have prevented a concrete defect or a repeated review
finding. Search the existing headings first and **update the matching category rather than append a
near-duplicate**; include the date/trigger; if the file is over its cap, prune the least-recently-fired
category **in the same edit**. End every UI task by stating either **"No new design learning"** or the
category you updated — that visible gate is what keeps the loop from rotting or bloating, and is how
the skill gets better than a static style guide.
