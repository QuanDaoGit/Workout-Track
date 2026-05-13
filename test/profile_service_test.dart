import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/profile_models.dart';
import 'package:workout_track/services/profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads default profile when no local profile exists', () async {
    final profile = await ProfileService().loadProfile();

    expect(profile.displayName, ProfileData.defaultName);
    expect(profile.avatarPath, ProfileData.defaultAvatarPath);
  });

  test('persists display name and avatar path', () async {
    final service = ProfileService();

    await service.saveDisplayName('Dana');
    await service.saveAvatarPath('assets/avatar/4.png');
    final profile = await service.loadProfile();

    expect(profile.displayName, 'Dana');
    expect(profile.avatarPath, 'assets/avatar/4.png');
  });

  test('blank display name falls back to Player', () async {
    final service = ProfileService();

    await service.saveDisplayName('   ');
    final profile = await service.loadProfile();

    expect(profile.displayName, ProfileData.defaultName);
  });
}
