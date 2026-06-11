# Release Audit — MVP Android Beta (2026-06-11)

> Pre-beta audit before first Firebase App Distribution build. Scope: mechanical gates, deploy
> checklist, code review of the uncommitted diff, security review, data-integrity deep dive.
> UX audit (`uxaudit:uxaudit`) deferred to a fresh session (plugin loads on restart).

## Verdict

**Ship-ready after decisions below.** One launch-crash BLOCKER was found and fixed during the
audit. Remaining items are decisions (2) and hardening work that is acceptable for a small beta.

## Gates (all green)

| Gate | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | 598/598 passed |
| Signed release build | `app-release.apk` built OK, 77.6 MB |
| Keystore hygiene | `ironbit-upload.jks` + `android/key.properties` both gitignored, not tracked |
| TODO/FIXME/debug prints | none left in `lib/` (only legit error-path `debugPrint`s) |
| Security review | no findings above the high-confidence bar |

## BLOCKER — found & fixed in this audit

| # | Finding | Fix |
|---|---|---|
| B1 | `MainActivity` was still in `package com.example.student_task` after the applicationId/namespace change to `com.erik.ironbit` — release APK would crash at launch (`ClassNotFoundException`). | Moved to `android/app/src/main/kotlin/com/erik/ironbit/MainActivity.kt`; old file deleted. Verified by successful release build. |
| B2 | **System nav-bar overlapped bottom buttons** (found in device testing). Flutter 3.44 + `targetSdk 35` forces edge-to-edge; "Finish Exercise", "Finish Workout", "Back to Home" sat under the Android gesture/nav bar and were hard to tap. | Added bottom-inset protection (`SafeArea(top: false)` on AppBar screens; `viewPadding.bottom` padding on the full-bleed summary) to the 5 pushed-route screens with bottom CTAs: `exercise_session.dart`, `active_workout.dart`, `workout_summary.dart`, `session_detail.dart`, `exercise_detail.dart`. App-wide sweep: the 5 tabs use the auto-inset Material `BottomNavigationBar` (safe); list-only routes (calendar/history/inventory) scroll edge-to-edge by design (no blocked control). **Watch:** `onboarding/solution_page.dart` CTA uses a hardcoded `Positioned(top: 704)` — may sit low on short screens; left as-is to avoid breaking the choreographed reveal, verify on a small device. |

## DECISIONS — need your call before sending to testers

| # | Item | Where | Recommendation |
|---|---|---|---|
| D1 | **RESOLVED 2026-06-11.** Demo gem top-up was reachable in the live shop UI (wallet pill "+" and the "Not enough gems" fallback). Now gated behind `kDebugMode`: release builds hide the "+" button entirely and skip the gem-pack sheet; debug builds keep both for dev/screenshots. Verified: analyze clean, shop/gem tests pass. | shop_page.dart | Done. |
| D2 | **`android:allowBackup` defaults to true** — device backups include SharedPreferences (bodyweight, sex PII). Counter-argument: with no cloud sync, backup is the user's only data-loss protection. | AndroidManifest.xml | Keep enabled for beta (data durability wins pre-launch); revisit with a real backup story. |

## SHOULD-FIX — fine for beta, schedule for early post-beta

