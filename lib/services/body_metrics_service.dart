import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/body_goal_models.dart';
import '../models/body_metrics_models.dart';

class BodyMetricsService {
  static const _enabledKey = 'body_metrics_enabled';
  static const _onboardedKey = 'body_metrics_onboarded';
  static const _entriesKey = 'body_metrics_entries_v1';

  /// Optional clock override for testing.
  final DateTime Function() _now;

  BodyMetricsService({DateTime Function()? nowProvider})
      : _now = nowProvider ?? DateTime.now;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
  }

  Future<List<WeightEntry>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entriesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final entries = [
      for (final e in list)
        WeightEntry.fromJson(e as Map<String, dynamic>),
    ];
    entries.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return entries;
  }

  Future<WeightEntry?> getLastEntry() async {
    final entries = await getEntries();
    return entries.isEmpty ? null : entries.last;
  }

  /// Whether a new weight log is allowed (7-day cadence).
  /// Uses max(storedTimestamp, now) to guard against clock manipulation.
  Future<bool> canLogWeight() async {
    final last = await getLastEntry();
    if (last == null) return true;
    final now = _now();
    final effectiveNow = now.isAfter(last.loggedAt) ? now : last.loggedAt;
    return effectiveNow.difference(last.loggedAt).inDays >= 7;
  }

  /// Days remaining until next log is allowed. 0 if can log now.
  Future<int> daysUntilNextLog() async {
    final last = await getLastEntry();
    if (last == null) return 0;
    final now = _now();
    final daysSince = now.difference(last.loggedAt).inDays;
    return max(0, 7 - daysSince);
  }

  /// Log a new weight entry. Throws if cadence not met.
  Future<WeightEntry> logWeight(double kg, {BodyGoal? currentGoal}) async {
    if (!await canLogWeight()) {
      throw StateError('Cannot log weight: 7-day cadence not met');
    }
    final entry = WeightEntry(
      weightKg: kg,
      loggedAt: _now(),
      goalAtTime: currentGoal,
    );
    final entries = await getEntries();
    entries.add(entry);
    await _persist(entries);
    return entry;
  }

  /// Delete an entry by timestamp.
  Future<void> deleteEntry(DateTime loggedAt) async {
    final entries = await getEntries();
    entries.removeWhere((e) => e.loggedAt == loggedAt);
    await _persist(entries);
  }

  /// Check if the weight change is direction-aligned with the goal.
  /// Returns false for first-ever log (no comparison data).
  static bool isDirectionAligned(
    WeightEntry current,
    WeightEntry? previous,
    BodyGoal goal,
  ) {
    if (previous == null) return false;
    final delta = current.weightKg - previous.weightKg;
    return switch (goal) {
      BodyGoal.cut => delta <= -0.3,
      BodyGoal.bulk => delta >= 0.3,
      BodyGoal.recomp => delta.abs() <= 0.5,
    };
  }

  Future<void> _persist(List<WeightEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_entriesKey, json);
  }
}
