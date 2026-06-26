# Ironbit Stats Mechanics

Last verified against code: 2026-06-12 (stats rules v3 — intensity currency).

This document describes the current character-stat system as implemented in `StatEngine`, `XpService`, `RestService`, and `ProgressiveOverloadService`.

## Core Rule

Real workout history is the source of character growth.

Ironbit's visible stat board has three graded capability stats, plus two separate status rows:

| Stat | Meaning | Source | Scale |
|---|---|---|---|
| STR | Strength | Weighted logged kg-volume from strength-biased muscles | 10-1000 |
| AGI | Agility | Weighted logged kg-volume from shoulders/core and support work | 10-1000 |
| END | Endurance | Weighted logged reps, scaled logarithmically | 10-1000 |
| VIT | Vitality | Recovery and training-balance meter | 10-100 |
| LCK | Luck | Weekly consistency streak (clean weeks on the training schedule) | 0-100 |

`STR / AGI / END` are the radar stats. `VIT` and `LCK` render as separate rows because they are recovery/consistency meters, not build-shape stats.

Workout-output stats start at `10`. LCK starts at `0`.

`DEF` is not a displayed stat anymore. The engine still keeps a hidden legacy `DEF` accumulator so old local snapshots and storage keys decode safely, but it should not appear in radar, detail rows, finish heroes, or product copy.

## Radar Readability Rule

The visible radar must be readable in roughly five seconds. For class-focus training, the top visible axis should point to the user's training identity:

| Top axis | Intended read |
|---|---|
| STR | Bruiser |
| AGI | Assassin |
| END | Tank |

The app test suite includes deterministic proxy coverage for this invariant, and the human validation protocol lives in `docs/radar-readability-validation.md`. The proxy is useful for regression safety, but the product goal is not considered fully proven until blind users can guess the class from the radar with greater than `70%` accuracy.

The default stat card includes a compact, class-neutral legend under the radar:

```text
STR POWER · AGI CONTROL · END STAMINA
```

It also shows a class-neutral build read derived from the dominant axis:

```text
BUILD: POWER | CONTROL | STAMINA | BALANCED
```

This explains the axes and the visible shape without revealing the user's class.

## Grade Ladder

The same grade helper is used for stat chips:

| Grade | Threshold |
|---|---:|
| D | `< 100` |
| C | `>= 100` |
| B | `>= 300` |
| A | `>= 600` |
| S | `>= 900` |

Stat values cap at `1000`, except VIT, which caps at `100`.

## STR / AGI Volume Formula

For each completed, non-abandoned workout session, each set contributes
**intensity credit** — the set's Epley e1RM-equivalent, not raw tonnage:

```text
set credit = load * (1 + min(reps, 12) / 30)
```

Heavy work outranks light work at equal tonnage (a 3×5 @ 100kg banks ~351
credit, a 3×25 @ 20kg banks ~84), and reps above 12 add no extra strength
credit, so high-rep fluff cannot farm STR. Credit is *summed* across sets — a
single heavy max cannot dominate consistent training. (Unlike calibration's
1RM detection, which *skips* sets above 12 reps, growth credit caps reps
instead of skipping so every logged set still moves the number.)

If a set has `weight == 0`, the load is `%BW × bodyweight`: the fraction comes
from a per-movement table (`data/bodyweight_loads.dart` — push-up ≈ `0.65`,
pull-up/chin-up/dip/squat/pistol = `1.0`, lunge/step-up = `0.85`, unknown
defaults to `0.65`) and the bodyweight from the session's save-time snapshot
(`WorkoutSession.bodyweightKgAtSave`, captured like `classAtSave`). Sessions
without a snapshot carry the last-known one forward, bottoming out at a
deterministic `70kg` fallback. Snapshots are frozen at save: profile edits
never rewrite the strength credit of past sessions.

For STR / AGI, accumulated credit is converted with a logarithmic curve:

```text
stat gain from volume = floor(100 * ln(volume / 120 + 1))
displayed stat = min(1000, 10 + stat gain)
```

