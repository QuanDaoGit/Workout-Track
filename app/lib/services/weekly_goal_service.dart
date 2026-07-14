import 'package:shared_preferences/shared_preferences.dart';

import '../data/programs_library.dart';
import '../models/calibration_quiz_models.dart';
import 'calibration_service.dart';
import 'program_service.dart';

/// Weekly train-days goal — a process goal ("train N days this week").
///
/// Process goals that are self-set and attainable outperform assigned or
/// outcome goals for exercise adherence, so the goal is seeded from what the
/// user already told us (program cadence, calibration quiz) at the *lower*
/// bound of their stated band, and stays user-editable.
class WeeklyGoalService {
  static const String goalKey = 'weekly_goal_v1';
  static const int minGoalDays = 2;
  static const int maxGoalDays = 7;
  static const int defaultGoalDays = 3;

  Future<int> getGoalDays() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(goalKey);
    if (stored != null) return stored.clamp(minGoalDays, maxGoalDays);
    return seededGoalDays();
  }

  Future<void> setGoalDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(goalKey, days.clamp(minGoalDays, maxGoalDays));
  }

  /// Seed priority: active program cadence → calibration quiz frequency
  /// (lower bound, so the opening weeks are winnable) → 3-day default.
  Future<int> seededGoalDays() async {
    final progress = await ProgramService().getActiveProgress();
    if (progress != null) {
      final program = programById(progress.programId);
      if (program != null) {
        return program.daysPerWeek.clamp(minGoalDays, maxGoalDays);
      }
    }
    final freq = await CalibrationService().trainingFreq();
    return switch (freq) {
      TrainingFreq.low => 2,
      TrainingFreq.mid => 4,
      TrainingFreq.high => 6,
      null => defaultGoalDays,
    };
  }
}
