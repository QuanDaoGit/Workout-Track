# Ironbit — Self-Contained App Briefing

> **Purpose.** This document explains how Ironbit *works under the hood* for someone who can
> **see the app's screenshots but has no access to the code**. Paste or upload it into a Claude
> chat alongside the screenshots so the assistant can reason about mechanics, product, and design
> — not just what the screens look like.
>
> Everything here is explained inline (no code links). Numbers and formulas are the *actual*
> shipped behavior as of 2026-05-31. The app is pre-launch; there is no live user data.

---

## 1. The soul

Ironbit is a **strength-training tracker with an RPG character-growth layer wrapped around it.**
You log real workouts (sets, reps, weight). Those logs fuel a pixel-arcade character who gains
combat stats, levels, ranks, classes, quests, and cosmetic loot.

**The soul doctrine (the one principle everything bends to):**

> *Every logged workout should make the user's character feel harder to abandon. Real training is
> the fuel; identity, streak, rank, loot, and ritual are the psychological engine.*

Five long-term hooks follow from that doctrine:

1. **Identity attachment.** Avatar, class, name, title, frame, and rank make the user feel they are
   building someone specific, not filling out a generic log.
2. **Competence growth.** Stats, grades, XP, suggested loads, and post-session deltas make effort
   legible immediately and cumulatively.
3. **Collection desire.** Frames, titles, themes, and loot feed the urge to complete the character
   sheet and show visible history.
4. **Ritual return.** Home mission, workout summary, weekly cadence, LCK, and guild signals make
   coming back feel like checking in on a living character.
5. **Recovery protection.** Rest days, shields, and VIT make recovery feel like protecting the
   build, not stepping away from it.

**Retention boundaries** (do not dilute the core loop):
accounts/login, cloud sync, social feed / friends / PvP / leaderboards, AI coaching, calorie or
nutrition tracking as a feature, Apple Health / Google Fit integration, server/cloud push (FCM /
remarketing), ads, or IAP. These would shift attention away from the self-contained
training-to-character loop. (On-device *local* notifications — rest-timer, opt-in workout reminders —
are in scope: no backend, no data leaves the device.)
Platform is **Android-first** (iOS later).

---

## 2. The core loop

```
   ┌──────────────────────────────────────────────────────┐
   │                                                        │
   │   TRAIN  ──►  LOG the session  ──►  STATS recompute    │
   │  (real gym)    (sets/reps/kg)      (from ALL history)  │
   │     ▲                                     │            │
   │     │                                     ▼            │
   │  motivation  ◄── LEVEL · RANK · CLASS · QUESTS · LOOT  │
   │                                                        │
   └──────────────────────────────────────────────────────┘
```

The hook is the feedback and the attachment it builds: a finished workout immediately shows **+X
STR / +Y AGI / +Z END**, XP gained, level progress, and any newly unlocked cosmetic. Consistency (training
streak) multiplies rewards, and each return makes the character feel more owned.

---

## 3. System map — how the pieces interact

**The data spine.** There is one source of truth: a list of **`WorkoutSession`** records stored
locally. *Almost nothing is a stored counter.* Stats, XP, level, ranks, streaks, quest progress,
loot eligibility, and the guild signal are all **recomputed from that session history** on demand.
This is what makes the fantasy trusted — wipe a session and everything downstream adjusts.

| System | Reads from | Produces |
|---|---|---|
| **Stat Engine** | session history (+ onboarding seed, rest state) | visible build stats, VIT/LCK meters, ranks, and last-session delta |
| **XP / Levels** | session history (+ streak multiplier) | total XP, level, level title |
| **Classes** | the class stored *on each session* at save time | a +20% volume bonus to that class's stat |
| **Quests** | session history + class focus | auto-evaluated daily/weekly objectives, claimable gems |
| **Gems** | local quest claim ledger | earned-only cosmetic currency |
| **Loot** | stats + session count (milestones) + gem purchases | deterministic cosmetic unlocks and early frame/theme buys |
| **Guild** | the ISO week + local simulation | a social-feel signal (NPC members), single-player |
| **Rest / Recovery** | session history + rest state | shields, recovery XP, and VIT's inputs |
| **Progressive Overload** | per-exercise history | next-session weight/rep suggestion |
| **Body Metrics** (opt-in) | user-logged bodyweight | EWMA trend line + weekly XP-boost potion (body-neutral) |

