import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/programs_library.dart';
import '../models/program_models.dart';
import 'loot_service.dart';
import 'ongoing_program_swap_service.dart';
import 'program_customization_service.dart';
import 'rest_service.dart';

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

  Future<ProgramProgress?> getActiveProgress({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = _loadProgress(prefs);
    if (progress == null) return null;
    final normalized = await _rollForwardCreditedRestDay(
      prefs,
      progress,
      now ?? _nowProvider(),
    );
    if (normalized != progress) {
      await _saveProgress(prefs, normalized);
    }
    return normalized;
  }

  Future<ProgramProgress> startProgram(String programId) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = ProgramProgress(
      programId: programId,
      currentWeek: 1,
      currentDayIndex: 0,
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

  Future<ProgramDay?> getTodayDay({DateTime? now}) async {
    final progress = await getActiveProgress(now: now);
    if (progress == null) return null;
    final program = programById(progress.programId);
    if (program == null || program.weekSchedule.isEmpty) return null;
    return program.weekSchedule[progress.currentDayIndex];
  }

  Future<ProgramProgress?> advanceDay({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = await getActiveProgress(now: now);
    if (progress == null) return null;

    final todayKey = RestService.dateKey(now ?? _nowProvider());
    if (prefs.getString(lastAdvancedDateKey) == todayKey) return progress;

    final program = programById(progress.programId);
    if (program == null || program.weekSchedule.isEmpty) return progress;
    final currentDay = program.weekSchedule[progress.currentDayIndex];
    final snapshot = ProgramDaySnapshot(
      programId: progress.programId,
      week: progress.currentWeek,
      dayIndex: progress.currentDayIndex,
      dateKey: todayKey,
    );
    final next = _nextProgress(
      progress,
      completedSessionDelta: currentDay.isWorkout ? 1 : 0,
    );

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

  Future<ProgramDaySnapshot?> creditedRestSnapshotForToday({
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = _loadSnapshot(prefs.getString(lastRestCreditSnapshotKey));
    final todayKey = RestService.dateKey(now ?? _nowProvider());
    if (snapshot == null || snapshot.dateKey != todayKey) return null;
    return snapshot;
  }

  Future<ProgramDaySnapshot?> creditRestDayForToday({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = await getActiveProgress(now: now);
    if (progress == null) return null;
    final program = programById(progress.programId);
    if (program == null || program.weekSchedule.isEmpty) return null;
    final day = program.weekSchedule[progress.currentDayIndex];
    if (day.isWorkout) return null;

    final todayKey = RestService.dateKey(now ?? _nowProvider());
    final existing = _loadSnapshot(prefs.getString(lastRestCreditSnapshotKey));
    if (existing != null &&
        existing.dateKey == todayKey &&
        existing.programId == progress.programId &&
        existing.week == progress.currentWeek &&
        existing.dayIndex == progress.currentDayIndex) {
      return existing;
    }

    final snapshot = ProgramDaySnapshot(
      programId: progress.programId,
      week: progress.currentWeek,
      dayIndex: progress.currentDayIndex,
      dateKey: todayKey,
    );
    await prefs.setString(
      lastRestCreditSnapshotKey,
      jsonEncode(snapshot.toJson()),
    );
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
    final day = await getTodayDay();
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
    if (program == null || program.weekSchedule.isEmpty) return null;
    return progress.copyWith(
      currentWeek: progress.currentWeek < 1 ? 1 : progress.currentWeek,
      currentDayIndex: progress.currentDayIndex.clamp(
        0,
        program.weekSchedule.length - 1,
      ),
      completedSessions: progress.completedSessions < 0
          ? 0
          : progress.completedSessions,
    );
  }

  Future<ProgramProgress> _rollForwardCreditedRestDay(
    SharedPreferences prefs,
    ProgramProgress progress,
    DateTime now,
  ) async {
    final snapshot = _loadSnapshot(prefs.getString(lastRestCreditSnapshotKey));
    if (snapshot == null) return progress;
    final todayKey = RestService.dateKey(now);
    if (snapshot.dateKey == todayKey) return progress;
    if (snapshot.programId != progress.programId ||
        snapshot.week != progress.currentWeek ||
        snapshot.dayIndex != progress.currentDayIndex) {
      return progress;
    }
    final program = programById(progress.programId);
    if (program == null || program.weekSchedule.isEmpty) return progress;
    final day = program.weekSchedule[progress.currentDayIndex];
    if (day.isWorkout) return progress;
    final next = _nextProgress(progress, completedSessionDelta: 0);
    await prefs.remove(lastRestCreditSnapshotKey);
    return next;
  }

  ProgramProgress _nextProgress(
    ProgramProgress progress, {
    required int completedSessionDelta,
  }) {
    final program = programById(progress.programId);
    if (program == null || program.weekSchedule.isEmpty) return progress;
    var nextIndex = progress.currentDayIndex + 1;
    var nextWeek = progress.currentWeek;
    if (nextIndex >= program.weekSchedule.length) {
      nextIndex = 0;
      nextWeek++;
    }
    return progress.copyWith(
      currentWeek: nextWeek,
      currentDayIndex: nextIndex,
      completedSessions:
          progress.completedSessions + completedSessionDelta.clamp(0, 1),
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
