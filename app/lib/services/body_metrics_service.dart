import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/body_goal_models.dart';
import '../models/body_metrics_models.dart';
import '../models/unit_models.dart';

class BodyMetricsService {
  static const _enabledKey = 'body_metrics_enabled';
  static const _onboardedKey = 'body_metrics_onboarded';
  static const _entriesKey = 'body_metrics_entries_v1';

  /// Last-log timestamp. No longer gates logging (logging is unrestricted) —
  /// retained so the reward-anchor migration can seed from it and so callers can
  /// read "last logged" cheaply.
  static const _lastLogAtKey = 'body_metrics_last_log_at';

  /// Tamper-resistant *reward* anchor: the last log that earned the weekly
  /// XP-boost potion. Separate from entries and never cleared by [deleteEntry],
  /// so delete-and-relog cannot farm a second potion inside the same 7-day
  /// window. Stamped by [markRewardGranted]; seeded on upgrade by
  /// [seedRewardAnchorFromLastLog].
  static const _rewardAnchorKey = 'body_metrics_reward_anchor_v1';

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
      for (final e in list) WeightEntry.fromJson(e as Map<String, dynamic>),
    ];
    entries.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return entries;
  }

  Future<WeightEntry?> getLastEntry() async {
    final entries = await getEntries();
    return entries.isEmpty ? null : entries.last;
  }

  /// The cadence anchor: the tamper-resistant last-log timestamp, falling back
  /// to the most recent entry's timestamp for users who logged before the token
  /// existed. Returns null only when nothing has ever been logged.
  Future<DateTime?> _lastLogAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastLogAtKey);
    if (raw != null && raw.isNotEmpty) return DateTime.tryParse(raw);
    final last = await getLastEntry();
    return last?.loggedAt;
  }

  /// Midnight of [d]'s calendar date. Cadence is measured in whole calendar
  /// days (not exact 24h spans) so the unlock lands on a stable weekday instead
  /// of creeping later each week off the precise log timestamp.
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The reward anchor: the last log that earned the weekly potion, or null if
  /// none has yet.
  Future<DateTime?> _rewardAnchor() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rewardAnchorKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Whether logging right now earns the weekly XP-boost potion (rolling 7
  /// calendar days since the last *rewarded* log). Logging itself is always
  /// allowed; this gates only the reward. Uses max(storedDate, nowDate) to guard
  /// against clock manipulation.
  Future<bool> canEarnReward() async {
    final anchor = await _rewardAnchor();
    if (anchor == null) return true;
    final anchorDay = _dateOnly(anchor);
    final nowDay = _dateOnly(_now());
    final effectiveDay = nowDay.isAfter(anchorDay) ? nowDay : anchorDay;
    return effectiveDay.difference(anchorDay).inDays >= 7;
  }

  /// Days remaining until the next weekly reward is available. 0 if available now.
  Future<int> daysUntilNextReward() async {
    final anchor = await _rewardAnchor();
    if (anchor == null) return 0;
    final anchorDay = _dateOnly(anchor);
    final nowDay = _dateOnly(_now());
    final effectiveDay = nowDay.isAfter(anchorDay) ? nowDay : anchorDay;
    return max(0, 7 - effectiveDay.difference(anchorDay).inDays);
  }

  /// Stamp the reward anchor to now after a weekly potion is granted. Never
  /// cleared by [deleteEntry], so the weekly window cannot be reopened by
  /// deleting an entry.
  Future<void> markRewardGranted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rewardAnchorKey, _now().toIso8601String());
  }

  /// Seed the reward anchor from the legacy last-log token (fallback: the most
  /// recent entry) the first time the decoupled-cadence build runs. Keeps a
  /// returning user from either getting a free potion on upgrade or having their
  /// next legitimate one suppressed. No-op once the anchor exists. Idempotency at
  /// the call site is guarded by [MigrationService].
  Future<void> seedRewardAnchorFromLastLog() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_rewardAnchorKey) != null) return;
    final legacy = await _lastLogAt();
    if (legacy != null) {
      await prefs.setString(_rewardAnchorKey, legacy.toIso8601String());
    }
  }

  /// Log a new weight entry. Logging is unrestricted (any day, even multiple
  /// times) — the weekly cadence now lives on the reward, not the log. Throws
  /// [ArgumentError] on an implausible weight (defence in depth behind the UI).
  Future<WeightEntry> logWeight(double kg, {BodyGoal? currentGoal}) async {
    if (!isPlausibleWeightKg(kg)) {
      throw ArgumentError.value(kg, 'kg', 'implausible bodyweight');
    }
    final entry = WeightEntry(
      weightKg: kg,
      loggedAt: _now(),
      goalAtTime: currentGoal,
    );
    final entries = await getEntries();
    entries.add(entry);
    await _persist(entries);

    // Keep the last-log token current (no longer gates logging; retained for the
    // reward-anchor migration seed and cheap "last logged" lookups).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastLogAtKey, entry.loggedAt.toIso8601String());
    return entry;
  }

  /// Correct an existing entry's weight in place (typo fix). Intentionally does
  /// **not** grant a potion or touch the cadence anchor — editing is not a new
  /// log, so it can't be used to farm rewards or reopen the weekly window.
  /// No-op if no entry matches [loggedAt] or [newKg] is implausible.
  Future<void> updateEntry(DateTime loggedAt, double newKg) async {
    if (!isPlausibleWeightKg(newKg)) return;
    final entries = await getEntries();
    final idx = entries.indexWhere((e) => e.loggedAt == loggedAt);
    if (idx < 0) return;
    final old = entries[idx];
    entries[idx] = WeightEntry(
      weightKg: newKg,
      loggedAt: old.loggedAt,
      goalAtTime: old.goalAtTime,
    );
    await _persist(entries);
  }

  /// Delete an entry by timestamp.
  Future<void> deleteEntry(DateTime loggedAt) async {
    final entries = await getEntries();
    entries.removeWhere((e) => e.loggedAt == loggedAt);
    await _persist(entries);
  }

  Future<void> _persist(List<WeightEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_entriesKey, json);
  }
}
