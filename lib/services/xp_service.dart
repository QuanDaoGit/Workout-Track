import '../models/workout_models.dart';

class XpService {
  static const List<int> _xpThresholds = [
    0,
    50,
    200,
    500,
    1500,
    3000,
    5000,
    10000,
  ];

  static int calculateSessionXP(WorkoutSession session) {
    int xp = 50;
    xp += session.exercises.fold(0, (sum, e) => sum + e.sets.length * 5);
    xp += session.actualDurationSeconds ~/ 60;
    if (session.isPartial) xp = (xp * 0.5).round();
    return xp;
  }

  static int calculateTotalXP(List<WorkoutSession> sessions) =>
      sessions.fold(0, (sum, s) => sum + calculateSessionXP(s));

  static int getLevel(int totalXP) {
    if (totalXP >= 10000) return 30;
    if (totalXP >= 5000) return 20;
    if (totalXP >= 3000) return 15;
    if (totalXP >= 1500) return 10;
    if (totalXP >= 500) return 5;
    if (totalXP >= 200) return 3;
    if (totalXP >= 50) return 2;
    return 1;
  }

  static String getRank(int level) {
    if (level >= 30) return 'Legend';
    if (level >= 20) return 'Champion';
    if (level >= 10) return 'Knight';
    if (level >= 5) return 'Squire';
    return 'Recruit';
  }

  static int xpForNextLevel(int currentLevel) {
    const milestones = [
      (2, 50),
      (3, 200),
      (5, 500),
      (10, 1500),
      (15, 3000),
      (20, 5000),
      (30, 10000),
    ];
    for (final (lvl, xp) in milestones) {
      if (currentLevel < lvl) return xp;
    }
    return 99999;
  }

  static int xpForCurrentLevel(int currentLevel) {
    int result = 0;
    for (final t in _xpThresholds) {
      if (getLevel(t) <= currentLevel) result = t;
    }
    return result;
  }

  static int calculateStreak(List<WorkoutSession> sessions) {
    final days =
        sessions
            .where((s) => !s.isPartial)
            .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    if (days.isEmpty) return 0;
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final yesterday = today.subtract(const Duration(days: 1));
    if (days.first != today && days.first != yesterday) return 0;

    int streak = 1;
    for (int i = 0; i < days.length - 1; i++) {
      if (days[i].difference(days[i + 1]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}