This gives fast early movement and slower late-game growth. The `120` scale
(`StatEngine.volumeCurveScale`) replaced the tonnage-era `500` so a
representative session keeps roughly the same early pacing in the new
currency.

### Muscle-To-Visible-Stat Weights

Each logged exercise can move more than one visible stat. This keeps the radar readable: focused training creates a clear shape, but non-focus axes do not look dead.

| Primary muscle | STR volume weight | AGI volume weight | END rep weight |
|---|---:|---:|---:|
| chest, triceps, forearms | `1.00x` | `0.12x` | `1.00x` |
| lats, middle back, lower back, biceps, traps, neck | `0.80x` | `0.12x` | `1.00x` |
| quadriceps, hamstrings, glutes, calves, adductors, abductors | `0.22x` | `0.07x` | `5.00x` |
| shoulders, abdominals | `0.20x` | `1.00x` | `1.10x` |

Legs at `0.22x` (raised from `0.10x` in v3) let heavy squats read as real
strength under the intensity currency while END stays the dominant visible
axis for leg training — pushing this above ~`0.22x` flips the Tank radar
identity to STR.

VIT is not fed by any muscle. Hidden legacy DEF still receives pulling/back/arm volume internally for compatibility, but it is not part of the visible stat board.

## END Formula

END comes from reps, weighted toward higher-rep work and lower-body durability work.

Per set:

| Rep range | END multiplier |
|---|---:|
| 1-7 reps | `0.5x` |
| 8-14 reps | `1.0x` |
| 15+ reps | `1.5x` |

```text
raw END points = sum(reps * rep_band_multiplier * muscle_END_weight)
END gain = floor(100 * ln(raw_END_points / 150 + 1))
displayed END = min(1000, 10 + END gain)
```

This logarithmic scaling prevents END from capping for every normal 20-session history.

## VIT Formula

VIT is a rolling recovery-balance meter over the last 14 days.

