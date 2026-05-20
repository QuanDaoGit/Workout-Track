import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/class_definitions.dart';
import '../data/muscle_groups.dart';
import '../models/character_class.dart';
import '../models/workout_models.dart';
import 'exercise_catalog_service.dart';
import 'rest_service.dart';
import 'workout_metric_service.dart';

class StatEngine {
  StatEngine({DateTime Function()? nowProvider, Map<String, String>? catalog})
    : _nowProvider = nowProvider ?? DateTime.now,
      _catalogOverride = catalog;

  static const combatStatsKey = 'combat_stats';
  static const _sessionsKey = 'workout_sessions';
  static const _peaksKey = 'combat_stat_peaks';
  static const _lastDeltaKey = 'combat_stat_last_delta';
  static const _lastSessionDateKey = 'combat_stats_last_session_date';
  static const _lastDecayDateKey = 'combat_stats_last_decay_date';

  static const stats = ['STR', 'DEF', 'VIT', 'AGI', 'LCK'];
  static const volumeStats = ['STR', 'DEF', 'VIT', 'AGI'];

  final DateTime Function() _nowProvider;
  final Map<String, String>? _catalogOverride;

  /// Returns all 5 stats as a map.
  Future<Map<String, int>> calculateAllStats() async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await _loadCompletedSessions(prefs);
    final catalog = await _loadCatalog();

    final computed = _statsForSessions(sessions, catalog);
    final latestSession = sessions.isEmpty ? null : sessions.last;
    final previousSessions = latestSession == null
        ? const <WorkoutSession>[]
        : sessions.where((session) => session.id != latestSession.id).toList();
    final previous = _statsForSessions(previousSessions, catalog);
    final delta = latestSession == null
        ? <String, int>{}
        : _deltaForLatestSession(
            before: previous,
            after: computed,
            latestSession: latestSession,
            catalog: catalog,
          );

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

  /// Returns rank letter for a given stat value.
  String getRank(int statValue) {
    if (statValue >= 800) return 'S';
    if (statValue >= 600) return 'A';
    if (statValue >= 400) return 'B';
    if (statValue >= 200) return 'C';
    return 'D';
  }

  /// Returns rank color for a given stat value.
  Color getRankColor(int statValue) {
    if (statValue >= 800) return const Color(0xFF00FF9C);
    if (statValue >= 600) return const Color(0xFFFFD700);
    if (statValue >= 400) return const Color(0xFF00BFFF);
    if (statValue >= 200) return Colors.white;
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
    return _decodeStats(stored);
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
    for (final stat in volumeStats) {
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
      ].where((session) => !session.isPartial).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

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
    Map<String, String> catalog,
  ) {
    final volumes = {for (final stat in volumeStats) stat: 0.0};
    for (final session in sessions) {
      for (final log in session.exercises) {
        final volume = _volumeForLog(log);
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

    return {
      for (final stat in volumeStats) stat: _statFromVolume(volumes[stat] ?? 0),
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
    final delta = <String, int>{
      for (final stat in touched)
        stat: (after[stat] ?? 0) - (before[stat] ?? 0),
    };
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
      CharacterClass.tank => 'VIT',
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

  String? _statForPrimaryMuscle(String muscle) {
    return switch (muscle.toLowerCase()) {
      'chest' || 'triceps' || 'forearms' => 'STR',
      'lats' ||
      'middle back' ||
      'lower back' ||
      'biceps' ||
      'traps' ||
      'neck' => 'DEF',
      'quadriceps' ||
      'hamstrings' ||
      'glutes' ||
      'calves' ||
      'adductors' ||
      'abductors' => 'VIT',
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

  int _statFromVolume(double volume) {
    return min(1000, (100 * log(volume / 500 + 1)).floor());
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

  Map<String, int> _emptyStats() => {for (final stat in stats) stat: 0};

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
