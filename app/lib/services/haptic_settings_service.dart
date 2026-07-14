import 'package:shared_preferences/shared_preferences.dart';

/// User toggle for haptic feedback (Profile -> Settings -> Haptics).
///
/// Defaults to **on** — the app ships with haptics. Persists across launches;
/// `BootService` reads it into `HapticService.enabled` at boot, and the Settings
/// toggle updates both this store and the live flag. Mirrors
/// `SoundSettingsService`.
class HapticSettingsService {
  static const String _key = 'haptics_enabled_v1';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
