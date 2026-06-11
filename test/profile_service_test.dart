import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/avatar_spec.dart';
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
    expect(profile.avatarSpec, AvatarSpec.fallback);
  });

  test('persists display name and avatar spec', () async {
    final service = ProfileService();
    const spec = AvatarSpec(
      skin: AvatarSkin.tone04,
      eyes: AvatarEyes.green,
      hair: AvatarHair.curly,
      hairColor: AvatarHairColor.red,
      expression: AvatarExpression.grin,
    );

    await service.saveDisplayName('Dana');
    await service.saveAvatarSpec(spec);
    final profile = await service.loadProfile();

    expect(profile.displayName, 'Dana');
    expect(profile.avatarSpec, spec);
    expect(await service.hasStoredAvatarSpec(), isTrue);
  });

  test('legacy avatarPath save falls back to the default face', () async {
    SharedPreferences.setMockInitialValues({
      'profile_state_v1':
          '{"displayName":"Old Timer","avatarPath":"assets/avatar/4.png"}',
    });
    final service = ProfileService();

    final profile = await service.loadProfile();

    expect(profile.displayName, 'Old Timer');
    expect(profile.avatarSpec, AvatarSpec.fallback);
    // No spec stored yet → the boot migration knows to seed one.
    expect(await service.hasStoredAvatarSpec(), isFalse);
  });

  test('blank display name falls back to Player', () async {
    final service = ProfileService();

    await service.saveDisplayName('   ');
    final profile = await service.loadProfile();

    expect(profile.displayName, ProfileData.defaultName);
  });
}
