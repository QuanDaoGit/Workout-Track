import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/muscle_groups.dart';
import '../models/workout_models.dart';
import 'adventure_service.dart';
import 'analytics_service.dart';
import 'calibration_service.dart';
import 'json_safe.dart';
import 'keyed_lock.dart';
import 'ongoing_program_swap_service.dart';
import 'rest_service.dart';
import 'stat_engine.dart';
import 'warmup_reward_service.dart';

enum MissionFinishState { none, completed, endedEarly }

class WorkoutStorageService {
  static const String _sessionsKey = 'workout_sessions';
  static const String _lastCompletedDateKey = 'last_completed_date';
  static const String _lastMissionFinishTypeKey = 'last_mission_finish_type';

  /// A live session that goes this long without a new logged set is treated as
  /// idle and offered for auto-save on the next app open/resume (or by the
  /// active page's foreground timer). See [getIdleTimedOutSession].
  static const Duration idleTimeout = Duration(minutes: 30);
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
    // Only the read-modify-write is serialised (against checkpoint/finish races
    // on the same blob); the sub-service orchestration below runs *outside* the
    // lock — some of those services mutate sessions themselves, so holding the
    // lock across them would deadlock on the same key.
    // Captured inside the lock: a completed (non-ongoing) row already under this
    // id means this is a re-save, not a new workout — so the funnel events below
    // must not double-count it (Codex F2).
    var alreadyCompleted = false;
    final sessions = await prefsWriteLock.synchronized(_sessionsKey, () async {
      final sessions = await getSessions();
      alreadyCompleted = sessions.any((s) => s.id == session.id && !s.isOngoing);
      // Incremental autosave leaves an ongoing checkpoint row under this
      // session's id; the completed save replaces it (otherwise we'd keep both
      // an ongoing and a completed row with the same id — a duplicate + a
      // lingering resume dock).
      sessions.removeWhere((s) => s.id == session.id && s.isOngoing);
      sessions.add(session);
      await _writeSessions(sessions);
      return sessions;
    });
    if (!session.isPartial) {
      // A finalized session can never be resumed — drop its ephemeral program
      // swaps (Codex plan-review F3 lifecycle).
      await OngoingProgramSwapService().clear(session.id);
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
      }
      await StatEngine().calculateAllStats();
      await RestService().refreshWeeklyShieldProgress(sessions);
      if (!session.isAbandoned) {
        // Adventure charge grant — awaited (never fire-and-forget) and after
        // the stat recompute. The instant workout payoff; the user spends the
        // charge later. The service swallows its own failures: an adventure
        // can never break a save.
        await AdventureService().grantChargeForSession(session);
        // Warm-up gem bonus — awaited, gated to a real warmed-up session, and
        // idempotent once/day. Swallows its own errors (never breaks a save).
        await WarmupRewardService().grantForSession(session);
        await markMissionFinished(session.date, MissionFinishState.completed);
        // Telemetry (ADR 0001) — only a genuinely NEW completed session, so a
        // re-save can't double-count the funnel; first_workout_saved is itself
        // lifetime-once inside the facade. Synthetic seed/import paths persist
        // sessions directly (not via saveSession), so they never reach here.
        if (!alreadyCompleted) {
          final setCount = session.exercises.fold<int>(
            0,
            (sum, e) => sum + e.sets.length,
          );
          await AnalyticsService.instance.logWorkoutSaved(
            exerciseCount: session.exercises.length,
            setCount: setCount,
            durationSeconds: session.actualDurationSeconds,
          );
          await AnalyticsService.instance.logFirstWorkoutSaved();
        }
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
    // Serialise the (date, type) pair so two concurrent writers can't interleave
    // into a mismatched date-from-A / type-from-B record.
    await prefsWriteLock.synchronized(_lastCompletedDateKey, () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCompletedDateKey, _dateKey(date));
      await prefs.setString(_lastMissionFinishTypeKey, state.name);
    });
    _emitChanged();
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> replaceOngoingSession(WorkoutSession session) async {
    await prefsWriteLock.synchronized(_sessionsKey, () async {
      final sessions = await getSessions();
      final updated = sessions.where((s) => !s.isOngoing).toList()..add(session);
      await _writeSessions(updated);
    });
  }

  /// Incrementally persist the live session (at start and on each set log) so a
  /// force-kill mid-session no longer loses logged sets, and so idle detection
  /// has a stored `lastActivityAt`. Writes silently (no change signal): the
  /// active page is on top, and the RootPage resume dock already refreshes from
  /// its 1-second poll, so we avoid churning a quest-tab reload on every set.
  Future<void> checkpointOngoingSession(WorkoutSession session) async {
    await prefsWriteLock.synchronized(_sessionsKey, () async {
      final sessions = await getSessions();
      final updated = sessions.where((s) => !s.isOngoing).toList()
        ..add(session);
      await _writeSessions(updated, notify: false);
    });
  }

  /// The most-idle live session eligible for idle auto-save: ongoing,
  /// **not** an explicit Save&Exit pause (those use the midnight `autoDiscardAt`
  /// path), with a trusted `lastActivityAt` at least [idleTimeout] in the past.
  /// Legacy rows (null `lastActivityAt`) are never auto-timed-out.
  Future<WorkoutSession?> getIdleTimedOutSession({
    DateTime? now,
    Duration? idleTimeout,
  }) async {
    final threshold = idleTimeout ?? WorkoutStorageService.idleTimeout;
    final currentTime = now ?? DateTime.now();
    final sessions = await getSessions();
    final timedOut = sessions.where((session) {
      final last = session.lastActivityAt;
      return session.isOngoing &&
          !session.isPausedForResume &&
          last != null &&
          !currentTime.isBefore(last.add(threshold));
    }).toList()..sort((a, b) => a.lastActivityAt!.compareTo(b.lastActivityAt!));
    return timedOut.isEmpty ? null : timedOut.first;
  }

  Future<void> replaceOngoingWithAbandoned(
    WorkoutSession session, {
    bool markMissionFinished = false,
  }) async {
    await prefsWriteLock.synchronized(_sessionsKey, () async {
      final sessions = await getSessions();
      final updated =
          sessions.where((s) => !s.isOngoing && s.id != session.id).toList()
            ..add(session);
      await _writeSessions(updated);
    });
    await OngoingProgramSwapService().clear(session.id);
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
    await prefsWriteLock.synchronized(_sessionsKey, () async {
      final sessions = await getSessions();
      var found = false;
      final updated = [
        for (final session in sessions)
          _annotatedIfMatch(session, sessionId, delta, () => found = true),
      ];
      if (!found) return;
      await _writeSessions(updated);
    });
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

  Future<void> _writeSessions(
    List<WorkoutSession> sessions, {
    bool notify = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_sessionsKey, raw);
    _cachedRaw = raw;
    _sessionCache = List.of(sessions);
    if (notify) _emitChanged();
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
    // Corruption-tolerant: a malformed blob or a single bad record yields the
    // salvageable subset (or []) instead of throwing on the boot/home path.
    final sessions = safeMapList(
      raw,
      WorkoutSession.fromJson,
      debugLabel: _sessionsKey,
    );
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
    return _rankedExerciseIds(catalog, limit: limit, targets: targets);
  }

  /// All-targets twin of [topExerciseIdsForTargets]: the user's most-trained
  /// exercises across *every* completed session (program days included),
  /// ranked frequency → recency → curated order. Skips partial/abandoned and
  /// drops ids no longer in [catalog]. Powers the manual quick-start default
  /// loadout when no muscle target is chosen yet. No fallback/top-up here —
  /// the StartWorkoutPage layer applies the quality gate and curated fallback.
  Future<List<String>> topExerciseIds(
    List<Exercise> catalog, {
    int limit = 5,
  }) async {
    if (limit <= 0) return const [];
    return _rankedExerciseIds(catalog, limit: limit, targets: null);
  }

  /// Shared frequency/recency counting core for the two public helpers above.
  /// [targets] `null` means no muscle filter (all-targets); a non-null set
  /// applies the exact same [_exerciseMatchesTargets] filter the targeted
  /// helper has always used, so that path stays behavior-compatible.
  Future<List<String>> _rankedExerciseIds(
    List<Exercise> catalog, {
    required int limit,
    required Set<String>? targets,
  }) async {
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
        if (targets == null) {
          // All-targets: still require a live catalog id so dead ids drop.
          if (!catalogById.containsKey(log.exerciseId)) continue;
        } else if (!_exerciseMatchesTargets(
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
    await prefsWriteLock.synchronized(_sessionsKey, () async {
      final sessions = await getSessions();
      final updated = sessions.where((s) => s.id != id).toList();
      await _writeSessions(updated);
    });
    await OngoingProgramSwapService().clear(id);
  }

  /// Replace a stored session by id (set edits from the session detail page).
  /// The session's persisted XP fields (`awardedXP` etc.) are intentionally
  /// left to the caller: XP was earned at save time — edits fix the record,
  /// not the reward (and editing must never farm XP).
  Future<void> updateSession(WorkoutSession session) async {
    await prefsWriteLock.synchronized(_sessionsKey, () async {
      final sessions = await getSessions();
      final index = sessions.indexWhere((s) => s.id == session.id);
      if (index < 0) return;
      sessions[index] = session;
      await _writeSessions(sessions);
    });
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
