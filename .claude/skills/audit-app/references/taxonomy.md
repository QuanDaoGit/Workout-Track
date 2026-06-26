# Audit unit taxonomy + track mapping

The ledger is built by globbing the codebase and mapping each file/area to units here. This file is the
mapping rule — when in doubt, **add a row** (over-coverage is cheap, a missed system is a launch bug).
Keep it reconciled: if a new `lib/pages` or `lib/services` file exists with no home here, add it.

## Track mapping (which `audit` tracks each unit type runs)

| Unit type | Source | `audit` tracks |
|---|---|---|
| **Screen** | one `lib/pages/**` file | Presentation + Deterministic lint (+ Journey if in a flow) |
| **Flow** | a sequence of screens | Journey (multi-screen capture) |
| **System** | a `lib/services` domain | Correctness (oracles) + State/integration |
| **Content/data** | a `lib/data` registry | Correctness/integrity (cross-reference, no dangling ids, invariants) |
| **Cross-cutting sweep** | spans many files | the relevant track, run app-wide |

---

## Screens (Presentation + lint; one row per `lib/pages/**` file)

Glob `lib/pages/**/*.dart`. Every page is a row. Group for sanity, but none may be dropped:
- **Core loop:** `home.dart`, `root_page.dart`, `Workout session/start_workout.dart`,
  `Workout session/active_workout.dart`, `Workout session/exercise_session.dart`,
  `Workout session/workout_summary.dart`.
- **Onboarding:** every `lib/pages/onboarding/*` page (cold open → problem → solution → calibration
  quiz → name → class reveal → program loading → start gate → reminders primer).
- **Identity/economy:** `profile_page.dart`, `inventory_page.dart`, `shop_page.dart`,
  `avatar_customizer_page.dart`, `class_select_page.dart`, `class_reveal_page.dart`.
- **Logs/analysis:** `workout_page.dart`, `calendar_page.dart`, `exercise_history_page.dart`,
  `strength_index_page.dart`, `body_metrics_*` pages.
- **Programs/exercises:** `programs_library_page.dart`, `program_detail_page.dart`,
  `create_exercise_page.dart`, `exercise_detail.dart`, `goal_selection_page.dart`.
- **Guild/quests/adventure:** `guild_page.dart`, `quests_page.dart`, `adventure_page.dart`,
  `expedition_report_page.dart`.
- The rest (boot splash, rank assessed, reveals, log-weight, session detail…): a row each.

Each screen needs a **render scenario** (see `audit` → `references/scenarios.md`) seeded via real
service APIs. A screen that can't yet be rendered is a row with status `blocked` (note why) — counted as
a gap, not silently skipped.

## Flows (Journey track — multi-screen)

- **Onboarding flow** (cold open → … → start gate) — the highest-stakes first-run sequence.
- **Workout session flow** (start → active → exercise logging → finish → summary → save).
- **Expedition/Adventure flow** (dispatch → charge → report/coffer).
- **Weigh-in flow** (log weight → reward/no-reward reveal).
- **Program lifecycle** (select/recommend → customize → schedule → swap → complete).

## Systems (Correctness oracles + State; group `lib/services` into domains)

For each, the Correctness track needs an **independent oracle** (docs fixture / invariant / separate
recompute — never just reading the service). Source of truth for the math: `docs/stats-mechanics.md`,
`docs/program-system.md`, `docs/quest-system.md`, CLAUDE.md.

