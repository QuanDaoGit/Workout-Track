# Handoff: Quest Claim → Wallet Flow

## Overview
This is the **reward-claim interaction** for the Ironbit **Quests** screen. When a user taps **CLAIM** on a completed quest, the reward (Gems) physically travels from that quest row up into the pinned **gem wallet** in the header, drawing an explicit cause→effect line, while **BIT** (the companion drone-core) witnesses and reacts.

The problem it solves: previously, claiming sprayed a few amber shards that flew outward and evaporated while the wallet ticked up separately — reward and wallet felt disconnected, and a claim low in the list didn't feel like it "landed" anywhere. This redesign makes the reward flow to a fixed destination so the moment reads as *I did the work → the reward is in my bank → BIT is glad.*

> **Net feeling:** reactive, earned, never intrusive. Currency is treated as valuable — animation never inflates it.

## About the Design Files
The files in this bundle are **design references created in HTML/React (Babel, in-browser)** — a prototype showing the intended look and behavior. **They are not production code to copy directly.** The task is to **recreate this design in the target codebase's environment** (the Ironbit app is Flutter — see `lib/theme/tokens.dart`, the source of truth for tokens) using its established patterns, widgets, and animation primitives. If implementing on another stack, use that stack's idioms; the spec below is framework-agnostic.

The prototype uses imperative DOM/canvas-style particle animation precisely *because* it's a throwaway reference — in Flutter this maps cleanly to an `AnimationController` + `Overlay`/`OverlayEntry` per gem (or a `CustomPainter` particle layer), `Tween` along a quadratic path, and `AnimatedSwitcher` for BIT's sprite cross-fade.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, timings, and easings are all specified and pulled from the Ironbit token system. Recreate pixel- and motion-accurately. Exact numbers below are starting values — refine the *feel* on a real device, but keep the structure (four beats, particle honesty, pinned destination).

---

## Screen / View

### Quests screen (claim interaction context)
- **Purpose:** the user reviews Daily / Weekly / Side quests and claims earned Gem rewards.
- **Layout (390×844 reference, iPhone-class):**
  - Vertical flex column inside the screen.
  - **Pinned header** (does NOT scroll) — `flex: none`, `padding: 12px 16px`, 1px bottom border `#2A2A3E`, background `#11111F`, `z-index: 4`. Two children, space-between:
    - **Left — BIT + speech line.** BIT is a **46×46** pixel sprite (real painted drone-core, not a generic mascot), with a mono speech line to its right (`11.5px`, `#9494B8`, line-height 1.35).
    - **Right — gem wallet.** `flex: none` pill: `#1C1C34` bg, 1px `#36365E` border, 4px radius, `padding: 8px 11px`, gap 7. Contains the 16×16 `gem.png` and a tabular-nums count (`ShareTechMono 17px`, color `#ff4dcd`/gem-magenta, `min-width: 34px`, right-aligned). **This pill is the flight destination and must stay pinned/on-screen at all times.**
  - **Scroll area** — `flex: 1; overflow-y: auto; padding: 16px 16px 28px`, vertical gap 22 between sections. Background is a subtle vertical gradient `#15152C → #0E0E1B`.
  - **Flight overlay** — an absolutely-positioned layer (`inset: 0`, `pointer-events: none`, `overflow: visible`, `z-index: 6`) spanning the whole screen, so gems can fly from any row (even near the bottom) up to the pinned wallet.

#### Sections (3)
Each section: a header row (`PressStart2P 12px` title `#E8E8FF` + `ShareTechMono 11px` subtitle `#9494B8`, and a right-aligned `done / total` count in `PressStart2P 9px #9494B8`), then a vertical stack of quest cards, gap 8.

1. **DAILY QUESTS** — subtitle "Resets at 00:00"
2. **WEEKLY QUESTS** — subtitle "Resets Monday"
3. **SIDE QUESTS** — subtitle "Permanent milestones"

