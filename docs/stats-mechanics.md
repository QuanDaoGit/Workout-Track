# Ironbit Stats Mechanics

Last verified against code: 2026-06-01.

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
| LCK | Luck | Current consecutive training-day streak | 0-100 |

`STR / AGI / END` are the radar stats. `VIT` and `LCK` render as separate rows because they are recovery/consistency meters, not build-shape stats.

Workout-output stats start at `10`. LCK starts at `0`.

`DEF` is not a displayed stat anymore. The engine still keeps a hidden legacy `DEF` accumulator so old local snapshots and storage keys decode safely, but it should not appear in radar, detail rows, finish heroes, or product copy.

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

For each completed, non-abandoned workout session, each set contributes volume:

```text
weighted set volume = reps * load
```

If a set has `weight == 0`, the engine uses `40kg` as a bodyweight proxy.

For STR / AGI, weighted raw volume is converted with a logarithmic curve:

```text
stat gain from volume = floor(100 * ln(volume / 500 + 1))
displayed stat = min(1000, 10 + stat gain)
```

This gives fast early movement and slower late-game growth.

### Muscle-To-Visible-Stat Weights

Each logged exercise can move more than one visible stat. This keeps the radar readable: focused training creates a clear shape, but non-focus axes do not look dead.

| Primary muscle | STR volume weight | AGI volume weight | END rep weight |
|---|---:|---:|---:|
| chest, triceps, forearms | `1.00x` | `0.12x` | `1.00x` |
| lats, middle back, lower back, biceps, traps, neck | `0.80x` | `0.12x` | `1.00x` |
| quadriceps, hamstrings, glutes, calves, adductors, abductors | `0.10x` | `0.07x` | `5.00x` |
| shoulders, abdominals | `0.20x` | `1.00x` | `1.10x` |

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

LCK is not a workout-output stat. It is the current consecutive training-day streak, capped at `100`.

```text
LCK = min(currentTrainingStreak, 100)
```

LCK diamonds:

| LCK | Diamonds | XP multiplier |
|---:|---:|---:|
| 0-24 | 0 | `1.0x` |
| 25-49 | 1 | `1.5x` |
| 50-74 | 2 | `2.0x` |
| 75-99 | 3 | `2.5x` |
| 100 | 4 | `3.0x` |

LCK affects XP multiplier and cache rarity shift. It should not be plotted on the same scale as STR/AGI/END.

## Class Bonuses

Class bonuses add `+20%` extra growth on class-focus muscles, but the bonus lands on the class's visible radar identity.

| Class | Focus muscles | Bonus stat |
|---|---|---|
| Assassin | Shoulders + Core | AGI |
| Bruiser | Chest + Back + Arms | STR |
| Tank | Legs | END |
| Vanguard | All buckets | Same stat the trained muscle already feeds |

Example: a Bruiser training back gets visible STR support from the base pulling weight and an extra `20%` class-bonus volume contribution into STR. A Tank training legs gets END-biased rep growth plus the Tank END bonus.

## Calibration Seed

Calibration can seed starting capability by writing seed volume in the same currency the normal stat formula consumes.

Current constraints:

- Calibration seed currently applies to the legacy kg-volume seed path (`STR / DEF / AGI`) for compatibility.
- END is not seeded, because it is rep-band derived.
- VIT is not seeded, because it is the recovery meter.
- The seed composes with real training and is recomputed through the same stat curve.

## Last-Session Delta

After stats are recomputed, the engine stores a latest-session delta.

Delta rules:

- Only stats touched by the latest session are included.
- STR / AGI / END can appear if the workout affected them.
- LCK appears only when it increases.
- VIT is recomputed from recovery state and is not treated as a per-session gain.
- DEF can still exist in stored internal deltas, but visible UI filters it out.

This delta drives finish-summary stat gains and recent-session tags.

## Decay

Internal decay applies only to `STR`, hidden legacy `DEF`, `AGI`, and `END`.

VIT and LCK do not use this decay path. DEF remains in this internal decay path only as a hidden legacy stat.

On app startup, missed scheduled training days since the last completed session are evaluated. Shielded misses are protected. Decay starts after the first unprotected missed day in a chain:

```text
decayUnits = max(0, unprotectedMissedTrainingDays - 1)
```

For each decay unit:

```text
newValue = max(floor(peak * 0.5), floor(currentValue * 0.9))
```

The stat cannot decay below 50% of its historical peak.

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

XP level gates:

| Level | Total XP |
|---:|---:|
| 1 | 0 |
| 2 | 50 |
| 3 | 200 |
| 5 | 500 |
| 10 | 1500 |
| 15 | 3000 |
| 20 | 5000 |
| 30 | 10000 |

Rank title by level:

| Level | Rank |
|---:|---|
| 1-4 | Recruit |
| 5-9 | Squire |
| 10-19 | Knight |
| 20-29 | Champion |
| 30+ | Legend |

## Suggested Loads

Suggested loads are opt-in and default off unless the user explicitly enables them.

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
estimated 1RM = weight * (1 + reps / 30)
```

For bodyweight sets, the same `40kg` bodyweight proxy is used.

## Storage Keys

Important stat-related local keys:

| Key | Purpose |
|---|---|
| `combat_stats` | current persisted stat snapshot |
| `combat_stat_peaks` | historical peaks for decay floors |
| `combat_stat_last_delta` | latest-session stat delta |
| `combat_stats_last_session_date` | last completed stat-producing session date |
| `combat_stats_last_decay_date` | last decay application date |
| `calibration_seed_volumes_v1` | calibration seed volume |
| `workout_sessions` | saved workout history |
| `rest_state_v1` | recovery schedule, shields, rest claims |
