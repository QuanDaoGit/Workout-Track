import 'avatar_spec.dart';

class ProfileData {
  const ProfileData({required this.displayName, required this.avatarSpec});

  static const defaultName = 'Player';

  /// App-wide bounds for the user's character / display name — the single source
  /// of truth shared by the onboarding name field, the profile name editor, and
  /// the persistence backstop. Keep every name input + validator pinned to these.
  static const int maxNameLength = 8;
  static const int minNameLength = 2;

  final String displayName;
  final AvatarSpec avatarSpec;

  ProfileData copyWith({String? displayName, AvatarSpec? avatarSpec}) {
    return ProfileData(
      displayName: displayName ?? this.displayName,
      avatarSpec: avatarSpec ?? this.avatarSpec,
    );
  }

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'avatarSpec': avatarSpec.toJson(),
  };

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    final name = (json['displayName'] as String? ?? '').trim();
    // Legacy saves carry an `avatarPath` image path instead of a spec —
    // AvatarSpec.fromJson(null) maps those to the fallback face.
    return ProfileData(
      displayName: name.isEmpty ? defaultName : name,
      avatarSpec: AvatarSpec.fromJson(
        (json['avatarSpec'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  factory ProfileData.defaults() {
    return const ProfileData(
      displayName: defaultName,
      avatarSpec: AvatarSpec.fallback,
    );
  }
}
