import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/character.dart';
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

  Future<void> createCharacterAndCompleteOnboarding(Character character) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(activeCharacterKey, jsonEncode(character.toJson()));
    await OnboardingService().markComplete();
  }
}
