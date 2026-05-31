import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/class_definitions.dart';
import '../data/muscle_groups.dart';
import '../models/character_class.dart';
import '../models/rest_models.dart';
import '../models/workout_models.dart';
import 'exercise_catalog_service.dart';
import 'rest_service.dart';
import 'workout_metric_service.dart';

class StatEngine {
  StatEngine({DateTime Function()? nowProvider, Map<String, String>? catalog})
    : _nowProvider = nowProvider ?? DateTime.now,
      _catalogOverride = catalog;

  static const combatStatsKey = 'combat_stats';
  static const calibrationSeedKey = 'calibration_seed_volumes_v1';
  static const _sessionsKey = 'workout_sessions';
  static const _peaksKey = 'combat_stat_peaks';
  static const _lastDeltaKey = 'combat_stat_last_delta';
  static const _lastSessionDateKey = 'combat_stats_last_session_date';
  static const _lastDecayDateKey = 'combat_stats_last_decay_date';
  static const endBackfillNoticeKey = 'end_stat_backfill_notice_pending';

  static const outputStats = ['STR', 'DEF', 'VIT', 'AGI', 'END'];
  static const stats = ['STR', 'DEF', 'VIT', 'AGI', 'END', 'LCK'];
  static const volumeStats = outputStats;
  // VIT is no longer volume-derived (it's the recovery meter), so it's out of
  // the kg-volume set and the decay set. END decays; VIT/LCK do not.
  static const _kgVolumeStats = ['STR', 'DEF', 'AGI'];
  static const _decayableStats = ['STR', 'DEF', 'AGI', 'END'];
  static const baseOutputStatValue = 10;

  /// Trailing window for the VIT recovery-balance meter.
  static const _vitalityWindowDays = 14;

  final DateTime Function() _nowProvider;
  final Map<String, String>? _catalogOverride;

  /// Returns all 5 stats as a map.
  Future<Map<String, int>> calculateAllStats() async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await _loadCompletedSessions(prefs);
    final catalog = await _loadCatalog();
    final seed = _decodeSeed(prefs.getString(calibrationSeedKey));

    final computed = _statsForSessions(sessions, catalog, seed);
    final latestSession = sessions.isEmpty ? null : sessions.last;
    final previousSessions = latestSession == null
        ? const <WorkoutSession>[]
        : sessions.where((session) => session.id != latestSession.id).toList();
    final previous = _statsForSessions(previousSessions, catalog, seed);
    final delta = latestSession == null
        ? <String, int>{}
        : _deltaForLatestSession(
            before: previous,
            after: computed,
            latestSession: latestSession,
            catalog: catalog,
          );

    // VIT is the recovery meter — recomputed fresh from rest/training balance,
    // not from this session's volume. Inject it into the persisted snapshot.
    computed['VIT'] = await _computeVitality(sessions);

    final peaks = _mergePeaks(
      _decodeStats(prefs.getString(_peaksKey)),
      computed,
    );
    await prefs.setString(combatStatsKey, jsonEncode(computed));
    await prefs.setString(_peaksKey, jsonEncode(peaks));
    await prefs.setString(_lastDeltaKey, jsonEncode(delta));
    if (latestSession != null) {
      final day = _dateOnly(latestSession.date);
      await prefs.setString(_lastSessionDateKey, day.toIso8601String());
      await prefs.setString(_lastDecayDateKey, day.toIso8601String());
    }

