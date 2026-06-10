# Exercise Picker Overhaul — curated/full-list toggle, filters, validated curation

**Status:** Spec approved, pending implementation plan.
**Scope source:** Pre-workout exercise-selection audit (issues 1–6) + new full-list toggle feature.

## Context

The pre-workout picker (`lib/pages/Workout session/start_workout.dart`) builds its candidate list
exclusively from the hand-authored curated allow-lists (`lib/data/curated_exercises.dart`). The audit
found six issues:

1. **Curated ceiling** — only ~150 of the 873-exercise catalog are ever reachable; search cannot find
   anything outside the curated set.
2. **No equipment filter** — `Exercise.equipment` exists on every catalog entry but is not filterable,
   despite equipment being the #1 real-world constraint.
3. **Unvalidated curation** — no test guards the curated lists. Scripted audit found: 13 unique ids
   with undeclared image assets (render NO PHOTO), 7 stretching entries masquerading as lifts, and
   23 bucket-misaligned entries.
4. **Coarse granularity** — the 7-bucket taxonomy cannot target biceps vs triceps or quads vs calves,
   though `primaryMuscle` data supports it.
5. **Stale doc** — CLAUDE.md still describes a "time picker" on this screen; duration/rest actually
   load silently from `WorkoutDefaultsService` (this is the intended design; fix is docs-only).
6. **Selection sharp edges** — toggling a muscle group wipes manual exercise picks
   (`_selectedExerciseIds = {}` then history re-seed); frequently-used non-top-3 lifts never float up.

**New feature:** a user-facing toggle between the curated default list and the full catalog, so users
who never change defaults are not confronted with hundreds of exercises (default = curated), while
power users get the whole library (fixes issue 1).

## Locked decisions

- **Architecture:** pure pool-builder helper (Approach B) — matches the codebase's pure-helper pattern
  (`applyProgramSwaps`, `nextWorkoutLookahead`); unit-testable; reusable by the program swap sheet later.
