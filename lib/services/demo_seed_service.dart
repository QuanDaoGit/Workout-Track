import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/avatar_spec.dart';
import '../models/body_goal_models.dart';
import '../models/calibration_quiz_models.dart';
import '../models/character.dart';
import '../models/character_class.dart';
import '../models/program_models.dart';
import '../models/user_profile_sex.dart';
import '../models/workout_models.dart';
import 'character_service.dart';
import 'profile_service.dart';
import 'program_service.dart';
import 'rest_service.dart';
import 'stat_engine.dart';

/// Marketing-only data seeder. NOT part of the product — it fabricates a
/// believable "solid intermediate" profile so advertising screenshots look
/// lived-in, then lets the real engines derive level, ranks, streak, records,
/// guild standing and quests from the seeded history (so nothing contradicts).
///
/// Trigger at launch (never ships enabled):
///   flutter run --dart-define=SEED_DEMO=intermediate   # wipe + seed
///   flutter run --dart-define=SEED_DEMO=clear          # wipe back to onboarding
///
/// Re-running re-anchors all dates to "today", so the streak stays current
/// across multiple shooting sessions.
class DemoSeedService {
  const DemoSeedService._();

  /// Wipes local state and writes a fresh intermediate persona.
  static Future<void> seedIntermediate({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final today = _dateOnly(now ?? DateTime.now());

    // 1. Persona — VANTA, a Bruiser (red, recomp), established ~11 weeks ago.
    final character = Character(
      name: 'VANTA',
      characterName: 'VANTA',
      calibration: const CalibrationResult(
        goal: BodyGoal.recomp,
        freq: TrainingFreq.high,
        exp: Experience.intermediate,
        bodyWeightKg: 80,
        sex: UserProfileSex.male,
        clazz: CharacterClass.bruiser,
      ),
      classConfirmedAt: today.subtract(const Duration(days: 77)),
      createdAt: today.subtract(const Duration(days: 77)),
    );
    await CharacterService().createCharacterAndCompleteOnboarding(character);

    // 2. Identity mirror + a sharp pixel face.
    await ProfileService().saveDisplayName('VANTA');
    await ProfileService().saveAvatarSpec(
      const AvatarSpec(
        skin: AvatarSkin.tone03,
        eyes: AvatarEyes.neon,
        hair: AvatarHair.swept,
        hairColor: AvatarHairColor.black,
        expression: AvatarExpression.focused,
      ),
    );

    // 3. Workout history — drives stats / XP / records / streak / guild / quests.
    final sessions = _buildSessions(today);
    await prefs.setString(
      'workout_sessions',
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );

    // 4. A real training schedule (so VIT recovery + Training Goals read well).
    await RestService().saveTrainingWeekdays({1, 2, 3, 4, 5}, now: today);

    // 5. An active program ~40% in (Home "Today's Mission" path card).
    final progress = ProgramProgress(
      programId: 'full_body_3x',
      currentWeek: 4,
      currentDayIndex: 0,
      workoutIndex: 0, // FULL BODY A — next-up workout stays actionable
      startedAt: today.subtract(const Duration(days: 35)),
      completedSessions: 10, // of ~24 → ~42%
    );
    await prefs.setString(
      ProgramService.progressKey,
      jsonEncode(progress.toJson()),
    );

    // 6. Prime the combat-stats cache (boot recompute would do this too).
    await StatEngine().calculateAllStats();
  }

  /// Wipes local state entirely (back to a clean first-run).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // --- session generation ---------------------------------------------------

  /// 28 consecutive days ending *yesterday* — today's mission stays open for the
  /// shot while the run still reads as a current 4-week streak (one LCK
  /// diamond). Weights ramp over time so recent sessions set records, and the
  /// count is tuned to land Level 15 (Knight), not Champion. Weights are heavy
  /// enough that capability stats sit in the B/A band.
  static List<WorkoutSession> _buildSessions(DateTime today) {
    final daysAgo = <int>[
      for (var d = 1; d <= 28; d++) d,
    ]..sort((a, b) => b.compareTo(a)); // oldest first → progressive overload

    final out = <WorkoutSession>[];
    final n = daysAgo.length;
    for (var i = 0; i < n; i++) {
      final factor = 0.80 + 0.20 * (i / (n - 1)); // 80% → 100% of base load
      final date = today
          .subtract(Duration(days: daysAgo[i]))
          .add(const Duration(hours: 18, minutes: 30));
      out.add(_session(date, _templates[i % _templates.length], factor, i));
    }
    return out;
  }

  static WorkoutSession _session(
    DateTime date,
    _DayTemplate t,
    double factor,
    int index,
  ) {
    final logs = [
      for (final m in t.moves)
        ExerciseLog(
          exerciseId: m.id,
          exerciseName: _humanize(m.id),
          sets: [
            for (var s = 0; s < m.sets; s++)
              SetEntry(
                weight: m.weight == 0 ? 0 : (m.weight * factor).roundToDouble(),
                reps: m.reps,
              ),
          ],
        ),
    ];
    return WorkoutSession(
      id: 'demo_${date.millisecondsSinceEpoch}_$index',
      date: date,
      muscleGroup: t.group,
      targetDurationMinutes: 45,
      actualDurationSeconds: 2520, // 42 min
      exercises: logs,
      estimatedCalories: 320,
      selectedExerciseIds: [for (final m in t.moves) m.id],
      classAtSave: 'bruiser',
    );
  }

  static String _humanize(String id) => id.replaceAll('_', ' ');

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // Three rotating full-body-leaning days covering STR (chest/legs/triceps),
  // DEF (back/biceps), AGI (shoulders/core) and END (reps).
  static const _templates = <_DayTemplate>[
    _DayTemplate('Chest', [
      _Move('Barbell_Bench_Press_-_Medium_Grip', 70, 8, 4),
      _Move('Incline_Dumbbell_Press', 28, 10, 3),
      _Move('Dumbbell_Shoulder_Press', 22, 10, 3),
      _Move('Triceps_Pushdown', 30, 12, 3),
      _Move('Hanging_Leg_Raise', 0, 12, 2),
    ]),
    _DayTemplate('Back', [
      _Move('Bent_Over_Barbell_Row', 65, 8, 4),
      _Move('Wide-Grip_Lat_Pulldown', 55, 10, 3),
      _Move('Barbell_Curl', 32, 10, 3),
      _Move('Romanian_Deadlift', 80, 8, 3),
      _Move('Russian_Twist', 12, 15, 2),
    ]),
    _DayTemplate('Legs', [
      _Move('Barbell_Squat', 95, 8, 4),
      _Move('Leg_Press', 160, 10, 3),
      _Move('Romanian_Deadlift', 85, 8, 3),
      _Move('Side_Lateral_Raise', 12, 12, 3),
      _Move('Hanging_Leg_Raise', 0, 12, 2),
    ]),
  ];
}

class _DayTemplate {
  const _DayTemplate(this.group, this.moves);
  final String group;
  final List<_Move> moves;
}

class _Move {
  const _Move(this.id, this.weight, this.reps, this.sets);
  final String id;
  final double weight;
  final int reps;
  final int sets;
}
