import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/charge_ritual_screen.dart';
import 'package:workout_track/pages/onboarding/gift_reveal_screen.dart';
import 'package:workout_track/pages/onboarding/start_gate_screen.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/services/sfx_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SfxService.enabled = false;
    HapticService.enabled = false;
  });
  tearDown(() {
    SfxService.enabled = true;
    HapticService.enabled = true;
  });

  Character character() => Character(
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
    characterName: 'Nova',
    createdAt: DateTime(2026, 5, 29, 12),
  );

  Future<void> pumpGift(WidgetTester tester, {required bool reduced}) {
    return tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: child!,
        ),
        home: GiftRevealScreen(character: character()),
      ),
    );
  }

  Future<void> advance(WidgetTester tester, int ms, {int step = 32}) async {
    for (var t = 0; t < ms; t += step) {
      await tester.pump(Duration(milliseconds: step));
    }
  }

  testWidgets('the offer renders BIT, the headline, YES and skip', (tester) async {
    await pumpGift(tester, reduced: true);
    await tester.pump();
    expect(find.text('A GIFT BEFORE YOU BEGIN'), findsOneWidget);
    expect(find.text('YES — SHOW ME'), findsOneWidget);
    expect(find.textContaining('take me to the start'), findsOneWidget);
  });

  testWidgets('reduced motion — YES navigates straight to the Charge Ritual', (
    tester,
  ) async {
    await pumpGift(tester, reduced: true);
    await tester.pump();
    await tester.tap(find.text('YES — SHOW ME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GiftRevealScreen), findsNothing);
    expect(find.byType(ChargeRitualScreen), findsOneWidget);
  });

  testWidgets('reduced motion — skip navigates to the Start Gate (name carried)', (
    tester,
  ) async {
    await pumpGift(tester, reduced: true);
    await tester.pump();
    await tester.tap(find.textContaining('take me to the start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(StartGateScreen), findsOneWidget);
    expect(find.text('Nova'), findsOneWidget);
  });

  testWidgets('full motion — YES flies BIT then lands on the Charge Ritual', (
    tester,
  ) async {
    await pumpGift(tester, reduced: false);
    await tester.pump();
    await tester.tap(find.text('YES — SHOW ME'));
    // flight (~1.3s) → fade-through-black (~0.24s) → navigate.
    await advance(tester, 1700);
    await tester.pump(const Duration(milliseconds: 400)); // fade route
    await tester.pump();
    expect(find.byType(ChargeRitualScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
