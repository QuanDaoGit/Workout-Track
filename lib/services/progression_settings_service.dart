import 'package:shared_preferences/shared_preferences.dart';

/// User toggle for "Suggested loads" in Profile → Settings.
/// Defaults to enabled on first launch.
class ProgressionSettingsService {
  static const String _key = 'progression_suggestions_enabled';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
