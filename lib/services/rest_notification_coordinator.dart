import 'package:flutter/widgets.dart';

/// The slice of notification scheduling the rest coordinator needs. Kept as a
/// tiny interface so the coordinator's unit tests never touch the real plugin.
/// Implemented by `NotificationService`.
abstract interface class RestAlertScheduler {
  Future<void> scheduleRestDone(DateTime endsAt);
  Future<void> cancelRestDone();
}

/// Bridges the rest timer to a local notification, gated on app lifecycle so the
/// notification exists **only while the app is backgrounded**:
///
/// - foreground → the in-app rest bar owns the countdown/alert (no notification,
///   so no double-alert, and natural-completion's `cancel()` is irrelevant here);
/// - backgrounded with an active rest + the user setting on → schedule a
///   "rest complete" alert at the rest's end instant;
/// - resumed → cancel any pending alert (the bar takes over again).
///
/// Decoupled from `RestTimerService`/`NotificationSettingsService` via injected
/// callbacks so `didChangeAppLifecycleState` is directly unit-testable.
class RestNotificationCoordinator with WidgetsBindingObserver {
  RestNotificationCoordinator({
    required RestAlertScheduler scheduler,
    required Future<bool> Function() restAlertEnabled,
    required DateTime? Function() activeRestEndsAt,
  }) : _scheduler = scheduler,
       _restAlertEnabled = restAlertEnabled,
       _activeRestEndsAt = activeRestEndsAt;

  final RestAlertScheduler _scheduler;
  final Future<bool> Function() _restAlertEnabled;
  final DateTime? Function() _activeRestEndsAt;

  /// Register with the binding (call once from the shell).
  void attach() => WidgetsBinding.instance.addObserver(this);

  /// Unregister (call from the shell's dispose).
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _onBackground();
      case AppLifecycleState.resumed:
        _onForeground();
      case AppLifecycleState.inactive:
        // Transient (e.g. app switcher, incoming call) — don't act; resume or
        // paused will follow and settle the real state.
        break;
    }
  }

  Future<void> _onBackground() async {
    final endsAt = _activeRestEndsAt();
    if (endsAt == null) return; // no rest running
    if (!await _restAlertEnabled()) return; // user turned the alert off
    await _scheduler.scheduleRestDone(endsAt);
  }

  Future<void> _onForeground() => _scheduler.cancelRestDone();
}
