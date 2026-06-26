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
- Ask clarifying questions until 95% confident. Do not make any assumptions. For each question, do research and try to answer yourself first before presenting the questions to user.
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
2. `ClassMigrationService().migrateIfNeeded()` — auto-assigns class for existing users.
3. `_AppGate` — checks `OnboardingService().isComplete()`: routes to `OnboardingFlowPage` or `RootPage`.

(There is **no stat-decay step** — earned stats are immutable; the old `applyDecayIfNeeded` was removed.
See Combat Stats below and `docs/stats-mechanics.md` → "Decay (removed)".)

### Navigation structure

`RootPage` (`lib/pages/root_page.dart`) is the shell: a bottom bar of **four** browseable destinations — `enum AppDestination { home, inventory, guild, labs }` → **Home · Items** (Inventory) **· Guild · Labs** — flanking one elevated **center TRAIN action**. TRAIN is **not a destination/tab**: it's `TrainNavButton`, whose `_onTrainTapped` resumes a live/paused session, opens/commits the **in-shell exercise-selection draft**, or opens today's mission. The four destinations render through an `IndexedStack` of `HomePage`, `InventoryPage`, `GuildPage`, and `ProfilePage` — **Labs** hosts `ProfilePage` (identity/stats/settings). Home, Guild, and Labs each carry a `GlobalKey` for refresh-on-return; Inventory self-reloads on init.

