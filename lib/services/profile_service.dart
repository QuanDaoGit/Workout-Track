import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/avatar_spec.dart';
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
    // Persistence backstop — the editor caps typing, but never trust the UI:
    // clamp to the shared bound so a stored name can't exceed it. Runes (not
    // code units) so a multi-byte char is never split mid-surrogate.
    final capped = String.fromCharCodes(
      cleanName.runes.take(ProfileData.maxNameLength),
    );
    await _save(
      profile.copyWith(
        displayName: capped.isEmpty ? ProfileData.defaultName : capped,
      ),
    );
  }

  Future<void> saveAvatarSpec(AvatarSpec avatarSpec) async {
    final profile = await loadProfile();
    await _save(profile.copyWith(avatarSpec: avatarSpec));
  }

  /// Whether the stored profile carries an avatar spec (vs. a legacy save
  /// from before the pixel-face system). Used by the one-shot migration.
  Future<bool> hasStoredAvatarSpec() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return false;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json['avatarSpec'] is Map;
    } catch (_) {
      return false;
    }
  }

  Future<void> _save(ProfileData profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }
}
