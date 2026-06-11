# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workspace Map

The project root wraps the whole product, not just the app code. Each non-code folder has its own
`CLAUDE.md` (agent brief) + `README.md` — **read a folder's `CLAUDE.md` before working in it.**

| Folder | Purpose |
|--------|---------|
| `lib/` `test/` `android/` `ios/` `assets/` … | The Flutter app (code). Architecture is documented below. |
| `docs/` | Product source of truth — `PRD.md`, `PRODUCT.md`, specs/plans, decisions. |
| `design/` | Visual identity, UX guidelines, screenshots. Theme *code* truth stays in `lib/theme/tokens.dart`. |
| `marketing/` | Positioning, copy, campaigns, marketing assets. |
| `app-management/` | Roadmap, releases/changelog, store listing, support. |
| `statistics/` | Analytics, metrics, observability planning (no data yet — pre-launch). |
| `research/` | User + competitive research. |
| `ops/` | Build, release, environment, CI mechanics. |

## Working Rules

**Before starting any task:**
- Read docs/PRD.md for scope and intent.
- Ask clarifying questions until 95% confident. Do not make any assumptions.
- For features and non-trivial fixes, follow the `/deep-feature` pipeline (skill routing → audit
  → research → opinion → Codex adversarial review → plan → implement). Trivial = non-behavioral
  text/formatting only — state why before skipping.

**After every major step:**
1. Run `flutter analyze` — zero issues required.
2. Run `flutter test` if tests exist.
3. Always screenshot the affected UI section.
4. Review: theme coherence, design consistency, functionality correctness.
5. Fix all issues before proceeding.

**Always:**
- One change at a time. Never rewrite whole files unless explicitly asked.
- State after each change: what changed, which file, what to test.
- Never build features outside docs/PRD.md without asking first.

---

## Commands

```bash
flutter pub get          # Install/update dependencies
flutter run              # Run on connected device/emulator
flutter analyze          # Lint (zero issues is the bar)
flutter test             # Run tests
flutter test test/stat_engine_test.dart  # Run a single test file
flutter build apk        # Build Android APK
```

After changing `pubspec.yaml` (assets, fonts, dependencies), always run `flutter pub get` and do a **full restart** — hot-reload won't pick up asset/font changes.

---

## Architecture

RPG-gamified workout tracker. Flutter app, Android-only. All persistence uses `SharedPreferences` with JSON serialization (no SQLite in practice, despite drift being a dependency).

### Directory layout

- `lib/pages/` — screens. Workout session pages live in `lib/pages/Workout session/` (note the space). Onboarding screens in `lib/pages/onboarding/`.
- `lib/services/` — business logic. Each service owns its own SharedPreferences key(s). Services are instantiated ad-hoc (no DI container), often with injectable `nowProvider`/`catalogOverride` for testability.
- `lib/models/` — data classes. All JSON-serializable with `fromJson`/`toJson`.
- `lib/data/` — static constants and registries: `curated_exercises.dart` (per-muscle-group exercise ID allow-lists), `class_definitions.dart` (class→muscle mapping), `loot_registry.dart` (all loot items), `muscle_groups.dart` (7-bucket canonical taxonomy), `programs_library.dart`, `strength_standards.dart`.
- `lib/theme/` — `tokens.dart` (single source of truth for palette, spacing, motion constants), `app_fonts.dart` (local `ShareTechMono` font helper).
- `lib/widgets/` — reusable arcade-themed components. `widgets/motion/` has micro-interaction wrappers (hold-depress, phosphor-tap, ambient-drift, etc.).

### App boot sequence (`main.dart`)

1. `MigrationService.runOnce()` — cleans dead SharedPreferences keys from removed features.
2. `StatEngine().applyDecayIfNeeded()` — daily stat decay for inactivity.
3. `ClassMigrationService().migrateIfNeeded()` — auto-assigns class for existing users.
4. `_AppGate` — checks `OnboardingService().isComplete()`: routes to `OnboardingFlowPage` or `RootPage`.