#### Quest card component
- Container: `#1C1C34` bg, 1px `#36365E` border, 4px radius, `padding: 13px`. When claimed: `opacity: 0.62`, transition `opacity .32s ease`.
- Row layout: `flex; align-items: center; gap: 12`.
  - **Status diamond** — 9×9, rotated 45°, 1px radius. Completed/claimed → neon `#00FF9C` with glow `0 0 7px rgba(0,255,156,.5)`; incomplete → `#555577` no glow.
  - **Text block** (`flex: 1`):
    - Title — `ShareTechMono 14px #E8E8FF`. *(Do NOT use faux-bold: ShareTechMono ships a single 400 weight; requesting 700 synthesizes a muddy bold. Keep 400.)*
    - Description — `ShareTechMono 12px #9494B8`, `margin-top: 3`.
    - Optional progress: a **segment bar** (`segs: [done,total]`) OR a text line (`ShareTechMono 11px #9494B8`).
    - Optional reward title — `ShareTechMono 11px #FFD700` (amber), e.g. "Title · The Initiate".
  - **Reward column** (`flex: none`, column, align-end, gap 8):
    - **Gem chip** (flight origin) — inline-flex, gap 5, bg `rgba(255,77,205,0.10)`, 1px border `rgba(255,77,205,0.45)` (or `#36365E` when dim), 4px radius, `padding: 6px 9px`. 13×13 `gem.png` + amount in `ShareTechMono 13px #ff4dcd`. Incomplete quests: `opacity: 0.55`, muted text/border.
    - **Action**, one of:
      - **CLAIM button** (claimable) — `PressStart2P 9px`, color `#11111F` on neon `#00FF9C`, no border, 4px radius, **`min-height: 44px`** (hit-target floor), `padding: 0 16px`, letter-spacing .4px, box-shadow `0 0 16px -2px rgba(0,255,156,.22), 0 3px 0 0 #009955` (pixel depth). Neon is **reserved for this single primary action**.
      - **CLAIMED label** (claimed) — `min-height: 44px`, `PressStart2P 8px #9494B8`, a neon `✓` + the word "CLAIMED". Meaning is conveyed by icon + text, never color alone.
      - **LOCKED label** (incomplete) — `min-height: 44px`, `PressStart2P 8px #555577`, bg `#2A2A3E`, 1px `#36365E` border, 4px radius.

---

## Interactions & Behavior — the four beats

The claim sequence is one orchestrated moment. **One big moment per claim.**

### Beat 1 · Anticipation (~80–120 ms)
On tap: CLAIM button does a quick press-down/squash (`translateY(2px) scale(0.94)`, transition `.1s cubic-bezier(.2,1.3,.4,1)`); the card plays a tiny `scale(1 → 0.985 → 1)` over 200ms and begins easing to its dimmed **CLAIMED** state. After **~100 ms**, the flight begins. A short beat so the eye registers "something is being released."

### Beat 2 · Flight (~650–800 ms per gem)
A small cluster of gems spawns at the claimed row's gem chip and **arcs up** to the wallet:
- **Particle count = honesty, not spectacle.** Represent the reward, **capped at a readable cluster (≤8 gems)** even for big payouts. The *real amount is conveyed by the counter count-up*, never by inflating particles. `N = reward ≤ 8 ? reward : 8`.
- **Arc:** quadratic Bézier. P0 = chip center, P2 = wallet center, control point P1 = midpoint **raised ~26–34 px** above the straight line. Slight lateral spread at the source (`(i − N/2)·7 px`) so gems **stream** rather than clump.
- **Timing/easing:** duration 670 ms (780 ms for big payouts) + up to ~90 ms jitter; ease `cubic-bezier(.45, 0, .4, 1)` — slow-in to a brief mid-flight **hang**, then accelerate into the wallet.
- **Stagger:** ~58 ms between gems (~46 ms for big payouts) so they form a stream.
- **Per-gem motion:** spin (`±260–420°` over the flight, alternating direction), and **scale down** `1 → ~0.58` as it approaches. Drop-shadow `0 0 5px rgba(255,77,205,.6)`. Gem sprite 18×18 (22×22 for big payouts).

### Beat 3 · Landing (per gem, on arrival)
Each gem lands into the wallet:
- **Counter count-up** (not a snap). The reward is distributed across the N gems (`floor(reward/N)` each, remainder added to the **last** gems so the counter completes on the final arrival). The displayed value eases toward the target (~exponential approach, ~300–400 ms feel).
- **Wallet scale-pulse** on each arrival: `scale(1 → 1.20 → 1)` over 300 ms (`1.30`/360 ms for big payouts), `cubic-bezier(.2,1.2,.4,1)`, with a brief gem-magenta glow `0 0 16px -2px rgba(255,77,205,.30)`.
- **Audio + haptic:** one distinct **bass-y gem "abundance" chime** (a triangle body 180→320 Hz + a square sparkle 880→1660 Hz; lower/longer for big payouts) and a **light impact haptic** on landing. These **fire regardless of motion settings.** Chime is throttled (≥60 ms apart) so rapid arrivals don't machine-gun.

