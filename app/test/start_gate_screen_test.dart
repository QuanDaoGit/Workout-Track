import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/start_gate_screen.dart';
import 'package:workout_track/widgets/avatar/ironbit_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Character character() => Character(
    name: 'Nova',
    calibration: const CalibrationResult(
      goal: BodyGoal.cut, freq: TrainingFreq.mid, exp: Experience.beginner,
      bodyWeightKg: 72, sex: UserProfileSex.preferNotToSay,
      clazz: CharacterClass.assassin,
    ),
    classConfirmedAt: DateTime(2026, 5, 29, 12),
    characterName: 'Nova',
    createdAt: DateTime(2026, 5, 29, 12),
  );

  Future<void> pump(WidgetTester tester, {required bool reduced}) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(disableAnimations: reduced), child: child!,
      ),
      home: StartGateScreen(character: character()),
    ),
  );

  testWidgets('reduced motion lands on the settled hero gate', (tester) async {
    await pump(tester, reduced: true);
    await tester.pump(); // post-frame skip-to-end

    // The hero avatar is present and rendered large (>= 120px).
    final avatar = tester.widget<IronbitAvatar>(find.byType(IronbitAvatar));
    expect(avatar.size, greaterThanOrEqualTo(120));

    // Identity + CTAs are all present in the settled state.
    expect(find.text('Nova'), findsOneWidget);
    expect(find.text('RECRUIT'), findsOneWidget);
    expect(find.text('LV.1'), findsOneWidget);
    expect(find.textContaining('0 / 50 XP'), findsOneWidget);
    expect(find.text('START WORKOUT'), findsOneWidget);
    expect(find.text('EXPLORE FIRST'), findsOneWidget);
  });
}