---

## 4. Character stats — the math (the heart of it)

There are three visible build-shape stats, plus two status meters. **STR / AGI / END** start at a
baseline of **10** and cap at **1000**. **VIT** is a 10-100 recovery-balance meter. **LCK** starts
at **0**, caps at **100**, and drives the XP multiplier. **DEF** is hidden legacy storage only; it
is not part of the radar, detail rows, finish heroes, or product copy.

| Stat | Name | What it represents | How it's produced |
|---|---|---|---|
| **STR** | Strength | Strength-biased output | weighted logged **volume** from pressing, pulling, arms, and leg support |
| **AGI** | Agility | Shoulders & core | logged **volume** on shoulders/core |
| **END** | Endurance | Work capacity | logged **reps** (rep-band and muscle weighted) |
| **VIT** | Vitality | Recovery balance | a rolling **14-day rest/training meter** (not volume) |
| **LCK** | Luck | Consistency | current **training streak**, drives an XP multiplier |

### 4.1 Volume, and which muscle feeds which stat

For each logged set, **volume = reps × load**, where `load` = the weight in kg, or **40 kg** if the
exercise is bodyweight / has no entered weight. A session can move more than one visible stat so
focused training creates a shape without leaving other axes dead:

| Primary muscle | STR volume | AGI volume | END reps |
|---|---:|---:|---:|
| chest, triceps, forearms | 1.00× | 0.12× | 1.00× |
| lats, middle back, lower back, biceps, traps, neck | 0.80× | 0.12× | 1.00× |
| quadriceps, hamstrings, glutes, calves, adductors, abductors | 0.10× | 0.07× | 5.00× |
| shoulders, abdominals | 0.20× | 1.00× | 1.10× |

Hidden legacy DEF still accumulates pulling/back/arm volume internally for compatibility, but it is
not displayed.

### 4.2 The volume → stat curve (diminishing returns)

A stat's value from accumulated volume `V` (in kg) is:

```
stat = 10 + floor( 100 × ln( V / 500 + 1 ) )      (capped at 1000)
```

It's **logarithmic** — early training moves the needle fast; veterans grind for small gains.
Worked examples:

| Total volume on that stat | Resulting stat |
|---|---|
| 0 kg | 10 (baseline) |
| 500 kg | ~79 |
| 1,000 kg | ~119 |
| 5,000 kg | ~249 |

### 4.3 END — endurance from reps

END rewards reps, weighted by rep range (higher reps = more endurance) and muscle. Per set:

```
endurance points = reps × (0.5 if reps ≤ 7 ;  1.0 if 8–14 ;  1.5 if reps ≥ 15)
raw END points = endurance points × muscle END weight
END = 10 + floor(100 × ln(raw END points / 150 + 1))      (capped 1000)
```

END is backfilled from existing history because reps are real logged data. Tank's class-focus bonus
lands in END, so leg training reads as durability/work capacity instead of just more STR.

### 4.4 VIT — the recovery meter (the unusual one)

VIT is **not** earned from lifting. It's a **0–100 rolling balance over the last 14 days** (floor
10), measuring whether you're recovering well. Each of the last 14 days earns credit:

- Completed a **scheduled** training day → **1.0**
- Trained on a **rest** day → **0.7** (mild overtraining ding)
- A **planned rest** day → **1.0** (productive recovery)
- A **shielded/protected** missed day → **0.5** (neutral)
- An **unplanned** missed day → **0** (detraining)

`raw = 100 × (sum of credit) / (days counted)`, then scaled by how much of your *scheduled*
training you actually completed, clamped to 10–100. It refreshes live every time stats are read, so
it reflects "today," not just your last save. High VIT = well-recovered and consistent; collapsing
VIT = either skipping or overtraining.

