import 'package:shared_preferences/shared_preferences.dart';

/// Per-category user toggles for local notifications (Profile -> Settings).
///
/// Two categories:
/// - **Tier A — rest-timer "rest complete" alert.** Default **on** (utility
///   default, like Hevy/Strong); the OS permission is asked contextually at the
///   first workout, so a default-on toggle is inert until the user grants it.
/// - **Tier B — training-day reminder.** Default **off** — a re-engagement
///   nudge is explicit-opt-in only (anti-guilt + no consent bypass: because
///   POST_NOTIFICATIONS is one grant for all types, a default-on reminder could
///   start firing the moment the user granted permission for the *rest* alert,
///   ignoring a "Not now"). It turns on only via the onboarding primer or the
///   Settings toggle. Scheduling additionally requires OS permission.
///
/// Mirrors [SoundSettingsService]: one value per key, no JSON blob (so there is
/// no read-modify-write race).
class NotificationSettingsService {
  static const String _restTimerKey = 'notif_rest_timer_alert_v1';
  static const String _restPermAskedKey = 'notif_rest_perm_asked_v1';
  static const String _trainingReminderKey = 'notif_training_reminder_v1';
  static const String _trainingReminderTimeKey = 'notif_training_reminder_time_v1';
  static const String _trainingPrimerShownKey = 'notif_training_primer_shown_v1';

  /// Default reminder time: 08:00 local, as minutes-since-midnight.
  static const int defaultTrainingReminderMinutes = 8 * 60;

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

  // ── Tier B — training-day reminder ──────────────────────────────────────

  /// The explicit opt-in for training-day reminders. **Default off** — it turns
  /// on only when the user accepts the primer or flips the Settings toggle.
  /// Scheduling still also requires the OS notification permission.
  Future<bool> isTrainingReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trainingReminderKey) ?? false;
  }

  Future<void> setTrainingReminderEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trainingReminderKey, value);
  }

  /// The time-of-day the reminder fires, as minutes since local midnight.
  Future<int> trainingReminderMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_trainingReminderTimeKey) ?? defaultTrainingReminderMinutes;
    return raw.clamp(0, 24 * 60 - 1);
  }

  Future<void> setTrainingReminderMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_trainingReminderTimeKey, minutes.clamp(0, 24 * 60 - 1));
  }

  /// Whether the one-time onboarding reminder primer has already been shown, so
  /// it is offered exactly once (and never re-nags). Settings is the path back.
  Future<bool> wasTrainingPrimerShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trainingPrimerShownKey) ?? false;
  }

  Future<void> setTrainingPrimerShown(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trainingPrimerShownKey, value);
  }
}
