import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/muscle_groups.dart';
import '../models/workout_models.dart';
import 'calibration_service.dart';
import 'rest_service.dart';
import 'stat_engine.dart';

enum MissionFinishState { none, completed, endedEarly }

class WorkoutStorageService {
  static const String _sessionsKey = 'workout_sessions';
  static const String _lastCompletedDateKey = 'last_completed_date';
  static const String _lastMissionFinishTypeKey = 'last_mission_finish_type';
  static final StreamController<void> _changes =
      StreamController<void>.broadcast();

  /// Decoded-session cache, keyed by the raw JSON string it was parsed from.
  /// `getSessions()` is called from every log surface and re-parsing the full
  /// blob each time is the hot path; keying on the raw string keeps the cache
  /// correct even when prefs are written externally (tests, migrations) —
  /// `prefs.getString` is an in-memory lookup, so the guard costs a string
  /// identity check, not a parse.
  static String? _cachedRaw;
  static List<WorkoutSession>? _sessionCache;

  static Stream<void> get changes => _changes.stream;

  Future<void> saveSession(WorkoutSession session) async {
    final sessions = await getSessions();
    sessions.add(session);
    await _writeSessions(sessions);
    if (!session.isPartial) {
      if (!session.isAbandoned) {
        // Auto-calibrate from the first few real workouts (measured 1RM → tier →
        // seed), before the recompute so the seed lands. Gated to the opening
        // sessions so established users are never retroactively seeded.
        final completedCount = sessions
            .where((s) => !s.isPartial && !s.isAbandoned)
            .length;
        await CalibrationService().maybeCalibrateEarlyWorkout(
          session,
          completedSessionCount: completedCount,
        );
        // Training recovers inactivity decay (muscle memory) before the
        // recompute applies the restored factor.
        await StatEngine().recoverFromWorkout();
      }
      await StatEngine().calculateAllStats();
      await RestService().refreshWeeklyShieldProgress(sessions);
      if (!session.isAbandoned) {
        await markMissionFinished(session.date, MissionFinishState.completed);
      }
    }
  }

  static Future<bool> isMissionCompletedToday() async {
    return (await missionFinishStateToday()) != MissionFinishState.none;
  }

  static Future<MissionFinishState> missionFinishStateToday({
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_lastCompletedDateKey);
    if (stored == null) return MissionFinishState.none;
    final currentTime = now ?? DateTime.now();
    final today =
        '${currentTime.year}-${currentTime.month.toString().padLeft(2, '0')}-${currentTime.day.toString().padLeft(2, '0')}';
    if (stored != today) return MissionFinishState.none;

    final storedType = prefs.getString(_lastMissionFinishTypeKey);
    return MissionFinishState.values.firstWhere(
      (state) => state.name == storedType,
      orElse: () => MissionFinishState.completed,
    );
  }

  static Future<void> markMissionFinished(
    DateTime date,
    MissionFinishState state,
  ) async {
    if (state == MissionFinishState.none) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCompletedDateKey, _dateKey(date));
    await prefs.setString(_lastMissionFinishTypeKey, state.name);
    _emitChanged();
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> replaceOngoingSession(WorkoutSession session) async {
    final sessions = await getSessions();
    final updated = sessions.where((s) => !s.isOngoing).toList()..add(session);
    await _writeSessions(updated);
  }

  Future<void> replaceOngoingWithAbandoned(
    WorkoutSession session, {
    bool markMissionFinished = false,
  }) async {
    final sessions = await getSessions();
    final updated =
        sessions.where((s) => !s.isOngoing && s.id != session.id).toList()
          ..add(session);
    await _writeSessions(updated);
    if (markMissionFinished) {
      await WorkoutStorageService.markMissionFinished(
        session.date,
        MissionFinishState.endedEarly,
      );
    }
  }

  Future<void> annotateSessionStatDelta(
    String sessionId,
    Map<String, int> delta,
  ) async {
    final sessions = await getSessions();
    var found = false;
    final updated = [
      for (final session in sessions)
        _annotatedIfMatch(session, sessionId, delta, () => found = true),
    ];
    if (!found) return;
    await _writeSessions(updated);
  }

  Future<WorkoutSession?> getOngoingSession() async {
    final sessions = await getSessions();
    final ongoing = sessions.where((s) => s.isOngoing).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return ongoing.isEmpty ? null : ongoing.first;
  }

