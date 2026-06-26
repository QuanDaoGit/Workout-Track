import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notification_settings_service.dart';
import 'rest_notification_coordinator.dart' show RestAlertScheduler;

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

  /// One-time init: timezone DB + the Android channel. Called from
  /// [BootService]. Does NOT request permission (cold-ask is an anti-pattern —
  /// permission is asked contextually).
  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    // Tier A only schedules short *relative* delays, so the zone label is
    // irrelevant to the firing instant (DST can't shift within a ≤5 min rest).
    // tz.local is left at its default; Tier B (absolute daily times) will set it.
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
}
