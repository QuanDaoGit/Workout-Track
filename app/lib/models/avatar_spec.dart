import 'dart:math';

import 'user_profile_sex.dart';

/// Options for the procedural 20x20 pixel-face avatar. Each enum is one
/// composable layer/palette choice; the sprite is rendered live by
/// `IronbitAvatar` — no image assets.
enum AvatarSkin { tone01, tone02, tone03, tone04, tone05 }

enum AvatarEyes { brown, blue, hazel, green, neon, cyan }

enum AvatarHair { spike, swept, buzz, curly, bob, long, bun, pony, bald }

enum AvatarHairColor { black, brown, blonde, red, gray }

enum AvatarExpression { ready, grin, focused, sad, shock, wink }

/// The user's avatar configuration — the single avatar source of truth,
/// persisted as enum names alongside the profile.
class AvatarSpec {
  const AvatarSpec({
    required this.skin,
    required this.eyes,
    required this.hair,
    required this.hairColor,
    required this.expression,
  });

  final AvatarSkin skin;
  final AvatarEyes eyes;
  final AvatarHair hair;
  final AvatarHairColor hairColor;
  final AvatarExpression expression;

  static const fallback = AvatarSpec(
    skin: AvatarSkin.tone02,
    eyes: AvatarEyes.brown,
    hair: AvatarHair.buzz,
    hairColor: AvatarHairColor.black,
    expression: AvatarExpression.ready,
  );

  /// Expressions that read well on NPCs/rosters (no sad/shock).
  static const friendlyExpressions = [
    AvatarExpression.ready,
    AvatarExpression.grin,
    AvatarExpression.focused,
    AvatarExpression.wink,
  ];

  /// Uniform random spec (guild NPCs). Pass a seeded [Random] for a stable
  /// per-NPC face. Expressions are limited to [friendlyExpressions].
  factory AvatarSpec.random(Random rng) {
    T pick<T>(List<T> values) => values[rng.nextInt(values.length)];
    return AvatarSpec(
      skin: pick(AvatarSkin.values),
      eyes: pick(AvatarEyes.values),
      hair: pick(AvatarHair.values),
      hairColor: pick(AvatarHairColor.values),
      expression: pick(friendlyExpressions),
    );
  }

  AvatarSpec copyWith({
    AvatarSkin? skin,
    AvatarEyes? eyes,
    AvatarHair? hair,
    AvatarHairColor? hairColor,
    AvatarExpression? expression,
  }) {
    return AvatarSpec(
      skin: skin ?? this.skin,
      eyes: eyes ?? this.eyes,
      hair: hair ?? this.hair,
      hairColor: hairColor ?? this.hairColor,
      expression: expression ?? this.expression,
    );
  }

  Map<String, dynamic> toJson() => {
    'skin': skin.name,
    'eyes': eyes.name,
    'hair': hair.name,
    'hairColor': hairColor.name,
    'expression': expression.name,
  };

  /// Unknown or missing values fall back per-field so old saves survive
  /// future option additions.
  factory AvatarSpec.fromJson(Map<String, dynamic>? json) {
    if (json == null) return fallback;
    T pick<T extends Enum>(List<T> values, dynamic name, T fb) {
      for (final value in values) {
        if (value.name == name) return value;
      }
      return fb;
    }

    return AvatarSpec(
      skin: pick(AvatarSkin.values, json['skin'], fallback.skin),
      eyes: pick(AvatarEyes.values, json['eyes'], fallback.eyes),
      hair: pick(AvatarHair.values, json['hair'], fallback.hair),
      hairColor: pick(
        AvatarHairColor.values,
        json['hairColor'],
        fallback.hairColor,
      ),
      expression: pick(
        AvatarExpression.values,
        json['expression'],
        fallback.expression,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarSpec &&
      other.skin == skin &&
      other.eyes == eyes &&
      other.hair == hair &&
      other.hairColor == hairColor &&
      other.expression == expression;

  @override
  int get hashCode => Object.hash(skin, eyes, hair, hairColor, expression);
}

/// Starter avatars. New users never pick a face during onboarding — they get
/// a neutral default seeded from the quiz's sex answer (hair length is the
/// only gendered cue) and can edit it any time from the profile.
class AvatarDefaults {
  static AvatarSpec forSex(UserProfileSex sex) {
    final hair = switch (sex) {
      UserProfileSex.male => AvatarHair.buzz,
      UserProfileSex.female => AvatarHair.long,
      UserProfileSex.preferNotToSay => AvatarHair.swept,
    };
    return AvatarSpec.fallback.copyWith(hair: hair);
  }
}
