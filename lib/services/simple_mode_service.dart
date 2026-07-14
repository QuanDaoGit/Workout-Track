import 'package:shared_preferences/shared_preferences.dart';

import '../models/calibration_quiz_models.dart';

/// The recommended Simple Mode default for a self-reported [Experience], used to
/// pre-select the onboarding guidance step (`reminders_primer_page.dart`). The
/// two highest tiers default to Compact (Simple Mode ON — pre-workout
/// scaffolding hidden); novice/beginner default to OFF (extra suggestions
/// shown). It is only a *pre-selection*: the user sees it, can flip it in one
/// tap, and can change it anytime in Settings — so a weak self-report never
/// silently reduces the experience (the choice is always visible + reversible,
/// and an un-shown/killed onboarding fails safe to OFF).
bool simpleModeDefaultForExperience(Experience exp) =>
    exp == Experience.intermediate || exp == Experience.advanced;

/// "Simple Mode" — an opt-in umbrella toggle in Profile → Settings for
/// experienced users who want to just-train: it strips the *pre-workout
/// scaffolding* (warm-up advisory card, the TRY/suggested-load prompt, the
/// curated first-run loadout default, and the progression re-opt-in nudge).
///
/// It is NOT a separate product/mode fork — the identity/XP/loot/class layer
/// is untouched (research 2026-06-28: serve experienced users with adaptive
/// defaults inside ONE app, not a fork). Default OFF, so it's a no-op for
/// existing users until they opt in. Surfaces read it at screen init (the same
/// contract as [ProgressionSettingsService]), so a flip takes effect on the
/// next opened Start/Exercise screen.
class SimpleModeService {
  static const String _key = 'simple_mode_enabled_v1';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
