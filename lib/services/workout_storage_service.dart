import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_models.dart';

class WorkoutStorageService {
  static const String _sessionsKey = 'workout_sessions';

  Future<void> saveSession(WorkoutSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);
    final List<dynamic> list = raw != null
        ? jsonDecode(raw) as List<dynamic>
        : [];
    list.add(session.toJson());
    await prefs.setString(_sessionsKey, jsonEncode(list));
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionsKey,
      jsonEncode(updated.map((s) => s.toJson()).toList()),
    );
  }
}