### Beat 4 · Settle (~700 ms hold, then resolve)
As gems land, **BIT cheers**:
- Sprite **cross-fades** turquoise neutral → amber cheer over **250 ms** (`AnimatedSwitcher`-style opacity).
- Wrapper **scale overshoot** `1 → 1.09 → 0.99 → 1` over 560 ms, `cubic-bezier(.2,1.2,.4,1)` — weighty, not bouncy. The cheer sprite already shows the plates spread, so the cross-fade reads as a "plate spread."
- Speech line updates to **"Good haul today."** (amber `#FFD700`).
- **Hold ~700 ms** (1000 ms for big payouts), then settle back to neutral turquoise; line returns to the idle line.

### Idle / rest
- BIT neutral, gentle **bob** (`translateY 0 → -3 → 0` over 3.4 s ease-in-out, infinite). Disabled under reduced motion.
- Idle speech line is contextual: rewards waiting → `"Rewards waiting — claim when ready."`; nothing claimable → `"Nothing to claim yet. Let us change that."` (forward-looking, **never a guilt-poke**).

---

## States & edge cases (all implemented in the prototype)

- **Reduced motion** (`prefers-reduced-motion` OR OS "remove animations" OR in-app toggle): **no travel, no pops.** The counter just updates to the new value (snap), BIT shows a brief static cheer frame (no scale animation) with the line updated, then returns to neutral. Audio + haptic still fire. Must remain a legible, labelled signal — never a dead/blank moment. (WCAG 2.3.3.)
- **Rapid claims** (claim several quests fast, e.g. "Claim all"): flights **pool gracefully** — multiple gem streams run concurrently and **merge** into one wallet. The counter has a single target that accumulates; each gem arrival adds its portion **exactly once**, so totals never double-count. BIT stays in cheer and the settle timer is refreshed/extended.
- **Claiming a quest low in the list:** gems originate at that row (which may be near the bottom of the scroll) and travel up to the **pinned** wallet — the destination is always on-screen. This is the reason BIT and the wallet are pinned.
- **Quiet board** (nothing to claim): no animation; BIT neutral with the calm forward line `"Nothing to claim yet. Let us change that."`
- **Big payouts** (side quests, e.g. 100 Gems + a title): feel bigger — slightly larger/denser/longer stream (still capped at 8), stronger counter pulse, BIT holds the cheer longer — but still capped and legible. *(Open question: exactly how to scale this. Current values are a reasonable starting point.)*
- **Accessibility:** the wallet count is in an `aria-live="polite"` region labelled "gem balance" (announce the change). BIT carries a `role="img"` + `aria-label` ("BIT, your companion" / "BIT, cheering"). Meaning is never conveyed by color alone (CLAIMED has a ✓ and text).

---

## State Management
Lift claim state above the rows so programmatic "claim all" and the engine can coordinate:
- `claimedIds: Set<string>` — which quests have been claimed this session.
- `walletDisplay` / `walletTarget` — the displayed (eased) vs. true gem total. Drive the displayed value toward the target each frame; this is what makes rapid claims accumulate without double-counting. **Increment the target only on each gem's arrival** (so the counter rises as gems land), except in reduced-motion where you snap.
- `bit: 'idle' | 'cheer'` and `bitLine: string` — BIT pose + speech, with a single settle timer (refreshed on each new claim) that returns BIT to idle.
- A per-quest ref map (`questId → { originElement, fire() }`) so "claim all" can trigger each row's claim with a stagger (~150 ms apart) and the engine knows each flight's origin rect.
- Trigger flow: `tap → mark claimed (anticipation) → after ~100ms, fly(originRect, reward) → per-gem arrival: bump target + pulse + chime + haptic + ensure BIT cheering → settle timer returns BIT to idle`.

No data fetching in the prototype; rewards are static demo data. In production, claim is presumably a server mutation — fire the animation optimistically on the response (or on tap with rollback) per the app's existing pattern.

---

## Design Tokens
Source of truth: `lib/theme/tokens.dart` (Flutter). Mirrored in `ironbit-tokens.css` (included in this bundle) and `colors_and_type.css` in the project.