| System | Key files | Oracle / invariant ideas |
|---|---|---|
| XP & levels | `xp_service`, `xp_reward_models`, `xp_boost_service` | known-answer from stats-mechanics; XP ≥ 0; more volume ⇒ ≥ XP; potion multiplier ≤ 5.0 cap |
| Combat stats | `stat_engine`, `stat_radar_read` | decay monotonic over idle days; calibration seed bounds; STR/AGI/END derivation |
| Progressive overload | `progressive_overload_service` | suggested load ≥ history floor; kind-aware (compound/iso/bodyweight) branches |
| Strength / e1RM | `strength_trend_service`, `strength_standards` | Epley known-answer; e1RM ≥ top-set weight; standards monotonic across levels |
| Calories | `calorie_service` | non-negative; scales with volume/duration per documented formula |
| Muscle coverage | `muscle_coverage_service`, `body_map_regions`, `muscle_splits` | session volume == Σ set volume; direct=1.0/indirect=0.5; meter total == rollup |
| Quests | `quest_service` | deterministic per-period pick (same seed ⇒ same pick); Limit Break clamp [×1.05,×1.30] |
| Loot & milestones | `loot_service`, `loot_registry`, `milestone_service` | first-title auto-equip once; thresholds monotonic; no dangling unlock ids |
| Gems | `gem_service`, `gem_ledger_entry` | append-only; **idempotent by id** (re-award doesn't double); sources valid |
| Warm-up reward | `warmup_reward_service`, `warmup_calculator` | idempotent by day; warm-ups feed no XP/stats |
| Rest & recovery | `rest_service`, `rest_timer_service` | timer capped at 600s; shield/VIT rules; carryover singleton |
| Body metrics | `body_metrics_service`, `weight_trend` | reward gated by rolling 7-day anchor; EWMA gating (≥4 entries, ≥14d) |
| Programs | `program_service`, `schedule_resolver`, `weekly_goal_service` | schedule resolves to real days; weekly goal counts correctly |
| Guild | `guild_service` | deterministic per ISO week |
| Workout core | `workout_storage_service`, `workout_metric_service`, `idle_session_guard`, `calorie_service` | checkpoint survives kill; idle auto-save credits time to last set; volume math |
| Character/profile | `character_service`, `profile_service` | persistence round-trip; avatar default by sex |
| Exercises | `exercise_catalog_service`, `custom_exercise_service`, `exercise_kind_cache` | built-in + custom merge; kind cache correct |
| Units | `unit_settings_service`, `unit_models` | kg/cm canonical; display conversion lossless round-trip |

## Content / data (integrity)

| Content | File | Integrity check |
|---|---|---|
| Programs library | `programs_library` | every referenced exercise id exists in the catalog |
| Curated exercises | `curated_exercises` | ids resolve; each muscle group non-empty |
| Exercise alternatives | `exercise_alternatives` | both sides resolve to real ids |
| Exercise demos | `exercise_demos` | asset paths exist (mp4 + poster) |
| Loot registry | `loot_registry` | unique ids; valid unlock rules; asset paths exist; ladders symmetric |
| Strength standards | `strength_standards` | monotonic across levels; covers expected lifts |
| Muscle taxonomy | `muscle_groups`, `muscle_splits` | every raw token maps to a bucket; splits validated (there's a `muscle_split_test`) |
| Bodyweight loads | `bodyweight_loads` | plausible coefficients |
| BIT copy / address | `bit_*_copy`, `companion_address` | no placeholder/TODO; register correct (name/warrior/recruit) |

## Coverage drift checks (run in step 1, before auditing)

Glob-exhaustiveness covers source units only. Flows + sweeps are hand-listed above and rot as the app
grows, so derive a second view and diff it against the ledger — anything unmatched goes to the report's
**`unmapped`** section (which blocks a complete verdict):
- **Navigation/route scan:** `Grep` `Navigator.push`/`pushReplacement`/`MaterialPageRoute`/`arcadeRoute`
  + `=> const \w+Page(` to list every screen actually reachable; reconcile against the screen rows (a
  page reachable but unlisted, or listed but unreachable/dead, is a finding).
- **Entrypoint scan:** notifications/deep-links/boot — `notification_service`, `boot_service`,
  `training_reminder_planner` — every entrypoint that lands the user somewhere is a flow to cover.
- **Registry cross-reference:** for each `lib/data` registry, scan that every id it emits resolves and
  every consumer's id exists (dangling-id sweep) — this is how content gaps (a program citing a deleted
  exercise) surface even without a dedicated row.

## Cross-cutting sweeps (run app-wide, after per-unit passes)

| Sweep | What it checks | How |
|---|---|---|
| Theme coherence | tokens only, no hex literals, 4px radius, FilledButton | `Grep` `0xFF`/`Color(0x`/`Colors.` outside tokens.dart |
| Icon rules | sharp variants only, no rounded Material, no rounded/sharp mix | `Grep` `Icons\.` not ending `_sharp` |
| A11y + reduced motion | semantics on custom controls; reduced-motion branch (omit animator, not zero duration) | render at `disableAnimations` + grep `MediaQuery...disableAnimations` |
| Persistence / migration | every service key migrates idempotently; `MigrationService` covers dead keys | read each service's keys + migration_service |
| Notifications / reminders | schedule correctness, permission gating, no duplicate/stale notifications | `notification_service`, `training_reminder_planner`, `rest_notification_coordinator` |
| Copy + body-neutral voice | no weight/body shaming, no red/green deltas, no scold copy; BIT register | grep copy + read body-metrics/quest/summary surfaces |
| Interrupt / state recovery | backgrounding mid-session, relaunch-after-kill, idle auto-save, resume restores sets/warm-ups | `idle_session_guard`, `workout_storage_service` checkpoint path |
| Device / responsive | small + large screen, long names, empty/sparse states | capture key screens at extra sizes |
