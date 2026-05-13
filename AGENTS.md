# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Working Rules

**Before starting any task:**
- Read PRD.md for scope and intent.
- Ask clarifying questions until 95% confident. Do not make any assumptions.

**After every major step:**
1. Run `flutter analyze` — zero issues required.
2. Run `flutter test` if tests exist.
3. Always screenshot the affected UI section.
4. Review: theme coherence, design consistency, functionality correctness.
5. Fix all issues before proceeding.

**Always:**
- One change at a time. Never rewrite whole files unless explicitly asked.
- State after each change: what changed, which file, what to test.
- Never build features outside PRD.md without asking first.

---

## Commands

```bash
flutter pub get          # Install/update dependencies
flutter run              # Run on connected device/emulator
flutter analyze          # Lint (zero issues is the bar)
flutter test             # Run tests
flutter build apk        # Build Android APK
```

After changing `pubspec.yaml` (assets, fonts, dependencies), always run `flutter pub get` and do a **full restart** — hot-reload won't pick up asset/font changes.

---

## Architecture

Flutter app. Pages in `lib/pages/`, services in `lib/services/`, models in `lib/models/`.

**Full navigation flow:**
1. `main.dart` — bootstraps `MaterialApp` with the full M3 dark arcade theme (neon green `0xFF00FF9C`, dark bg `0xFF0D0D1A`). Theme is the source of truth for all colors, fonts, shapes.
2. `pages/home.dart` — static home with "Start Workout" → pushes `StartWorkoutPage`.
3. `pages/start_workout.dart` — muscle group selection, workout time (`CupertinoPicker`), and exercise picker sheet.
   - `showExercisePicker()` opens a `showModalBottomSheet` containing `_ExercisePickerSheet`.
   - `_ExercisePickerSheetState` owns `selectedExerciseIds` (multi-select `Set<String>`) and `favoriteExerciseIds`. Renders a `ListView` of `_ExerciseCard` widgets.
   - `_ExerciseCard` — fixed-height card with `Stack`: background image, dark overlay, top-right selection indicator (neon circle+check when selected, outlined circle when not), bottom-right favorite `IconButton`.
   - `_SelectionBar` — sticky footer; "Continue" → `AlertDialog` → "Start Workout" pushes `ActiveWorkoutPage` and pops both dialog and sheet.
4. `pages/active_workout.dart` — live workout session. Runs a `Timer` for elapsed time. Tracks per-exercise `_ExerciseStatus` (notStarted/inProgress/done). Tapping an exercise pushes `ExerciseSessionPage` and awaits returned `List<SetEntry>`. "End Early" dialog offers "Save & Quit" (partial save → pop to root) or "End Session" (push summary). "Finish Workout" button enabled only when all exercises are done.
5. `pages/exercise_session.dart` — per-exercise set logging. Manages a list of `_SetRow` (weight + reps `TextEditingController` pairs). "Finish Exercise" validates all fields and pops `List<SetEntry>` back to `ActiveWorkoutPage`.
6. `pages/workout_summary.dart` — post-workout summary. Displays time, total sets, exercise count, estimated kcal. Shows per-exercise calorie breakdown. `PopScope(canPop: false)` prevents back navigation. "Save & Exit" persists a `WorkoutSession` via `WorkoutStorageService` then pops to root.

**Models (`lib/models/workout_models.dart`):**
- `Exercise` — id, name, level, images; helpers: `imageAssetPath`, `levelLabel`, `levelRank`.
- `SetEntry` — weight (double, kg) + reps (int); JSON serializable.
- `ExerciseLog` — exerciseId, exerciseName, sets; computes `totalVolume`.
- `WorkoutSession` — full record of a completed or partial session; JSON serializable for `shared_preferences` storage.

**Services:**
- `services/favorite_service.dart` — persists favorite exercise IDs to `shared_preferences` as a sorted string list.
- `services/workout_storage_service.dart` — appends/reads `WorkoutSession` objects as a JSON list under key `workout_sessions` in `shared_preferences`.
- `services/calorie_service.dart` — MET-based calorie estimation (`estimateCalories`) and per-exercise calorie split proportional to volume (`exerciseCalories`). Assumes 70 kg body weight; MET values: Legs 6.0, Chest/Back 5.0, Arms 4.0.

**Exercise data:**
- `assets/exercises.json` is loaded once via `_loadExerciseCatalog()` and memoized in `exerciseCatalogFuture` on `_StartWorkoutPageState`.
- Each exercise has `id`, `name`, `level` (`beginner`/`intermediate`/`expert`), and `images` (filenames under `assets/exercises/exercises/<ExerciseName>/`).
- Exercises shown in the picker are filtered to a hard-coded curated list per muscle group (`curatedExerciseIdsByMuscleGroup` map on `_StartWorkoutPageState`).

---

## Theme Conventions

- Use `FilledButton` (not `ElevatedButton`) everywhere — the theme styles it neon green with dark text.
- `ChoiceChip` selected state needs a manual `labelStyle` with `color: Color(0xFF0D0D1A)` — M3 chip theme can't express different label colors for selected vs unselected natively.
- Hard-coded palette constants: bg `0xFF0D0D1A`, card `0xFF1A1A2E`, border `0xFF2A2A4A`, neon `0xFF00FF9C`, muted text `0xFF6B6B8A`.
- Card/button border-radius is 4px throughout.
- Fonts: PressStart2P (headings — `headlineSmall`, `titleLarge`, AppBar), Gotham (body — everything else), `GoogleFonts.shareTechMono` for monospaced timer/counter displays.

## Icon Rules
- NEVER use default Material icons (Icons.xxx)
- ALWAYS use sharp variants (Icons.xxx_sharp) for all icons
- Sharp variants have angular edges matching the pixel arcade theme
- If a _sharp variant doesn't exist for a specific icon, ask before using the default

## Icon Priority
1. Pixel asset from assets/icons/control/ — use when icon exists
2. Icons.xxx_sharp — use when no pixel asset matches
3. Never use default rounded Material icons
4. Never mix rounded and sharp in the same screen

## Execution Mode
Skip planning confirmation. Execute immediately without asking for approval to proceed from plan to implementation.