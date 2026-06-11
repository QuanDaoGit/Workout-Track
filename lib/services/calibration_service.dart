import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/strength_standards.dart';
import '../models/calibration_quiz_models.dart';
import '../models/user_profile_sex.dart';
import '../models/workout_models.dart';
import 'stat_engine.dart';

/// Turns the onboarding "calibration run" into starting character stats.
///
/// Reads the logged sets of the first workout(s), estimates a per-stat 1RM
/// (Epley), maps it to a strength tier, and stores a per-stat *seed volume* in
/// the same kg-volume currency [StatEngine] consumes. The engine adds the seed
/// before its log curve, so calibration composes with real training and is
/// never erased by a recompute (Gap 1). The seed only ratchets upward and
/// freezes after [calibrationSessionTarget] sessions.
class CalibrationService {
  CalibrationService({StatEngine? statEngine})
    : _statEngine = statEngine ?? StatEngine();

  final StatEngine _statEngine;

  static const _seedKey = StatEngine.calibrationSeedKey;
  static const calibrationSessionCountKey = 'calibration_session_count_v1';
  static const calibrationCompleteKey = 'calibration_complete_v1';
  static const calibrationSeedSourceKey = 'calibration_seed_source_v1';
  static const workoutSeedSource = 'workout';
  static const _sessionCountKey = calibrationSessionCountKey;
  static const _completeKey = calibrationCompleteKey;
  static const _bodyweightKey = 'calibration_bodyweight_kg_v1';
  static const _heightKey = 'calibration_height_cm_v1';
  static const _sexKey = 'calibration_sex_v1';
  static const _freqKey = 'calibration_freq_v1';
  static const _experienceKey = 'calibration_experience_v1';
  static const _classConfirmedAtKey = 'class_confirmed_at_v1';

  static const calibrationSessionTarget = 3;
  static const _maxRepsForOneRm = 12; // Epley is reliable for ~2–10 reps.

  // --- Screen 4 inputs ------------------------------------------------------

