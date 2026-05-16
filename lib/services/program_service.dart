import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/programs_library.dart';
import '../models/program_models.dart';
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

  Future<ProgramProgress?> skipDayManually({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = await getActiveProgress(now: now);
    if (progress == null) return null;
    final next = _nextProgress(progress, completedSessionDelta: 0);
    await _saveProgress(prefs, next);
    return next;
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
}
