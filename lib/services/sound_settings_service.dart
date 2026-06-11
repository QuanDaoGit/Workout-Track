import 'package:shared_preferences/shared_preferences.dart';

/// User toggle for sound effects (Profile -> Settings -> Sound).
///
/// Defaults to **on** — the app ships with sound. Persists across launches;
/// `main()` reads it into [SfxService.enabled] at boot, and the Settings toggle
/// updates both this store and the live flag.
class SoundSettingsService {
  static const String _key = 'sound_enabled_v1';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