- **Granularity (#4):** sub-muscle **filter chips inside the picker** derived from `primaryMuscle`.
  The 7-bucket taxonomy is unchanged everywhere else (sessions, stats, programs).
- **Duration/rest (#5):** keep silent defaults; documentation fix only.
- **Assets (#3):** declare only the 13 missing curated folders (~1.2 MB). Show-all mode renders
  undeclared exercises with the existing `_NoPhotoPlaceholder` (verified present in
  `lib/widgets/exercise_card.dart` via `errorBuilder`).
- **Full-mode content:** exclude `category` ∈ {stretching, cardio} (137 entries) — sets×weight logging
  is meaningless for them. Plyometrics stay (rep-loggable).
- **Toggle:** default **off** (curated); persisted preference (new `WorkoutDefaultsService` key).

## Verified ground truth (scripted, 2026-06-10)

- All 873 catalog entries have `primaryMuscles[0]`; all 17 distinct values map into the 6 concrete
  buckets via `muscleGroupForDetailed` — zero orphans.
- `muscleGroupForDetailed` **never** returns `'Full Body'` → full-mode bucket matching must treat
  `Full Body` in the target set as a **wildcard** (otherwise zero results).
- `category` distribution: strength 581, stretching 123, plyometrics 61, powerlifting 38, olympic 35,
  strongman 21, cardio 14. The `Exercise` model does not yet parse it.
- Equipment distribution: barbell 170, dumbbell 123, other 122, body only 111, cable 81, machine 67,
  kettlebells 53, bands 20, medicine ball 17, exercise ball 12, foam roll 11, e-z curl bar 9, null 77.
- Curated ids not in the catalog: **0**.
- `topExerciseIdsForTargets` production callers: only `start_workout.dart` (+1 test) — refactor safe.

## Design

### 1. Pure pool builder — `lib/data/exercise_pool.dart` (new)

```dart
class ExercisePoolFilters {
  // equipment buckets (multi), sub-muscles (multi), level, favoritesOnly, query
}

List<Exercise> buildCandidatePool({
  required List<Exercise> catalog,
  required List<String> targetGroups,
  required bool fullCatalog,
  List<String> pinnedIds = const [],     // program loadout / current selection
  Map<String, int> usageCounts = const {},
  ExercisePoolFilters filters = const ExercisePoolFilters(),
})
```

- **Curated mode** (`fullCatalog: false`): current behavior — custom exercises matching targets +
  `curatedExerciseIdsForMuscleGroups(targets)` + pinned ids. Byte-for-byte default UX.
- **Full mode**: every catalog exercise whose `primaryMuscle` bucket ∈ targets (custom exercises match
  on `muscleGroup`), **`Full Body` in targets = wildcard**, minus `category` ∈ {stretching, cardio}.
  Curated ids render as the pinned first section; the tail is alphabetical under a muted
  `MORE EXERCISES` divider.
- **Ordering**: pinned/selected → usage count desc → curated order → alphabetical.
- **Equipment bucketing** (helper in the same file): Barbell (barbell, e-z curl bar), Dumbbell,
  Machine, Cable, Bodyweight (body only), Kettlebell (kettlebells), Bands, Other (balls, foam roll,
  other, null).
- **Sub-muscle availability** (helper): the set of `primaryMuscle` values present in the unfiltered
  pool; the UI shows the row only when ≥ 2 values have hits.

### 2. Model — `Exercise.category` (additive)

Parse `json['category']` into a nullable `category` field (`lib/models/workout_models.dart`).
Custom exercises: null (treated as strength — never excluded). Include in `toJson` only when set.

### 3. UI — `start_workout.dart` (thinned consumer)

- **`FULL LIST` `ArcadeChip`** beside FILTER. Persisted via new `WorkoutDefaultsService`
  `getShowFullExercisePool()`/`setShowFullExercisePool(bool)` (default false). Program mode: toggle
  available, pool stays locked to the day's muscle groups.
- Expanded filter panel adds **equipment chips (multi-select)** and the **contextual sub-muscle row**
  (label set: Biceps/Triceps/Forearms, Quads/Hamstrings/Glutes/Calves/Abductors/Adductors,
  Lats/Mid Back/Lower Back/Traps, Shoulders/Neck — shown only when ≥2 have hits). `Clear` resets
  level + favorites + equipment + sub-muscles.
- **Lazy list**: restructure the body so exercise cards render via `ListView.builder`, with the
  target/search/filter headers as leading list items — required for 700+ cards in full mode.
- Search/level/favorites behave as today but operate on whichever pool is active.

### 4. Selection-state fixes — `start_workout.dart` + `workout_storage_service.dart`

- `_toggleMuscleGroup`: new selection = old selection ∩ new pool (bucket match); history top-3 seeds
  **only when the resulting selection is empty**. Program mode preselection unchanged.
- Extract the counting loop of `topExerciseIdsForTargets` into `usageCountsForTargets` (returns
  counts + lastSeen); top-3 keeps identical behavior; the pool builder consumes the counts for
  float-up ordering.

### 5. Curated data cleanup — `curated_exercises.dart` + `pubspec.yaml`

- **Declare 13 folders** (~1.2 MB): Standing_Military_Press, Dumbbell_Shoulder_Press,
  Arnold_Dumbbell_Press, Side_Lateral_Raise, Face_Pull, Plank, Hanging_Leg_Raise, Russian_Twist,
  Crunches, Barbell_Ab_Rollout_-_On_Knees, Dead_Bug, Mountain_Climbers, Air_Bike.
- **Prune stretching entries** (7 instances / 5 ids): Behind_Head_Chest_Stretch,
  Seated_Front_Deltoid (Chest+Shoulders), Overhead_Lat (Back+Shoulders), Overhead_Triceps,
  Seated_Biceps.
- **Prune misaligned copies** — each pruned id already lives in (or simply leaves for) its correct
  bucket: from Chest: Alternating_Renegade_Row, Press_Sit-Up,
  Handstand_Push-Ups, Push_Press; from Arms: Handstand_Push-Ups, Plyo_Kettlebell_Pushups, Push_Press,
  One-Arm_Kettlebell_Snatch, Clean_and_Jerk; from Shoulders: Plyo_Kettlebell_Pushups, Neck_Press;
  from Core: Glute_Ham_Raise, Alternating_Renegade_Row, Plyo_Kettlebell_Pushups,
  One-Arm_Kettlebell_Floor_Press, Leg-Over_Floor_Press, One-Arm_Kettlebell_Snatch.
- **Documented exceptions const** (deliberate cross-bucket keeps): Bench_Press_with_Chains → Chest,
  Upright_Cable_Row → Shoulders, Kettlebell_Sumo_High_Pull → Shoulders, Mountain_Climbers → Core.
- Post-prune bucket sizes: Chest 24, Back 29, Arms 23, Legs 30, Shoulders 11, Core 9 — all healthy.

### 6. Validation test — `test/curated_exercises_test.dart` (new)

For every curated id: (a) exists in `assets/exercises.json`; (b) image folder declared in
`pubspec.yaml` (read both files directly in the test); (c) `category` ∉ {stretching, cardio};
(d) `primaryMuscle` bucket == curated bucket, modulo the exceptions const ('Full Body' exempt from
(d) only). This is the drift guard the audit found missing.

### 7. Docs

- Root `CLAUDE.md` workout-flow description: remove "time picker" mention; note the curated/full
  toggle and silent duration/rest defaults.

## Tests

- `test/exercise_pool_test.dart` — curated vs full membership; Full Body wildcard; stretching/cardio
  exclusion; ordering (pinned → usage → curated order → alpha); equipment bucketing incl. null→Other;
  sub-muscle filter; level/favorites/query; custom-exercise inclusion in both modes.
- `test/curated_exercises_test.dart` — as §6.
- Widget test: select an exercise → add a second muscle group → selection preserved; history seeding
  only on empty.
- Existing suites must stay green (`multi_muscle_targets_test.dart` covers the top-3 refactor).

## Verification

1. `flutter analyze` — zero new issues (12 pre-existing avatar/profile test errors are baseline).
2. `flutter test` — full suite + new tests green.
3. Manual (Android): default picker unchanged (curated, images everywhere — incl. the 13 newly
   declared); FULL LIST on → curated section first, `MORE EXERCISES` tail, search finds non-curated
   movements, no jank while scrolling; equipment chip Dumbbell+Bodyweight filters correctly;
   Arms → sub-muscle chips Biceps/Triceps/Forearms work; toggle state survives app restart; program
   day start: toggle expands within the day's muscles only; muscle-group toggle keeps manual picks.

## Out of scope

Swap-sheet adoption of the pool builder (follow-up), shipping all 873 image sets, duration/rest
controls on the review screen, any change to the 7-bucket taxonomy outside the picker, per-exercise
favorites redesign.
