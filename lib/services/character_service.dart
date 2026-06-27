import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/character.dart';
import 'analytics_service.dart';
import 'onboarding_service.dart';

class CharacterService {
  static const activeCharacterKey = 'active_character_v1';

  Future<Character?> loadActiveCharacter() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(activeCharacterKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Character.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  /// Persists the character, then flags onboarding complete. SharedPreferences
  /// has no multi-key transaction, so these are two awaits — and the order is
  /// deliberate: write the character FIRST, set the completion flag SECOND. If
  /// the app is killed in the (tiny) gap, the flag is still false, so the next
  /// launch safely re-onboards and overwrites — rather than the inverse failure
  /// (flag set but no character), which would route a characterless user to Home
  /// and break it. The safe partial state is the one we leave behind.
  Future<void> createCharacterAndCompleteOnboarding(Character character) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(activeCharacterKey, jsonEncode(character.toJson()));
    await OnboardingService().markComplete();
    // Activation-funnel head (ADR 0001). During a SEED_DEMO seed this runs before
    // AnalyticsService.bootstrap (main.dart orders the seed first), so the no-op
    // facade absorbs it and a synthetic persona never emits onboarding_complete.
    await AnalyticsService.instance.logOnboardingComplete();
  }
}
