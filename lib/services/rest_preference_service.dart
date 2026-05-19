import 'package:shared_preferences/shared_preferences.dart';

import '../models/character_class.dart';

/// Sticky rest-duration preference. Saved once the user picks on
/// `start_workout`; subsequent workouts pre-fill from this value.
///
/// Class-based defaults apply only on first-ever workout (no saved value):
/// Tank = 180 s, Bruiser = 90 s, Assassin = 60 s. Heavy lifters rest longer.
class RestPreferenceService {
  static const _key = 'last_rest_seconds';

  /// Returns the user's saved preference, or `null` if never set.
  Future<int?> get() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key);
  }

  Future<void> set(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, seconds);
  }

  /// Class-based default applied when [get] returns null.
  static int defaultForClass(CharacterClass cls) => switch (cls) {
    CharacterClass.tank => 180,
    CharacterClass.bruiser => 90,
    CharacterClass.assassin => 60,
  };
}
