"Workout Tracker is a strength-training app with an RPG visualization layer. Real workout data is the only input to character growth. Every feature must translate training into RPG language, or be cut."

## Muscle taxonomy

The canonical muscle-group list is **`Chest, Back, Shoulders, Arms, Legs, Core, Full Body`** — seven Title-Case strings. Defined in [lib/data/muscle_groups.dart](lib/data/muscle_groups.dart). Every UI surface (Start Workout chips, Create Exercise picker, Exercises filter, muscle-balance chart, calorie MET map, class focus mappings) references this single list. `WorkoutSession.muscleGroup` and `Exercise.muscleGroup` are normalized to the canonical form at read-time via `normalizeMuscleGroup(raw)`; no DB rewrite needed.

Detailed muscles in `assets/exercises.json` (chest, lats, biceps, quadriceps, …) are mapped to one of the seven canonical buckets via `muscleGroupForDetailed(detailed)`. The detailed-muscle → combat-stat mapping (e.g. `lats → DEF`, `biceps → DEF`, `chest → STR`) stays in `StatEngine` — it operates on detailed muscles, not buckets, to preserve granularity.

Adding or removing a bucket requires updating: the `canonicalMuscleGroups` list, the `_detailedToBucket` map, `curated_exercises.dart`, `class_definitions.dart` `musclesForClass`, `StatEngine._fallbackPrimary`, `workout_page.dart` `_muscles` + `_muscleColors`, and `CalorieService._metByMuscleGroup`.

## Progressive overload guidance

Linear-progression rule, with branches for under-performance and detraining:

- **+2.5 kg** when the previous session's top set met the rep target (smallest jump achievable with standard plates: 1.25 kg × 2 sides).
- **Repeat the same weight** when the rep target was missed by 1–3 reps.
- **−2.5 kg** when the target was missed by 4+ reps (deload branch).
- **Repeat the previous weight, no increase** when the gap between sessions exceeds 21 days (detrained branch).
- **+1 rep** for bodyweight exercises that met the target; **repeat reps** for those that missed.

Rep targets are per-exercise-kind: `compound = 8`, `isolation = 12`, `bodyweight = 15`. Classification uses `exercises.json` `mechanic` field (`compound` / `isolation`) plus a weight-zero heuristic for bodyweight, cached per-exercise in `shared_preferences` under `exercise_kind_cache_v1`. The cache is sticky once written so a hybrid exercise (bodyweight then weighted vest) doesn't flip its rep target mid-program.

The suggestion is pre-filled into Set 1's weight + reps inputs in `kMutedText` to distinguish "the app's guess" from "your entry"; tapping a field brightens it to `kText`. A `TRY: 22.5 kg × 8` label sits above Set 1 only. When the user logs Set 1, its values copy into all subsequent empty set rows (linear-progression straight sets). Users can disable suggestions entirely via Profile → Settings → Suggested loads (default on).

This serves beginner and early-intermediate lifters. Advanced periodization (RPE, autoregulation, block programming) is deliberately out of scope.
