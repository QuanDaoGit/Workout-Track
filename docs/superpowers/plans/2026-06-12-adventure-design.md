# Adventure — design spec (2026-06-12)

> Status: **implemented 2026-06-13** (`AdventureService` + Home/AdventurePage/report reveal).
> The Stage-4 Codex review produced two design amendments now in force: **settlement (data) is
> separated from reveal (presentation)** — dispatch auto-settles any revealable pending first,
> so a pending expedition can never cost a dispatch day — and the **clock-forward trust
> boundary** is explicitly accepted (offline app; consistent with quests/LCK; every dispatch
> still costs a real logged workout with ≥1 set). Payout was amended to base ±30%, rolled at
> dispatch, seeded by expedition id (no reroll on reopen). Asset briefs live in
> [design/adventure-asset-briefs.md](../../../design/adventure-asset-briefs.md).

## Concept

Adventure makes **absolute stats matter economically**: your character goes on simulated
expeditions and brings back gems, and your stat *ranks* set the wage. It is the app's first
"simulated world" surface that absolute STR/AGI/END feed directly.

**Soul rationale (why this passes):**
- **Trust anchor intact** — expeditions are *fueled exclusively by real workouts* (one completed
  session = the day's dispatch). No training → no expeditions → no gems. Every gem in the economy
  still traces to a logged session.
- **No idle loop** — nothing accrues by wall-clock. This is deliberate: an idle battle/dungeon
  system was previously built and stripped (see `MigrationService` dead keys). The precedent is
  [WalkScape](https://massivelyop.com/2023/05/05/massively-on-the-go-walkscapes-schamppu-wants-game-to-walk-the-fitness-walk/),
  which gates *all* progress behind real steps ("no step wasted") — substitute "workout" for "step".
- **Narrative meaning over points** — [Zombies, Run!](https://bitletics.com/blog/gamified-fitness-apps/)'s
  lesson: the expedition *report* (where your character went, what they found) is the reward;
  gems are the receipt.
- **Rank aspiration finally has teeth** — promotions (D→C→B→A→S) are visible wage raises.
- **Cosmetic-only economy** — gems remain earned-only and spend only on cosmetics
  ([faucet/sink discipline](https://machinations.io/articles/game-economy-design-free-to-play-games)).
  Never XP, never power.

## The loop

1. **Open app** → if an expedition is pending, the **report greets you** (reveal ceremony).
2. **Train** → the **first completed workout save of the day dispatches** your character to your
   standing-order route.
3. **Close.** The expedition resolves on your next open — no timers, no check-back farming.

Rules:
- **One expedition at a time, one per day.** A second same-day workout earns its normal XP/stats
  but does not re-dispatch (the character is still out). Reports can never stack: logging a
  workout requires opening the app, which resolves the prior report first.
- **5 expeditions/week cap** (faucet protection; matches a realistic max training cadence).
- **Standing orders:** the active route is set on the Adventure page and persists until changed.
  The first-ever workout prompts a one-time route pick.

## Routes

All routes are open from day one; your rank on the route's stat sets the pay (no gating — the
"raise that stat" pull comes from the wage gap). Accents mirror class colors, teaching the stat
system implicitly.

| Route | Stat | Accent | World |
|---|---|---|---|
| **IRON VAULT** | STR | ember red (`kDanger` family) | forge canyon, sealed vault gates |
| **SKY TRACER** | AGI | violet (Assassin `0xFFB14DFF`) | night sky-run above the clouds |
| **INFINI MAZE** | END | cyan (`kCyan`) | endless labyrinth, forward forever |

A 4th mixed-stat route is the natural season-2 expansion slot (deliberately out of v1 scope).

## Payout

- **Rank-tier base** on the route's stat (D/C/B/A/S): **8 / 12 / 18 / 26 / 40 gems**.
- **Final payout = uniform random in [base − 30%, base + 30%]**, rounded. Symmetric and bounded
  with EV = base — bounded "spice", deliberately **not** a gacha/jackpot shape (the
  [variable-reward ethics line](https://www.futurelearn.com/info/courses/game-psychology/0/steps/428456)
  this app will not cross). The rank base stays fully legible.
- **Economy fit:** existing faucets are dailies 5, weeklies 5–20, side quests 100; sinks 150–6,000.
  At 5/week: D-rank ≈ 40 gems/week, S-rank ≈ 200/week — cheapest shop item takes a D-rank about a
  month, an S-rank under a week. Strong rank envy without breaking scarcity.
- **Finds:** occasional flavor items in the report (lore junk — a rusted forge key, a spire
  shard). Rarity-tinted collection charm; **never power, never gem-bearing**.

## Surfaces (v1)

- **Home:** the pending report reveal on open, plus a compact **EXPEDITION card** (current
  orders, pending status) → taps through to the Adventure page. (Same placement philosophy as
  the Shadow card.)
- **AdventurePage** (pushed from Home, like the Shop — *not* a tab): route orders, the live
  diorama, expedition history.
- The full Home / Training Ground / Adventure **area restructure is explicitly out of scope** —
  this page becomes the Adventure "area" later with zero migration.

## Presentation

- **Parallax pixel diorama:** 3 layers per route (sky / far silhouettes / tileable ground strip),
  authored at 480×270 native, integer-upscaled with nearest-neighbor (`FilterQuality.none`,
  matching the avatar painter's no-AA rule). `AnimationController` + `CustomPaint` — no game
  engine dependency.
- **Walking character:** the user's own `AvatarSpec` face on a **code-drawn pixel body** (avatar
  grid language: ~20×28, 2-frame leg alternation + 1px bob, class-color trim). Zero image assets;
  all ~8,100 faces work automatically. First time the user sees their character as a whole little
  person out in the world.
- **Report ceremony:** a few seconds of the diorama scrolling, then the report types in —
  scanline/CRT chrome (the Shadow's visual language), gem count-up, find icon stamp with existing
  strobe/shake juice. **Reduced motion: static frame, no scroll.**
- **Ambient particles** per route (embers / jetstream motes / rune dust) via the existing
  `widgets/motion` vocabulary.
- Asset budget ≈ ½MB (9 small backdrop PNGs + 3 emblems + a finds icon sheet); briefs in
  [design/adventure-asset-briefs.md](../../../design/adventure-asset-briefs.md).

## Open items for the implementation phase

- **Codex adversarial review** of this design (pipeline Stage 4) before any plan/code — expected
  pressure points: week-cap clock semantics, dispatch/resolve persistence atomicity, gem-ledger
  idempotency (one grant per expedition id), report flavor-text pool, payout RNG seeding
  (deterministic per expedition id, so re-opens can't reroll).
- Build order may use **placeholder backdrops** (solid-color layers) while real art is generated.
- Report flavor-text pool (per route, a handful of lines) — to be written at implementation.
