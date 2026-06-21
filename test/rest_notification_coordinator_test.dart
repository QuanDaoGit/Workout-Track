import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/rest_notification_coordinator.dart';

/// Records calls so we can assert the coordinator's scheduling decisions without
/// touching the real flutter_local_notifications plugin.
class _FakeScheduler implements RestAlertScheduler {
  final List<DateTime> scheduled = [];
  int cancels = 0;

  @override
  Future<void> scheduleRestDone(DateTime endsAt) async => scheduled.add(endsAt);

  @override
  Future<void> cancelRestDone() async => cancels++;
}

/// Flush the async chain inside the void [didChangeAppLifecycleState].
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 1));

void main() {
  late _FakeScheduler scheduler;
  DateTime? restEndsAt;
  bool enabled = true;

  RestNotificationCoordinator build() => RestNotificationCoordinator(
    scheduler: scheduler,
    restAlertEnabled: () async => enabled,
    activeRestEndsAt: () => restEndsAt,
  );

  setUp(() {
    scheduler = _FakeScheduler();
    restEndsAt = DateTime.now().add(const Duration(minutes: 2));
    enabled = true;
  });

  test('backgrounding with an active rest + setting on schedules at endsAt',
      () async {
    final c = build();
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    await _settle();
    expect(scheduler.scheduled, [restEndsAt]);
    expect(scheduler.cancels, 0);
  });

  test('hidden behaves like paused (schedules)', () async {
    final c = build();
    c.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await _settle();
    expect(scheduler.scheduled, [restEndsAt]);
  });

  test('backgrounding with no active rest schedules nothing', () async {
    restEndsAt = null;
    final c = build();
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    await _settle();
    expect(scheduler.scheduled, isEmpty);
  });

  test('backgrounding with the setting off schedules nothing', () async {
    enabled = false;
    final c = build();
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    await _settle();
    expect(scheduler.scheduled, isEmpty);
  });

  test('resuming cancels any pending alert', () async {
    final c = build();
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _settle();
    expect(scheduler.cancels, 1);
    expect(scheduler.scheduled, isEmpty);
  });

  test('inactive (transient) does nothing', () async {
    final c = build();
    c.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await _settle();
    expect(scheduler.scheduled, isEmpty);
    expect(scheduler.cancels, 0);
  });

  test('background then resume = schedule then cancel (the normal round-trip)',
      () async {
    final c = build();
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    await _settle();
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _settle();
    expect(scheduler.scheduled, [restEndsAt]);
    expect(scheduler.cancels, 1);
  });
}
