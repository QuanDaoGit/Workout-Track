import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/character_class.dart';
import '../models/guild_models.dart';

/// Local, single-player simulation of the guild feature. There is no backend,
/// so the player's guild is seeded with NPC "members" and every social signal
/// (Forge Nods, weekly recap, member stats) is computed on-device. NPC weekly
/// numbers are deterministic per ISO week so the screen is stable within a week
/// and refreshes on Monday.
class GuildService {
  static const _guildKey = 'guild_v1';
  static const _membersKey = 'guild_members_v1';
  static const _nodsKey = 'guild_forge_nods_v1';

  static const maxMembers = 10;
  static const _seedNpcCount = 6;

  static const _adjectives = [
    'Iron',
    'Brass',
    'Hollow',
    'Forge',
    'Quiet',
    'Bright',
    'Black',
    'Bronze',
    'Steel',
    'Old',
  ];
  static const _nouns = [
    'Wake',
    'Anvil',
    'Vault',
    'Pact',
    'Crew',
    'Ring',
    'Drift',
    'Chain',
    'Watch',
    'Mark',
  ];

  static const _npcNames = [
    'Rho',
    'Vex',
    'Cass',
    'Tor',
    'Juno',
    'Bex',
    'Kane',
    'Mara',
    'Pyx',
    'Lun',
  ];

  // ---------------------------------------------------------------------------
  // ISO week helpers
  // ---------------------------------------------------------------------------

  static String weekIso(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final thursday = d.add(Duration(days: 4 - d.weekday));
    final firstThursdayYear = thursday.year;
    final firstJan = DateTime.utc(firstThursdayYear, 1, 1);
    final week = 1 + (thursday.difference(firstJan).inDays ~/ 7);
    return '$firstThursdayYear-W${week.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Assignment / seeding
  // ---------------------------------------------------------------------------

  /// Ensures the player is in a guild. Local build: always creates the player's
  /// own guild (no cross-user matching is possible) and seeds NPC members.
  /// Idempotent.
  Future<Guild> ensureAssigned({
    required CharacterClass classFocus,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_guildKey);
    if (existing != null) {
      return Guild.fromJson(jsonDecode(existing) as Map<String, dynamic>);
    }

    final n = now ?? DateTime.now();
    final name = await _generateName(prefs);
    final guild = Guild(
      id: n.microsecondsSinceEpoch.toString(),
      name: name,
      classFocus: classFocus,
      createdAt: n,
      weekIso: weekIso(n),
      weeklyVolumeKg: 0,
      weeklySessionsTotal: 0,
    );
    final members = <GuildMember>[
      GuildMember(
        userId: kPlayerGuildUserId,
        displayName: 'You',
        joinedAt: n,
        lastActiveAt: n,
        weeklyVolumeKg: 0,
        weeklySessions: 0,
        isPlayer: true,
      ),
      for (var i = 0; i < _seedNpcCount; i++) _seedNpc(i, n),
    ];
    await prefs.setString(_guildKey, jsonEncode(guild.toJson()));
    await _saveMembers(prefs, members);
    return guild;
  }

  GuildMember _seedNpc(int index, DateTime now) {
    // One NPC is intentionally stale to demonstrate the inactive (greyed) tile.
    final lastActive = index == _seedNpcCount - 1
        ? now.subtract(const Duration(days: 18))
        : now.subtract(Duration(days: index % 3));
    return GuildMember(
      userId: 'npc_$index',
      displayName: _npcNames[index % _npcNames.length],
      joinedAt: now.subtract(Duration(days: 7 + index)),
      lastActiveAt: lastActive,
      weeklyVolumeKg: 0, // filled deterministically on weekly sync
      weeklySessions: 0,
      avatarPath: 'assets/avatar/${(index % 7) + 1}.png',
    );
  }

  Future<String> _generateName(SharedPreferences prefs) async {
    // Single guild locally, so collisions are effectively impossible; the
    // number-suffix rule is kept for parity with the spec.
    final seed = DateTime.now().microsecondsSinceEpoch;
    final adj = _adjectives[seed % _adjectives.length];
    final noun = _nouns[(seed ~/ 7) % _nouns.length];
    return '$adj $noun';
  }

  // ---------------------------------------------------------------------------
  // Reads (weekly reset applied)
  // ---------------------------------------------------------------------------

  Future<Guild?> getGuild() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guildKey);
    return raw == null
        ? null
        : Guild.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<List<GuildMember>> _members(SharedPreferences prefs) async {
    final raw = prefs.getString(_membersKey);
    if (raw == null) return [];
    return [
      for (final m in jsonDecode(raw) as List<dynamic>)
        GuildMember.fromJson(m as Map<String, dynamic>),
    ];
  }