  Future<WorkoutSession?> getExpiredPausedSession({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    final sessions = await getSessions();
    final expired = sessions.where((session) {
      final discardAt = session.autoDiscardAt;
      return session.isOngoing &&
          session.isPausedForResume &&
          discardAt != null &&
          !discardAt.isAfter(currentTime);
    }).toList()..sort((a, b) => a.autoDiscardAt!.compareTo(b.autoDiscardAt!));
    return expired.isEmpty ? null : expired.first;
  }

  Future<void> _writeSessions(List<WorkoutSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_sessionsKey, raw);
    _cachedRaw = raw;
    _sessionCache = List.of(sessions);
    _emitChanged();
  }

  Future<List<WorkoutSession>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);
    if (raw == null) return [];
    final cached = _sessionCache;
    if (cached != null && raw == _cachedRaw) {
      // Copy on the way out: callers mutate the returned list (sort/add).
      return List.of(cached);
    }
    final sessions = [
      for (final item in jsonDecode(raw) as List<dynamic>)
        WorkoutSession.fromJson(item as Map<String, dynamic>),
    ];
    _cachedRaw = raw;
    _sessionCache = List.of(sessions);
    return sessions;
  }

  Future<WorkoutSession?> lastCompletedSession() async {
    final completed =
        (await getSessions())
            .where((session) => !session.isPartial && !session.isAbandoned)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return completed.isEmpty ? null : completed.first;
  }

  Future<List<String>> topExerciseIdsForTargets(
    List<String> targetGroups,
    List<Exercise> catalog, {
    int limit = 3,
  }) async {
    final targets = normalizeTargetMuscleGroups(targetGroups).toSet();
    if (targets.isEmpty || limit <= 0) return const [];

    final catalogById = {for (final exercise in catalog) exercise.id: exercise};
    final curatedOrder = <String, int>{};
    for (final exercise in catalog) {
      curatedOrder.putIfAbsent(exercise.id, () => curatedOrder.length);
    }
    final counts = <String, int>{};
    final lastSeen = <String, DateTime>{};

    for (final session in await getSessions()) {
      if (session.isPartial || session.isAbandoned) continue;
      final seenThisSession = <String>{};
      for (final log in session.exercises) {
        if (!seenThisSession.add(log.exerciseId)) continue;
        if (!_exerciseMatchesTargets(
          log.exerciseId,
          session,
          catalogById,
          targets,
        )) {
          continue;
        }
        counts[log.exerciseId] = (counts[log.exerciseId] ?? 0) + 1;
        final currentLast = lastSeen[log.exerciseId];
        if (currentLast == null || session.date.isAfter(currentLast)) {
          lastSeen[log.exerciseId] = session.date;
        }
      }
    }

    final ids = counts.keys.toList()
      ..sort((a, b) {
        final countCompare = counts[b]!.compareTo(counts[a]!);
        if (countCompare != 0) return countCompare;
        final recentCompare = lastSeen[b]!.compareTo(lastSeen[a]!);
        if (recentCompare != 0) return recentCompare;
        return (curatedOrder[a] ?? 1 << 30).compareTo(
          curatedOrder[b] ?? 1 << 30,
        );
      });

    return ids.take(limit).toList();
  }

  bool _exerciseMatchesTargets(
    String exerciseId,
    WorkoutSession session,
    Map<String, Exercise> catalogById,
    Set<String> targets,
  ) {
    final exercise = catalogById[exerciseId];
    final primary = exercise?.primaryMuscle;
    if (primary != null) {
      final bucket = muscleGroupForDetailed(primary);
      if (bucket != null) return targets.contains(bucket);
    }

    final group = exercise?.muscleGroup;
    if (group != null) {
      final normalized = normalizeMuscleGroup(group);
      if (normalized != null) return targets.contains(normalized);
    }

    return session.targetMuscleGroups.any(targets.contains);
  }

  Future<void> deleteSession(String id) async {
    final sessions = await getSessions();
    final updated = sessions.where((s) => s.id != id).toList();
    await _writeSessions(updated);
  }

  /// Replace a stored session by id (set edits from the session detail page).
  /// The session's persisted XP fields (`awardedXP` etc.) are intentionally
  /// left to the caller: XP was earned at save time — edits fix the record,
  /// not the reward (and editing must never farm XP).
  Future<void> updateSession(WorkoutSession session) async {
    final sessions = await getSessions();
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index < 0) return;
    sessions[index] = session;
    await _writeSessions(sessions);
  }

  static void _emitChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }
}

WorkoutSession _annotatedIfMatch(
  WorkoutSession session,
  String sessionId,
  Map<String, int> statDelta,
  void Function() markFound,
) {
  if (session.id != sessionId) return session;
  markFound();
  return _withStatDelta(session, statDelta);
}

WorkoutSession _withStatDelta(
  WorkoutSession session,
  Map<String, int> statDelta,
) => session.copyWith(statDelta: Map<String, int>.from(statDelta));
