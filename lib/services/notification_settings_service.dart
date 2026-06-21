import 'package:shared_preferences/shared_preferences.dart';

/// Per-category user toggles for local notifications (Profile -> Settings).
///
/// Tier A ships one category: the rest-timer "rest complete" alert. Defaults to
/// **on** (utility default, like Hevy/Strong) — but the OS notification
/// permission is asked contextually, so a default-on toggle is inert until the
/// user grants permission. Mirrors [SoundSettingsService]: one bool per key, no
/// JSON blob (so there is no read-modify-write race).
class NotificationSettingsService {
  static const String _restTimerKey = 'notif_rest_timer_alert_v1';
  static const String _restPermAskedKey = 'notif_rest_perm_asked_v1';

  Future<bool> isRestTimerAlertEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_restTimerKey) ?? true;
  }

  Future<void> setRestTimerAlertEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_restTimerKey, value);
  }

  /// Whether we've already made the one-time contextual permission ask, so the
  /// default-on alert prompts exactly once (and never re-nags after a denial).
  Future<bool> wasRestPermAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_restPermAskedKey) ?? false;
  }

  Future<void> setRestPermAsked(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_restPermAskedKey, value);
  }
}
