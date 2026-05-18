import 'dart:ui';

/// Animation states for a single battle sprite.
enum SpriteAnimState { idle, attacking, hurt, dodging, victory, defeat }

/// A single animation event describing what both sprites should do.
class SpriteAnimEvent {
  const SpriteAnimEvent({
    required this.playerState,
    required this.enemyState,
    this.isCrit = false,
    this.abilityId,
    this.abilityColor,
    this.abilityOnPlayer = true,
    this.playerHp,
    this.enemyHp,
    this.durationMs = 700,
  });

  final SpriteAnimState playerState;
  final SpriteAnimState enemyState;

  /// True if this event is a critical hit (triggers gold strobe).
  final bool isCrit;

  /// 2-letter ability abbreviation to display as icon, or null.
  final String? abilityId;

  /// Class color for hit flash override and ability icon.
  final Color? abilityColor;

  /// Whether the ability icon appears above player (true) or enemy (false).
  final bool abilityOnPlayer;

  /// Updated player HP after this event (null = no change).
  final int? playerHp;

  /// Updated enemy HP after this event (null = no change).
  final int? enemyHp;

  /// Total duration of this animation step in milliseconds.
  final int durationMs;
}