### Navigation structure

`RootPage` is a 5-tab bottom navigation shell: **Home**, **Workout** (history/calendar), **Quests**, **Guild**, **Profile**. Each tab has a `GlobalKey` for refresh-on-return.

**Workout session flow** (all in `lib/pages/Workout session/`):
1. `StartWorkoutPage` — muscle group chips, time picker, exercise picker bottom sheet (multi-select with favorites).
2. `ActiveWorkoutPage` — live timer, per-exercise status tracking, rest timer. Tapping exercise pushes `ExerciseSessionPage`, awaits `List<SetEntry>`. All-done enables "Finish Workout".
3. `ExerciseSessionPage` — set logging (weight + reps). "Finish Exercise" validates and pops data back.
4. `WorkoutSummaryPage` — post-workout XP awards, stats, calorie breakdown. `PopScope(canPop: false)`. "Save & Exit" persists via `WorkoutStorageService` then pops to root.

**Onboarding flow** (`lib/pages/onboarding/`): multi-screen cinematic sequence — cold open → problem → solution → calibration quiz → name (creates the character) → class reveal → generating → start gate. There is no avatar step: a gender-seeded default pixel face (`AvatarDefaults.forSex`) is assigned at name-commit and shown at the start gate; users edit it later from Profile. Completes by pushing `RootPage(openWorkoutStarterOnLaunch: true)`.

### Core gamification systems

| System | Service | Key concepts |
|--------|---------|-------------|
| XP & Levels | `XpService` | Session XP from volume/time/sets. Threshold-based leveling. LCK stat multiplier. |
| Combat Stats | `StatEngine` | Visible radar stats are STR/AGI/END. VIT = recovery meter. LCK = streak-based XP multiplier. DEF is hidden legacy storage only. Daily decay for inactivity. Calibration seed from onboarding quiz. |
| Classes | `ClassService`, `class_definitions.dart` | 3 classes: Assassin (Shoulders+Core), Bruiser (Chest+Back+Arms), Tank (Legs). Each has a theme color and associated body goal. (Vanguard was removed.) |
| Quests | `QuestService` | Weekly/side quests with XP rewards. Computed from workout sessions + class context. |
| Loot & Inventory | `LootService`, `loot_registry.dart` | Avatar frames and themes. Rarity tiers. Equip/unequip. Deterministic milestone unlocks for collection pull. |
| Guild | `GuildService` | Local single-player simulation with NPC members. Deterministic per ISO week. Forge Nods social signal. |
| Body Metrics | `BodyMetricsService`, `BodyGoalService` | Opt-in weight tracking (body-neutral by design). 7-day cadence. XP Boost Potions on weight log. |
| Progressive Overload | `ProgressiveOverloadService` | Suggests weight/rep targets based on history. Kind-aware (compound/isolation/bodyweight). |
| Rest & Recovery | `RestService`, `RestTimerService` | Shield charges, recovery XP, rest day protection. VIT stat integration. |
| Programs | `ProgramService`, `programs_library.dart` | Structured workout programs with scheduled sessions. |
| Character | `CharacterService` | Name, class, quiz answers. Created during onboarding. |
| Avatar | `AvatarSpec` (`models/avatar_spec.dart`), `IronbitAvatar` (`widgets/avatar/`) | Procedural 20×20 pixel face (skin/eyes/hair/hairColor/expression) — zero image assets, ~8,100 combos. Stored on `ProfileData.avatarSpec`; edited via `AvatarCustomizerPage` (tap the profile identity frame). Guild NPCs use seeded `AvatarSpec.random`. |

### Product doctrine

Every logged workout should make the user's character feel harder to abandon. Real training is the
fuel; identity, streak, rank, loot, and ritual are the psychological engine. When adding or changing
features, prefer surfaces that strengthen one of the long-term hooks:

- **Identity attachment:** avatar, name, class, rank, title, frame.
- **Competence growth:** stats, grades, XP, suggested loads, visible deltas.
- **Collection desire:** deterministic frames, themes, titles, future cosmetic horizons.
- **Ritual return:** home mission, workout summary, weekly cadence, LCK, guild signal.
- **Recovery protection:** rest days, shields, VIT, and decay rules that make the build worth
  preserving.

### Exercise data pipeline

1. `assets/exercises.json` — ~800 exercises with `id`, `name`, `level`, `images`, `primaryMuscles`.
2. `ExerciseCatalogService` — merges built-in (cached) + custom exercises. Single access point.
3. `data/curated_exercises.dart` — `curatedExerciseIdsByMuscleGroup` map filters the picker to a curated subset per muscle group.
4. `data/muscle_groups.dart` — canonical 7-bucket taxonomy (Chest/Back/Shoulders/Arms/Legs/Core/Full Body). `muscleGroupForDetailed()` maps raw muscle names from JSON → buckets.
5. Exercise images: `assets/exercises/exercises/<ExerciseName>/0.jpg`, `1.jpg`, etc.
6. Form demos: `data/exercise_demos.dart` is a small id→asset registry (curated, currently the 5 FULL BODY A lifts). `widgets/exercise_demo_player.dart` (`video_player`/ExoPlayer) plays the muted looping mp4 — tap toggles pause/play, reduced-motion starts paused, backgrounding pauses. The large surfaces (`exercise_session.dart` via the `widgets/exercise_demo_cabinet.dart` "demo cabinet", `exercise_detail.dart` hero) host the player; the cabinet has a persisted HIDE/SHOW toggle (`WorkoutDefaultsService`, `exercise_demo_hidden_v1`) and a fullscreen viewer. Thumbnails use the poster still via `exerciseThumbAsset()`. Exercises without a demo fall back to the static catalog photo. Source mp4s live in `assets/exercises/animated-videos/` (undeclared); `ops/generate_exercise_demos.py` normalizes them into the declared `assets/exercises/demos/` mp4s + posters.

### Persistence pattern

All state in `SharedPreferences` as JSON strings. Key services and their storage keys:
- `workout_sessions` — `WorkoutStorageService` (completed/ongoing sessions)
- `combat_stats` — `StatEngine` (cached stat values)
- `quest_state_v1` — `QuestService`
- `rest_state_v1` — `RestService`
- `guild_v1` / `guild_members_v1` — `GuildService`
- `loot_inventory` / `equipped_loot` — `LootService`
- `active_character_v1` — `CharacterService`

`WorkoutStorageService.changes` is a broadcast `StreamController<void>` that notifies listeners when sessions are written — `RootPage` subscribes to refresh quest-aware tabs.

---

## Theme Conventions