### 4.5 LCK — consistency as luck, and the XP multiplier

```
LCK = current consecutive-day training streak, capped at 100
diamonds = floor(LCK / 25), capped at 4
XP multiplier = 1.0 + 0.5 × diamonds
```

| LCK | Diamonds | XP multiplier |
|---|---|---|
| 0–24 | 0 | 1.0× |
| 25–49 | 1 | 1.5× |
| 50–74 | 2 | 2.0× |
| 75–99 | 3 | 2.5× |
| 100 | 4 | 3.0× |

"The consistent lifter is the lucky one." The multiplier is applied to workout XP at award time.

### 4.6 Ranks, baseline, cap

Each stat shows a letter rank: **D** (<100), **C** (≥100), **B** (≥300), **A** (≥600), **S** (≥900);
all stats cap at 1000 (so S leaves headroom). New lifters promote fast; S is a long grind.

### 4.7 No decay — earned stats are immutable

Inactivity no longer erodes the workout-output stats (**STR, hidden legacy DEF, AGI, END**) — once
earned they never decrease. The old loss-framed decay (×0.9 per unprotected missed day, floored at
half your peak) was **retired**: it punished absence (against the anti-guilt mandate) and overstated
real detraining, which is gradual. Boot still spends rest-day **shields** to protect the consistency
**streak** for missed scheduled days — but it touches no stat. **VIT** (the live recovery/rest-balance
meter) and **LCK** (the live streak) still move with training rhythm; that is their nature as live
meters, not decay of earned progress.

### 4.8 Calibration — where starting stats come from

New no-workout characters start honestly at the baseline: **STR/AGI/END/VIT = 10** and
**LCK = 0**. The onboarding quiz captures self-reported **experience**
(novice / beginner / intermediate / advanced) as training context only; it does not grant stat
value or starting rank. The fantasy stays sticky because the visible growth is fed by logged
workouts.

The only valid calibration seed is workout-derived. If the onboarding path includes an actual
logged calibration run, the app can estimate a per-stat 1RM from those sets using Epley, map it to
strength standards, and store a **workout-sourced seed volume** in the same kg-volume currency the
engine uses. That seed is added *before* the log curve, composes with real training, ratchets upward,
and freezes after the calibration window. Self-report never writes `calibration_seed_volumes_v1`.

---

## 5. XP & leveling

**Session XP (a completed workout):**

```
XP = 50 (base) + 5 × (total sets logged) + 1 × (minutes elapsed)
```

- A **partial** (saved early, still ongoing) session earns **50%** of that.
- An **abandoned** session earns `min(minutes elapsed, target minutes)`.
- Then the **LCK multiplier** (§4.5) and any active **XP-boost potions** (§7) apply on top.

**Levels are quantized** — only specific levels exist, gated by cumulative XP:

| Total XP | Level | Title |
|---|---|---|
| 0 | 1 | Recruit |
| 50 | 2 | Recruit |
| 200 | 3 | Recruit |
| 500 | 5 | Squire |
| 1,500 | 10 | Knight |
| 3,000 | 15 | Knight |
| 5,000 | 20 | Champion |
| 10,000 | 30 | Legend |

Titles by level band: **Recruit** (<5), **Squire** (5–9), **Knight** (10–19), **Champion** (20–29),
**Legend** (30+).

---

## 6. Classes

Four classes give a **session-time mechanical bonus** to the class's visible radar identity, but
only for the class's focus muscles. The class active when a workout is *saved* is stored on that
session, so switching classes later never rewrites old growth.

| Class | Focus muscles | Bonus | Theme color |
|---|---|---|---|
| **Bruiser** | Chest + Back + Arms | +20% → **STR** | red `#FF2D55` |
| **Assassin** | Shoulders + Core | +20% → **AGI** | violet `#B14DFF` |
| **Tank** | Legs | +20% → **END** | cyan `#00BFFF` |

Switching class is a destructive action (resets ultimate progress) and requires explicit
type-to-confirm.

---

## 7. Supporting systems (brief but complete)

