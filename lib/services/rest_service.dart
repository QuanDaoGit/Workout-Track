import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/rest_models.dart';
import '../models/workout_models.dart';
import 'xp_service.dart';

class RestProtectionResult {
  const RestProtectionResult({
    required this.protectedCount,
    required this.unprotectedMissedDates,
    required this.state,
  });

  final int protectedCount;
  final List<DateTime> unprotectedMissedDates;
  final RestState state;
}

class RestService {
  RestService({DateTime Function()? nowProvider})
    : _nowProvider = nowProvider ?? DateTime.now;

  static const stateKey = 'rest_state_v1';
  static const maxShieldCharges = 2;

  final DateTime Function() _nowProvider;

  Future<RestState> loadState({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(stateKey);
    final currentDay = _dateOnly(now ?? _nowProvider());
    final currentWeekKey = weekKey(currentDay);
    var state = raw == null
        ? RestState.defaults(currentWeekKey: currentWeekKey)
        : RestState.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    state = _normalizeState(state, currentDay);
    await _saveState(state);
    return state;
  }

  Future<void> saveTrainingWeekdays(Set<int> weekdays, {DateTime? now}) async {
    final currentDay = _dateOnly(now ?? _nowProvider());
    final sanitized = _sanitizeWeekdays(weekdays);
    final state = await loadState(now: currentDay);
    final nextStart = _nextMonday(currentDay);
    final nextStartKey = dateKey(nextStart);

    if (_sameWeekdays(sanitized, state.trainingWeekdays)) {
      await _saveState(state.copyWith(clearPending: true));
      return;
    }

    await _saveState(
      state.copyWith(
        pendingTrainingWeekdays: sanitized,
        pendingStartWeekKey: nextStartKey,
      ),
    );
  }

  Future<RestState> ensureAutomaticRecoveryForToday({
    required List<WorkoutSession> sessions,
    required int baseXP,
    DateTime? now,
    RestState? state,
  }) async {
    final currentDay = _dateOnly(now ?? _nowProvider());
    final loadedState = state ?? await loadState(now: currentDay);
    final info = dayInfoForState(
      day: currentDay,
      sessions: sessions,
      state: loadedState,
      now: currentDay,
    );
    final autoStart = loadedState.autoRecoveryStartKey == null
        ? currentDay
        : parseDateKey(loadedState.autoRecoveryStartKey!);
    var updatedState = loadedState.autoRecoveryStartKey == null
        ? loadedState.copyWith(autoRecoveryStartKey: dateKey(currentDay))
        : loadedState;

    if (!info.isPlannedRestDay ||
        info.hasCompletedWorkout ||
        currentDay.isBefore(autoStart) ||
        updatedState.recoveryClaims.containsKey(info.dateKey)) {
      await _saveState(updatedState);
      return updatedState;
    }

    final xp = recoveryRewardXP(baseXP);
    final claims = Map<String, RestRecoveryClaim>.from(
      updatedState.recoveryClaims,
    );
    claims[info.dateKey] = RestRecoveryClaim(xp: xp, claimedAt: currentDay);
    updatedState = updatedState.copyWith(recoveryClaims: claims);
    await _saveState(updatedState);
    return updatedState;
  }

  Future<RestState> addProgramPlannedRestDate(
    DateTime day, {
    DateTime? now,
    RestState? state,
  }) async {
    final targetDay = _dateOnly(day);
    final loadedState = state ?? await loadState(now: now ?? targetDay);
    final key = dateKey(targetDay);
    if (loadedState.programRestDateKeys.contains(key)) return loadedState;

    final keys = Set<String>.from(loadedState.programRestDateKeys)..add(key);
    final updated = loadedState.copyWith(programRestDateKeys: keys);
    await _saveState(updated);
    return updated;
  }

  Future<RestState> addProgramTrainingDate(
    DateTime day, {
    DateTime? now,
    RestState? state,
  }) async {
    final targetDay = _dateOnly(day);
    final loadedState = state ?? await loadState(now: now ?? targetDay);
    final key = dateKey(targetDay);
    if (loadedState.programTrainingDateKeys.contains(key)) return loadedState;

    final keys = Set<String>.from(loadedState.programTrainingDateKeys)
      ..add(key);
    final updated = loadedState.copyWith(programTrainingDateKeys: keys);
    await _saveState(updated);
    return updated;
  }

  Future<int> effectiveRecoveryXP(
    List<WorkoutSession> sessions, {
    DateTime? now,
  }) async {
    final state = await loadState(now: now);
    return effectiveRecoveryXPForState(
      sessions: sessions,
      state: state,
      now: now,
    );
  }

  int effectiveRecoveryXPForState({
    required List<WorkoutSession> sessions,
    required RestState state,
    DateTime? now,
  }) {
    var total = 0;
    for (final entry in state.recoveryClaims.entries) {
      final day = parseDateKey(entry.key);
      final info = dayInfoForState(
        day: day,
        sessions: sessions,
        state: state,
        now: now,
      );
      if (info.isPlannedRestDay && !info.hasCompletedWorkout) {
        total += entry.value.xp;
      }
    }
    return total;
  }

  Future<int> effectiveRecoveryXPForDay(
    DateTime day,
    List<WorkoutSession> sessions, {
    DateTime? now,
  }) async {
    final state = await loadState(now: now);
    return dayInfoForState(
      day: day,
      sessions: sessions,
      state: state,
      now: now,
    ).recoveryXP;
  }

  Future<RestDayInfo> dayInfo(
    DateTime day,
    List<WorkoutSession> sessions, {
    DateTime? now,
  }) async {
    final state = await loadState(now: now);
    return dayInfoForState(
      day: day,
      sessions: sessions,
      state: state,
      now: now,
    );
  }

  RestDayInfo dayInfoForState({
    required DateTime day,
    required List<WorkoutSession> sessions,
    required RestState state,
    DateTime? now,
  }) {
    final currentDay = _dateOnly(now ?? _nowProvider());
    final targetDay = _dateOnly(day);
    final key = dateKey(targetDay);
    final programRestDay = state.programRestDateKeys.contains(key);
    final programTrainingDay = state.programTrainingDateKeys.contains(key);
    final trainingDay =
        programTrainingDay ||
        (!programRestDay &&
            trainingWeekdaysForDate(
              targetDay,
              state,
            ).contains(targetDay.weekday));
    final completed = _hasCompletedWorkoutOn(targetDay, sessions);
    final abandonedOnly =
        !completed &&
        sessions.any(
          (session) => session.isAbandoned && _sameDay(session.date, targetDay),
        );
    final hasClaim = state.recoveryClaims.containsKey(key);
    final protected = state.protectedMissDateKeys.contains(key);
    final recoveryXP = hasClaim && !completed && !trainingDay
        ? state.recoveryClaims[key]!.xp
        : 0;

    final kind = completed
        ? RestDayKind.workoutComplete
        : protected
        ? RestDayKind.protectedMiss
        : !trainingDay
        ? RestDayKind.plannedRest
        : targetDay.isBefore(currentDay)
        ? RestDayKind.unplannedMiss
        : abandonedOnly
        ? RestDayKind.abandonedOnly
        : RestDayKind.trainingDay;

    return RestDayInfo(
      dateKey: key,
      kind: kind,
      isScheduledTrainingDay: trainingDay,
      hasCompletedWorkout: completed,
      hasRecoveryClaim: hasClaim,
      isProtected: protected,
      recoveryXP: recoveryXP,
      shieldCharges: state.shieldCharges,
    );
  }

  /// LCK as a rolling weekly *consistency* streak: how many full 7-day blocks
  /// have elapsed since the streak began. The streak survives indefinitely and
  /// is reset to zero only by an *unscheduled recovery* — a scheduled training
  /// day that passed with no completed workout and no shield
  /// ([RestDayKind.unplannedMiss]). Shielded misses ([RestDayKind.protectedMiss])
  /// and gaps on non-scheduled days never reset it. Pure: deterministic for a
  /// given [state] + [sessions] + [now].
  int consistencyWeeks({
    required List<WorkoutSession> sessions,
    required RestState state,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? _nowProvider());

    // The streak cannot predate the user's first completed workout.
    DateTime? firstWorkout;
    for (final session in sessions) {
      if (session.isPartial) continue;
      final day = _dateOnly(session.date);
      if (firstWorkout == null || day.isBefore(firstWorkout)) firstWorkout = day;
    }
    if (firstWorkout == null) return 0;

    // Walk back from today to the first workout; the most recent unprotected
    // missed scheduled day ends the streak. Today is never a miss
    // (dayInfoForState only flags days strictly before today), so the user
    // always has the current day left to train.
    DateTime streakStart = firstWorkout;
    var cursor = today;
    while (!cursor.isBefore(firstWorkout)) {
      final info = dayInfoForState(
        day: cursor,
        sessions: sessions,
        state: state,
        now: today,
      );
      if (info.kind == RestDayKind.unplannedMiss) {
        streakStart = cursor.add(const Duration(days: 1));
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }

    if (streakStart.isAfter(today)) return 0;
    final weeks = today.difference(streakStart).inDays ~/ 7;
    return min(weeks, 100);
  }

  /// Async convenience: loads rest state and returns [consistencyWeeks]. Mirrors
  /// how the vitality meter loads state before evaluating recovery balance.
  Future<int> currentConsistencyWeeks({
    required List<WorkoutSession> sessions,
    DateTime? now,
  }) async {
    final state = await loadState(now: now);
    return consistencyWeeks(sessions: sessions, state: state, now: now);
  }

  Future<RestState> refreshWeeklyShieldProgress(
    List<WorkoutSession> sessions, {
    DateTime? now,
  }) async {
    final currentDay = _dateOnly(now ?? _nowProvider());
    var state = await loadState(now: currentDay);
    final lastFullWeekStart = _monday(
      currentDay,
    ).subtract(const Duration(days: 7));
    DateTime weekStart;

    if (state.lastProcessedWeekKey == null) {
      final completed = _completedSessions(sessions);
      if (completed.isEmpty) {
        weekStart = lastFullWeekStart;
      } else {
        final earliest = completed
            .map((session) => _monday(session.date))
            .reduce((a, b) => a.isBefore(b) ? a : b);
        weekStart = earliest.isAfter(lastFullWeekStart)
            ? lastFullWeekStart
            : earliest;
      }
    } else {
      weekStart = parseDateKey(
        state.lastProcessedWeekKey!,
      ).add(const Duration(days: 7));
    }

    if (weekStart.isAfter(lastFullWeekStart)) return state;

    var consecutive = state.consecutiveSuccessfulWeeks;
    var shields = state.shieldCharges;
    var scheduleHistory = Map<String, Set<int>>.from(state.scheduleByWeekKey);
    var processedKey = state.lastProcessedWeekKey;

    while (!weekStart.isAfter(lastFullWeekStart)) {
      final key = dateKey(weekStart);
      scheduleHistory.putIfAbsent(key, () => state.trainingWeekdays);
      final successful = _isSuccessfulWeek(
        weekStart: weekStart,
        sessions: sessions,
        state: state.copyWith(scheduleByWeekKey: scheduleHistory),
      );

      if (successful) {
        consecutive++;
        if (consecutive >= 2) {
          shields = min(maxShieldCharges, shields + 1);
          consecutive = 0;
        }
      } else {
        consecutive = 0;
      }

      processedKey = key;
      weekStart = weekStart.add(const Duration(days: 7));
    }

    state = state.copyWith(
      consecutiveSuccessfulWeeks: consecutive,
      shieldCharges: shields,
      lastProcessedWeekKey: processedKey,
      scheduleByWeekKey: scheduleHistory,
    );
    await _saveState(state);
    return state;
  }

  Future<RestProtectionResult> applyShieldsForMissedTrainingDays({
    required List<WorkoutSession> sessions,
    required DateTime since,
    DateTime? now,
  }) async {
    final currentDay = _dateOnly(now ?? _nowProvider());
    var state = await refreshWeeklyShieldProgress(sessions, now: currentDay);
    final missed = missedTrainingDaysSinceForState(
      sessions: sessions,
      state: state,
      since: since,
      now: currentDay,
      includeProtected: false,
    );

    var shields = state.shieldCharges;
    var protectedCount = 0;
    final protectedKeys = Set<String>.from(state.protectedMissDateKeys);
    for (final day in missed) {
      if (shields <= 0) break;
      protectedKeys.add(dateKey(day));
      shields--;
      protectedCount++;
    }

    if (protectedCount > 0) {
      state = state.copyWith(
        shieldCharges: shields,
        protectedMissDateKeys: protectedKeys,
      );
      await _saveState(state);
    }

    final unprotected = missedTrainingDaysSinceForState(
      sessions: sessions,
      state: state,
      since: since,
      now: currentDay,
      includeProtected: false,
    );
    return RestProtectionResult(
      protectedCount: protectedCount,
      unprotectedMissedDates: unprotected,
      state: state,
    );
  }

  List<DateTime> missedTrainingDaysSinceForState({
    required List<WorkoutSession> sessions,
    required RestState state,
    required DateTime since,
    DateTime? now,
    bool includeProtected = false,
  }) {
    final currentDay = _dateOnly(now ?? _nowProvider());
    var day = _dateOnly(since).add(const Duration(days: 1));
    final missed = <DateTime>[];

    while (day.isBefore(currentDay)) {
      final key = dateKey(day);
      final trainingDay =
          state.programTrainingDateKeys.contains(key) ||
          (!state.programRestDateKeys.contains(key) &&
              trainingWeekdaysForDate(day, state).contains(day.weekday));
      final protected = state.protectedMissDateKeys.contains(key);
      if (trainingDay &&
          !_hasCompletedWorkoutOn(day, sessions) &&
          (includeProtected || !protected)) {
        missed.add(day);
      }
      day = day.add(const Duration(days: 1));
    }
    return missed;
  }

  Future<int> appliedDecayUnitsForChain(String chainKey) async {
    final state = await loadState();
    if (state.decayChainStartKey != chainKey) return 0;
    return state.appliedDecayUnits;
  }

  Future<void> recordAppliedDecayUnits(String chainKey, int units) async {
    final state = await loadState();
    await _saveState(
      state.copyWith(decayChainStartKey: chainKey, appliedDecayUnits: units),
    );
  }

  Set<int> trainingWeekdaysForDate(DateTime day, RestState state) {
    final key = weekKey(day);
    return state.scheduleByWeekKey[key] ?? state.trainingWeekdays;
  }

  static int recoveryRewardXP(int baseXP) {
    final progress = XpService.progressForTotalXP(baseXP);
    final scaled = (progress.levelSpanXP * 0.02).round();
    return min(40, max(1, scaled));
  }

  static String dateKey(DateTime date) {
    final day = _dateOnly(date);
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  static String weekKey(DateTime date) => dateKey(_monday(date));

  static DateTime parseDateKey(String key) {
    final parts = key.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  Future<void> _saveState(RestState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(stateKey, jsonEncode(state.toJson()));
  }

  RestState _normalizeState(RestState state, DateTime currentDay) {
    var training = _sanitizeWeekdays(state.trainingWeekdays);
    var pending = state.pendingTrainingWeekdays == null
        ? null
        : _sanitizeWeekdays(state.pendingTrainingWeekdays!);
    var pendingStart = state.pendingStartWeekKey;
    var scheduleHistory = Map<String, Set<int>>.from(state.scheduleByWeekKey);
    final autoRecoveryStartKey =
        state.autoRecoveryStartKey ?? dateKey(currentDay);
    final currentWeekKey = weekKey(currentDay);
    scheduleHistory.putIfAbsent(currentWeekKey, () => training);

    if (pending != null && pendingStart != null) {
      final pendingStartDate = parseDateKey(pendingStart);
      if (!currentDay.isBefore(pendingStartDate)) {
        training = pending;
        scheduleHistory[pendingStart] = pending;
        pending = null;
        pendingStart = null;
      }
    }

    return state.copyWith(
      trainingWeekdays: training,
      pendingTrainingWeekdays: pending,
      pendingStartWeekKey: pendingStart,
      shieldCharges: state.shieldCharges.clamp(0, maxShieldCharges).toInt(),
      consecutiveSuccessfulWeeks: max(0, state.consecutiveSuccessfulWeeks),
      appliedDecayUnits: max(0, state.appliedDecayUnits),
      autoRecoveryStartKey: autoRecoveryStartKey,
      scheduleByWeekKey: scheduleHistory,
      clearPending: pending == null,
    );
  }

  bool _isSuccessfulWeek({
    required DateTime weekStart,
    required List<WorkoutSession> sessions,
    required RestState state,
  }) {
    final trainingDays = trainingWeekdaysForDate(weekStart, state);
    for (final weekday in trainingDays) {
      final day = weekStart.add(Duration(days: weekday - 1));
      if (state.programRestDateKeys.contains(dateKey(day))) continue;
      if (!_hasCompletedWorkoutOn(day, sessions)) return false;
    }
    for (final key in state.programTrainingDateKeys) {
      final day = parseDateKey(key);
      if (weekKey(day) != weekKey(weekStart)) continue;
      if (!_hasCompletedWorkoutOn(day, sessions)) return false;
    }
    return true;
  }

  List<WorkoutSession> _completedSessions(List<WorkoutSession> sessions) =>
      sessions.where((session) => !session.isPartial).toList();

  bool _hasCompletedWorkoutOn(DateTime day, List<WorkoutSession> sessions) {
    return sessions.any(
      (session) => !session.isPartial && _sameDay(session.date, day),
    );
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _monday(DateTime date) {
    final day = _dateOnly(date);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static DateTime _nextMonday(DateTime date) =>
      _monday(date).add(const Duration(days: 7));

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static Set<int> _sanitizeWeekdays(Set<int> weekdays) {
    final sanitized = weekdays.where((day) => day >= 1 && day <= 7).toSet();
    if (sanitized.isEmpty || sanitized.length == 7) {
      return RestState.defaultTrainingWeekdays;
    }
    return sanitized;
  }

  bool _sameWeekdays(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}
