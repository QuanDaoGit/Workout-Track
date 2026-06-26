import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/services/notification_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('rest-timer alert defaults ON (utility default)', () async {
    expect(await NotificationSettingsService().isRestTimerAlertEnabled(), true);
  });

  test('rest-timer alert round-trips', () async {
    final s = NotificationSettingsService();
    await s.setRestTimerAlertEnabled(false);
    expect(await s.isRestTimerAlertEnabled(), false);
    await s.setRestTimerAlertEnabled(true);
    expect(await s.isRestTimerAlertEnabled(), true);
  });

  test('permission-asked flag defaults false and round-trips', () async {
    final s = NotificationSettingsService();
    expect(await s.wasRestPermAsked(), false);
    await s.setRestPermAsked(true);
    expect(await s.wasRestPermAsked(), true);
  });

  test('training reminder defaults OFF (explicit opt-in, no consent bypass)',
      () async {
    expect(await NotificationSettingsService().isTrainingReminderEnabled(),
        false);
  });

  test('training reminder enabled round-trips', () async {
    final s = NotificationSettingsService();
    await s.setTrainingReminderEnabled(true);
    expect(await s.isTrainingReminderEnabled(), true);
    await s.setTrainingReminderEnabled(false);
    expect(await s.isTrainingReminderEnabled(), false);
  });

  test('reminder time defaults to 08:00 and round-trips (clamped)', () async {
    final s = NotificationSettingsService();
    expect(await s.trainingReminderMinutes(),
        NotificationSettingsService.defaultTrainingReminderMinutes);
    expect(NotificationSettingsService.defaultTrainingReminderMinutes, 8 * 60);
    await s.setTrainingReminderMinutes(19 * 60 + 30); // 7:30 PM
    expect(await s.trainingReminderMinutes(), 19 * 60 + 30);
    // Out-of-range is clamped into a valid time-of-day.
    await s.setTrainingReminderMinutes(99999);
    expect(await s.trainingReminderMinutes(), 24 * 60 - 1);
  });

  test('training primer-shown flag defaults false and round-trips', () async {
    final s = NotificationSettingsService();
    expect(await s.wasTrainingPrimerShown(), false);
    await s.setTrainingPrimerShown(true);
    expect(await s.wasTrainingPrimerShown(), true);
  });
}
