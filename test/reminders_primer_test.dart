import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/avatar_spec.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/reminders_primer_page.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/services/simple_mode_service.dart';

/// The onboarding "guidance" step embedded in RemindersPrimerPage: a self-
/// contained card that flips the existing Simple Mode on/off, pre-selected from
/// the user's self-reported experience, committed by its OWN controls (not the
/// TURN ON / NOT NOW notification buttons), reversible, with a peek preview.
///
/// The value is persisted the moment the card is displayed (Codex F1: never
/// before the user has seen it) and on every flip (Codex F2: the store is the
/// single source of truth). Fresh prefs per test; pump (never pumpAndSettle) —
/// the primer carries perpetual ambient drift.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HapticService.enabled = false; // no vibration plugin in the test env
  });
  tearDown(() => HapticService.enabled = true);

  Character character(Experience exp) => Character(
    name: 'Rex',
    calibration: CalibrationResult(
      goal: BodyGoal.cut,
      freq: TrainingFreq.mid,
      exp: exp,
      bodyWeightKg: 72,
      sex: UserProfileSex.preferNotToSay,
      clazz: CharacterClass.assassin,
    ),
    classConfirmedAt: DateTime(2026, 5, 29, 12),
    characterName: 'Rex',
    createdAt: DateTime(2026, 5, 29, 12),
  );

  Future<void> pumpPrimer(WidgetTester tester, Experience exp) async {
    // A tall phone-sized view so the scrolling guidance card is on-screen and
    // taps land (the default 600px test viewport clips it below the fold).
    tester.view.physicalSize = const Size(1170, 3200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child!,
        ),
        home: RemindersPrimerPage(
          character: character(exp),
          avatarSpec: AvatarSpec.fallback,
          trainingWeekdays: const {1, 3, 5},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pump();
    await tester.tap(find.text(text));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('intermediate preselects Compact and seeds Simple Mode ON', (
    tester,
  ) async {
    await pumpPrimer(tester, Experience.intermediate);

    expect(find.text('WORKOUT GUIDANCE'), findsOneWidget);
    expect(find.text('COMPACT'), findsOneWidget);
    expect(find.text('EXTRA SUGGESTIONS'), findsOneWidget);
    // Persisted the moment the card was displayed.
    expect(await SimpleModeService().isEnabled(), isTrue);
  });

  testWidgets('beginner preselects Extra suggestions and seeds Simple Mode OFF', (
    tester,
  ) async {
    await pumpPrimer(tester, Experience.beginner);
    expect(await SimpleModeService().isEnabled(), isFalse);
  });

  testWidgets('tapping Extra suggestions flips Simple Mode OFF (intermediate)', (
    tester,
  ) async {
    await pumpPrimer(tester, Experience.intermediate);
    expect(await SimpleModeService().isEnabled(), isTrue);

    await tapText(tester, 'EXTRA SUGGESTIONS');

    expect(await SimpleModeService().isEnabled(), isFalse);
  });

  testWidgets('tapping Compact flips Simple Mode ON (beginner)', (tester) async {
    await pumpPrimer(tester, Experience.beginner);
    expect(await SimpleModeService().isEnabled(), isFalse);

    await tapText(tester, 'COMPACT');

    expect(await SimpleModeService().isEnabled(), isTrue);
  });

  testWidgets('See the difference reveals the preview, which swaps with the pick', (
    tester,
  ) async {
    // Beginner → Extra suggestions selected, so the revealed mock shows extras.
    await pumpPrimer(tester, Experience.beginner);
    expect(find.text('Warm up'), findsNothing); // collapsed by default

    await tapText(tester, 'SEE THE DIFFERENCE');
    expect(find.text('Warm up'), findsOneWidget);
    expect(find.textContaining('TRY:'), findsOneWidget);

    // Flipping to Compact strips the scaffolding from the mock in place.
    await tapText(tester, 'COMPACT');
    expect(find.text('Warm up'), findsNothing);
    expect(find.textContaining('TRY:'), findsNothing);
  });

  testWidgets('the reminder actions remain present alongside the guidance card', (
    tester,
  ) async {
    // Guidance is a separate decision (Codex F4): TURN ON / NOT NOW still render
    // as the notification actions.
    await pumpPrimer(tester, Experience.intermediate);
    expect(find.text('TURN ON'), findsOneWidget);
    expect(find.text('NOT NOW'), findsOneWidget);
  });
}
