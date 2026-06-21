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
}