**Colors**
| Token | Hex | Use here |
|---|---|---|
| bg | `#11111F` | screen / header bg |
| bg gradient | `#15152C → #0E0E1B` | scroll area |
| card | `#1C1C34` | cards, wallet pill |
| surface-2 | `#232342` | raised surfaces |
| border | `#36365E` | default 1px borders |
| border-dark | `#2A2A3E` | dividers, locked fills |
| neon | `#00FF9C` | **CLAIM action only**, completed status, ✓ |
| neon-dark | `#009955` | button pixel-depth shadow |
| **gem (magenta)** | `#ff4dcd` | **the Gem currency** — wallet count, chips, particles |
| gem-dark | `#961c8c` | gem facet shadow (sprite ramp) |
| amber | `#FFD700` | BIT cheer line, reward-title text, segment-bar fill |
| text | `#E8E8FF` | primary text |
| muted | `#9494B8` | secondary text, idle BIT line |
| dim | `#555577` | disabled/locked labels, incomplete diamond |

> **Currency note:** Gems = **magenta** (`gem.png`, `#ff4dcd`). XP = amber. They are different currencies — do not conflate. The product model is **Quests → Gems** (training → XP; BIT scouting → haul). Neon green is reserved exclusively for the single primary action (CLAIM).

**Type**
- Display/labels — **PressStart2P** (section titles 12px, counts 9px, CLAIM 9px, CLAIMED/LOCKED 8px).
- Counters/meta — **ShareTechMono** (wallet 17px, quest title 14px @400, desc 12px, progress 11px).
- Body — **Gotham** (not heavily used on this screen).

**Spacing** — 4 / 8 / 12 / 16 / 24 scale. Header pad 12×16, card pad 13, section gap 22, card stack gap 8.

**Shape** — **4px radius everywhere** (the only radius in the system). Pixel-crisp: `image-rendering: pixelated` on all sprites/particles; no anti-aliasing, no smooth gradients on gems, no soft blur as a *primary* effect (a flat low-opacity glow disc / drop-shadow accent is fine).

**Motion** — system tokens: fast 120 ms, base 180 ms, pop 220 ms, curve `cubic-bezier(0.215,0.61,0.355,1)` (easeOutCubic). The claim sequence deliberately uses longer, overshoot curves for the *celebration* (flight 670–780 ms `cubic-bezier(.45,0,.4,1)`; pulses/overshoot `cubic-bezier(.2,1.2,.4,1)`). Consider adding a documented "celebration" motion token rather than treating these as one-offs.

**Glow** — gem `0 0 16px -2px rgba(255,77,205,.30)`; neon `0 0 16px -2px rgba(0,255,156,.22)`; amber `0 0 16px -2px rgba(255,215,0,.22)`.

---

## Assets
In `reference/assets/`:
- **`gem.png`** — the faceted magenta pixel-diamond Gem currency sprite. Used for the wallet icon, the reward chips, and the flight particles. (Source: project `economy/gem.png`.)
- **`bit_neutral.png`** — BIT's neutral pose: turquoise core, plates close. (Source: project `BIT Fix/sprites/bit_neutral_8x.png`, 352×352, transparent.)
- **`bit_cheer.png`** — BIT's cheer pose: amber grinning core, plates spread. (Source: `BIT Fix/sprites/bit_cheer_8x.png`.)

BIT is the **existing painted drone-core** — reuse his real neutral/cheer poses, do not redraw him as a generic mascot. Other poses exist in the project (`bit_alert`, `bit_rest`) if needed.

Fonts (in `reference/fonts/`): PressStart2P, ShareTechMono, Gotham (Book/Medium). In production, use the app's bundled font registration.

---

## Files
- **`reference/Quest Claim Flow.html`** — the runnable prototype (self-contained: open in a browser). Side panel toggles every state: Claim all (rapid), Reset, Reduced motion, Sound + haptic, Quiet board.
- **`reference/assets/`** — gem + BIT sprites.
- **`reference/fonts/`** — the three type families.
- **`ironbit-tokens.css`** — the full Ironbit color + type token sheet (mirror of `tokens.dart`).
- **`screenshots/`** — static reference frames (idle board, claimed/cheer state).

Original source in the project: `quest_claim_flow/Quest Claim Flow.html`. The pre-existing (XP-based) Quests screen lives at `ui_kits/ironbit-app/QuestsScreen.jsx` — this flow supersedes its claim interaction and corrects the currency to Gems.
