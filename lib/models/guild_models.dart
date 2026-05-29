import '../models/character_class.dart';

/// The player's guild. Local-only and single-instance in this build — there is
/// no backend, so "members" other than the player are seeded NPCs and all
/// social signals stay on-device. (See GuildService for the simulation notes.)
class Guild {
  const Guild({
    required this.id,
    required this.name,
    required this.classFocus,
    required this.createdAt,
    required this.weekIso,
    required this.weeklyVolumeKg,
    required this.weeklySessionsTotal,
  });

  final String id;
  final String name;
  final CharacterClass classFocus;
  final DateTime createdAt;

  /// ISO week the rolling weekly counters belong to (e.g. "2026-W22").
  final String weekIso;
  final int weeklyVolumeKg;
  final int weeklySessionsTotal;

  Guild copyWith({
    String? weekIso,
    int? weeklyVolumeKg,
    int? weeklySessionsTotal,
  }) => Guild(
    id: id,
    name: name,
    classFocus: classFocus,
    createdAt: createdAt,
    weekIso: weekIso ?? this.weekIso,
    weeklyVolumeKg: weeklyVolumeKg ?? this.weeklyVolumeKg,
    weeklySessionsTotal: weeklySessionsTotal ?? this.weeklySessionsTotal,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'classFocus': classFocus.name,
    'createdAt': createdAt.toIso8601String(),
    'weekIso': weekIso,
    'weeklyVolumeKg': weeklyVolumeKg,
    'weeklySessionsTotal': weeklySessionsTotal,
  };

  factory Guild.fromJson(Map<String, dynamic> json) => Guild(
    id: json['id'] as String,
    name: json['name'] as String,
    classFocus: CharacterClass.values.firstWhere(
      (c) => c.name == json['classFocus'],
      orElse: () => CharacterClass.bruiser,
    ),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    weekIso: json['weekIso'] as String? ?? '',
    weeklyVolumeKg: (json['weeklyVolumeKg'] as num?)?.toInt() ?? 0,
    weeklySessionsTotal: (json['weeklySessionsTotal'] as num?)?.toInt() ?? 0,
  );
}

class GuildMember {
  const GuildMember({
    required this.userId,
    required this.displayName,
    required this.joinedAt,
    required this.lastActiveAt,
    required this.weeklyVolumeKg,
    required this.weeklySessions,
    this.avatarPath,
    this.isPlayer = false,
    this.isSeededExample = false,
  });

  final String userId;
  final String displayName;
  final DateTime joinedAt;
  final DateTime lastActiveAt;
  final int weeklyVolumeKg;
  final int weeklySessions;
  final String? avatarPath;
  final bool isPlayer;
  final bool isSeededExample;

  GuildMember copyWith({
    DateTime? lastActiveAt,
    int? weeklyVolumeKg,
    int? weeklySessions,
    String? displayName,
    String? avatarPath,
  }) => GuildMember(
    userId: userId,
    displayName: displayName ?? this.displayName,
    joinedAt: joinedAt,
    lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    weeklyVolumeKg: weeklyVolumeKg ?? this.weeklyVolumeKg,
    weeklySessions: weeklySessions ?? this.weeklySessions,
    avatarPath: avatarPath ?? this.avatarPath,
    isPlayer: isPlayer,
    isSeededExample: isSeededExample,
  );

  /// Inactive ≥14 days → greyed tile. ≥30 days → removable (handled in service).
  bool inactiveAsOf(DateTime now) => now.difference(lastActiveAt).inDays >= 14;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'displayName': displayName,
    'joinedAt': joinedAt.toIso8601String(),
    'lastActiveAt': lastActiveAt.toIso8601String(),
    'weeklyVolumeKg': weeklyVolumeKg,
    'weeklySessions': weeklySessions,
    if (avatarPath != null) 'avatarPath': avatarPath,
    'isPlayer': isPlayer,
    'isSeededExample': isSeededExample,
  };

  factory GuildMember.fromJson(Map<String, dynamic> json) => GuildMember(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    joinedAt:
        DateTime.tryParse(json['joinedAt'] as String? ?? '') ?? DateTime.now(),
    lastActiveAt:
        DateTime.tryParse(json['lastActiveAt'] as String? ?? '') ??
        DateTime.now(),
    weeklyVolumeKg: (json['weeklyVolumeKg'] as num?)?.toInt() ?? 0,
    weeklySessions: (json['weeklySessions'] as num?)?.toInt() ?? 0,
    avatarPath: json['avatarPath'] as String?,
    isPlayer: json['isPlayer'] as bool? ?? false,
    isSeededExample: json['isSeededExample'] as bool? ?? false,
  );
}

/// Canonical id for the local player's guild membership.
const String kPlayerGuildUserId = 'me';

/// Snapshot for the weekly recap surface.
class GuildRecap {
  const GuildRecap({
    required this.guildName,
    required this.weeklyVolumeKg,
    required this.playerVolumeKg,
    required this.topThreeUserIds,
  });

  final String guildName;
  final int weeklyVolumeKg;
  final int playerVolumeKg;
  final List<String> topThreeUserIds;

  bool get playerInTopThree => topThreeUserIds.contains(kPlayerGuildUserId);
}
