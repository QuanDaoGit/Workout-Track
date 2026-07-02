import 'package:flutter/foundation.dart';

import 'avatar_spec.dart';

/// The guild's craftable emblem — a **banner** (1 of 4 cloth shapes) bearing an
/// optional **emblem** (1 of 4 symbols, or none), each layer **independently**
/// coloured. Ported from the Crest Forge handoff (real pixel-art assets + a
/// tone-preserving recolor + a gentle cloth sway). [bannerColor]/[emblemColor]
/// are ARGB ints, or **0 = "auto"** (resolve from the player's class theme colour
/// at render time, so a fresh crest matches the class until the user picks one).
@immutable
class GuildCrest {
  const GuildCrest({
    this.shape = 0,
    this.emblem = 0,
    this.bannerColor = 0,
    this.emblemColor = 0,
  });

  /// 0..3 → swallowtail / pennant / draped / notched.
  final int shape;

  /// 0..3 → sword / shield / gem / bolt; [noEmblem] (-1) → bare banner.
  final int emblem;

  /// ARGB int, or 0 for "auto" (class theme colour).
  final int bannerColor;
  final int emblemColor;

  /// Sentinel: no emblem stamped on the banner.
  static const int noEmblem = -1;

  GuildCrest copyWith({
    int? shape,
    int? emblem,
    int? bannerColor,
    int? emblemColor,
  }) => GuildCrest(
    shape: shape ?? this.shape,
    emblem: emblem ?? this.emblem,
    bannerColor: bannerColor ?? this.bannerColor,
    emblemColor: emblemColor ?? this.emblemColor,
  );

  Map<String, dynamic> toJson() => {
    'shape': shape,
    'emblem': emblem,
    'bannerColor': bannerColor,
    'emblemColor': emblemColor,
  };

  /// Decodes a stored crest. **Back-compat:** an older `{shape, charge, color}`
  /// blob (the code-drawn placeholder) decodes gracefully — `shape` carries over
  /// (clamped to the 4 banners), the dropped `charge` glyph becomes the default
  /// sword emblem, and the single legacy `color` seeds BOTH banner + emblem.
  factory GuildCrest.fromJson(Map<String, dynamic> json) {
    final legacy = (json['color'] as num?)?.toInt();
    final shape = ((json['shape'] as num?)?.toInt() ?? 0).clamp(0, 3).toInt();
    return GuildCrest(
      shape: shape,
      emblem: (json['emblem'] as num?)?.toInt() ?? 0,
      bannerColor: (json['bannerColor'] as num?)?.toInt() ?? legacy ?? 0,
      emblemColor: (json['emblemColor'] as num?)?.toInt() ?? legacy ?? 0,
    );
  }
}

/// The player's guild — rebuilt from scratch (solo-honest v1). Always named
/// "BIT" (the companion *is* the hall). The roster is **derived**, not a stored
/// member list: it's the player plus OPEN slots awaiting future real guildmates
/// (Phase 2). Only this lightweight entity is persisted (`guild_v2`) — members
/// are computed live, so real members later just fill OPEN slots with no
/// migration. Identity (the [crest]) is local + permanent by design; the guild
/// **level** is derived from cumulative training, not stored here.
@immutable
class Guild {
  const Guild({
    required this.id,
    required this.name,
    required this.createdAt,
    this.crest = const GuildCrest(),
  });

  final String id;

  /// Fixed to "BIT" in v1 (no naming flow); kept on the model so a future
  /// rename is a value change, not a schema one.
  final String name;

  /// When the guild was founded — stable identity anchor for Phase-2 sync.
  final DateTime createdAt;

  /// The craftable emblem (additive field — absent in older `guild_v2` blobs
  /// decodes to the default crest, so no migration is needed).
  final GuildCrest crest;

  Guild copyWith({GuildCrest? crest}) => Guild(
    id: id,
    name: name,
    createdAt: createdAt,
    crest: crest ?? this.crest,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'crest': crest.toJson(),
  };

  factory Guild.fromJson(Map<String, dynamic> json) => Guild(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'BIT',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    crest: json['crest'] is Map
        ? GuildCrest.fromJson((json['crest'] as Map).cast<String, dynamic>())
        : const GuildCrest(),
  );
}

/// A roster entry. v1 only ever has the player; the rest of the roster is OPEN
/// slots (rendered as placeholders, not members). Not persisted — derived from
/// the live profile + this week's training. Phase 2 adds real members here.
@immutable
class GuildMember {
  const GuildMember({
    required this.name,
    required this.avatarSpec,
    required this.activeDays,
    this.rank = 'RECRUIT',
    this.framePath,
    this.frameCount = 1,
    this.isPlayer = true,
  });

  final String name;
  final AvatarSpec avatarSpec;

  /// Distinct training days this week (reuses `trainingDaysThisWeek`).
  final int activeDays;

  /// Earned guild rank (your standing — status, not authority over others).
  /// Derived from the guild level via `GuildService.guildRank`.
  final String rank;

  /// The equipped avatar-frame poster path + animation frame count (the earned
  /// cosmetic must render wherever the avatar appears). Null = no frame.
  final String? framePath;
  final int frameCount;
  final bool isPlayer;
}