| # | Finding | Detail |
|---|---|---|
| S1 | **Save-path write ordering.** Potion charges are consumed and the loot drop is persisted (`workout_summary.dart:277–281`) *before* the session itself is saved (`:307`). A process kill in that window spends a potion / grants loot for a session that never existed. Low probability (sub-second window), but the fix is a deliberate reorder: compute multipliers without persisting, persist after `saveSession`. (Note: an earlier sub-report claimed potions are also consumed for reward-ineligible sessions — verified false; consumption is inside the `eligible` branch.) |
| S2 | **`fromJson` crash paths.** Many models hard-crash on malformed/old-shape data: `SetEntry`/`ExerciseLog`/`WorkoutSession` (`workout_models.dart:144,167,302,309`), `XpBoostPotion` (`xp_boost_potion.dart:50–52`), `ClassState` (`class_state.dart:77–81`), `BodyGoalState`, `WeightEntry`, `Guild`/`GuildMember`, `RestState._decodeWeekdays`. One corrupt entry = whole store fails to load. Beta installs start fresh (no old shapes), so acceptable now — but do a defensive-parsing pass (tryParse + null-safe casts + per-entry skip) before any update that changes schemas. |
| S3 | **Migration done-flags written after the work.** `runClearSelfReportedStatSeedOnce`, `runEndStatBackfillOnce`, `runStatsRecomputeIfRulesChanged` (`migration_service.dart:67–103`) and `ClassMigrationService.migrateIfNeeded` (`class_migration_service.dart:13–29`) set their "done" flag only after a recompute that can throw — a persistent failure re-runs the migration every boot; the class migration re-run could overwrite a user-chosen class. |
| S4 | **Clock-backwards guards missing.** Streak/LCK resets to 0 (`workout_metric_service.dart:63–83`); program day can double-advance (`program_service.dart:88–89`); weekly quests can reset/re-claim (`quest_service.dart:165–195`). Body metrics already has the `max(stored, now)` guard pattern (`body_metrics_service.dart:85`) — replicate it. Requires deliberate clock manipulation; not a beta risk. |
| S5 | **`mcp_toolkit` in runtime `dependencies`** (pubspec.yaml) but imported nowhere — dead weight in the APK. Move to dev_dependencies or remove (then `flutter pub get` + full test run). |
| S6 | **APK size 77.6 MB** (exercise images + demo mp4s). Fine for Firebase App Distribution; for Play Store later, build AAB (`flutter build appbundle`) and consider asset trimming. |

## NOTES (no action)

- Boot sequence is well-protected: `BootService.run()` wraps all boot work in try/catch with an
  onboarding-decision fallback (`boot_service.dart:23–47`).
- Gem ledger design is sound: append-only, idempotent quest claims by claim key, balance-checked
  spends (`gem_service.dart`).
- `SEED_DEMO` seeder is compile-time gated (`String.fromEnvironment`, `main.dart:12`) — dead code
  in release builds; cannot be triggered at runtime.
- Signing config (`build.gradle.kts`) follows the standard Flutter pattern; passwords never reach
  build output. Builds on machines without `key.properties` will fail loudly at the `as String`
  cast — acceptable for a solo project (CI would need a guard).
- Two independent "find the Monday" implementations exist (`QuestService.weeklyPeriodKey`,
  `RestService.weekKey`) — currently consistent; unify if either changes.

## Manual device-test checklist (you run these on a real phone)

Install `build\app\outputs\flutter-apk\app-release.apk` on a clean device (or wipe app data):

1. **Launch** — app icon says "Ironbit" (not student_task), splash plays, no instant crash
   (this validates the release build's R8/minification behavior debug builds don't exercise).
2. **Fresh onboarding** — full run: cold open → quiz → name → class reveal → program select →
   start gate. No step hangs; character created.
3. **Empty states** — visit all 5 tabs with zero sessions; nothing crashes or looks broken.
4. **First workout loop** — start workout → log 1 exercise (few sets) → finish → summary shows
   XP/stat deltas → Save & Exit → session appears in history; Home updates.
5. **Quest claim** — complete a daily quest (Show Up), claim it, gems land in wallet.
6. **Shop** — browse, attempt a purchase (D1 behavior depends on your decision).
7. **Exercise demo player** — open a FULL BODY A lift; video plays muted/looping; HIDE toggle works.
8. **Kill/relaunch** — force-stop mid-session, relaunch: resume flow works, no data loss.
9. **Reduced motion** (if device has it) — demo player starts paused.
10. **Size/perf feel** — install size acceptable, tab switches smooth on your oldest test device.

## Process notes

- Phase 5 (UX audit) pending: run `/uxaudit:uxaudit` in a fresh session (plugin installed
  mid-session today, loads on restart).
- Changelog created at `app-management/releases/v1.0.0.md` as part of this audit.
