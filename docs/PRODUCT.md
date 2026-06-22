Ironbit is a strength-training app where every logged workout should make the user's character feel
harder to abandon. Real training is the fuel; identity, streak, rank, loot, and ritual are the
psychological engine.

The fantasy works because it is anchored to the user's own effort. Progress should feel sticky
because it is earned, visible, cumulative, and personally named. Every feature should strengthen
one of the long-term hooks: identity attachment, competence growth, collection desire, ritual
return, rank aspiration, or recovery protection.

## Muscle taxonomy

The canonical muscle-group list is **`Chest, Back, Shoulders, Arms, Legs, Core, Full Body`**: seven Title-Case strings. Defined in [lib/data/muscle_groups.dart](../lib/data/muscle_groups.dart). Every UI surface (Start Workout chips, Create Exercise picker, Exercises filter, muscle-balance chart, calorie MET map, class focus mappings) references this single list. `WorkoutSession.muscleGroup` and `Exercise.muscleGroup` are normalized to the canonical form at read-time via `normalizeMuscleGroup(raw)`; no DB rewrite needed.

Detailed muscles in `assets/exercises.json` (chest, lats, biceps, quadriceps, etc.) are mapped to one of the seven canonical buckets via `muscleGroupForDetailed(detailed)`. The detailed-muscle to character-stat weighting stays in `StatEngine`: it operates on detailed muscles, not buckets, to preserve granularity. The visible radar uses `STR / AGI / END`; `DEF` remains only as a hidden legacy accumulator for old local snapshots.

Adding or removing a bucket requires updating: the `canonicalMuscleGroups` list, the `_detailedToBucket` map, `curated_exercises.dart`, `class_definitions.dart` `musclesForClass`, `StatEngine._fallbackPrimary`, `workout_page.dart` `_muscles` + `_muscleColors`, and `CalorieService._metByMuscleGroup`.

## Character stats and XP

The visible stat board has three build-shape stats plus two status meters. `STR / AGI / END` are cumulative workout-output stats and start at 10 so a new character has a visible baseline. `VIT` is a 10-100 recovery-balance meter. `LCK` starts at 0 because it is streak-derived. `DEF` is hidden legacy storage only and should not appear in product copy or UI.

STR and AGI grow from weighted logged kg-volume by primary muscle. END grows from logged reps, weighted by rep range and muscle:

- 1-7 reps: each rep counts 0.5x toward END
- 8-14 reps: each rep counts 1.0x toward END
- 15+ reps: each rep counts 1.5x toward END

END is backfilled from existing workout history because those reps are real logged training data. LCK is not a crit stat and is not a workout-output stat. LCK equals the current training streak capped at 100 and drives an award-time XP multiplier:

- LCK 0-24: 0 diamonds, 1.0x XP
- LCK 25-49: 1 diamond, 1.5x XP
- LCK 50-74: 2 diamonds, 2.0x XP
- LCK 75-99: 3 diamonds, 2.5x XP
- LCK 100: 4 diamonds, 3.0x XP

Workout XP is stored at award time after applying LCK. Active XP potions multiply on top of LCK for workouts. Recovery XP is automatic rest XP and is not multiplied by LCK.

Quests now award earned gems instead of new XP. Legacy claimed quest XP remains counted so existing users do not lose levels, but future quest claims should write `0` XP and the appropriate gem award.

## Classes

Class choice has a session-time mechanical bonus. The class active when the workout is saved is persisted on the `WorkoutSession`, so later class switching does not rewrite old character growth.

- Bruiser: +20% STR effective volume from chest, back, and arms training.
- Assassin: +20% AGI effective volume from shoulders and core training.
- Tank: +20% END effective rep growth from legs training.

The bonus uses actual logged exercise primary-muscle attribution, not only the selected workout target. Tank is END-led so leg training reads as durability/work capacity instead of making every lower-body user look like a Bruiser.

## Quest and ritual design

Quests exist to make the return ritual concrete: open the app, see a mission, train, then watch the
character ledger move. Quest progress must be derivable from workout history or other real app data
so the user trusts that the fantasy is attached to real effort. Daily quests are fixed
auto-evaluated training checks: show up, train class focus, and hit the daily volume floor. Users
may still claim completed rewards, but there is no "Done" button for unverifiable tasks.

## Gems and cosmetic shop

Gems are an earned-only local currency for cosmetic early unlocks. There is no IAP, billing,
subscription, paid pack, or external economy in v1. Gems come from claimable quests:

- daily quests: 5 gems each
- weekly quests: 5 / 5 / 10 / 10 / 20 gems
- side quests: 100 gems and the existing title reward

Frames and themes can have a `gemPrice` and can be purchased early from Inventory. Deterministic
milestone unlocks remain the guaranteed progression path. Titles remain achievement-only and do not
have gem prices.

## Progressive overload guidance

Linear-progression rule, with branches for under-performance and detraining:

- **+2.5 kg** when the previous session's top set met the rep target (smallest jump achievable with standard plates: 1.25 kg x 2 sides).
- **Repeat the same weight** when the rep target was missed by 1-3 reps.
- **-2.5 kg** when a *confident* history shows a session fell well below the user's own demonstrated floor (deload branch). With sparse (<2 clean sessions) or inconsistent/undulating history there is no baseline to judge, so **no deload is suggested** — the engine only encourages.
- **Repeat the previous weight, no increase** when the gap between sessions exceeds 21 days (detrained branch).
- **+1 rep** for bodyweight exercises that met the target; **repeat reps** for those that missed.

Rep targets are **history-anchored**, not fixed. From ≥2 recent sessions the engine takes the median of your **top-set reps** and builds a small range around it — `aim = median + 1` (one rep of headroom, never pushing you above your demonstrated reps), `floor = median − 2` (deload headroom) — clamped to a per-kind band (compound 3-12, isolation 6-20, bodyweight 5-30) and run through the same double-progression machinery as a program prescription. The per-kind constants (`compound = 8`, `isolation = 12`, `bodyweight = 15`) are the **ACSM novice default**, used only as the sparse-history fallback aim. An onboarding **training-goal** pick (Strength / Muscle / Endurance — asked right after the body goal) *seeds* that fallback (5 / 8 / 15 reps) in place of the kind default for new users; once ≥2 sessions of history exist the kind-banded history takes over. The pick seeds the **cold start only** — it never clamps real history (that would re-create the phantom deload for anyone training away from their stated goal). A null pick (legacy users) = the kind default. Kind classification uses `exercises.json` `mechanic` (`compound` / `isolation`) plus a weight-zero heuristic for bodyweight, cached per-exercise in `shared_preferences` under `exercise_kind_cache_v1` (sticky, so a hybrid exercise's clamp band does not flip mid-program).

The suggestion is pre-filled into the set's weight + reps inputs in `kMutedText` to distinguish "the app's guess" from "your entry"; tapping a field brightens it to `kText`. A `TRY: 22.5 kg x 8` label sits above the first un-logged set and follows down as each set is saved. When the user logs Set 1, its values copy into all subsequent empty set rows (linear-progression straight sets). Users can disable suggestions entirely via Profile > Settings > Suggested loads (default on).

This serves beginner and early-intermediate lifters. The rep target is *lightly* autoregulated — it follows your demonstrated rep range — but effort-based autoregulation (RPE/RIR) and block periodization remain deliberately out of scope.
