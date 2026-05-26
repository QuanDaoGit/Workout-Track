"Workout Tracker is a strength-training app with an RPG visualization layer. Real workout data is the only input to character growth. Every feature must translate training into RPG language, or be cut."

## Muscle taxonomy

The canonical muscle-group list is **`Chest, Back, Shoulders, Arms, Legs, Core, Full Body`**: seven Title-Case strings. Defined in [lib/data/muscle_groups.dart](lib/data/muscle_groups.dart). Every UI surface (Start Workout chips, Create Exercise picker, Exercises filter, muscle-balance chart, calorie MET map, class focus mappings) references this single list. `WorkoutSession.muscleGroup` and `Exercise.muscleGroup` are normalized to the canonical form at read-time via `normalizeMuscleGroup(raw)`; no DB rewrite needed.

Detailed muscles in `assets/exercises.json` (chest, lats, biceps, quadriceps, etc.) are mapped to one of the seven canonical buckets via `muscleGroupForDetailed(detailed)`. The detailed-muscle to character-stat mapping (for example, `lats` to `DEF`, `biceps` to `DEF`, `chest` to `STR`) stays in `StatEngine`: it operates on detailed muscles, not buckets, to preserve granularity.

Adding or removing a bucket requires updating: the `canonicalMuscleGroups` list, the `_detailedToBucket` map, `curated_exercises.dart`, `class_definitions.dart` `musclesForClass`, `StatEngine._fallbackPrimary`, `workout_page.dart` `_muscles` + `_muscleColors`, and `CalorieService._metByMuscleGroup`.

## Character stats and XP

STR, DEF, VIT, AGI, and END are cumulative workout-output stats. They start at 10 so a new character has a visible baseline; LCK starts at 0 because it is streak-derived. STR/DEF/VIT/AGI are derived from logged exercise volume by primary muscle. END is class-neutral and grows from logged reps:

- 1-7 reps: each rep counts 0.5x toward END
- 8-14 reps: each rep counts 1.0x toward END
- 15+ reps: each rep counts 1.5x toward END

END is backfilled from existing workout history because those reps are real logged training data. LCK is not a crit stat and is not a workout-output stat. LCK equals the current training streak capped at 100 and drives an award-time XP multiplier:

- LCK 0-24: 0 diamonds, 1.0x XP
- LCK 25-49: 1 diamond, 1.5x XP
- LCK 50-74: 2 diamonds, 2.0x XP
- LCK 75-99: 3 diamonds, 2.5x XP
- LCK 100: 4 diamonds, 3.0x XP

Workout XP and claimable quest XP are stored at award time after applying LCK. Active XP potions multiply on top of LCK for workouts. Recovery XP is automatic rest XP and is not multiplied by LCK.

Quest XP values are base values. Balance future quest rewards assuming a committed user can receive up to 3.0x from LCK before any separate potion effects.

## Classes

Class choice has a session-time mechanical bonus. The class active when the workout is saved is persisted on the `WorkoutSession`, so later class switching does not rewrite old character growth.

- Bruiser: +20% STR effective volume from chest, back, and arms training.
- Assassin: +20% AGI effective volume from shoulders and core training.
- Tank: +20% VIT effective volume from legs training.

The bonus uses actual logged exercise primary-muscle attribution, not only the selected workout target. END has no class bonus.

## Quest ethics

Manual-confirm quests are deliberately not used. Quest progress must be derivable from workout history or other real app data. Daily quests are fixed auto-evaluated training checks: show up, train class focus, and hit the daily volume floor. Users may still claim completed rewards, but there is no "Done" button for unverifiable tasks.

## Progressive overload guidance

Linear-progression rule, with branches for under-performance and detraining:

- **+2.5 kg** when the previous session's top set met the rep target (smallest jump achievable with standard plates: 1.25 kg x 2 sides).
- **Repeat the same weight** when the rep target was missed by 1-3 reps.
- **-2.5 kg** when the target was missed by 4+ reps (deload branch).
- **Repeat the previous weight, no increase** when the gap between sessions exceeds 21 days (detrained branch).
- **+1 rep** for bodyweight exercises that met the target; **repeat reps** for those that missed.

Rep targets are per-exercise-kind: `compound = 8`, `isolation = 12`, `bodyweight = 15`. Classification uses `exercises.json` `mechanic` field (`compound` / `isolation`) plus a weight-zero heuristic for bodyweight, cached per-exercise in `shared_preferences` under `exercise_kind_cache_v1`. The cache is sticky once written so a hybrid exercise (bodyweight then weighted vest) does not flip its rep target mid-program.

The suggestion is pre-filled into Set 1's weight + reps inputs in `kMutedText` to distinguish "the app's guess" from "your entry"; tapping a field brightens it to `kText`. A `TRY: 22.5 kg x 8` label sits above Set 1 only. When the user logs Set 1, its values copy into all subsequent empty set rows (linear-progression straight sets). Users can disable suggestions entirely via Profile > Settings > Suggested loads (default on).

This serves beginner and early-intermediate lifters. Advanced periodization (RPE, autoregulation, block programming) is deliberately out of scope.