  Future<void> saveCalibrationInputs({
    double? bodyweightKg,
    double? heightCm,
    required UserProfileSex sex,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (bodyweightKg != null && bodyweightKg > 0) {
      await prefs.setDouble(_bodyweightKey, bodyweightKg);
    } else {
      await prefs.remove(_bodyweightKey);
    }
    await prefs.setString(_sexKey, sex.name);
    await saveHeightCm(heightCm);
  }

  Future<double?> bodyweightKg() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_bodyweightKey);
  }

  /// Body height in canonical centimetres. Profile info only — no stat
  /// calculation consumes it yet. Stored here so all one-time onboarding inputs
  /// share a persistence home. Pass null/<=0 to clear.
  Future<void> saveHeightCm(double? heightCm) async {
    final prefs = await SharedPreferences.getInstance();
    if (heightCm != null && heightCm > 0) {
      await prefs.setDouble(_heightKey, heightCm);
    } else {
      await prefs.remove(_heightKey);
    }
  }

  Future<double?> heightCm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_heightKey);
  }

  Future<UserProfileSex> sex() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfileSex.fromName(prefs.getString(_sexKey));
  }

  /// Quiz-derived training preferences (Q2 frequency + Q3 experience). Kept
  /// alongside the other one-time onboarding inputs in the same service so all
  /// quiz-derived data has one persistence home.
  Future<void> saveTrainingPreferences({
    required TrainingFreq freq,
    required Experience exp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_freqKey, freq.name);
    await prefs.setString(_experienceKey, exp.name);
  }

  Future<TrainingFreq?> trainingFreq() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_freqKey);
    return raw == null ? null : TrainingFreq.fromName(raw);
  }

  Future<Experience?> experience() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_experienceKey);
    return raw == null ? null : Experience.fromName(raw);
  }

  Future<void> markClassConfirmed({DateTime? at}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _classConfirmedAtKey,
      (at ?? DateTime.now()).toIso8601String(),
    );
  }

  Future<DateTime?> classConfirmedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_classConfirmedAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completeKey) ?? false;
  }

  Future<int> sessionCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_sessionCountKey) ?? 0;
  }

  // --- Epley 1RM ------------------------------------------------------------

  static double epley1Rm(double weight, int reps) {
    if (weight <= 0 || reps <= 0) return 0;
    return weight * (1 + reps / 30);
  }

  /// Best estimated 1RM across the qualifying sets of a log (weighted sets of
  /// at most [_maxRepsForOneRm] reps).
  static double bestOneRmForLog(ExerciseLog log) {
    var best = 0.0;
    for (final set in log.sets) {
      if (set.reps <= 0 || set.reps > _maxRepsForOneRm || set.weight <= 0) {
        continue;
      }
      final est = epley1Rm(set.weight, set.reps);
      if (est > best) best = est;
    }
    return best;
  }

  // --- recording ------------------------------------------------------------

  /// Records one calibration workout and returns the updated seed volumes.
  /// No-op (returns current seed) once calibration is frozen.
  Future<Map<String, double>> recordCalibrationWorkout(
    WorkoutSession session, {
    Map<String, String>? catalog,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existingSeed = _decodeDoubleMap(prefs.getString(_seedKey));
    if (prefs.getBool(_completeKey) ?? false) return existingSeed;

    final cat = catalog ?? await _statEngine.loadCatalog();
    final bw = prefs.getDouble(_bodyweightKey);
    final sx = UserProfileSex.fromName(prefs.getString(_sexKey));

    // Best 1RM and actual logged volume per stat for this session. The actual
    // volume is expressed in the engine's intensity-credit currency (v3) so
    // the top-up below subtracts exactly what the engine will add for this
    // session, landing the displayed stat on the tier target.
    final sessionBodyweight =
        session.bodyweightKgAtSave ?? bw ?? StatEngine.fallbackBodyweightKg;
    final best1RmPerStat = <String, double>{};
    final actualVolumePerStat = <String, double>{};
    for (final log in session.exercises) {
      final muscle = cat[log.exerciseId] ?? '';
      final stat = StatEngine.statForPrimaryMuscle(muscle);
      if (stat == null) continue;
      final oneRm = bestOneRmForLog(log);
      if (oneRm > (best1RmPerStat[stat] ?? 0)) best1RmPerStat[stat] = oneRm;
      actualVolumePerStat[stat] =
          (actualVolumePerStat[stat] ?? 0) +
          StatEngine.intensityCreditForLog(log, bodyweightKg: sessionBodyweight);
    }

    final newSeed = Map<String, double>.from(existingSeed);
    best1RmPerStat.forEach((stat, oneRm) {
      if (oneRm <= 0) return;
      final tier = (bw != null && bw > 0)
          ? StrengthStandards.tierForRelativeStrength(oneRm / bw, sx)
          : StrengthStandards.tierForAbsolute1RM(oneRm);
      final targetVolume = StatEngine.volumeForStat(
        StrengthStandards.targetStatForTier(tier),
      );
      // Top-up over this session's own logged volume so the displayed stat
      // lands on the tier target without double-counting the session.
      final topUp = max(0.0, targetVolume - (actualVolumePerStat[stat] ?? 0));
      // Ratchet upward only — an off-day or light session never lowers a seed.
      newSeed[stat] = max(existingSeed[stat] ?? 0, topUp);
    });

    final count = (prefs.getInt(_sessionCountKey) ?? 0) + 1;
    await prefs.setString(_seedKey, jsonEncode(newSeed));
    await prefs.setInt(_sessionCountKey, count);
    if (newSeed.isNotEmpty) {
      await prefs.setString(calibrationSeedSourceKey, workoutSeedSource);
    }
    if (count >= calibrationSessionTarget) {
      await prefs.setBool(_completeKey, true);
    }
    return newSeed;
  }

  /// Calibrates from an early real workout — measured 1RM → tier → seed — when
  /// calibration is still open and this is within the first
  /// [calibrationSessionTarget] completed sessions. No-op otherwise, so existing
  /// users with training history are never retroactively seeded (which would
  /// inflate stats they already earned). This drives onboarding calibration off
  /// the user's first real workouts instead of a forced in-onboarding run —
  /// accurate (measured, not self-reported) and friction-free.
  Future<void> maybeCalibrateEarlyWorkout(
    WorkoutSession session, {
    required int completedSessionCount,
    Map<String, String>? catalog,
  }) async {
    if (completedSessionCount > calibrationSessionTarget) return;
    if (await isComplete()) return;
    await recordCalibrationWorkout(session, catalog: catalog);
  }

  Future<Map<String, double>> seedVolumes() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeDoubleMap(prefs.getString(_seedKey));
  }

  Map<String, double> _decodeDoubleMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in decoded.entries) e.key: (e.value as num).toDouble(),
    };
  }
}
