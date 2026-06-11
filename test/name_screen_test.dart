import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/character_draft.dart';
import 'package:workout_track/models/avatar_spec.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/name_screen.dart';
import 'package:workout_track/pages/onboarding/start_gate_screen.dart';
import 'package:workout_track/services/character_service.dart';
import 'package:workout_track/services/profile_service.dart';
import 'package:workout_track/widgets/motion/power_on.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'reduced motion renders prompt, subtext, empty field, counter, disabled button',
    (tester) async {
      await _pumpNameScreen(tester);

      expect(find.text('NAME YOUR CHARACTER'), findsOneWidget);
      expect(find.text("this is who you'll become."), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('0/16'), findsOneWidget);
      expect(find.text('ENTER A NAME'), findsOneWidget);
    },
  );

  testWidgets('invalid characters are stripped and paste caps at 16', (
    tester,
  ) async {
    await _pumpNameScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('name_input_field')),
      "A@!b🙂-c d'e1234567890",
    );
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('name_input_field')),
    );
    final text = field.controller!.text;
    expect(text.length, 16);
    expect(RegExp(r"^[A-Za-z0-9 '\-]+$").hasMatch(text), isTrue);
  });

  testWidgets('one-character and whitespace-only input keep button disabled', (
    tester,
  ) async {
    await _pumpNameScreen(tester);

    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump();
    expect(find.text('ENTER A NAME'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(find.text('ENTER A NAME'), findsOneWidget);
  });

  testWidgets(
    'two valid trimmed characters enable button and deleting disables',
    (tester) async {
      await _pumpNameScreen(tester);

      expect(find.byType(PowerOn), findsOneWidget);
      await tester.enterText(find.byType(TextField), ' ax ');
      await tester.pump();

      expect(find.text('I AM AX'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump();

      expect(find.text('ENTER A NAME'), findsOneWidget);
    },
  );

  testWidgets('keyboard done commits and advances to the start gate', (
    tester,
  ) async {
    await _pumpNameScreen(tester);

    await tester.enterText(find.byType(TextField), 'Nova');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(StartGateScreen), findsOneWidget);
  });

  testWidgets('button tap commits and advances to the start gate', (
    tester,
  ) async {
    await _pumpNameScreen(tester);

    await tester.enterText(find.byType(TextField), 'Kai');
    await tester.pump();
    await tester.tap(find.text('I AM KAI'));
    await tester.pumpAndSettle();

    expect(find.byType(StartGateScreen), findsOneWidget);
  });

  testWidgets('the typed name creates the character (no avatar step)', (
    tester,
  ) async {
    await _pumpNameScreen(tester);

    await tester.enterText(find.byType(TextField), 'Nova');
    await tester.pump();
    await tester.tap(find.text('I AM NOVA'));
    await tester.pumpAndSettle();

    expect(find.byType(StartGateScreen), findsOneWidget);
    expect((await CharacterService().loadActiveCharacter())?.name, 'Nova');
    // The gender-seeded starter face is mirrored into the profile store.
    final profile = await ProfileService().loadProfile();
    expect(
      profile.avatarSpec,
      AvatarDefaults.forSex(UserProfileSex.preferNotToSay),
    );
    expect(find.text('Nova'), findsOneWidget);
  });
}

Future<void> _pumpNameScreen(
  WidgetTester tester, {
  CharacterDraft? draft,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // Propagate disableAnimations to pushed routes (Avatar / Start Gate).
      builder: (context, child) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: child!,
      ),
      home: NameScreen(draft: draft ?? _baseDraft),
    ),
  );
  await tester.pump();
}

final _baseDraft = CharacterDraft(
  calibration: const CalibrationResult(
    goal: BodyGoal.cut,
    freq: TrainingFreq.mid,
    exp: Experience.beginner,
    bodyWeightKg: 72,
    sex: UserProfileSex.preferNotToSay,
    clazz: CharacterClass.assassin,
  ),
  classConfirmedAt: DateTime(2026, 5, 29, 12),
);