  Future<void> _saveMembers(
    SharedPreferences prefs,
    List<GuildMember> members,
  ) async {
    await prefs.setString(
      _membersKey,
      jsonEncode(members.map((m) => m.toJson()).toList()),
    );
  }

  /// One-stop read for the guild screen: applies the weekly reset, syncs the
  /// player's real weekly numbers, refreshes NPC weekly numbers for the current
  /// week, and returns members sorted by weekly volume (desc).
  Future<({Guild guild, List<GuildMember> members})> loadGuildView({
    required CharacterClass classFocus,
    required int playerWeeklyVolumeKg,
    required int playerWeeklySessions,
    DateTime? now,
  }) async {
    final n = now ?? DateTime.now();
    await ensureAssigned(classFocus: classFocus, now: n);
    final prefs = await SharedPreferences.getInstance();
    final week = weekIso(n);

    final members = await _members(prefs);
    final synced = <GuildMember>[];
    for (final m in members) {
      if (m.isPlayer) {
        synced.add(
          m.copyWith(
            weeklyVolumeKg: playerWeeklyVolumeKg,
            weeklySessions: playerWeeklySessions,
            lastActiveAt: playerWeeklySessions > 0 ? n : m.lastActiveAt,
          ),
        );
      } else {
        final vol = _npcWeeklyVolume(m.userId, week);
        synced.add(
          m.copyWith(
            weeklyVolumeKg: vol,
            weeklySessions: _npcWeeklySessions(m.userId, week),
          ),
        );
      }
    }
    synced.sort((a, b) => b.weeklyVolumeKg.compareTo(a.weeklyVolumeKg));

    final total = synced.fold<int>(0, (sum, m) => sum + m.weeklyVolumeKg);
    final totalSessions = synced.fold<int>(0, (s, m) => s + m.weeklySessions);
    final guild = (await getGuild())!.copyWith(
      weekIso: week,
      weeklyVolumeKg: total,
      weeklySessionsTotal: totalSessions,
    );

    await prefs.setString(_guildKey, jsonEncode(guild.toJson()));
    await _saveMembers(prefs, synced);
    return (guild: guild, members: synced);
  }

  // Deterministic per-week NPC numbers (stable within a week, fresh on Monday).
  int _npcWeeklyVolume(String userId, String week) {
    final h = '$week|$userId'.hashCode & 0x7fffffff;
    return 2000 + (h % 16000); // 2,000–18,000 kg
  }

  int _npcWeeklySessions(String userId, String week) {
    final h = '$week|s|$userId'.hashCode & 0x7fffffff;
    return 2 + (h % 5); // 2–6 sessions
  }

  // ---------------------------------------------------------------------------
  // Forge Nod — one per (recipient, week)
  // ---------------------------------------------------------------------------

  Future<Set<String>> _nods(SharedPreferences prefs) async {
    final raw = prefs.getString(_nodsKey);
    if (raw == null) return {};
    return {for (final e in jsonDecode(raw) as List<dynamic>) e as String};
  }

  String _nodKey(String recipientId, String week) => '$week|$recipientId';

  Future<bool> hasNodded(String recipientId, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final nods = await _nods(prefs);
    return nods.contains(_nodKey(recipientId, weekIso(now ?? DateTime.now())));
  }

  /// Sends a Forge Nod. Returns false if already sent to this member this week.
  Future<bool> sendForgeNod(String recipientId, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final week = weekIso(now ?? DateTime.now());
    final nods = await _nods(prefs);
    final key = _nodKey(recipientId, week);
    if (nods.contains(key)) return false;
    nods.add(key);
    await prefs.setString(_nodsKey, jsonEncode(nods.toList()));
    return true;
  }

  /// Simulated count of nods the player "received" this week (deterministic).
  int nodsReceivedThisWeek({DateTime? now}) {
    final week = weekIso(now ?? DateTime.now());
    return (week.hashCode & 0x7fffffff) % 6; // 0–5
  }

  // ---------------------------------------------------------------------------
  // Weekly recap
  // ---------------------------------------------------------------------------

  Future<GuildRecap> recap({
    required CharacterClass classFocus,
    required int playerWeeklyVolumeKg,
    required int playerWeeklySessions,
    DateTime? now,
  }) async {
    final view = await loadGuildView(
      classFocus: classFocus,
      playerWeeklyVolumeKg: playerWeeklyVolumeKg,
      playerWeeklySessions: playerWeeklySessions,
      now: now,
    );
    final topThree = view.members.take(3).map((m) => m.userId).toList();
    return GuildRecap(
      guildName: view.guild.name,
      weeklyVolumeKg: view.guild.weeklyVolumeKg,
      playerVolumeKg: playerWeeklyVolumeKg,
      topThreeUserIds: topThree,
    );
  }
}
