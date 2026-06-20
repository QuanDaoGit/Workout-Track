import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/programs_library.dart';
import '../models/program_models.dart';
import 'loot_service.dart';
import 'ongoing_program_swap_service.dart';
import 'program_customization_service.dart';
import 'rest_service.dart';
import 'schedule_resolver.dart';

/// A const synthetic rest day returned by [ProgramService.getTodayDay] on a
/// non-training weekday. Rest is calendar-derived under the weekday-anchored
/// schedule, so it is no longer a slot in the program's progression.
const ProgramDay _calendarRestDay = ProgramDay(
  dayNumber: 0,
  type: ProgramDayType.rest,
  label: 'REST',
);

class ProgramService {
  ProgramService({DateTime Function()? nowProvider})
    : _nowProvider = nowProvider ?? DateTime.now;

  static const progressKey = 'active_program_progress_v1';
  static const lastAdvancedDateKey = 'program_last_advanced_date_v1';
  static const lastCompletedSnapshotKey = 'program_last_completed_snapshot_v1';
  static const lastRestCreditSnapshotKey =
      'program_last_rest_credit_snapshot_v1';
  static const ongoingProgramSessionKey = 'program_ongoing_session_id_v1';
  static const ongoingProgramRestSessionKey =
      'program_ongoing_rest_session_id_v1';
  static const completionsKey = 'program_completions_v1';
  static const pendingCompletionRevealKey =
      'program_pending_completion_reveal_v1';

  final DateTime Function() _nowProvider;

  RestService get _restService => RestService(nowProvider: _nowProvider);

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<ProgramProgress?> getActiveProgress({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    return _loadProgress(prefs);
  }

  /// The training weekdays in effect for [date] (the frozen historical snapshot
  /// for past weeks, the committed/pending set for the current/future week).
  /// Single resolution point so [getTodayDay] and `RestService.dayInfoForState`
  /// can never disagree about whether a day is a training day.
  Future<Set<int>> _effectiveWeekdays(DateTime date) async {
    final state = await _restService.loadState(now: date);
    return _restService.trainingWeekdaysForDate(date, state);
  }

  Future<ProgramProgress> startProgram(String programId) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = ProgramProgress(
      programId: programId,
      currentWeek: 1,
      currentDayIndex: 0,
      workoutIndex: 0,
      startedAt: _nowProvider(),
      completedSessions: 0,
    );
    await _saveProgress(prefs, progress);
    await prefs.remove(lastAdvancedDateKey);
    await prefs.remove(lastCompletedSnapshotKey);
    await prefs.remove(lastRestCreditSnapshotKey);
    await prefs.remove(ongoingProgramSessionKey);
    await prefs.remove(ongoingProgramRestSessionKey);
    await prefs.remove(pendingCompletionRevealKey);
    return progress;
  }

