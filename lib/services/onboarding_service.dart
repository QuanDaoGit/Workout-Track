import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the first-run onboarding flow has been completed. Local-only;
/// a reinstall wipes this, so a fresh install re-onboards automatically.
class OnboardingService {
  static const _key = 'onboarding_complete_v1';

  Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