- All palette constants live in `lib/theme/tokens.dart` — import `tokens.dart`, never hard-code hex values.
- Key tokens: `kBg` (`0xFF11111F`), `kCard` (`0xFF1C1C34`), `kBorder` (`0xFF36365E`), `kNeon` (`0xFF00FF9C`), `kText` (`0xFFE8E8FF`), `kMutedText` (`0xFF9494B8`), `kAmber` (`0xFFFFD700`), `kCyan` (`0xFF00BFFF`), `kDanger` (`0xFFFF2D55`).
- Spacing scale: `kSpace1`–`kSpace5` (4/8/12/16/24). Layout: `kCardRadius` = 4, `kButtonHeight` = 48, `kPrimaryCardBorderWidth` = 1.2.
- Motion: `kMotionFast` (120ms), `kMotionBase` (180ms), `kMotionPop` (220ms), `kMotionCurve` = `easeOutCubic`.
- `neonGlow()` helper for box shadows.
- Use `FilledButton` (not `ElevatedButton`) everywhere — the theme styles it neon green with dark text.
- `ChoiceChip` selected state needs a manual `labelStyle` with `color: kBg` — M3 chip theme can't express different label colors for selected vs unselected natively.
- Card/button border-radius is 4px (`kCardRadius`) throughout.
- Fonts: PressStart2P (headings — `headlineSmall`, `titleLarge`, AppBar), Gotham (body — everything else), `AppFonts.shareTechMono()` for monospaced timer/counter displays (local font, not GoogleFonts).
- Class-specific theme colors (match each class's icon art): Assassin `0xFFB14DFF` (violet), Bruiser `kDanger` `0xFFFF2D55` (red), Tank `kCyan` `0xFF00BFFF` (blue).

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

---

## Phase 7 Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Custom exercises stored in SharedPreferences, not SQLite | Consistency with all other app persistence; data volume is small (dozens of exercises max). |
| 2 | ExerciseCatalogService centralizes all exercise loading | Eliminated 6 duplicate rootBundle.loadString calls; single cache invalidation point for custom exercises. |
| 3 | Body metrics OFF by default, opt-in via settings toggle | PRD body-neutral mandate: user must consciously choose to enable weight tracking. |
| 4 | 7-day cadence enforced at service layer, not UI-only | Prevents clock manipulation exploits; service uses max(storedTimestamp, now) guard. |
| 5 | No red/green colors on weight arrows or deltas | Body-neutral design: muted-only directional indicators prevent implicit "good/bad" framing. |
| 6 | Direction-aligned bonus is silent when not earned | Reward page never mentions alignment/misalignment; absence of bonus is simply absence, not failure. |
| 7 | XP Boost Potions are charge-based: 3 charges per potion, one spent per eligible workout save (3→2→1→gone), expiring after 1 week as a backstop | Rewards the act of tracking across the next few workouts rather than a single 24h window; spent on save (not grant) so it still incentivizes timely training. |
| 8 | Potion multiplier capped at 5.0x | Prevents runaway XP inflation from stacking many potions; keeps leveling meaningful. |
| 9 | BodyGoal stored as snapshot in each WeightEntry | Allows historical analysis even after goal changes; direction alignment checks use current goal, not historical. |
| 10 | Custom exercises use explicit primaryMuscle field, not runtime lookup | StatEngine can map custom exercises to combat stats without needing the raw JSON primaryMuscles array. |

## Phase 8 Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | ClassBattleModifier is pure/stateless — receives ClassBattleContext value object | Keeps BattleEngine deterministic; same inputs always produce same outputs regardless of async state. |
| 2 | BattleInput.classContext is nullable (optional) | Backwards compatibility: old battle results and flows without class selection still work. |
| 3 | ClassBattleCarryover persisted separately from ClassState | Carryover changes every battle; ClassState changes only on class selection/ultimate unlock — different write cadences. |
| 4 | Migration auto-assigns class from body goal silently (no reveal page) | Existing users shouldn't be blocked from using the app by a forced cinematic; they can change class later. |
| 5 | Ultimate requires 2x volume snapshot (min 1000kg) to prevent instant unlock | Snapshot=0 at selection time (new user) would otherwise unlock ultimate immediately with any training. |
| 6 | ClassSprite uses errorBuilder fallback to colored placeholder | Assets not yet available; placeholder is functional and theme-consistent without blocking development. |
| 7 | Epic frames marked bossExclusive to keep class frames progression-bound | Preserves class-frame achievement value and long-term collection pull. |
| 8 | Type AGREE dialog for class switching (destructive action) | Locks abilities and resets ultimate progress — irreversible enough to warrant explicit user confirmation. |
| 9 | Pending ultimate reveal flag fires on next app open, not immediately | Workout save context is wrong moment for a long cinematic; home page load is the natural celebration point. |
| 10 | Shadow Strike extra turn loops within same round (not new round) | Preserves round count semantics and maxRounds=20 cap; extra attacks happen within the player attack phase. |
