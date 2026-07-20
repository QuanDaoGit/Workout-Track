# PRD.md — Ironbit (Workout Tracker)

> **Status:** Pre-launch. Living document. Last reconciled with the codebase 2026-05-31.
> Source of truth for *scope and intent*. For *implementation truth* (tokens, services,
> architecture) see the root [CLAUDE.md](../CLAUDE.md) and [PRODUCT.md](PRODUCT.md).

## Purpose
Solo gym-goer logs and tracks workout sessions from their phone, and every logged lift
feeds an RPG character-growth layer they become attached to. No account. Works offline-first; training
data stays on-device (anonymous, opt-out usage analytics + opt-in crash reporting — [ADR 0001](decisions/0001-usage-instrumentation.md)).

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
- [x] Start Workout: muscle-target chips drive the loadout — each selected target adds two default
      exercises (your top-2 history for it, else curated) and deselecting cleanly removes them; a
      returning user opens with the last session's targets pre-selected (one-tap START). Card-level
      Replace swaps a lift for ~4 same-muscle alternatives; the full curated picker hides behind
      "ADD EXERCISE". Program days show the prescribed lifts with Replace (ephemeral, sets×reps
      preserved across a force-kill) and no chips. Duration set via scroll picker.
- [x] Optional **warm-up sets**: a demoted warm-up sub-section in the exercise screen logs
      ramp-up sets — one-tap **LOG IT** from the advisory warm-up suggestion, or a manual
      **+ WARM-UP SET**. Warm-up sets are stored apart from working sets and feed **no**
      volume/stat/XP/overload — they only mark that the user warmed up, which earns a small
      once-per-day **gem** bonus (anchored to the completed real workout, revealed calmly on the
      summary, capped per calendar day via an idempotent gem-ledger entry so it can't be farmed).
      Integrity comes from logging an *actual* set (an observable act), not a self-reported toggle;
      skipping is always silent (no nag). A separate optional **mobility guide** (RAMP light-cardio
      raise + muscle-tailored dynamic drills) is reachable from Start as unrewarded reference.
- [x] Active session: live timer, per-exercise status, rest timer. Each logged set checkpoints
      to storage (crash-safe), and a 30-min inactivity window offers an idle auto-save reveal
      (save & finish / keep training / discard) — on the active page or on the next app open.
- [x] Per-exercise set logging (weight + reps). A single advisory **warm-up suggestion** sits above
      the set table — one non-adjustable, never-logged prep set whose load is equipment-aware
      (barbell bar+plate-pairs / dumbbell-kettlebell steps / cable-machine stack pins) and derived
      from the lift's working weight, always sanitized to a settable number; absent for bodyweight
      and when no working weight is known. A plate calculator (pre-fillable from the warm-up or any
      set's weight) is shown only for plate-loaded lifts (barbell / E-Z curl bar), not stacks,
      dumbbells, or bodyweight; inside it the bar weight is a one-tap preset selector
      (Olympic / Women's / EZ) with a Custom fallback, not a typed field.
- [x] Post-workout summary: XP awards, stat deltas, calorie breakdown, save to local storage.
- [x] Workout history (list + calendar) and per-exercise detail.

### Character growth (the RPG layer)
- [x] **Readable character stats** — visible radar stats are STR, AGI, and END; VIT is a recovery meter; LCK is the streak/XP multiplier.
  - STR and AGI are derived from weighted logged exercise volume by primary muscle.
  - END grows from logged reps with rep-range and muscle weighting; Tank focus pushes END.
  - VIT is a 10-100 recovery/training-balance meter.
  - LCK equals the current training streak (capped at 100) and drives an award-time XP multiplier.
- [x] Workout-output stats start at 10 (LCK at 0) and are immutable — once earned they never decrease (inactivity no longer decays them; the consistency streak is protected by shields).
- [x] Stat card on Profile (radar + detail rows); stat delta shown after each completed session.
- [x] Calibration quiz captures training context; workout-output stats start at 10 until real
      logged training changes them.

### Classes
- [x] 3 classes: **Assassin** (Shoulders+Core), **Bruiser** (Chest+Back+Arms), **Tank** (Legs).
      Each has a theme color and session-time mechanical bonus. (Vanguard was removed.)
- [x] Class is persisted on each `WorkoutSession` at save time so later switching never rewrites history.

### Supporting systems
- [x] Earned feature unlocks (`FeatureGateService`) — **the app assembles itself as you train.**
      Meta surfaces gate behind earned milestones (Quests @ 1 completed workout — the board stays
      off/no-effect until then, and turns on with the first Show Up reward already claimable; Shop @
      first gems; Guild @ 3 workouts; Items @ first non-default loot; Adventure @ 5 workouts). The
      tool core (Home, TRAIN/logging, Logs, XP/stats/level, BIT, Labs) is never gated, and the day-0
      FIRST QUEST mission launcher stays live (it earns the first unlock). Locked surfaces stay
      **visible** (dimmed nav, dormant cards, an unpowered wall board/pad) with invitation-framed
      copy — never debt/countdown framing; nothing expires or re-locks (unlocks are latched forever).
      Each unlock plays the standardized **NEW SYSTEM ONLINE** ceremony on the shell (BIT-hosted,
      skippable, reduced-motion-safe; multiple pending unlocks coalesce into one catch-up card).
      Existing installs are grandfathered fully unlocked with no ceremonies. Design + evidence:
      `docs/superpowers/specs/2026-07-14-feature-unlock-drip-design.md`, `research/insights.md`
      (2026-07-14 entry).
- [x] XP & levels (`XpService`), threshold leveling, LCK multiplier.
- [x] Quests (`QuestService`) — auto-evaluated from workout history; no manual-confirm quests. A
      **rotating pool** surfaces a fresh deterministic set each period (3 daily / 5 weekly, each anchored
      by a reliable win; side = a permanent milestone ladder). **Limit Break** is a personalized weekly
      volume target from the user's own recent training — a doable stretch, rounded to the nearest 100.
      **BIT voices the board** (pinned header) — a small faced `BitMoodCore` + a state-derived,
      body-neutral line (shared `BitSpeechBubble`); an empty board reads as *quiet*, never a guilt-poke.
      Claiming a quest **flies the reward gems** from the CLAIM button to the pinned magenta gem wallet,
      which counts up as they land while BIT cheers (`quest_claim_flight.dart`; reduced motion snaps).
- [x] Loot & inventory (`LootService`) — deterministic milestone unlocks (avatar frames/themes)
      that create collection pull without paid shortcuts.
- [x] Guild (`GuildService`) — local single-player simulation with NPC members, deterministic per ISO week.
- [x] Adventure (`AdventureService`) — workout-fueled expeditions. Each completed workout grants one
      expedition **charge** (max 1/day, banked up to 3) — the instant payoff, surfaced on the workout
      summary. The user spends a charge to send the character out on a chosen stat-keyed route (IRON
      VAULT/STR, SKY TRACER/AGI, INFINI MAZE/END) via a console-style stage-select ceremony (tap to
      arm → the other two lock → DISPATCH). Recovery (**VIT**) scales the haul: duration 4–8h and a
      1.0–1.4× gem multiplier, both frozen at dispatch. Payout = rank base (8/12/18/26/40) × VIT
      multiplier × ±30% roll. Gems **settle durably on the next Home open** (idempotent ledger),
      but the **report is the single reveal, gated behind COLLECT** — a tapped curtain, never an
      auto-push (so the numbers reveal once, on the report's diorama/flavor/find/count-up). One
      expedition out at a time; ≤5 dispatch/ISO-week (weekly gem budget = 5 ×
      base × [1.0–1.4×]). Idempotent ledger awards, occasional no-power flavor finds. **The 4–8h
      gated wait is a deliberate, eyes-open exception to the no-idle-loop doctrine:** gems are
      cosmetic-only, the wait is never punished (no expiry/withering, calm collection), and a
      clock-forward skip only bypasses the wait, never the charge cost (a real logged workout). The
      **home-room pad doubles as the in-room dispatch dock**: the pad's own readout strip is repainted
      as an **integrated 3-segment charge meter** (`widgets/room/pad_charge_meter.dart` — a faithful
      port of the `pad-charge-meter` handoff) that lights **0–3 cyan** for the banked charges, with a
      static armed glow only when a dispatch is possible — no separate label, nothing protrudes, no nag
      at zero. The meter shows in **every pad state** (home / out / haul), only hidden by the transition
      FX, so the dock never reverts to a bare strip; and when a workout **banks a charge** the newly-lit
      segment gives a brief **arrival flash** (the rare earned moment gets a beat; reduced-motion → none).
      Earning is independent of an expedition being out (workout-while-out still banks a charge). The
      **dispatch console** ("WHERE DOES BIT SCOUT?") shows the charge as the **energy-cell icon + `N/3`**
      (`widgets/room/energy_cell.dart`, a faithful port; cyan = BIT's energy, depleted = dead grey, never
      red). The **report ceremony** reveals staged, **tap-to-skip**, with the gem + found item **popping
      in** (scale + a brief glow / rarity-colour flash) — juice, never a slot-machine roll. Tap → SEND BIT console → BIT launches
      up the beam and scouts → while out, the dock shows his **turquoise hologram in a containment
      rig** ("out there", not gone) + "back ~Nh" → on return, BIT **rides the beam home and the dock
      fabricates a magenta haul coffer** → tapping the coffer **dissolves it (the curtain) and routes
      into the report** (the single reveal). The coffer is the **persisted authority**
      (`hasUncollectedHaul`): it survives kill/reopen, blocks re-dispatch until collected
      (single-track pad), and a returning haul plays the homecoming once (backlog = static coffer).
      BIT *himself* is the expedition protagonist — he also **hover-glides the scrolling route
      diorama** (Adventure tiles + report) in right-facing profile; **no avatar walker on any
      expedition surface**. See
      `docs/superpowers/plans/2026-06-12-adventure-design.md` (+ the v2 addendum),
      `docs/superpowers/plans/2026-06-17-expedition-pad-dock.md`, and
      `docs/superpowers/plans/2026-06-17-expedition-homecoming-coffer.md`.
- [x] Body metrics (`BodyMetricsService`) — opt-in, body-neutral weight tracking: log any time, an
      EWMA **trend line** smooths the noise, and a single weekly XP-boost reward (rolling 7-day
      window) rewards the act of checking in.
- [x] Progressive overload (`ProgressiveOverloadService`) — plate-true ±2.5 kg suggestions, kind-aware.
- [x] Rest & recovery (`RestService`) — shield charges, recovery XP, rest-day protection.
- [x] Rest-day Recovery Briefing (`RecoveryInsightService`, 2026-07-18) — both Home recovery cards'
      primary opens a BIT-voiced bottom sheet with one rotating recovery insight per rest day
      (35-entry pool in `data/recovery_insights.dart`, deterministic unseen-first rotation, honest
      wrap line). Research-grounded (SDT competence > rewards): deliberately NO XP/gems/streak and
      no guilt or train-nudge copy — rest stays protected. Spec + plan:
      `docs/superpowers/specs/2026-07-18-rest-day-recovery-insights-design.md`.
- [x] Home-room micro-interactions (2026-07-20) — a two-tier camera grammar makes the room feel
      physical at the moment of interaction: the wall quest board's tap **dollies the camera into
      the board** (280ms raster-layer zoom while the quest route holds back, then CRT-reveals over
      it; the pop plays a 190ms pull-back settle), the pad's dispatch tap plays a subtle 1.05
      **focus-push** under the sheet, pressing BIT fires a shaped ~280ms haptic **purr**
      (`HapticService.bitPurr`, drone-safe fallbacks), and board + pad answer pointer-down with a
      paint-level **press-light**. All user-triggered feedback, never ambient decoration; reduced
      motion keeps today's exact behavior (the purr stays — action-tied, own toggle). Deliberately
      trimmed by adversarial review: no overscroll stir, no time-of-day tint, gaze deferred. Spec:
      `docs/superpowers/specs/2026-07-20-home-room-micro-interactions-design.md`.
- [x] Programs (`ProgramService`) — structured workout programs (PPL, Full Body, Upper/Lower).
- [x] Onboarding — cinematic sequence: cold open → problem → solution → calibration quiz →
      avatar → name → class reveal → rank assessed → charge ritual → start gate.
- [x] Companion mascot **BIT** — an in-world pixel "drone core" that is the system's faceless voice
      through onboarding and **embodies** at the start gate, greeting the user by name for the first
      time ("What should we do first, {name}?"). Subordinate to the user-hero (never on the identity
      card); see `lib/widgets/companion/`. Address register: name (intimate) / "warrior" (ceremony) /
      "recruit" (pre-embodiment), with "warrior" as the fallback for an unusable name. In-app
      presence has begun — BIT voices the **quest board** and **lives in the home room**: one speech
      box (`BitSpeechBubble` — an in-world balloon ABOVE BIT with a downward tail) that rotates short,
      body-neutral life-advice when home (a fresh line on each Home re-entry), greets **"It's me
      again"** once when the away hologram first appears, carries the
      live expedition status while scouting, and prompts **"Check out the loots"** (gem-magenta,
      tap-to-collect) when a haul waits (`data/bit_room_copy.dart`; never a guilt-poke). The room
      also mounts a **wall quest board** (`widgets/room/quest_board.dart`) upper-left, a little above
      BIT (counterweighting the world window): a glance peek (QUESTS · 5-seg weekly bar · gem pip)
      that tints **amber + breathes only when a reward is claimable** (else calm steady-cyan, the
      pad-LED hue), tapping routes to the full Quests page; when a reward waits BIT also speaks a calm
      claimable nudge line (tappable → Quests). A small
      **spam-tap easter egg**: poke BIT five times fast (≤350ms apart) at home and he tires of it —
      smoothly slumps to a REST pose and sighs **"I guess bro..."** for ~3s, then perks back to neutral
      advice (armed only at home/idle, so it never buries a haul or away line; reduced motion → an
      instant slump, still legible). The interview
      voice is a planned follow-up.

---

## Out of Scope
- User login / accounts, cloud sync, social/multiplayer/PvP, leaderboards.
- AI coaching / AI-generated recommendations.
- Apple Health / Google Fit integration.
- Nutrition / calorie counting as a primary feature (calorie *estimate* on summary only).
- Paid features or in-app purchases.
- **Server / cloud push notifications** (FCM, remarketing, any backend-driven message). On-device
  **local notifications** (rest-timer alerts, opt-in workout reminders) ARE in scope — they need no
  backend/account/network and send no data off-device. (Analytics/crash telemetry is a separate,
  data-minimized stream — see [ADR 0001](decisions/0001-usage-instrumentation.md); **push/FCM
  messaging stays out of scope**.)
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