  Future<void> quitProgram() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(progressKey);
    await prefs.remove(lastAdvancedDateKey);
    await prefs.remove(lastCompletedSnapshotKey);
    await prefs.remove(lastRestCreditSnapshotKey);
    await prefs.remove(ongoingProgramSessionKey);
    await prefs.remove(ongoingProgramRestSessionKey);
    await prefs.remove(pendingCompletionRevealKey);
    // Note: completionsKey (forged-path history) intentionally persists so the
    // Guild Card keeps a record even after a program is quit.
  }

  /// Today's resolved program day under the weekday-anchored schedule: the
  /// next-up workout ([Program.workouts]`[workoutIndex]`) on a training weekday,
  /// or a synthetic [ProgramDay] REST on a non-training weekday. Rest is
  /// calendar-derived — it is no longer a slot in the progression.
  Future<ProgramDay?> getTodayDay({DateTime? now}) async {
    final progress = await getActiveProgress(now: now);
    if (progress == null) return null;
    final program = programById(progress.programId);
    if (program == null || program.workouts.isEmpty) return null;
    final date = _dateOnly(now ?? _nowProvider());
    final resolved = const ScheduleResolver().resolve(
      date: date,
      program: program,
      workoutIndex: progress.workoutIndex,
      effectiveWeekdays: await _effectiveWeekdays(date),
    );
    return resolved.displayedWorkout ?? _calendarRestDay;
  }

  /// The workout the user is mid-session on (or would start now), regardless of
  /// weekday — used for prescriptions/resume so off-anchor (forgiveness)
  /// training still gets its TARGET banners. Null when no program/workouts.
  Future<ProgramDay?> activeWorkoutDay() async {
    final progress = await getActiveProgress();
    if (progress == null) return null;
    final program = programById(progress.programId);
    if (program == null || program.workouts.isEmpty) return null;
    return program.workouts[progress.workoutIndex % program.workouts.length];
  }

  /// Advances the workout-only cursor by exactly one on a completed workout
  /// (wrapping mod the workout count), bumping [ProgramProgress.currentWeek] each
  /// time the cycle wraps to 0 (one "week" = one full pass of the program's
  /// workouts — the cadence the legacy 7-slot wrap used). Guarded once-per-day so
  /// a double save can't double-advance.
  Future<ProgramProgress?> advanceDay({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = await getActiveProgress(now: now);
    if (progress == null) return null;

    final todayKey = RestService.dateKey(now ?? _nowProvider());
    if (prefs.getString(lastAdvancedDateKey) == todayKey) return progress;

    final program = programById(progress.programId);
    if (program == null || program.workouts.isEmpty) return progress;
    final snapshot = ProgramDaySnapshot(
      programId: progress.programId,
      week: progress.currentWeek,
      dayIndex: progress.workoutIndex,
      dateKey: todayKey,
    );
    final next = _nextProgress(progress, program);

    await _saveProgress(prefs, next);
    await prefs.setString(lastAdvancedDateKey, todayKey);
    await prefs.setString(
      lastCompletedSnapshotKey,
      jsonEncode(snapshot.toJson()),
    );
    return next;
  }

  /// Records arc completion exactly once when the active arc reaches the
  /// program's target. Grants the identity title, flags the program as awaiting
  /// the next-path choice, and stages a pending reveal. Returns the recorded
  /// [ProgramCompletion], or null if not complete (or already recorded).
  ///
  /// Call this immediately after [advanceDay] on workout save.
  Future<ProgramCompletion?> evaluateCompletion({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = await getActiveProgress(now: now);
    if (progress == null) return null;
    if (progress.completedArc) return null;
    final program = programById(progress.programId);
    if (program == null) return null;
    if (progress.arcSessions < program.targetSessions) return null;

    final titleId = titleIdForProgram(progress.programId) ?? '';
    final completion = ProgramCompletion(
      programId: progress.programId,
      titleId: titleId,
      sessions: progress.arcSessions,
      completedAt: now ?? _nowProvider(),
    );

    final completions = _loadCompletions(prefs)..add(completion);
    await prefs.setStringList(
      completionsKey,
      completions.map((c) => jsonEncode(c.toJson())).toList(),
    );
    if (titleId.isNotEmpty) {
      await LootService().grantItem(titleId);
    }
    await _saveProgress(prefs, progress.copyWith(completedArc: true));
    await prefs.setString(
      pendingCompletionRevealKey,
      jsonEncode(completion.toJson()),
    );
    return completion;
  }

  /// Reads and clears the staged completion reveal (set by [evaluateCompletion]).
  /// Used by the reveal flow and the Home fallback after an interrupted save.
  Future<ProgramCompletion?> consumePendingCompletionReveal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(pendingCompletionRevealKey);
    if (raw == null) return null;
    await prefs.remove(pendingCompletionRevealKey);
    return ProgramCompletion.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Starts the next program in the completion chain with a fresh arc. Returns
  /// the new progress, or null if there is no active program / no chain target.
  Future<ProgramProgress?> beginNextPath() async {
    final prefs = await SharedPreferences.getInstance();
    final progress = _loadProgress(prefs);
    if (progress == null) return null;
    final nextId = programChainNext[progress.programId];
    if (nextId == null) return null;
    return startProgram(nextId);
  }

  /// Keeps the same program but opens a fresh arc (new finish line) without
  /// wiping history — rolls the arc baseline up to the current session count.
  Future<ProgramProgress?> stayWithProgram() async {
    final prefs = await SharedPreferences.getInstance();
    final progress = _loadProgress(prefs);
    if (progress == null) return null;
    final rolled = progress.copyWith(
      arcStartSessions: progress.completedSessions,
      completedArc: false,
    );
    await _saveProgress(prefs, rolled);
    await prefs.remove(pendingCompletionRevealKey);
    return rolled;
  }

  /// All recorded program completions, oldest first. Drives the Guild Card.
  Future<List<ProgramCompletion>> completedPrograms() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadCompletions(prefs);
  }

  Future<ProgramDaySnapshot?> completedSnapshotForToday({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = _loadSnapshot(prefs.getString(lastCompletedSnapshotKey));
    final todayKey = RestService.dateKey(now ?? _nowProvider());
    if (snapshot == null || snapshot.dateKey != todayKey) return null;
    return snapshot;
  }

  Future<void> markOngoingProgramSession(
    String sessionId, {
    bool restDayWorkout = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ongoingProgramSessionKey, sessionId);
    if (restDayWorkout) {
      await prefs.setString(ongoingProgramRestSessionKey, sessionId);
    } else {
      await prefs.remove(ongoingProgramRestSessionKey);
    }
  }

  Future<bool> isOngoingProgramSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(ongoingProgramSessionKey) == sessionId;
  }

  Future<bool> isOngoingProgramRestSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(ongoingProgramRestSessionKey) == sessionId;
  }

  /// Rebuilds the sets × reps targets for a resumed ongoing session, so the
  /// TARGET banners survive leave/pause → resume (prescriptions are never
  /// persisted with the session). Empty for manual sessions, rest-day
  /// sessions, or when no program is active. Safe to call before the day
  /// advances: [advanceDay] only runs at workout save, which also clears the
  /// ongoing flag, so the current day index still matches the session.
  Future<Map<String, SetRepScheme>> prescriptionsForOngoingSession(
    String sessionId,
  ) async {
    if (!await isOngoingProgramSession(sessionId)) return const {};
    final progress = await getActiveProgress();
    // The in-session workout is the active workout-index slot regardless of
    // weekday, so off-anchor (forgiveness) training keeps its TARGET banners.
    final day = await activeWorkoutDay();
    if (progress == null || day == null || !day.isWorkout) return const {};
    final effective = await ProgramCustomizationService().effectiveDay(
      progress.programId,
      day,
    );
    // Apply this session's ephemeral swaps on top of the effective (persistently
    // customized) prescriptions so a resumed in-session swap keeps its sets×reps
    // (Codex plan-review F4 composition: persistent first, then session).
    final sessionSwaps = await OngoingProgramSwapService().swapsFor(sessionId);
    if (sessionSwaps.isEmpty) return effective.prescription;
    return {
      for (final entry in effective.prescription.entries)
        sessionSwaps[entry.key] ?? entry.key: entry.value,
    };
  }

  Future<void> clearOngoingProgramSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(ongoingProgramSessionKey) == sessionId) {
      await prefs.remove(ongoingProgramSessionKey);
    }
    if (prefs.getString(ongoingProgramRestSessionKey) == sessionId) {
      await prefs.remove(ongoingProgramRestSessionKey);
    }
  }

  ProgramProgress? _loadProgress(SharedPreferences prefs) {
    final raw = prefs.getString(progressKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final progress = ProgramProgress.fromJson(decoded);
    final program = programById(progress.programId);
    if (program == null || program.workouts.isEmpty) return null;
    return progress.copyWith(
      currentWeek: progress.currentWeek < 1 ? 1 : progress.currentWeek,
      workoutIndex: progress.workoutIndex.clamp(
        0,
        program.workouts.length - 1,
      ),
      completedSessions: progress.completedSessions < 0
          ? 0
          : progress.completedSessions,
    );
  }

  ProgramProgress _nextProgress(ProgramProgress progress, Program program) {
    final count = program.workouts.length;
    if (count == 0) return progress;
    final nextWorkoutIndex = (progress.workoutIndex + 1) % count;
    // A wrap back to 0 means a full cycle of the program's workouts elapsed.
    final nextWeek = nextWorkoutIndex == 0
        ? progress.currentWeek + 1
        : progress.currentWeek;
    return progress.copyWith(
      currentWeek: nextWeek,
      workoutIndex: nextWorkoutIndex,
      completedSessions: progress.completedSessions + 1,
    );
  }

  Future<void> _saveProgress(
    SharedPreferences prefs,
    ProgramProgress progress,
  ) async {
    await prefs.setString(progressKey, jsonEncode(progress.toJson()));
  }

  ProgramDaySnapshot? _loadSnapshot(String? raw) {
    if (raw == null) return null;
    return ProgramDaySnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  List<ProgramCompletion> _loadCompletions(SharedPreferences prefs) {
    final raw = prefs.getStringList(completionsKey) ?? const [];
    return raw
        .map(
          (e) =>
              ProgramCompletion.fromJson(jsonDecode(e) as Map<String, dynamic>),
        )
        .toList();
  }
}
