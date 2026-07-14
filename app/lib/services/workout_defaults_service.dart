import 'package:shared_preferences/shared_preferences.dart';

import 'class_service.dart';
import 'rest_preference_service.dart';

class WorkoutDefaultsService {
  static const _durationKey = 'default_workout_duration_minutes_v1';
  static const _demoHiddenKey = 'exercise_demo_hidden_v1';
  static const defaultDurationMinutes = 90;
  static const minDurationMinutes = 15;
  static const maxDurationMinutes = 240;

  static int clampDurationMinutes(int minutes) {
    return minutes.clamp(minDurationMinutes, maxDurationMinutes).toInt();
  }

  static int clampRestSeconds(int seconds) {
    return seconds.clamp(30, 300).toInt();
  }

  Future<int> getDurationMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return clampDurationMinutes(
      prefs.getInt(_durationKey) ?? defaultDurationMinutes,
    );
  }

  Future<void> setDurationMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_durationKey, clampDurationMinutes(minutes));
  }

  Future<int> getRestSeconds() async {
    final saved = await RestPreferenceService().get();
    if (saved != null) return clampRestSeconds(saved);
    final cls = await ClassService().getCurrentClass();
    return clampRestSeconds(RestPreferenceService.defaultForClass(cls));
  }

  Future<void> setRestSeconds(int seconds) async {
    await RestPreferenceService().set(clampRestSeconds(seconds));
  }

  /// Whether the form-demo cabinet is collapsed to its strip (user choice,
  /// app-wide). Default false — demos show.
  Future<bool> getExerciseDemoHidden() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_demoHiddenKey) ?? false;
  }

  Future<void> setExerciseDemoHidden(bool hidden) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoHiddenKey, hidden);
  }
}