- **Quests.** Auto-evaluated from workout history + class focus - *never* manual "Done" buttons for
  unverifiable tasks. Daily quests are fixed checks (show up, train your class focus, hit a daily
  volume floor); you may *claim* completed rewards. New quest claims award earned gems, while legacy
  quest XP remains counted for existing users.
- **Gems.** Earned-only, local-only cosmetic currency from quest claims. There is no IAP, billing,
  subscription, paid pack, or server economy.
- **Loot & inventory.** Cosmetic only (avatar frames, themes). Unlocks are **deterministic
  milestones** keyed to stats/session count, with gem prices for early frame/theme purchases. Class
  frames are still earned through progression. Titles remain achievement-only.
- **Guild.** A **local single-player simulation** with NPC members, deterministic per ISO week. It
  delivers the *social feel* (a "Forge Nods" signal) without any real networking, account, or
  multiplayer — consistent with offline/no-account.
- **Rest & recovery.** Shield charges protect streaks/stats on missed days; planned rest days are
  protected and even productive (they feed VIT). Generates automatic recovery XP (not multiplied by
  LCK).
- **Programs.** Optional structured plans (e.g. PPL, Full Body 3×, Upper/Lower) that schedule a
  muscle group per day and track progress, replacing manual muscle-group selection.
- **Progressive overload.** Suggests the next session's weight/reps per exercise using
  double-progression: **+2.5 kg** when the top set hit the top of its rep range, **repeat** while
  climbing within range, **−2.5 kg** only when a *confident* history shows a real drop below the
  user's own floor (sparse/inconsistent history never deloads — no baseline to judge), **repeat** if
  21+ days since last (detrained), **+1 rep** for bodyweight. The rep target is **history-anchored** —
  it follows the user's demonstrated reps (median of recent top sets, clamped per kind); compound 8 /
  isolation 12 / bodyweight 15 are the novice-default fallback. An onboarding **training-goal**
  (Strength / Muscle / Endurance, asked after the body goal) **seeds** that fallback (5 / 8 / 15) for new
  users until ≥2 sessions of history exist — a cold-start seed, never a clamp on real history. The
  suggestion pre-fills in a muted
  color ("the app's guess") above the first un-logged set; it never auto-commits.
