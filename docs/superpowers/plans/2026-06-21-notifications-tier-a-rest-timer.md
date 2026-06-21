# Notification system — Tier A foundation (rest-timer-over) — 2026-06-21

## Context
First slice of a local (NOT server-push) notification system. Scope reconciled: PRD/roadmap/
app-briefing now say server/cloud push is out, on-device local notifications are in. Research brief:
`research/insights.md` (2026-06-21 entry). Tier B (opt-in workout-day reminder) and Tier C (state
nudges) are deferred.

## Decisions (research + user intent calls)
- **Local only** — no backend/account/network; preserves the offline/private wedge.
- **Lifecycle-gated**: the rest-over notification is scheduled ONLY when the app backgrounds with an
  active rest, and cancelled on resume. Foreground stays in-app-bar-only → no double-alert, no need to
  distinguish SKIP from natural completion, zero rest-timer call-site edits. `RestTimerService` stays pure.
- **Precision = exact + graceful fallback** (user call): `SCHEDULE_EXACT_ALARM` (user-grantable, no Play
  review); `exactAllowWhileIdle` when `canScheduleExactNotifications()`, else `inexactAllowWhileIdle`.
- **Toggle defaults ON** (user call); OS permission asked contextually (not at launch); denial respected,
  never re-nagged. Best-effort delivery (OEM killers) — never promise exactness.
- **Anti-guilt copy** (utility, no streak/guilt): "Rest complete · Time for your next set."
- Tier A needs no timezone-name plugin: a rest is a short *relative* delay, so
  `tz.TZDateTime.now(tz.local).add(d)` is the correct instant even if `tz.local` defaults to UTC (DST
  irrelevant for ≤5 min). Tier B (absolute daily times) will add `flutter_timezone`.

## Changes by file
1. `pubspec.yaml` — add `flutter_local_notifications`, `timezone`.
2. `android/app/build.gradle.kts` — `multiDexEnabled = true`; `isCoreLibraryDesugaringEnabled = true`;
   `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.
3. `android/app/src/main/AndroidManifest.xml` — add `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`.
4. `lib/services/notification_settings_service.dart` — NEW, mirrors `SoundSettingsService`; key
   `notif_rest_timer_alert_v1`, default **true**.
5. `lib/services/notification_service.dart` — NEW; wraps `FlutterLocalNotificationsPlugin`:
   `init()` (tz init + channel), `requestPermissions()` (POST_NOTIFICATIONS + exact-alarm),
   `scheduleRestDone(endsAt)` (mode chosen by `canScheduleExactNotifications`), `cancelRestDone()`.
   Fixed id `1001`, channel `rest_timer`. Injectable plugin for tests.
6. `lib/services/rest_notification_coordinator.dart` — NEW; `WidgetsBindingObserver`. On
   paused/hidden + active rest + setting on → schedule; on resumed → cancel. Pure
   `didChangeAppLifecycleState` for unit tests.
7. `lib/services/boot_service.dart` — `await NotificationService.instance.init()` (in try; no perm ask).
8. `lib/pages/root_page.dart` — instantiate + register/unregister the coordinator with WidgetsBinding.
9. Settings UI (ironbit-design) — "Rest timer alert" toggle + contextual permission soft-ask.

## Reuse
`SoundSettingsService` (settings pattern), `RestTimerService.current` (state source), `BootService`
(init site), `RootPage` shell (observer host), tokens/sharp-icons (UI).

## Verification
- `flutter analyze` zero issues; `flutter test` all pass.
- New tests: coordinator matrix (lifecycle × active-rest × setting × permission → schedule/cancel);
  settings service default + round-trip; pubspec/manifest drift guard.
- On-device manual: background mid-rest → notification fires ~on time; resume → cancelled; SKIP →
  none; permission denied → inert, no crash.

## Deferred
Tier B daily workout-day reminder (needs `flutter_timezone`, boot receiver + `RECEIVE_BOOT_COMPLETED`,
personalized time from `RestService.trainingWeekdays`); Tier C state nudges.
