# PRD.md — Ironbit (Workout Tracker)

> **Status:** Pre-launch. Living document. Last reconciled with the codebase 2026-05-31.
> Source of truth for *scope and intent*. For *implementation truth* (tokens, services,
> architecture) see the root [CLAUDE.md](../CLAUDE.md) and [PRODUCT.md](PRODUCT.md).

## Purpose
Solo gym-goer logs and tracks workout sessions from their phone, and every logged lift
feeds an RPG character-growth layer they become attached to. No account. No cloud. Works offline,
always.

**Soul doctrine (from [PRODUCT.md](PRODUCT.md)):** every logged workout should make the user's
character feel harder to abandon. Real training is the fuel; identity, streak, rank, loot, and
ritual are the psychological engine.

## Target User
Single user. Gym-goer, beginner to early-intermediate. Tracks personal progress over time and is
motivated by visible, earned progression, identity attachment, rank aspiration, collection desire,
and a repeatable training ritual.

## Platform
Android first. iOS later.

## Data Storage
Local only via `shared_preferences` with JSON serialization. No Firebase, no login, no sync.
(`drift` is a dependency but SQLite is not used in practice.)

---

## Shipped Features

### Workout logging
- [x] Start Workout: a returning user opens straight onto their frequency-ranked "usual" loadout
      (one tap to START), with the muscle-target step collapsed behind a Focus affordance and
      card-level Replace (swap a lift for ~4 alternatives) demoting the full curated picker to a
      "See All" escape. A new user — or one below the history threshold — gets the curated
      chip-first picker (multi-select with favorites). Duration set via scroll picker.
- [x] Active session: live timer, per-exercise status, rest timer. Each logged set checkpoints
      to storage (crash-safe), and a 30-min inactivity window offers an idle auto-save reveal
      (save & finish / keep training / discard) — on the active page or on the next app open.
- [x] Per-exercise set logging (weight + reps).
- [x] Post-workout summary: XP awards, stat deltas, calorie breakdown, save to local storage.
- [x] Workout history (list + calendar) and per-exercise detail.

### Character growth (the RPG layer)
- [x] **Readable character stats** — visible radar stats are STR, AGI, and END; VIT is a recovery meter; LCK is the streak/XP multiplier.
  - STR and AGI are derived from weighted logged exercise volume by primary muscle.
  - END grows from logged reps with rep-range and muscle weighting; Tank focus pushes END.
  - VIT is a 10-100 recovery/training-balance meter.
  - LCK equals the current training streak (capped at 100) and drives an award-time XP multiplier.
  - DEF is hidden legacy compatibility storage only, not a visible stat.
- [x] Workout-output stats start at 10 (LCK at 0); daily decay only after consecutive inactivity, never on planned rest.
- [x] Stat card on Profile (radar + detail rows); stat delta shown after each completed session.
- [x] Calibration quiz captures training context; workout-output stats start at 10 until real
      logged training changes them.

### Classes
- [x] 3 classes: **Assassin** (Shoulders+Core), **Bruiser** (Chest+Back+Arms), **Tank** (Legs).
      Each has a theme color and session-time mechanical bonus. (Vanguard was removed.)
- [x] Class is persisted on each `WorkoutSession` at save time so later switching never rewrites history.

### Supporting systems
- [x] XP & levels (`XpService`), threshold leveling, LCK multiplier.
- [x] Quests (`QuestService`) — auto-evaluated from workout history; no manual-confirm quests.
- [x] Loot & inventory (`LootService`) — deterministic milestone unlocks (avatar frames/themes)
      that create collection pull without paid shortcuts.
