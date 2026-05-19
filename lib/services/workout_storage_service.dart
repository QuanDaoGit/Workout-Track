import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_models.dart';
import 'rest_service.dart';
import 'stat_engine.dart';

class WorkoutStorageService {
  static const String _sessionsKey = 'workout_sessions';
  static const String _lastCompletedDateKey = 'last_completed_date';

  Future<void> saveSession(WorkoutSession session) async {
    final sessions = await getSessions();
    sessions.add(session);
    await _writeSessions(sessions);
    if (!session.isPartial) {
      await StatEngine().calculateAllStats();
      await RestService().refreshWeeklyShieldProgress(sessions);
      if (!session.isAbandoned) {
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now();
        final dateStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        await prefs.setString(_lastCompletedDateKey, dateStr);
      }
    }
  }

  static Future<bool> isMissionCompletedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_lastCompletedDateKey);
    if (stored == null) return false;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return stored == today;
  }

  Future<void> replaceOngoingSession(WorkoutSession session) async {
    final sessions = await getSessions();
    final updated = sessions.where((s) => !s.isOngoing).toList()..add(session);
    await _writeSessions(updated);
  }

  Future<void> replaceOngoingWithAbandoned(WorkoutSession session) async {
    final sessions = await getSessions();
    final updated = sessions.where((s) => !s.isOngoing).toList()..add(session);
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

  Future<void> deleteSession(String id) async {
    final sessions = await getSessions();
    final updated = sessions.where((s) => s.id != id).toList();
    await _writeSessions(updated);
  }
}
