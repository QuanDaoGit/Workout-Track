import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/body_goal_models.dart';

class BodyGoalService {
  static const _key = 'body_goal_v1';

  Future<BodyGoalState?> getGoalState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    return BodyGoalState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> setGoal(BodyGoal goal, {double? targetWeight}) async {
    final state = BodyGoalState(
      goal: goal,
      setAt: DateTime.now(),
      targetWeight: targetWeight,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> updateTargetWeight(double? weight) async {
    final current = await getGoalState();
    if (current == null) return;
    final updated = BodyGoalState(
      goal: current.goal,
      setAt: current.setAt,
      targetWeight: weight,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(updated.toJson()));
  }
}
