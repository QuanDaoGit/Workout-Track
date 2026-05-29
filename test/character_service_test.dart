import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/services/character_service.dart';
import 'package:workout_track/services/onboarding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Character JSON round-trips nested calibration and dates', () {
    final character = _character();

    final decoded = Character.fromJson(
      jsonDecode(jsonEncode(character.toJson())) as Map<String, dynamic>,
    );

    expect(decoded.name, 'Nova');
    expect(decoded.characterName, 'Nova');
    expect(decoded.selectedAvatarId, 'avatar_03');
    expect(decoded.calibration.goal, BodyGoal.cut);
    expect(decoded.calibration.freq, TrainingFreq.mid);
    expect(decoded.calibration.exp, Experience.beginner);
    expect(decoded.calibration.bodyWeightKg, 72);
    expect(decoded.calibration.sex, UserProfileSex.preferNotToSay);
    expect(decoded.calibration.clazz, CharacterClass.assassin);
    expect(decoded.classConfirmedAt, DateTime(2026, 5, 29, 12));
    expect(decoded.createdAt, DateTime(2026, 5, 29, 12, 30));
  });

  test(
    'createCharacterAndCompleteOnboarding stores active character',
    () async {
      final service = CharacterService();

      await service.createCharacterAndCompleteOnboarding(_character());

      final loaded = await service.loadActiveCharacter();
      expect(loaded?.name, 'Nova');
      expect(loaded?.selectedAvatarId, 'avatar_03');
      expect(await OnboardingService().isComplete(), isTrue);
    },
  );
}

Character _character() {
  return Character(
    name: 'Nova',
    calibration: const CalibrationResult(
      goal: BodyGoal.cut,
      freq: TrainingFreq.mid,
      exp: Experience.beginner,
      bodyWeightKg: 72,
      sex: UserProfileSex.preferNotToSay,
      clazz: CharacterClass.assassin,
    ),
    classConfirmedAt: DateTime(2026, 5, 29, 12),
    selectedAvatarId: 'avatar_03',
    characterName: 'Nova',
    createdAt: DateTime(2026, 5, 29, 12, 30),
  );
}
