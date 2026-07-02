import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/guild_models.dart';
import '../models/workout_models.dart';

/// Owns the guild entity (`guild_v2`). Rebuilt from scratch — no NPC members,
/// no simulation. The guild is auto-created on first need, always named "BIT",
/// and persisted once; the roster (player + OPEN slots) is derived at the UI
/// layer from the live profile + this week's training, so nothing fake is stored.
class GuildService {
  GuildService({DateTime Function()? nowProvider})
    : _now = nowProvider ?? DateTime.now;

  final DateTime Function() _now;

  static const String _key = 'guild_v2';

  /// The guild's fixed name in v1.
  static const String guildName = 'BIT';

  /// Total roster slots: the player + (rosterSize - 1) OPEN slots.
  static const int rosterSize = 6;

  /// Count of crest banner shapes / emblem symbols (ported pixel-art assets).
  /// Emblems also offer a "none" option in the editor beyond these 4.
  static const int crestShapeCount = 4;
  static const int crestEmblemCount = 4;

  /// Highest guild level.
  static const int maxGuildLevel = 5;

  /// Cumulative completed-session thresholds at which the guild reaches each
  /// level. Body-neutral: progress is **showing up** (sessions), never volume.
  static const List<int> _levelThresholds = [0, 5, 15, 30, 52];

  /// Returns the guild, creating + persisting it on first call. Idempotent —
  /// the stored entity (id + founding date) is never re-stamped.
  Future<Guild> ensureGuild() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      return Guild.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    final now = _now();
    final guild = Guild(
      id: now.microsecondsSinceEpoch.toString(),
      name: guildName,
      createdAt: now,
    );
    await prefs.setString(_key, jsonEncode(guild.toJson()));
    return guild;
  }

  /// The guild if it exists, else null (no side effects).
  Future<Guild?> getGuild() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return raw == null
        ? null
        : Guild.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Persists a new crest (creating the guild first if needed). Returns the
  /// updated guild.
  Future<Guild> updateCrest(GuildCrest crest) async {
    final guild = await ensureGuild();
    final updated = guild.copyWith(crest: crest);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(updated.toJson()));
    return updated;
  }

  /// Completed (non-partial, non-abandoned) sessions — the guild's lifetime
  /// "showing up" count that drives its level.
  static int completedSessions(List<WorkoutSession> sessions) =>
      sessions.where((s) => !s.isPartial && !s.isAbandoned).length;

  /// The guild level (1..maxGuildLevel) for a completed-session count.
  static int guildLevel(int completed) {
    var level = 1;
    for (var i = 1; i < _levelThresholds.length; i++) {
      if (completed >= _levelThresholds[i]) level = i + 1;
    }
    return level;
  }

  /// Progress within the current level: (sessionsIntoLevel, sessionsForLevel).
  /// At max level returns null (no bar to fill).
  static (int, int)? guildLevelProgress(int completed) {
    final level = guildLevel(completed);
    if (level >= maxGuildLevel) return null;
    final floor = _levelThresholds[level - 1];
    final next = _levelThresholds[level];
    return (completed - floor, next - floor);
  }

  // ---- Roles (the earned guild rank ladder) -------------------------------

  /// Role ladder — your earned standing in the guild (status, NOT authority over
  /// others). Mapped to the guild level: showing up climbs your rank.
  static const List<String> rankNames = [
    'RECRUIT',
    'MEMBER',
    'VETERAN',
    'OFFICER',
    'LEADER',
  ];

  static String guildRank(int level) =>
      rankNames[(level - 1).clamp(0, rankNames.length - 1)];

  // ---- Weekly Cache (cooperative active-days goal) -------------------------

  /// Gems auto-banked once per week when the cache completes.
  static const int cacheRewardGems = 20;

  /// Active-days target. Solo = 3 (WHO-floor-ish — resting is safe, leaves 4
  /// rest days). Scales with real members in Phase 2 (per-member daily cap is
  /// inherent in active-days). The ledger id is versioned so this can evolve.
  static int cacheTarget(int eligibleMembers) =>
      eligibleMembers <= 1 ? 3 : 3 * eligibleMembers;

  /// Canonical Monday-of-week key (yyyy-MM-dd), derived from the SAME `now` and
  /// the SAME Monday basis as `WorkoutMetricService.trainingDaysThisWeek`, so the
  /// reward week can never drift from the active-days window (Codex F2).
  static String cacheWeekKey(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    return '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }
}