> **Outward use (Adventure, shipped 2026-06-13):** VIT is the only stat that scales an Adventure
> expedition. Captured & frozen at dispatch, it maps across its real [10,100] domain to the haul's
> **duration (4–8h)** and **gem multiplier (1.0–1.4×)** — well-recovered characters roam longer and
> pay richer. See `AdventureService.durationForVit` / `multiplierForVit`. (STR/AGI/END set the
> route's rank/base pay; VIT scales the haul on top.)


It rewards:

- completing scheduled training days
- resting on planned rest days
- using shield protection for missed training days

It penalizes:

- unplanned missed training days
- too much unscheduled rest-day training, mildly
- inactivity, by scaling down when scheduled training is not completed

Credit rules:

| Day outcome | Credit |
|---|---:|
| completed scheduled workout | `1.0` |
| planned rest day | `1.0` |
| protected miss | `0.5` |
| unplanned miss | `0.0` |
| workout on rest day | `0.7` |

Then:

```text
raw VIT = round(100 * sumCredit / consideredDays)
activityFactor = completedScheduledTrainingDays / scheduledTrainingDays
VIT = clamp(round(raw VIT * activityFactor), 10, 100)
```

If there is no usable recovery history yet, VIT is `10`.

## LCK Formula

LCK is not a workout-output stat. It is a **weekly consistency streak**: the number of full
7-day blocks the user has sustained since the streak began, capped at `100`.

```text
LCK = min(floor(daysSinceStreakStart / 7), 100)
```

The streak is **skip-only reset**: it survives indefinitely and resets to `0` only on an
*unscheduled recovery* — a scheduled training day that passed with no completed workout and no
shield (a `RestDayKind.unplannedMiss`). Shielded misses and gaps on non-scheduled days never
reset it. `streakStart` is the day after the most recent unprotected missed scheduled day, or the
user's first completed workout if they have never missed one. Today is never counted as a miss, so
the current day is always still available to train. Implemented as
`RestService.consistencyWeeks` and surfaced as `LCK` by `StatEngine`.

LCK diamonds (fast-start weekly ladder):

| LCK (clean weeks) | Diamonds | XP multiplier |
|---:|---:|---:|
| 0 | 0 | `1.0x` |
| 1-2 | 1 | `1.5x` |
| 3-5 | 2 | `2.0x` |
| 6-9 | 3 | `2.5x` |
| 10+ | 4 | `3.0x` |

LCK affects XP multiplier and cache rarity shift. It should not be plotted on the same scale as STR/AGI/END.

## Class Bonuses

Class bonuses add `+20%` extra growth on class-focus muscles, but the bonus lands on the class's visible radar identity.

| Class | Focus muscles | Bonus stat |
|---|---|---|
| Assassin | Shoulders + Core | AGI |
| Bruiser | Chest + Back + Arms | STR |
| Tank | Legs | END |

Example: a Bruiser training back gets visible STR support from the base pulling weight and an extra `20%` class-bonus volume contribution into STR. A Tank training legs gets END-biased rep growth plus the Tank END bonus.

## Calibration Seed

Self-reported quiz experience does not seed stats. A level-1 user with no completed workout history stays at the baseline values above.

Calibration can seed capability only when it is derived from real logged workout sets. That workout-derived seed writes volume in the same currency the normal stat formula consumes.

Current constraints:

- Calibration seed currently applies to the legacy kg-volume seed path (`STR / DEF / AGI`) for compatibility.
- END is not seeded, because it is rep-band derived.
- VIT is not seeded, because it is the recovery meter.
- The seed composes with real training and is recomputed through the same stat curve.
- Future seed writes should mark `calibration_seed_source_v1 = workout`.

## Last-Session Delta

After stats are recomputed, the engine stores a latest-session delta.

Delta rules:

- Only stats touched by the latest session are included.
- STR / AGI / END can appear if the workout affected them.
- LCK appears only when it increases.
- VIT is recomputed from recovery state and is not treated as a per-session gain.
- DEF can still exist in stored internal deltas, but visible UI filters it out.

This delta drives finish-summary stat gains and recent-session tags.

## Decay (removed — earned stats are immutable)

Inactivity no longer decays earned stats. `STR`, `AGI`, `END` (and hidden legacy `DEF`) never
decrease once earned. The old loss-framed decay factor (`combat_decay_factor_v1`, ×0.97 per
unprotected missed training day, floored at half) was **retired**: it punished absence (against the
anti-guilt mandate) and overstated real detraining, which is gradual.

On app startup, `StatEngine.processMissedTrainingDays` still evaluates missed scheduled training days
since the last completed session and **spends shields to protect the streak** (the rest/consistency
mechanic) — but it no longer lowers any stat. `MigrationService.runDecayRemovalOnce` clears the legacy
decay factor once and, if a board was currently decayed, recomputes it upward (un-decayed) with the
one-time delta suppressed so the gain never surfaces as a fake board jump.

VIT (the live recovery/rest-balance meter) and LCK (the live streak) still move with training rhythm —
that is their nature as live meters, not decay of earned progress.

## Adventure (rank consumption)

Adventure (`AdventureService`, key `adventure_state_v1`) is the economy consumer of absolute
ranks: a completed workout dispatches an expedition whose gem payout is set by `getRank` on the
chosen route's stat (D/C/B/A/S → 8/12/18/26/40 base, ±30% rolled **at dispatch**, seeded by the
expedition id so a reopen can never reroll). Rank is captured at dispatch and stored. Adventure
is strictly read-only over the stat board, XP, and workout history; its only writes are its own
state key and idempotent gem-ledger entries (`adventure:<expeditionId>`). Caps: one dispatch per
day, five per ISO week, max-anchored against clock rollback; clock-forward manipulation is an
accepted offline trust boundary (consistent with quests/LCK) that still costs one real logged
workout (≥1 set with reps) per dispatch.

## Rules-Version Migration (Grandfather Floor)