- **Body metrics (opt-in, body-neutral).** Off by default. Log bodyweight **any time**; a
  time-aware EWMA **trend line** (shown once there's enough data) smooths daily noise — the raw
  number is never the headline and there are no red/green arrows. A single **XP-boost potion**
  (3 charges, one spent per eligible workout save — so it boosts the next 3 workouts — expiring after
  3 weeks, multiplier capped at 5.0×) is granted at most once per **rolling 7-day window** — rewarding
  the *act of tracking*, not any particular number. (The old weekly-logging gate and the silent
  direction-aligned bonus were removed.)
- **Calories.** A rough MET-based **estimate** shown on the workout summary only. Not a tracked
  feature, not a goal, never framed as good/bad.

---

## 8. Onboarding (the first-run cinematic)

A multi-screen cinematic sequence sets up the character identity:

```
cold open → problem → solution → calibration quiz → avatar select → name
          → class reveal → generating → rank assessed → start gate → (Home)
```

The **calibration quiz** captures experience (training context only, §4.8), training frequency, sex,
and optional bodyweight. The class reveal assigns a starting class from the answers. Character stats
still start at baseline until real logged training changes them. After onboarding runs once, the app
always opens to the main shell.

---

## 9. Data & persistence

- **Everything is local**, stored as JSON in the device's key–value store (`SharedPreferences`).
  No database server, no API, no network calls, no keys.
- The **completed `WorkoutSession` list** is the master record; combat stats, XP, last-session
  delta, and stat peaks are cached snapshots but are *recomputed from history* when needed.
- A session carries: date, target muscle group, duration (target + actual), the exercises logged
  (each with its sets of weight×reps), the **class at save time**, and the awarded XP snapshot.
- On every app launch the boot sequence runs: data migrations → END backfill → **missed-day shield
  pass** (streak protection; no stat decay) → class auto-assignment for legacy users → onboarding gate
  (new user → onboarding, else → Home).

---

## 10. Navigation & screen map (use this to read the screenshots)

The app is a **4-destination bottom-nav shell with an elevated center Train action**
(**Home · Inventory · ⟨Train⟩ · Guild · Labs**):

| Slot | What it shows / which systems surface |
|---|---|
| **Home** | Character avatar/frame, level + title, build/status stats with ranks, last-session deltas, today's mission, class. Quests, Adventure, and workout **history/calendar** are reached from here (pushed pages). |
| **Inventory** | Loot inventory + the gem Shop; the new-loot badge lives on this icon. |
| **Train** *(center action — not a page)* | Opens exercise selection **in-shell** (nav stays visible; the pick persists as a draft across tabs); the button **arms** once ≥1 lift is chosen and commits via one "START THIS WORKOUT?" confirm. **Resumes** a live session instead, and **pulses** while one runs (it replaced the old always-visible active-workout dock). |
| **Guild** | The local guild simulation — NPC members, weekly social signal. |
| **Labs** | Avatar/name/class, full stat card, settings (opt-in body metrics, progressive-overload toggle), progress charts, and the Programs/Exercise **library**. |

**The workout-logging flow** (the center Train action opens selection in-shell; the Home mission and "repeat" still push it full-screen):

```
Start Workout (pick muscle group → duration → pick exercises)
   → Active Workout (live timer; tap an exercise to log it; rest timer)
      → Exercise Session (log each set: weight + reps; "Finish Exercise")
   → (all exercises done) → Finish Workout
      → Workout Summary (XP awarded, stat deltas, calorie estimate; "Save & Exit")
```

The summary is the payoff screen: it's where **+X STR / +Y AGI / +Z END**, XP, level progress, and any new
loot appear. Saving writes the `WorkoutSession`, which is what makes every downstream system update.

---

## 11. Design language (so visual critique stays on-brand)

- **Pixel arcade, dark-mode only.** Neon-on-near-black, sharp 4px corners, retro-game feel.
- **Palette:** background `#11111F`, card `#1C1C34`, borders `#36365E`, primary neon green
  `#00FF9C`, text `#E8E8FF`, muted text `#9494B8`, amber `#FFD700`, cyan `#00BFFF`, danger red
  `#FF2D55`. Class colors: Assassin violet `#B14DFF`, Bruiser red `#FF2D55`, Tank cyan `#00BFFF`.
- **Type:** PressStart2P for headings, Gotham for body, a monospaced font for timers/counters.
- **Icons:** sharp/angular only (no rounded icons), to match the pixel theme; pixel-art control
  icons where available.
- **Motion:** quick, tactile micro-interactions (button depress, phosphor flash, ambient drift)
  with short durations (~120–220ms).
- **Body-neutral mandate (again):** directional change uses *muted* indicators only — never
  red/green good-vs-bad on bodyweight or deltas; the *absence* of a bonus is just absence, never
  framed as failure.

---

## 12. Cheat-sheet (one-screen recap)

- **Visible radar stats:** STR, AGI, END. Baseline 10, cap 1000, ranks D→S.
- **STR/AGI** = `10 + floor(100·ln(weighted volume/500 + 1))`; volume = reps × (weight or 40).
- **END** = rep-band points × muscle END weight, then `10 + floor(100·ln(points/150 + 1))`.
- **VIT** = 10-100 recovery-balance meter (rest + completed training good; overtraining/skips bad).
- **LCK** = streak (cap 100) → XP multiplier up to **3.0×**.
- **Session XP** = 50 + 5×sets + 1×minute, ×LCK ×potions.
- **Classes** = +20% volume to one stat for focus muscles (Assassin→AGI, Bruiser→STR, Tank→END).
- **Everything derives from the local `WorkoutSession` history.** No account, no IAP; training data
  stays on-device. Earned identity, sticky progress, body-neutral, offline-first. (Anonymous opt-out
  analytics + opt-in crash reporting — ADR 0001.)
