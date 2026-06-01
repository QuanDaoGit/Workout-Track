import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_models.dart';

/// User toggle for "Suggested loads" in Profile -> Settings.
/// Defaults to off until the user opts in after enough completed workouts.
class ProgressionSettingsService {
  static const String _key = 'progression_suggestions_enabled';
  static const String _promptAcceptedKey = 'progression_prompt_accepted';
  static const String _promptDismissCountKey =
      'progression_prompt_dismiss_count';
  static const String _promptDismissedUntilKey =
      'progression_prompt_dismissed_until';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    if (value) await prefs.setBool(_promptAcceptedKey, true);
  }

  Future<bool> shouldShowOptInPrompt({
    required List<WorkoutSession> sessions,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_key) == true) return false;
    if (prefs.getBool(_promptAcceptedKey) == true) return false;

    final dismissCount = prefs.getInt(_promptDismissCountKey) ?? 0;
    if (dismissCount >= 3) return false;

    final dismissedUntilRaw = prefs.getString(_promptDismissedUntilKey);
    final dismissedUntil = dismissedUntilRaw == null
        ? null
        : DateTime.tryParse(dismissedUntilRaw);
    final reference = now ?? DateTime.now();
    if (dismissedUntil != null && dismissedUntil.isAfter(reference)) {
      return false;
    }

    final completed = sessions
        .where((session) => !session.isPartial && !session.isAbandoned)
        .length;
    return completed >= 5;
  }

  Future<void> acceptOptInPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    await prefs.setBool(_promptAcceptedKey, true);
  }

  Future<void> dismissOptInPrompt({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final nextCount = (prefs.getInt(_promptDismissCountKey) ?? 0) + 1;
    await prefs.setInt(_promptDismissCountKey, nextCount);
    if (nextCount < 3) {
      final until = (now ?? DateTime.now()).add(const Duration(days: 30));
      await prefs.setString(_promptDismissedUntilKey, until.toIso8601String());
    }
  }
}
