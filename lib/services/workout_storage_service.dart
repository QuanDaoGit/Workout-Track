import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/muscle_groups.dart';
import '../models/workout_models.dart';
import 'rest_service.dart';
import 'stat_engine.dart';

enum MissionFinishState { none, completed, endedEarly }

class WorkoutStorageService {
  static const String _sessionsKey = 'workout_sessions';
  static const String _lastCompletedDateKey = 'last_completed_date';
  static const String _lastMissionFinishTypeKey = 'last_mission_finish_type';

  Future<void> saveSession(WorkoutSession session) async {
    final sessions = await getSessions();
    sessions.add(session);
    await _writeSessions(sessions);
    if (!session.isPartial) {
      await StatEngine().calculateAllStats();
      await RestService().refreshWeeklyShieldProgress(sessions);
      if (!session.isAbandoned) {
        await markMissionFinished(
          session.date,
          MissionFinishState.completed,
        );
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
    final updated = sessions
        .where((s) => !s.isOngoing && s.id != session.id)
        .toList()
      ..add(session);
    await _writeSessions(updated);
    if (markMissionFinished) {
      await WorkoutStorageService.markMissionFinished(
        session.date,
        MissionFinishState.endedEarly,
      );
    }
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
    await prefs.setString(
      _sessionsKey,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }

  Future<List<WorkoutSession>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in list)
        WorkoutSession.fromJson(item as Map<String, dynamic>),
    ];
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
}
