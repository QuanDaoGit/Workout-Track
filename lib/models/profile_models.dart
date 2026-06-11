import 'avatar_spec.dart';

class ProfileData {
  const ProfileData({required this.displayName, required this.avatarSpec});

  static const defaultName = 'Player';

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
