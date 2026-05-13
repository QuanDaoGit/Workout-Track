import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile_models.dart';

class ProfileService {
  static const String _profileKey = 'profile_state_v1';

  Future<ProfileData> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return ProfileData.defaults();

    try {
      return ProfileData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ProfileData.defaults();
    }
  }

  Future<void> saveDisplayName(String displayName) async {
    final profile = await loadProfile();
    final cleanName = displayName.trim();
    await _save(
      profile.copyWith(
        displayName: cleanName.isEmpty ? ProfileData.defaultName : cleanName,
      ),
    );
  }

  Future<void> saveAvatarPath(String avatarPath) async {
    final profile = await loadProfile();
    final cleanPath = avatarPath.trim();
    await _save(
      profile.copyWith(
        avatarPath: cleanPath.isEmpty
            ? ProfileData.defaultAvatarPath
            : cleanPath,
      ),
    );
  }

  Future<void> _save(ProfileData profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }
}