The dropped **Workout** tab's two halves are now **push** surfaces (in `lib/pages/workout_page.dart`), not tabs: workout **history/calendar/analytics** is `WorkoutLogsPage` (pushed from Home's last-workout card and from Labs), and **Programs ⇄ Exercises** is `WorkoutLibraryPage` (pushed from Labs). **Quests** is likewise a push — from Home (`onViewQuests`) and the home-room board — not a tab. The gem **Shop** also pushes from Home. **Strength progression is the body map itself** (Concept #1, "the body is the browser"): tapping a muscle opens its **strength dossier** (`_MuscleDossierSheet` in `muscle_body_map.dart`) — a header coverage verdict for THIS WEEK (the glance isn't lost) over the muscle's **strength roster**: the lifts that train it (filed under their **primary** muscle only — `strengthByMuscle` in `body_map_regions.dart`, so a bench doesn't clutter the triceps roster), each a `StrengthMomentumRow` → the existing `ExerciseHistoryPage` chart. Rows lead with a **plain verdict** (`NEW BEST`/`ON THE RISE`/`HOLDING`/`REBUILDING` — never "e1RM" jargon; `REBUILDING` is the honest, non-punitive down state, never red), a signed "vs last" delta, and an **"est. max"** (an estimate, never called "best"). Data: `StrengthTrendService` (all-time momentum from `ProgressiveOverloadService.epley1RM` — the same estimate the chart plots; `StrengthMomentum` band ±2.5%). A secondary **ALL LIFTS** route on the body map opens `StrengthIndexPage` (`lib/pages/strength_index_page.dart`) — the completeness net (every weighted lift once, searchable) for the "show me everything" intent, reworked into a **visual roster**: each lift is a `StrengthRosterRow` (`widgets/strength_roster_row.dart`) — a movement-pattern **lift icon** (`widgets/lift_icon.dart` + `data/lift_icons.dart`, a name-keyword classifier → 13 pixel glyphs in `assets/icons/lift-icons/`, recoloured via `BlendMode.srcIn`) + the lift name + a big **est-max** number + a verdict **glyph** (★ new-best / ▲ rising / – holding / ▼ rebuilding, the down state muted never red) + a small signed delta — text traded for visual identity. Lifts group into **completeness-preserving sections** (NEW BESTS / RECENTLY TRAINED / REBUILDING, every lift in exactly one, empty sections dropped); **filter chips** (ALL / RISING / NEW / REBUILDING) slice by momentum into a flat view; a single **`EST. MAX · <unit>`** column hint carries the honest-estimate framing; a one-time reduced-motion-safe entrance stagger; only a genuine new best gets the amber flourish. A user can **pin up to 3 "anchor" lifts** (`PinnedLiftsService`, key `pinned_lift_ids_v1`, block-and-tell at the cap — a 4th pin shows a floating "unpin one first" notice, never auto-evicts) — pinned lifts surface as a richer **`PinnedLiftCard`** (`widgets/pinned_lift_card.dart`, cyan accent, the lift icon + verdict WORD + signed delta + neutral "trained N×" mastery line + the **one** sparkline with an amber PR marker) at the **top of the ALL view only** (filter views stay truthful), pulled out of their section so nothing shows twice. Pin via **long-press** a row (also a custom Semantics action for switch/screen-reader; a persistent "PINNED N/3 · hold a lift to add" status line keeps it discoverable); unpin via the card's pin icon. Stale pins (a lift whose sessions were deleted) self-heal on load (`pruneTo`) so a ghost pin can't deadlock the cap. The **dossier** keeps the denser `StrengthMomentumRow` (muscle-grouped context). The inline Logs "LOAD TRENDS" top-3 (heaviest-weight, ≥5 sessions) is unchanged — a complementary no-estimation glance. **Coverage shading/meter stays singular** (weekly sets); strength lives only in the dossier (no strength-lens — avoids conflating two meanings in one brightness channel). The detailed per-muscle meter rows are **collapsed by default** per group (`_expandedGroups`) — the page opens to the body + the group titles (SHOULDERS · ARMS / CHEST · CORE / LEGS) with an expand chevron; tap a header to reveal its rows (reduced motion skips the `AnimatedSize` rather than zeroing its duration). The Logs **session list** shows the 3 most recent, with **SHOW MORE** (+5 each) and a **SHOW LESS** (appears once expanded → resets to 3).

**Workout session flow** (all in `lib/pages/Workout session/`):
1. `StartWorkoutPage` — muscle group chips, time picker, exercise picker bottom sheet (multi-select with favorites). Primary entry is **in-shell** as the center TRAIN action's selection surface (`embedded: true`, survives tab nav); also pushed standalone (e.g. the empty-log CTA). A live **"today's targets" preview** (`widgets/target_body_preview.dart`) sits above the loadout: a compact static front/back pixel body that lights the muscles the selected lifts will train — **primary bright, secondary dim** (mirroring coverage's 1.0/0.5 credit, never overstating a synergist) — via the shared `targetedBodyMuscles()` mapping in `body_map_regions.dart` (same primary→detailed→body path as the history coverage map, so they can't disagree). A plan **preview**, not a coverage verdict: binary intent only — no MEV/MAV/zone words; only the trained side(s) render (a push day shows no all-dark back); the `TARGETS: …` text line is the screen-reader source. Updates live as the loadout changes (research: the evidence-favored placement over enriching the confirm dialog — the start is a forward-looking planning moment, so a partial highlight reads as intent, not the peak-end "incomplete" hazard of a post-workout map).
2. `ActiveWorkoutPage` — live timer, per-exercise status tracking, rest timer. Tapping exercise pushes `ExerciseSessionPage`, awaits `List<SetEntry>`. All-done enables "Finish Workout". Each logged set silently checkpoints the ongoing session to storage (`checkpointOngoingSession`, no change-signal) stamping `WorkoutSession.lastActivityAt` + a credited `actualDurationSeconds` — so a force-kill no longer loses logged sets. **Idle auto-save:** after 30 min (`WorkoutStorageService.idleTimeout`) with no new set, a reveal (`showIdleSessionDialog`, SAVE & FINISH / KEEP TRAINING / DISCARD) is offered — by the active page's own timer while it's on top, or by `RootPage._showIdleRevealIfNeeded` on the next open/resume after a kill (gated on `ModalRoute.isCurrent`; both arbitrated by `IdleSessionGuard`). SAVE credits time only up to the last set; a zero-set idle session is dropped silently.
3. `ExerciseSessionPage` — set logging (weight + reps). **Sequential gate:** only the first un-logged row (the *frontier*) is editable; later rows are gated (disabled fields, muted **empty-circle** `radio_button_unchecked_sharp` button) and a tap warns "Log your previous set first" (the opaque row `GestureDetector` catches it — disabled `TextField`s ignore pointers). Logging a row fills its **empty circle → filled `check_circle_sharp`**, starts the between-set rest, and shows a brief floating **"Rest timer started"** notice; re-tapping a logged row unlocks it (and unfocuses, re-gating the rows below). "Finish Exercise" validates and pops data back. (The one-time *plate-calc hint line* was removed; the plate-calculator suffix icon + sheet stay.)
4. `WorkoutSummaryPage` — post-workout XP awards, stats, calorie breakdown. `PopScope(canPop: false)`. "Save & Exit" persists via `WorkoutStorageService` then pops to root.

**Onboarding flow** (`lib/pages/onboarding/`): multi-screen cinematic sequence — cold open → problem → solution → calibration quiz → name (creates the character) → class reveal → generating → start gate. There is no avatar step: a gender-seeded default pixel face (`AvatarDefaults.forSex`) is assigned at name-commit and shown at the start gate; users edit it later from Profile. Completes by pushing `RootPage(openWorkoutStarterOnLaunch: true)`. The **name screen** opens with a BIT-presented **starter-readout panel** (`widgets/onboarding/starter_readout_panel.dart`) — a faced, living `BitMoodCore` delivering a BIG "Your program is built, warrior." over a *reversible* recap of the recommended plan (class flavor · program · training days; weight/sex stay private, body-neutral; the whole card taps back to program selection to edit) — so the user reads/validates the plan their answers built right before the irreversible name commit. Framed as a recommendation, **not** an owned identity (research: a derived class hard-labelled "YOUR BUILD" reads as imposed; insights.md). The screen's upper content is a `SingleChildScrollView` that lifts the focused field above the keyboard (`ensureVisible` on focus), since the panel pushes it down.

### Core gamification systems

| System | Service | Key concepts |
|--------|---------|-------------|
| XP & Levels | `XpService` | Session XP from volume/time/sets. Threshold-based leveling. LCK stat multiplier. |
| Combat Stats | `StatEngine` | Visible radar stats are STR/AGI/END. VIT = recovery meter. LCK = streak-based XP multiplier. DEF is hidden legacy storage only. **Earned stats are immutable — NO inactivity decay** (gain-framed/body-neutral; STR/AGI/END/DEF never decrease once earned; VIT is the one live meter that recovers/recedes with rest-vs-training balance). Calibration seed from onboarding quiz. |
| Classes | `ClassService`, `class_definitions.dart` | 3 classes: Assassin (Shoulders+Core), Bruiser (Chest+Back+Arms), Tank (Legs). Each has a theme color and associated body goal. (Vanguard was removed.) |
| Quests | `QuestService` | A **rotating pool** auto-evaluated from workout history (no manual confirm): each closure-carrying `_QuestTemplate` self-evaluates against a computed `_QuestStats`. Daily (3) + weekly (5) surface a **deterministic per-period pick** — an FNV hash of the period key seeds the shuffle (stable within a period, rotates across them, like the Guild) — each anchored by a guaranteed reliable win (Show Up / Opening Move); **side** = the full permanent milestone ladder. **Limit Break** is a featured weekly with a **personalized** volume target: `round100(avg(last ≤4 weeks' volume) × 1.15)`, clamped `[×1.05, ×1.30]`, excluded until ≥1 baseline week. Side quests grant a loot **title badge** (`sideQuestTitleLootId`; ids stable, names migratable). Gems-only reward. |
| Loot & Inventory | `LootService`, `loot_registry.dart` | Avatar frames + title badges (themes removed). Rarity tiers. Equip/unequip — the **first earned title auto-equips** from any source (`evaluateUnlocks` mirrors the quest path; only the user's first-ever title, guarded on owned-non-default count so a chosen/cleared title is never overridden). Frames earn on one **completed-sessions** axis (rarity == effort, monotonic 4→52). Titles are one ladder: a **symmetric per-muscle-volume set** (Chest/Back/Shoulders/Arms/Legs/Core @ 8,000 kg), plus session/set/minute/breadth/stat/program ladders; the chest-sessions `title_shadow_slayer` is frozen (ruleless, grandfathered). Deterministic milestone unlocks for collection pull. **Frames are self-contained 260×260 PNGs in `assets/unlocks/avatar_frames/<id>/` authored to a 26-cell grid (central 20×20 transparent aperture + 3-cell border ring)** — `LootAvatarFrame` (`widgets/loot_avatar_frame.dart`) seats the avatar at `20/26` of the tile so its pixel cell matches the frame's, renders the frame as the **only** border (no inner box bleed) via `FilterQuality.none` at integer sizes (130/260), and falls back to the default `iron` frame when none equipped. Epic `inferno`/`void` are **10-frame animations** (`<id>_<i>.png`, `frameCount` on `LootItem`) — a ~12 fps loop frozen to the poster under reduced motion (reconciled in `didChangeDependencies`); grids/thumbnails always show the static poster. |
| Guild | `GuildService` | Local single-player simulation with NPC members. Deterministic per ISO week. Forge Nods social signal. |
| Body Metrics | `BodyMetricsService`, `BodyGoalService` | Opt-in weight tracking (body-neutral). Log any time; EWMA trend line (display-only); single weekly XP-boost reward gated by a rolling 7-day `body_metrics_reward_anchor_v1`. |
| Progressive Overload | `ProgressiveOverloadService` | Suggests weight/rep targets based on history. Kind-aware (compound/isolation/bodyweight). |
| Rest & Recovery | `RestService`, `RestTimerService` | Shield charges, recovery XP, rest day protection. VIT stat integration. **Rest timer** is the `endsAt`-sourced singleton `RestTimerService` (`start`/`cancel`/**`adjust(±s)`**, capped at `maxRestSeconds` 600). Two surfaces share it: between-**set** rest is the thin `RestTimerBar` (unchanged); between-**exercise** rest (after Finish Exercise) is a focal **`RestBreakPanel`** takeover on `active_workout` — faced BIT in `BitPose.rest`, a **PressStart2P countdown** (the same typeface as the `_ElapsedDisplay` session clock — one timer face), ±15s, **cyan** mono **SKIP REST** → back to logging. While the takeover is up, the **session header collapses** to a slim strip (group · cleared · progress) so the rest countdown is the **sole live timer**; tapping it expands a **dimmed but still-running** ELAPSED (`_headerExpanded`, chevrons), and it auto-restores to the full bright header the instant the rest ends. It is gated on `_restAfterFinish` (a between-set rest bleeding through on back-out must **not** take over) and **suppressed when `_allDone`** (suppress = `cancel()` the rest, so Finish Workout is reachable and no rest leaks into the summary). The rest is a **global singleton that carries over**: opening any exercise (the single `_openExercise` funnel) is unambiguous intent, so there is **no skip-rest dialog** and no silent cancel — the rest simply rides into the next screen's own rest bar. |
| Programs | `ProgramService`, `programs_library.dart` | Structured workout programs with scheduled sessions. |
| Character | `CharacterService` | Name, class, quiz answers. Created during onboarding. |
| Avatar | `AvatarSpec` (`models/avatar_spec.dart`), `IronbitAvatar` (`widgets/avatar/`) | Procedural 20×20 pixel face (skin/eyes/hair/hairColor/expression) — zero image assets, ~8,100 combos. Stored on `ProfileData.avatarSpec`; edited via `AvatarCustomizerPage` (tap the profile identity frame). Guild NPCs use seeded `AvatarSpec.random`. |
| Companion (BIT) | `BitSprite`/`BitSpeechBubble` (`widgets/companion/`), `bitAddress` (`data/companion_address.dart`) | Mascot **BIT** — a pixel "drone core" (raster sprites in `assets/mascot/bit-sprites/`, painted `errorBuilder` fallback). The system's faceless voice through screens 1–2; **reveals its face at the Solution screen (screen 3)** — the emotional peak, played as a **weighty power-up**: an anticipation *inhale* (BIT coils — sinks, draws its plates in, dims) → a surge into a **cheer** face (amber — eyes open + a grin, plates spread, a *gentle* overshoot) → a brief still **hold** at the peak → a calm **settle to a steady neutral** (turquoise), speaking as the user's guide (`BitMoodCore` `reveal`/`anticipation`/`idleAmp` + the `cheer` pose). Whenever present, BIT carries a **smooth sub-pixel idle float + slow plate breathing** (decoupled sines; reduced motion → a still home). Once revealed it stays **faced (or absent) — never faceless again**. The `StartGateScreen` stays the user-hero's bigger embodiment (character card + first name-drop, "What should we do first, {name}?"), with BIT already faced. Subordinate to the user-hero — never on the identity frame. Address register: name (intimate) / "warrior" (ceremony) / "recruit" (pre-embodiment), "warrior" the fallback. Interview voice is a planned follow-up; **in-app presence has begun** — BIT now lives on the **quest board** in a **pinned header** (does not scroll): a small, idle-damped, *faced* `BitMoodCore` + a state-derived line beside the **slim magenta gem wallet** (`kGemMagenta`). Claiming a quest **flies the reward gems** from the CLAIM button up to the wallet (which counts up as they land) and BIT **cheers** as they arrive — `widgets/quest_claim_flight.dart` (`GemFlightLayer` + `GemWallet`), the port of the Quest Claim handoff (`assets/quests/design_handoff_quest_claim`); reduced motion snaps the count + a static cheer; this replaced the old outward gem-shard burst (`GemClaimBurst`, deleted). Copy in `data/bit_quest_copy.dart`; an empty board reads *quiet*, never a guilt-poke. BIT's **home room** also mounts a **wall quest board** (`widgets/room/quest_board.dart`) upper-left, a little above BIT (counterweighting the world window) — a faithful port of `assets/design_handoff_home_room/quest-board/quest-board.js`: a *glance, don't transact* peek (QUESTS · 5-seg weekly bar in the pad-LED cyan `bitGlow` · one gem pip) that stays calm steady-cyan and **tints amber + breathes only when ≥1 reward is claimable** (`questClaimable`; reduced motion → static), tapping routes to the full board (`onViewQuests`); it's the room's only breathing accent. BIT also speaks a **claimable nudge line** (`BitRoomVoiceKind.claimable`, reusing `BitQuestCopy.briefing`, tappable → Quests) slotted below the away/haul states, above advice. `BitSpeechBubble` is the **canonical shared BIT voice primitive** — `tailDirection` (left/right/none) lets it sit on any side. BIT also anchors the **between-exercise rest** as a focal `BitPose.rest` `BitMoodCore` (faced, float + plate-breathing) in `widgets/rest_break_panel.dart` — see the Rest & Recovery row. |

### Product doctrine

Every logged workout should make the user's character feel harder to abandon. Real training is the
fuel; identity, streak, rank, loot, and ritual are the psychological engine. When adding or changing
features, prefer surfaces that strengthen one of the long-term hooks:

- **Identity attachment:** avatar, name, class, rank, title, frame.
- **Competence growth:** stats, grades, XP, suggested loads, visible deltas.
- **Collection desire:** deterministic frames, themes, titles, future cosmetic horizons.
- **Ritual return:** home mission, workout summary, weekly cadence, LCK, guild signal.
- **Recovery protection:** rest days, shields, and VIT recovery that protect the build between
  sessions. Earned stats are immutable (gains never decay) — the build is preserved by design, not
  threatened into preservation.

### Exercise data pipeline

1. `assets/exercises.json` — ~800 exercises with `id`, `name`, `level`, `images`, `primaryMuscles`, `secondaryMuscles`. The `Exercise` model carries `primaryMuscle` (first primary) **and** `secondaryMuscles` (synergists, e.g. bench → triceps/front delts; ~69% of built-ins non-empty, custom exercises have none); both feed **display/coverage analysis only** — no volume/stat/XP/overload path reads them.
2. `ExerciseCatalogService` — merges built-in (cached) + custom exercises. Single access point.
3. `data/curated_exercises.dart` — `curatedExerciseIdsByMuscleGroup` map filters the picker to a curated subset per muscle group.
4. `data/muscle_groups.dart` — canonical 7-bucket taxonomy (Chest/Back/Shoulders/Arms/Legs/Core/Full Body). `muscleGroupForDetailed()` maps raw muscle names from JSON → buckets. `services/muscle_coverage_service.dart` is the pure analyzer behind the Logs **muscle-coverage body map**: `weeklySetsByBucket` rolls logged working sets into the **7 buckets**, `weeklySetsByMuscle` into **detailed muscles** (biceps≠triceps etc.) — both fractional (direct primary = 1.0, indirect secondary = 0.5, primary wins on overlap; warm-ups/partial/unknown excluded). Detailed keys are the raw free-exercise-db tokens **except** the two that lack head granularity, split via `data/muscle_splits.dart` (`splitDetailedMuscle` + the curated `curatedMuscleSplits` override map, EMG movement-pattern rule): `shoulders`→`front_delt`/`rear_delt`, `abdominals`→`rectus_abdominis`/`obliques`, scoped to curated lifts — an un-curated splittable token stays the **coarse generic token** (folded to front-delt/rectus by the map, never guessed onto rear/obliques). A `muscle_split_test.dart` integrity test validates every override against the real catalog. The **body map** itself — `widgets/muscle_body_map.dart` (a faithful port of the `assets/body_diagram` handoff: a front/back pixel body whose muscles brighten by weekly sets, intensity via `Image`'s `opacity:` over alpha-only region masks tinted to one uniform `kCoverageLit` in code (`ColorFilter.srcIn` — the baked per-muscle hue is discarded, so a recolor is a single-token edit), over a `kCoverageScrim`@0.5 base-dim, `RepaintBoundary`, read-only per-side meter, reduced-motion-static) driven by `data/body_map_regions.dart` (16-muscle region model + the ported ramp + mask↔muscle map) — **replaces the old Muscle Balance bars** in `WorkoutLogsPage`. Tapping a muscle opens its **strength dossier** (see the Navigation section — the body is the strength browser): a header coverage verdict over the muscle's strength roster, each lift → `ExerciseHistoryPage`. (The meter total still uses the shared `creditPerSet` → `muscleBreakdown` rollup so the bar can't disagree with the coverage crediting; `weeklyContributors` remains the coverage path. The strength roster is a *separate* primary-muscle grouping — `strengthByMuscle` — answering "my lifts for this muscle", not "what worked it this week".) A **range selector** (`CoverageWindow` enum: `7-DAY` / `4-WK AVG` / `12-WK AVG`, periodization-length rolling windows, default `7-DAY`) sits above the body: the longer presets show the **weekly AVERAGE** (`MuscleCoverageService.averagedContributors` — the single pure calc boundary; `_LogsTab` owns the window + recompute, the widget stays presentational), so a multi-week window stays comparable to the **weekly** MEV/MAV bands. The divisor is **capped to real history** (`min(window, now−firstSessionEver)`, ≥1 wk) so a new user's hard week is never divided by empty pre-history weeks (reads RESTED); the unit is labelled **"avg/wk · last N wk"** (the real span) so an average is never misread as raw recent work; longer views are opt-in + body-neutral (no scold for a deload-dimmed muscle).
5. Exercise images: `assets/exercises/exercises/<ExerciseName>/0.jpg`, `1.jpg`, etc.
6. Form demos: `data/exercise_demos.dart` is a small id→asset registry (curated, currently 15 program lifts — all chest/back lifts plus the squat/curl/pushdown staples; legs & the remaining arm lifts have no clip yet). `widgets/exercise_demo_player.dart` (`video_player`/ExoPlayer) plays the muted looping mp4 — tap toggles pause/play, reduced-motion starts paused, backgrounding pauses. The large surfaces (`exercise_session.dart` via the `widgets/exercise_demo_cabinet.dart` "demo cabinet", `exercise_detail.dart` hero) host the player; the cabinet has a persisted HIDE/SHOW toggle (`WorkoutDefaultsService`, `exercise_demo_hidden_v1`) and a fullscreen viewer. Thumbnails use the poster still via `exerciseThumbAsset()`. Exercises without a demo fall back to the static catalog photo. Source mp4s live in `assets/exercises/animated-videos/` (undeclared); `ops/generate_exercise_demos.py` normalizes them into the declared `assets/exercises/demos/` mp4s + posters.

### Persistence pattern

All state in `SharedPreferences` as JSON strings. Key services and their storage keys:
- `workout_sessions` — `WorkoutStorageService` (completed/ongoing sessions)
- `combat_stats` — `StatEngine` (cached stat values)
- `quest_state_v1` — `QuestService`
- `rest_state_v1` — `RestService`
- `guild_v1` / `guild_members_v1` — `GuildService`
- `loot_inventory` / `equipped_loot` — `LootService`
- `active_character_v1` — `CharacterService`
- `gem_ledger_v1` — `GemService` (append-only, idempotent-by-id gem ledger; sources: quest / adventure / demoTopUp / cosmeticPurchase / **warmup**)

**Warm-up reward (re-anchored to logged sets):** warm-up sets are real, logged `SetEntry`s stored apart from working sets in `ExerciseLog.warmupSets` (working `sets` stays the volume/stat/XP/overload truth — every aggregator reads it untouched). `WorkoutSession.warmedUp` is a **derived** getter (`exercises.any((e) => e.hasWarmupSet)`), not a stored field. Logged in the exercise screen via the advisory card's **LOG IT** (one tap) or a manual **+ WARM-UP SET** in the warm-up sub-section; the session page round-trips a single `isWarmup`-flagged list, split into `sets`/`warmupSets` once at `_ActiveWorkoutPage._buildExerciseLogs` (resume recombines `[...sets, ...warmupSets]` so a force-kill never drops them). On save, `WarmupRewardService.grantForSession` (called from `saveSession`, like the Adventure charge) awards a small gem bonus via `GemService.awardWarmupGems` — idempotent by **day** (`warmup:<dayKey>`), so it's capped at one/day, gated to a non-abandoned session with a real working set, and feeds no XP/stats. The optional unrewarded mobility guide is `data/warmup_routines.dart` (RAMP, tailored by `targetMuscleGroups`) shown by `widgets/warmup_sheet.dart`, reachable from Start.

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
| 4 | Logging is unrestricted; the 7-day cadence now gates only the *reward* (separate `body_metrics_reward_anchor_v1`), enforced at the service layer | Frequent weigh-ins feed the trend line; the rolling-7-day reward window (max(storedDay, now) guard) keeps the anti-farm intent without blocking measurement. Migrated idempotently by `runWeightLogRewardAnchorOnce`, which seeds the reward anchor from the legacy last-log token (no free or suppressed potion on upgrade). |
| 5 | No red/green colors on weight arrows or deltas | Body-neutral design: muted-only directional indicators prevent implicit "good/bad" framing. |
| 6 | The silent direction-aligned bonus was **removed** for a single weekly act-reward | Reward legibility + body-neutrality: the reward is for the *act* of checking in (legible), never the weight's direction. Absence of a reward stays silent — the not-rewarded reveal is calm, never framed as a miss. |
| 7 | XP Boost Potions are charge-based: 3 charges per potion, one spent per eligible workout save (3→2→1→gone), expiring after **3 weeks** as a backstop | Rewards the act of tracking across the next few workouts; the 3-week backstop (was 1 week) lets all three charges be spent at a realistic weekly training cadence instead of stranding the 3rd. |
| 8 | Potion multiplier capped at 5.0x | Prevents runaway XP inflation from stacking many potions; keeps leveling meaningful. |
| 9 | BodyGoal stored as snapshot in each WeightEntry | Allows historical analysis even after goal changes; the snapshot rides along on every entry. |
| 10 | Custom exercises use explicit primaryMuscle field, not runtime lookup | StatEngine can map custom exercises to combat stats without needing the raw JSON primaryMuscles array. |
| 11 | Body-weight display is a time-aware EWMA **trend line** (α≈0.1), gated until ≥4 entries & ≥14-day span; raw weigh-ins are faint dots, velocity is muted + tap-to-reveal | Trend weight (Hacker's Diet / MacroFactor) filters daily water-weight noise so the number is honest and calmer to read; gating prevents a sparse, misleading "precise" trend; no headline velocity keeps it body-neutral (the rate is data, never judgment). Display-only — feeds no combat stat. |

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