    return computed;
  }

  // Widening D/C/B/A/S grade ladder (no F). Small early gaps, large late gaps,
  // so new lifters promote fast and veterans grind for S. All grades reachable
  // under the 1000 stat cap (S at 900 leaves headroom). Tunable.
  static const rankThresholdC = 100;
  static const rankThresholdB = 300;
  static const rankThresholdA = 600;
  static const rankThresholdS = 900;

  /// Returns rank letter for a given stat value.
  String getRank(int statValue) {
    if (statValue >= rankThresholdS) return 'S';
    if (statValue >= rankThresholdA) return 'A';
    if (statValue >= rankThresholdB) return 'B';
    if (statValue >= rankThresholdC) return 'C';
    return 'D';
  }

  /// Returns rank color for a given stat value.
  Color getRankColor(int statValue) {
    if (statValue >= rankThresholdS) return const Color(0xFF00FF9C);
    if (statValue >= rankThresholdA) return const Color(0xFFFFD700);
    if (statValue >= rankThresholdB) return const Color(0xFF00BFFF);
    if (statValue >= rankThresholdC) return Colors.white;
    return const Color(0xFF6B6B8A);
  }

  /// Returns LCK value for current week.
  Future<int> calculateLuck() async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await _loadCompletedSessions(prefs);
    final catalog = await _loadCatalog();
    return _luckForSessions(sessions, catalog);
  }

  /// Returns stat delta from most recent session.
  Future<Map<String, int>> getLastSessionDelta() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodePartialStats(prefs.getString(_lastDeltaKey));
  }

  Future<Map<String, int>> getStoredStats() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(combatStatsKey);
    if (stored == null) return calculateAllStats();
    final sessions = await _loadCompletedSessions(prefs);
    if (sessions.isEmpty) {
      // No completed workouts yet — recompute instead of blindly writing
      // baseline. calculateAllStats applies any calibration seed (so a quiz-
      // seeded user keeps their starting ranks) and persists a clean baseline
      // when there is no seed. Writing _emptyStats() here would wipe the seed.
      return calculateAllStats();
    }
    // VIT is a live recovery meter — always refresh it on read so it reflects
    // today's rest/training balance even between workout saves.
    final decoded = _decodeStats(stored);
    decoded['VIT'] = await _computeVitality(sessions);
    return decoded;
  }

  static double endurancePointsForSet(SetEntry set) {
    if (set.reps <= 0) return 0;
    final multiplier = set.reps <= 7
        ? 0.5
        : set.reps <= 14
        ? 1.0
        : 1.5;
    return set.reps * multiplier;
  }

  static Future<void> markEndBackfillNoticePending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(endBackfillNoticeKey, true);
  }

  static Future<bool> consumeEndBackfillNotice() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(endBackfillNoticeKey) ?? false;
    if (pending) {
      await prefs.remove(endBackfillNoticeKey);
    }
    return pending;
  }

  /// Check and apply decay if needed.
  Future<void> applyDecayIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    var current = _decodeStats(prefs.getString(combatStatsKey));
    if (prefs.getString(combatStatsKey) == null) {
      current = await calculateAllStats();
    }

    final currentLuck = await calculateLuck();
    current['LCK'] = currentLuck;

    final sessions = await _loadCompletedSessions(prefs);
    final latestSession = sessions.isEmpty ? null : sessions.last;
    final lastSessionRaw = prefs.getString(_lastSessionDateKey);
    if (latestSession == null && lastSessionRaw == null) {
      await prefs.setString(combatStatsKey, jsonEncode(current));
      return;
    }

    final today = _dateOnly(_nowProvider());
    final lastSessionDate = _dateOnly(
      latestSession?.date ?? DateTime.parse(lastSessionRaw!),
    );
    final restService = RestService(nowProvider: _nowProvider);
    final protection = await restService.applyShieldsForMissedTrainingDays(
      sessions: sessions,
      since: lastSessionDate,
      now: today,
    );
    final requiredDecayUnits = max(
      0,
      protection.unprotectedMissedDates.length - 1,
    );
    final chainKey = RestService.dateKey(lastSessionDate);
    final appliedUnits = await restService.appliedDecayUnitsForChain(chainKey);
    final daysToApply = requiredDecayUnits - appliedUnits;

    if (daysToApply <= 0) {
      await prefs.setString(combatStatsKey, jsonEncode(current));
      return;
    }

    final peaks = _decodeStats(prefs.getString(_peaksKey));
    for (final stat in _decayableStats) {
      final peak = peaks[stat] ?? current[stat] ?? 0;
      final floorValue = (peak * 0.5).floor();
      var value = current[stat] ?? 0;
      for (var day = 0; day < daysToApply; day++) {
        value = max(floorValue, (value * 0.9).floor());
      }
      current[stat] = value;
    }

    await prefs.setString(combatStatsKey, jsonEncode(current));
    await restService.recordAppliedDecayUnits(chainKey, requiredDecayUnits);
    await prefs.setString(_lastDecayDateKey, today.toIso8601String());
  }

  Future<List<WorkoutSession>> _loadCompletedSessions(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_sessionsKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return [
        for (final item in decoded)
          WorkoutSession.fromJson(item as Map<String, dynamic>),
      ].where((session) => !session.isPartial && !session.isAbandoned).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Public catalog loader (exerciseId -> primary muscle). Reused by
  /// calibration so its exercise->stat mapping matches the engine exactly.
  Future<Map<String, String>> loadCatalog() => _loadCatalog();

  Future<Map<String, String>> _loadCatalog() async {
    if (_catalogOverride != null) return _catalogOverride;
    // Built-in exercises: use raw JSON to get primaryMuscles field
    final raw = await rootBundle.loadString('assets/exercises.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    final result = <String, String>{
      for (final item in decoded)
        (item as Map<String, dynamic>)['id'] as String: _firstPrimaryMuscle(
          item['primaryMuscles'] as List<dynamic>?,
        ),
    };
    // Custom exercises: use stored primaryMuscle field
    final custom = await ExerciseCatalogService().getCustomExercises();
    for (final e in custom) {
      result[e.id] = e.primaryMuscle ?? '';
    }
    return result;
  }

  String _firstPrimaryMuscle(List<dynamic>? muscles) {
    if (muscles == null || muscles.isEmpty) return '';
    return muscles.first as String? ?? '';
  }

  Map<String, int> _statsForSessions(
    List<WorkoutSession> sessions,
    Map<String, String> catalog, [
    Map<String, double> seed = const {},
  ]) {
    final volumes = {for (final stat in _kgVolumeStats) stat: 0.0};
    var endurance = 0.0;
    for (final session in sessions) {
      for (final log in session.exercises) {
        final volume = _volumeForLog(log);
        endurance += _endurancePointsForLog(log);
        final primary = _primaryForLog(log, session, catalog);
        final stat = _statForPrimaryMuscle(primary);
        if (stat != null) {
          volumes[stat] = (volumes[stat] ?? 0) + volume;
        }

        final classBonusStat = _classBonusStatForLog(session, primary);
        if (classBonusStat != null) {
          volumes[classBonusStat] =
              (volumes[classBonusStat] ?? 0) + (volume * 0.2);
        }
      }
    }

    // Calibration seed volume (from the onboarding calibration workout) is
    // expressed in the same kg-volume currency, so it composes with training
    // and survives every recompute. Constant across before/after, so it does
    // not leak into per-session deltas.
    for (final stat in _kgVolumeStats) {
      final s = seed[stat];
      if (s != null && s > 0) {
        volumes[stat] = (volumes[stat] ?? 0) + s;
      }
    }

    return {
      for (final stat in _kgVolumeStats)
        stat: _withOutputBaseline(_statFromVolume(volumes[stat] ?? 0)),
      'END': _withOutputBaseline(endurance.floor()),
      'LCK': _luckForSessions(sessions, catalog),
    };
  }

  Map<String, int> _deltaForLatestSession({
    required Map<String, int> before,
    required Map<String, int> after,
    required WorkoutSession latestSession,
    required Map<String, String> catalog,
  }) {
    final touched = _touchedStatsForSession(latestSession, catalog);
    final delta = <String, int>{};
    for (final stat in touched) {
      final value = (after[stat] ?? 0) - (before[stat] ?? 0);
      if (value != 0) delta[stat] = value;
    }
    final luckDelta = (after['LCK'] ?? 0) - (before['LCK'] ?? 0);
    if (luckDelta > 0) delta['LCK'] = luckDelta;
    return delta;
  }

  Set<String> _touchedStatsForSession(
    WorkoutSession session,
    Map<String, String> catalog,
  ) {
    final touched = <String>{};
    for (final log in session.exercises) {
      if (_endurancePointsForLog(log) > 0) touched.add('END');
      final primary = _primaryForLog(log, session, catalog);
      final stat = _statForPrimaryMuscle(primary);
      if (stat != null) touched.add(stat);
      final classBonusStat = _classBonusStatForLog(session, primary);
      if (classBonusStat != null) touched.add(classBonusStat);
    }
    return touched;
  }

  int _luckForSessions(
    List<WorkoutSession> sessions,
    Map<String, String> catalog,
  ) {
    // LCK = current consecutive-day training streak, capped at 100.
    // The consistent lifter is the lucky one. Fed by training history only.
    return min(
      WorkoutMetricService.currentStreak(sessions, now: _nowProvider()),
      100,
    );
  }

  Future<int> _computeVitality(List<WorkoutSession> sessions) async {
    final restService = RestService(nowProvider: _nowProvider);
    final state = await restService.loadState(now: _nowProvider());
    return vitalityFromState(state, sessions, restService);
  }

  /// VIT = a rolling recovery-balance meter over the last [_vitalityWindowDays]
  /// days (0–100, floor [baseOutputStatValue]). Rewards completing scheduled
  /// training AND resting on rest days; mildly dings training on rest days
  /// (overtraining); scales down by how much of the scheduled training you
  /// actually did, so inactivity collapses it toward the floor. Public for
  /// tests.
  int vitalityFromState(
    RestState state,
    List<WorkoutSession> sessions,
    RestService restService,
  ) {
    final now = _dateOnly(_nowProvider());
    var sumCredit = 0.0;
    var considered = 0;
    var scheduledTraining = 0;
    var completedScheduled = 0;
    for (var i = 0; i < _vitalityWindowDays; i++) {
      final day = now.subtract(Duration(days: i));
      final info = restService.dayInfoForState(
        day: day,
        sessions: sessions,
        state: state,
        now: now,
      );
      if (info.isScheduledTrainingDay) scheduledTraining++;
      switch (info.kind) {
        case RestDayKind.workoutComplete:
          if (info.isScheduledTrainingDay) {
            completedScheduled++;
            sumCredit += 1.0;
          } else {
            sumCredit += 0.7; // trained on a rest day — mild overtraining
          }
          considered++;
        case RestDayKind.plannedRest:
          sumCredit += 1.0; // productive recovery
          considered++;
        case RestDayKind.protectedMiss:
          sumCredit += 0.5; // shielded — neutral
          considered++;
        case RestDayKind.unplannedMiss:
          considered++; // detraining — zero credit
        case RestDayKind.trainingDay:
        case RestDayKind.abandonedOnly:
          break; // today, no verdict yet
      }
    }
    if (considered == 0) return baseOutputStatValue;
    final raw = 100.0 * sumCredit / considered;
    final activityFactor = scheduledTraining == 0
        ? 1.0
        : min(1.0, completedScheduled / scheduledTraining);
    return (raw * activityFactor)
        .round()
        .clamp(baseOutputStatValue, 100)
        .toInt();
  }

  String _primaryForLog(
    ExerciseLog log,
    WorkoutSession session,
    Map<String, String> catalog,
  ) {
    final primary = catalog[log.exerciseId];
    return primary ?? _fallbackPrimary(session);
  }

  String? _classBonusStatForLog(WorkoutSession session, String primaryMuscle) {
    final cls = _classFromStoredName(session.classAtSave);
    if (cls == null) return null;
    final bucket = muscleGroupForDetailed(primaryMuscle);
    if (bucket == null || !musclesForClass(cls).contains(bucket)) return null;
    return switch (cls) {
      CharacterClass.bruiser => 'STR',
      CharacterClass.assassin => 'AGI',
      // Tank focuses Legs, which now feed STR (was VIT before the recovery
      // redesign), so the Tank bonus follows legs into STR.
      CharacterClass.tank => 'STR',
      // Balanced: the +20% bonus lands on whatever stat the trained muscle
      // already feeds (bonus on every focus, not one). The §7 #4 "80% rate"
      // refinement is deferred — this keeps a single shared 0.2 multiplier.
      CharacterClass.vanguard => statForPrimaryMuscle(primaryMuscle),
    };
  }

  CharacterClass? _classFromStoredName(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final cls in CharacterClass.values) {
      if (cls.name == raw) return cls;
    }
    return null;
  }

  String _fallbackPrimary(WorkoutSession session) {
    return switch (session.muscleGroup.toLowerCase()) {
      'chest' => 'chest',
      'back' => 'lats',
      'shoulders' => 'shoulders',
      'arms' => 'biceps',
      'legs' => 'quadriceps',
      'core' => 'abdominals',
      _ => '',
    };
  }

  String? _statForPrimaryMuscle(String muscle) => statForPrimaryMuscle(muscle);

  /// Maps a primary muscle name to the kg-volume combat stat it feeds, or null
  /// if the muscle does not contribute to a volume stat.
  static String? statForPrimaryMuscle(String muscle) {
    return switch (muscle.toLowerCase()) {
      // Legs join the pressing muscles under STR (squat/deadlift = raw force).
      // VIT is no longer fed by any muscle — it's the recovery meter.
      'chest' ||
      'triceps' ||
      'forearms' ||
      'quadriceps' ||
      'hamstrings' ||
      'glutes' ||
      'calves' ||
      'adductors' ||
      'abductors' => 'STR',
      'lats' ||
      'middle back' ||
      'lower back' ||
      'biceps' ||
      'traps' ||
      'neck' => 'DEF',
      'shoulders' || 'abdominals' => 'AGI',
      _ => null,
    };
  }

  double _volumeForLog(ExerciseLog log) {
    return log.sets.fold<double>(0, (sum, set) {
      final load = set.weight > 0 ? set.weight : 40.0;
      return sum + set.reps * load;
    });
  }

  double _endurancePointsForLog(ExerciseLog log) {
    return log.sets.fold<double>(
      0,
      (sum, set) => sum + endurancePointsForSet(set),
    );
  }

  int _statFromVolume(double volume) {
    return min(1000, (100 * log(volume / 500 + 1)).floor());
  }

  /// Inverse of [_statFromVolume]: the kg volume that yields [targetStat]
  /// (above the baseline of 10). Used to size calibration seeds in the same
  /// currency the engine consumes. Clamped to non-negative.
  static double volumeForStat(int targetStat) {
    final above = targetStat - baseOutputStatValue;
    if (above <= 0) return 0;
    // +0.5 lands mid-band so the engine's floor() yields exactly [targetStat]
    // rather than one below it.
    return 500 * (exp((above + 0.5) / 100) - 1);
  }

  Map<String, double> _decodeSeed(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries)
        if (_kgVolumeStats.contains(entry.key))
          entry.key: (entry.value as num).toDouble(),
    };
  }

  int _withOutputBaseline(int value) {
    return min(1000, baseOutputStatValue + value);
  }

  Map<String, int> _mergePeaks(
    Map<String, int> storedPeaks,
    Map<String, int> current,
  ) {
    return {
      for (final stat in stats)
        stat: max(storedPeaks[stat] ?? 0, current[stat] ?? 0),
    };
  }

  Map<String, int> _decodeStats(String? raw) {
    if (raw == null) return _emptyStats();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final stat in stats) stat: (decoded[stat] as num?)?.toInt() ?? 0,
    };
  }

  Map<String, int> _decodePartialStats(String? raw) {
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries)
        if (stats.contains(entry.key)) entry.key: (entry.value as num).toInt(),
    };
  }

  Map<String, int> _emptyStats() => {
    for (final stat in outputStats) stat: baseOutputStatValue,
    'LCK': 0,
  };

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
