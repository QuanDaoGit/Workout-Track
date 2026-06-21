import 'dart:math';

import '../models/unit_models.dart';
import '../models/workout_models.dart';
import '../models/xp_reward_models.dart';
import 'unit_settings_service.dart';

class XpProgress {
  const XpProgress({
    required this.totalXP,
    required this.level,
    required this.levelBaseXP,
    required this.nextLevelXP,
  });

  final int totalXP;
  final int level;
  final int levelBaseXP;
  final int nextLevelXP;

  int get currentLevelXP => max(0, totalXP - levelBaseXP);

  int get levelSpanXP => max(1, nextLevelXP - levelBaseXP);

  double get fraction =>
      (currentLevelXP / levelSpanXP).clamp(0.0, 1.0).toDouble();

  String get label => '$currentLevelXP / $levelSpanXP XP';
}

class XpService {
  /// XP→level curve: concave + contiguous. `level = 1 + floor(sqrt(totalXP/k))`,
  /// so every integer level exists (no more 50–100-session gaps at the top) and
  /// the cost per level grows linearly — fast early, gently slowing. k = 11 is
  /// the largest scale that keeps every legacy threshold at or above its old
  /// level (50→2, 200→3, 500→5, 1500→10, 3000→15, 5000→20, 10000→30), so a
  /// re-derivation on update can never demote a user's level or rank.
  static const double _levelCurveScale = 11.0;

  static int calculateSessionXP(WorkoutSession session) {
    if (session.isAbandoned) {
      return _abandonedTimeXP(session, session.actualDurationSeconds);
    }
    if (session.isOngoing) {
      return _partialPerformanceXP(session, session.actualDurationSeconds);
    }
    return session.awardedXP ??
        _completedSessionXP(session, session.actualDurationSeconds);
  }

  static int calculateLiveSessionXP(WorkoutSession session, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final elapsedSeconds = session.elapsedSecondsForDisplay(currentTime);

    if (session.isAbandoned) {
      return _abandonedTimeXP(session, elapsedSeconds);
    }
    if (session.isOngoing) {
      return _partialPerformanceXP(session, elapsedSeconds);
    }
    return session.awardedXP ?? _completedSessionXP(session, elapsedSeconds);
  }

  static int calculateBaseSessionXP(WorkoutSession session) {
    if (session.isAbandoned) {
      return _abandonedTimeXP(session, session.actualDurationSeconds);
    }
    if (session.isOngoing) {
      return _partialPerformanceXP(session, session.actualDurationSeconds);
    }
    return _completedSessionXP(session, session.actualDurationSeconds);
  }

  static SessionRewardEligibility rewardEligibility(WorkoutSession session) {
    if (session.isAbandoned) {
      return const SessionRewardEligibility(
        eligible: false,
        reason: 'Session ended early.',
      );
    }
    if (session.isOngoing || session.isPartial) {
      return const SessionRewardEligibility(
        eligible: false,
        reason: 'Finish the session to earn XP.',
      );
    }

    final durationEligible = session.actualDurationSeconds >= 15 * 60;
    final volumeEligible = _totalVolume(session) >= 200;
    final exerciseEligible =
        session.exercises.where((log) => log.sets.isNotEmpty).length >= 3;
    if (durationEligible || volumeEligible || exerciseEligible) {
      return const SessionRewardEligibility(
        eligible: true,
        reason: 'Workout qualifies for rewards.',
      );
    }
    return SessionRewardEligibility(
      eligible: false,
      reason:
          'Log 15 min, ${formatWeight(200, Units.weight, decimals: 0)}, or 3 exercises to earn XP.',
    );
  }

  static SessionXpBreakdown buildBreakdown({
    required WorkoutSession session,
    required int baseXP,
    required double lckMultiplier,
    required double potionMultiplier,
    int lootBonusXP = 0,
  }) {
    final eligibility = rewardEligibility(session);
    return SessionXpBreakdown(
      eligibility: eligibility,
      baseXP: eligibility.eligible ? baseXP : 0,
      lckMultiplier: eligibility.eligible ? lckMultiplier : 1.0,
      potionMultiplier: eligibility.eligible ? potionMultiplier : 1.0,
      lootBonusXP: eligibility.eligible ? lootBonusXP : 0,
    );
  }

  /// Weekly LCK diamond thresholds, in consecutive consistency weeks. Fast-start
  /// ladder: the first diamond lands after a single clean week, the full
  /// four-diamond 3.0x buff at ten. See `RestService.consistencyWeeks` for how
  /// the streak (LCK) itself is earned and reset.
  static const lckDiamondWeekThresholds = [1, 3, 6, 10];

  static int lckDiamondCount(int lck) {
    var filled = 0;
    for (final threshold in lckDiamondWeekThresholds) {
      if (lck >= threshold) filled++;
    }
    return filled;
  }

  static double lckXpMultiplier(int lck) => 1.0 + (lckDiamondCount(lck) * 0.5);

  static String multiplierLabel(double multiplier) {
    final fixed = multiplier.toStringAsFixed(1);
    return '${fixed}x';
  }

  static int _completedSessionXP(WorkoutSession session, int elapsedSeconds) {
    int xp = 50;
    xp += session.exercises.fold(0, (sum, e) => sum + e.sets.length * 5);
    xp += elapsedSeconds ~/ 60;
    return xp;
  }

  static double _totalVolume(WorkoutSession session) =>
      session.exercises.fold(0, (sum, log) => sum + log.totalVolume);

  static int _partialPerformanceXP(WorkoutSession session, int elapsedSeconds) {
    if (session.exercises.isEmpty && elapsedSeconds <= 0) return 0;
    return (_completedSessionXP(session, elapsedSeconds) * 0.5).round();
  }

  static int _abandonedTimeXP(WorkoutSession session, int elapsedSeconds) {
    final elapsedMinutes = max(0, elapsedSeconds ~/ 60);
    return min(elapsedMinutes, session.targetDurationMinutes);
  }

  static int calculateTotalXP(List<WorkoutSession> sessions) => sessions
      .where((s) => !s.isOngoing)
      .fold(0, (sum, s) => sum + calculateSessionXP(s));

  static XpProgress progressForTotalXP(int totalXP) {
    final level = getLevel(totalXP);
    return XpProgress(
      totalXP: totalXP,
      level: level,
      levelBaseXP: xpForCurrentLevel(level),
      nextLevelXP: xpForNextLevel(level),
    );
  }

  static int getLevel(int totalXP) {
    if (totalXP <= 0) return 1;
    return 1 + sqrt(totalXP / _levelCurveScale).floor();
  }

  static String getRank(int level) {
    if (level >= 30) return 'Legend';
    if (level >= 20) return 'Champion';
    if (level >= 10) return 'Knight';
    if (level >= 5) return 'Squire';
    return 'Recruit';
  }

  /// Total XP at which [currentLevel] advances to the next level — the inverse
  /// of [getLevel] at the boundary (`k × level²`).
  static int xpForNextLevel(int currentLevel) {
    final l = currentLevel < 1 ? 1 : currentLevel;
    return (_levelCurveScale * l * l).round();
  }

  /// Total XP at which [currentLevel] begins — the floor of its progress bar
  /// (`k × (level − 1)²`).
  static int xpForCurrentLevel(int currentLevel) {
    final l = currentLevel < 1 ? 1 : currentLevel;
    return (_levelCurveScale * (l - 1) * (l - 1)).round();
  }
}