- [x] Guild (`GuildService`) — local single-player simulation with NPC members, deterministic per ISO week.
- [x] The Shadow (`ShadowService`) — nemesis built from the user's own steady training: acute
      (last 10 days) vs chronic (prior 28 days) per-axis pace contest on STR/AGI/END. Home
      callout + Guild-tab arena (ghost of the user's own avatar, dual radar). First genuine
      defeat grants the Shadowbane title + Spectral Frame (identity only — never XP/gems);
      a decaying high-water floor blocks rewards for beating a rested-away baseline. See
      `docs/stats-mechanics.md` → "The Shadow".
- [x] Adventure (`AdventureService`) — workout-fueled expeditions. Each completed workout grants one
      expedition **charge** (max 1/day, banked up to 3) — the instant payoff, surfaced on the workout
      summary. The user spends a charge to send the character out on a chosen stat-keyed route (IRON
      VAULT/STR, SKY TRACER/AGI, INFINI MAZE/END) via a console-style stage-select ceremony (tap to
      arm → the other two lock → DISPATCH). Recovery (**VIT**) scales the haul: duration 4–8h and a
      1.0–1.4× gem multiplier, both frozen at dispatch. Payout = rank base (8/12/18/26/40) × VIT
      multiplier × ±30% roll. The report greets the user once the haul returns (wall-clock
      `returnsAt`, monotonic max-seen rollback guard; collected on the page or auto-revealed on the
      next Home open). One expedition out at a time; ≤5 dispatch/ISO-week (weekly gem budget = 5 ×
      base × [1.0–1.4×]). Idempotent ledger awards, occasional no-power flavor finds. **The 4–8h
      gated wait is a deliberate, eyes-open exception to the no-idle-loop doctrine:** gems are
      cosmetic-only, the wait is never punished (no expiry/withering, calm collection), and a
      clock-forward skip only bypasses the wait, never the charge cost (a real logged workout). See
      `docs/superpowers/plans/2026-06-12-adventure-design.md` (+ the v2 addendum).
- [x] Body metrics (`BodyMetricsService`) — opt-in, body-neutral weight tracking: log any time, an
      EWMA **trend line** smooths the noise, and a single weekly XP-boost reward (rolling 7-day
      window) rewards the act of checking in.
- [x] Progressive overload (`ProgressiveOverloadService`) — plate-true ±2.5 kg suggestions, kind-aware.
- [x] Rest & recovery (`RestService`) — shield charges, recovery XP, rest-day protection.
- [x] Programs (`ProgramService`) — structured workout programs (PPL, Full Body, Upper/Lower).
- [x] Onboarding — cinematic sequence: cold open → problem → solution → calibration quiz →
      avatar → name → class reveal → rank assessed → start gate.

---

## Out of Scope
- User login / accounts, cloud sync, social/multiplayer/PvP, leaderboards.
- AI coaching / AI-generated recommendations.
- Apple Health / Google Fit integration.
- Nutrition / calorie counting as a primary feature (calorie *estimate* on summary only).
- Paid features or in-app purchases.
- Push notifications.
- Advanced periodization (RPE, autoregulation, block programming).

---

## Design Constraints
- Theme: pixel arcade, **dark mode only**. All palette/spacing/motion constants live in
  [lib/theme/tokens.dart](../lib/theme/tokens.dart) — never hard-code hex.
  Key tokens: `kBg 0xFF11111F`, `kCard 0xFF1C1C34`, `kNeon 0xFF00FF9C`, `kText 0xFFE8E8FF`,
  `kAmber 0xFFFFD700`, `kCyan 0xFF00BFFF`, `kDanger 0xFFFF2D55`.
- Fonts: PressStart2P (headings), Gotham (body), `AppFonts.shareTechMono()` (mono timers/counters).
- Border radius 4px (`kCardRadius`). `FilledButton` everywhere. Sharp (`_sharp`) icons only.
- Body-neutral: no red/green good-bad framing on weight; alignment bonuses are silent when not earned.

---

## Roadmap pointers
Feature plans and reconciled specs live in [docs/superpowers/plans/](superpowers/plans/).
Product/design rationale lives in [PRODUCT.md](PRODUCT.md) and the Phase 7/8 decision tables in
the root [CLAUDE.md](../CLAUDE.md).
