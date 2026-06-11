import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/services/sound_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to on when nothing is stored', () async {
    expect(await SoundSettingsService().isEnabled(), isTrue);
  });

  test('setEnabled persists and round-trips', () async {
    final service = SoundSettingsService();

    await service.setEnabled(false);
    expect(await service.isEnabled(), isFalse);

    await service.setEnabled(true);
    expect(await service.isEnabled(), isTrue);
  });
}
