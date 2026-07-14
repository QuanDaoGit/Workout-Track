import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notification_settings_service.dart';
import 'rest_notification_coordinator.dart' show RestAlertScheduler;
import 'rest_service.dart';
import 'training_reminder_planner.dart';

/// Local (on-device) notifications — no backend, no network, no data leaves the
/// device. Tier A ships one notification: a "rest complete" alert fired when a
/// rest period ends while the app is backgrounded (the in-app bar owns the
/// foreground case; see [RestNotificationCoordinator]).
///
/// Delivery is best-effort: exact when the OS grants the exact-alarm permission,
/// inexact otherwise, and OEM battery managers can still drop a scheduled alarm.
class NotificationService implements RestAlertScheduler {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Fixed id so a re-scheduled rest replaces the pending one (only ever one
  // rest runs at a time).
  static const int _restNotifId = 1001;
  static const String _restChannelId = 'rest_timer';
  static const String _restChannelName = 'Rest timer';
  static const String _restChannelDesc =
      'Alerts you when a rest period is over.';

  // Tier B — training-day reminder. A calmer channel than the alarm-category
  // rest alert: default importance, no full-screen takeover (anti-guilt nudge).
  static const String _trainingChannelId = 'training_reminder';
  static const String _trainingChannelName = 'Training reminders';
  static const String _trainingChannelDesc =
      'A gentle nudge on your training days.';

  /// One-time init: timezone DB + the Android channels. Called from
  /// [BootService]. Does NOT request permission (cold-ask is an anti-pattern —
  /// permission is asked contextually).
  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    // Tier B fires at absolute local wall-clock times, so the device zone must
    // be the real one (the default is UTC → an 08:00 reminder would drift). Tier
    // A is relative (≤5 min) so it never cared; setting the real zone only makes
    // it more correct. Best-effort: fall back to the default zone on failure.
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      debugPrint('NotificationService: could not resolve local timezone: $e');
    }
    try {
      const settings = InitializationSettings(
        // White-silhouette status-bar icon (the launcher mipmap renders as a
        // flat white square — Android masks small-icons by alpha). Default for
        // both the rest alert and the training reminder.
        android: AndroidInitializationSettings('@drawable/ic_stat_ironbit'),
      );
      await _plugin.initialize(settings: settings);
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _restChannelId,
          _restChannelName,
          description: _restChannelDesc,
          importance: Importance.high,
        ),
      );
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _trainingChannelId,
          _trainingChannelName,
          description: _trainingChannelDesc,
          importance: Importance.defaultImportance,
        ),
      );
      // Only latch as initialized once the plugin genuinely came up — otherwise a
      // transient failure would permanently mark us "ready" while the plugin is
      // dead, and every later schedule/cancel would throw "must be initialized".
      _initialized = true;
    } catch (e) {
      // Best-effort: a notification subsystem must never crash boot / a workout
      // (also covers the unit-test env where no platform plugin is registered).
      // _initialized stays false so the next call retries init().
      debugPrint('NotificationService.init failed: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android {
    try {
      return _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
    } catch (_) {
      return null; // no platform plugin (e.g. unit tests) → degrade silently
    }
  }

  /// Requests POST_NOTIFICATIONS (Android 13+) and, best-effort, the
  /// exact-alarm permission. Returns whether posting notifications is allowed.
  /// Call from the contextual soft-ask, never at launch.
  Future<bool> requestPermissions() async {
    final android = _android;
    if (android == null) return false;
    try {
      final granted = await android.requestNotificationsPermission() ?? false;
      // Exact alarm sharpens timing but is optional — inexact is the fallback.
      await android.requestExactAlarmsPermission();
      return granted;
    } catch (e) {
      debugPrint('NotificationService.requestPermissions failed: $e');
      return false;
    }
  }

  /// Whether the OS currently allows posting notifications.
  Future<bool> hasPermission() async {
    try {
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// One-time contextual permission ask for the default-on rest alert — call at
  /// a natural moment (a workout starting), not at launch. No-ops if the user
  /// turned the alert off, or if we've already asked once (never re-nags).
  Future<void> maybeAskRestPermission() async {
    final settings = NotificationSettingsService();
    if (!await settings.isRestTimerAlertEnabled()) return;
    if (await settings.wasRestPermAsked()) return;
    await settings.setRestPermAsked(true);
    await requestPermissions();
  }

  @override
  Future<void> scheduleRestDone(DateTime endsAt) async {
    if (!_initialized) await init();
    // Already over (or invalid) → nothing to fire; zonedSchedule would throw.
    if (!endsAt.isAfter(DateTime.now())) return;

    try {
      final canExact = await _android?.canScheduleExactNotifications() ?? false;
      final mode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _plugin.zonedSchedule(
        id: _restNotifId,
        scheduledDate: tz.TZDateTime.from(endsAt, tz.local),
        title: 'Rest complete',
        body: 'Time for your next set.',
        androidScheduleMode: mode,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _restChannelId,
            _restChannelName,
            channelDescription: _restChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
          ),
        ),
      );
    } catch (e) {
      debugPrint('NotificationService.scheduleRestDone failed: $e');
    }
  }

  @override
  Future<void> cancelRestDone() async {
    // Mirror scheduleRestDone's guard: the coordinator cancels on every app
    // resume, which can run before init() has completed — and the plugin throws
    // "must be initialized before use" if cancel() is called first.
    if (!_initialized) await init();
    try {
      await _plugin.cancel(id: _restNotifId);
    } catch (e) {
      debugPrint('NotificationService.cancelRestDone failed: $e');
    }
  }

  // ── Tier B — training-day reminders ─────────────────────────────────────

  /// Reconcile the scheduled training-day reminders against the current opt-in,
  /// OS permission, schedule and time. **Always clears the whole id range first**
  /// so a removed weekday can't leave a stale weekly alarm firing (Codex review
  /// finding #3), then (re)schedules only when the user has opted in AND the OS
  /// permission is held. Idempotent — safe to call on boot, on a schedule edit,
  /// on a settings change, and right after the opt-in is granted.
  Future<void> syncTrainingReminders() async {
    if (!_initialized) await init();
    await cancelAllTrainingReminders();

    final settings = NotificationSettingsService();
    // Opt-in (explicit) AND the OS grant are both required — a default-off
    // consent flag means granting permission for the rest alert can never
    // silently start firing reminders (Codex review finding #1).
    if (!await settings.isTrainingReminderEnabled()) return;
    if (!await hasPermission()) return;

    final minutes = await settings.trainingReminderMinutes();
    final restState = await RestService().loadState();
    final slots = trainingReminderSlots(
      weekdays: restState.trainingWeekdays,
      minutes: minutes,
    );
    for (final slot in slots) {
      await _scheduleTrainingReminder(slot);
    }
  }

  Future<void> _scheduleTrainingReminder(TrainingReminderSlot slot) async {
    try {
      final canExact = await _android?.canScheduleExactNotifications() ?? false;
      final mode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _plugin.zonedSchedule(
        id: slot.id,
        scheduledDate: _nextInstanceOfWeekdayTime(
          slot.weekday,
          slot.hour,
          slot.minute,
        ),
        title: 'Training day',
        body: 'Time to train. Your move.',
        androidScheduleMode: mode,
        // Weekly repeat at the same weekday + time.
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _trainingChannelId,
            _trainingChannelName,
            channelDescription: _trainingChannelDesc,
            // Gentler than the rest alert: a reminder, not an alarm takeover.
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
    } catch (e) {
      debugPrint('NotificationService.scheduleTrainingReminder failed: $e');
    }
  }

  /// Cancel every training-reminder slot (the full 2001..2007 range).
  Future<void> cancelAllTrainingReminders() async {
    if (!_initialized) await init();
    for (final id in allTrainingReminderIds) {
      try {
        await _plugin.cancel(id: id);
      } catch (e) {
        debugPrint('NotificationService.cancelTrainingReminder($id) failed: $e');
      }
    }
  }

  /// The next future instant matching [weekday] (1=Mon..7=Sun) at [hour]:[minute]
  /// in the device's local zone — the anchor the weekly `dayOfWeekAndTime` match
  /// repeats from.
  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
