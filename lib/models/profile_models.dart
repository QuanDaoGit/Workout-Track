class ProfileData {
  const ProfileData({required this.displayName, required this.avatarPath});

  static const defaultName = 'Player';
  static const defaultAvatarPath = 'assets/avatar/EverFace1.0.png';

  final String displayName;
  final String avatarPath;

  ProfileData copyWith({String? displayName, String? avatarPath}) {
    return ProfileData(
      displayName: displayName ?? this.displayName,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'avatarPath': avatarPath,
  };

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    final name = (json['displayName'] as String? ?? '').trim();
    final avatar = (json['avatarPath'] as String? ?? '').trim();
    return ProfileData(
      displayName: name.isEmpty ? defaultName : name,
      avatarPath: avatar.isEmpty ? defaultAvatarPath : avatar,
    );
  }

  factory ProfileData.defaults() {
    return const ProfileData(
      displayName: defaultName,
      avatarPath: defaultAvatarPath,
    );
  }
}