`StatEngine.statsRulesVersion` (currently `3`) is bumped whenever the stat
formula changes; `MigrationService.runStatsRecomputeIfRulesChanged` recomputes
cached stats at app-update boot so a re-tune never lands mid-workout.

At the v3 migration (tonnage → intensity currency), the visible STR/AGI a user
had already earned under the old rules is captured once as a **grandfather
floor** (`combat_stat_floor_v1`). The engine clamps every later recompute to at
least these values, so the rules change can never read as lost progress. Normal
growth continues above the floor. The floor is only
written when real completed sessions back the cached board; a cached value with
no history behind it (corruption, cleared data) is recomputed away instead.

## XP Mechanics

Completed workout base XP:

```text
base XP = 50 + (5 * logged set count) + elapsedMinutes
```

New completed sessions are reward-eligible only if at least one is true:

- duration is at least 15 minutes
- volume is at least 200kg
- exercise count is at least 3

If not eligible:

- session still saves
- XP is `0`
- potion is not consumed
- cache drop does not roll

If eligible:

```text
awarded XP = round(base XP * LCK multiplier * potion multiplier) + lootBonusXP
```

Loot bonus XP is additive and is not multiplied.

XP levels follow a **concave, contiguous** curve — every integer level exists,
fast early, gently slowing, no late dead-end:

```text
level(totalXP) = 1 + floor(sqrt(totalXP / 11))
xpForLevel(L)  = 11 * (L - 1)^2     // total XP at which level L begins
```

`k = 11` is the largest scale that keeps every legacy threshold at or above its
old level (50→2, 200→3, 500→5, 1500→10, 3000→15, 5000→20, 10000→30), so the
re-derivation on update can never demote a user's level or rank. Representative
points:

| Total XP | Level |
|---:|---:|
| 11 | 2 |
| 44 | 3 |
| 176 | 5 |
| 1,100 | 11 |
| 5,000 | 22 |
| 10,000 | 31 |

Rank title by level:

| Level | Rank |
|---:|---|
| 1-4 | Recruit |
| 5-9 | Squire |
| 10-19 | Knight |
| 20-29 | Champion |
| 30+ | Legend |

## Suggested Loads

Suggested loads are **on by default** from first install.

A TRY suggestion appears only after at least 5 logged sets for that exercise.

It never auto-fills Set 1. The user must tap `TRY`.

Targets:

| Exercise kind | Target reps |
|---|---:|
| Compound | 8 |
| Isolation | 12 |
| Bodyweight | 15 |

Weighted progression:

- 14+ day break: suggest `lastLoad * 0.95`
- target met: suggest `lastLoad + 2.5kg`
- small shortfall: hold load, aim for target reps
- larger shortfall: deload to `lastLoad * 0.95`
- cap suggestion at `0.9 * estimated 1RM`

Bodyweight progression:

- target met: add `+1 rep`
- target missed: repeat target reps

Estimated 1RM uses Epley:

```text
estimated 1RM = weight * (1 + reps / 30)   (reps > 1)
estimated 1RM = weight                      (reps == 1 — a single IS the max;
                                             Epley overshoots ~3.3% at 1 rep)
```

For bodyweight sets, the same `40kg` bodyweight proxy is used.

## Storage Keys

Important stat-related local keys:

| Key | Purpose |
|---|---|
| `combat_stats` | current persisted stat snapshot |
| `combat_stat_peaks` | historical per-stat peaks |
| `combat_stat_last_delta` | latest-session stat delta |
| `combat_stats_last_session_date` | last completed stat-producing session date |
| `combat_stat_floor_v1` | grandfather floor from the v3 rules migration |
| `stats_rules_version_v1` | last stat-rules version the cache was computed under |
| `calibration_seed_volumes_v1` | workout-derived calibration seed volume |
| `workout_sessions` | saved workout history |
| `rest_state_v1` | recovery schedule, shields, rest claims |
| `adventure_state_v1` | Adventure orders, pending expedition, day/week caps, report history |
