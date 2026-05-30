import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/character_draft.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/avatar_select_screen.dart';
import 'package:workout_track/pages/onboarding/name_screen.dart';
import 'package:workout_track/pages/onboarding/start_gate_screen.dart';
import 'package:workout_track/services/character_service.dart';
import 'package:workout_track/services/onboarding_service.dart';
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

  testWidgets('keyboard done commits when valid', (tester) async {
    Character? created;
    await _pumpNameScreen(
      tester,
      onCharacterCreated: (character) async => created = character,
    );

    await tester.enterText(find.byType(TextField), 'Nova');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(created?.name, 'Nova');
    expect(created?.selectedAvatarId, 'avatar_04');
    expect(await OnboardingService().isComplete(), isTrue);
    expect((await CharacterService().loadActiveCharacter())?.name, 'Nova');
    expect(find.byType(StartGateScreen), findsOneWidget);
    // Reduced-motion path lands directly on the sustained state: prompt
    // visible, both buttons rendered.
    expect(find.text('READY TO TRAIN?'), findsOneWidget);
    expect(find.text('START WORKOUT'), findsOneWidget);
    expect(find.text('EXPLORE FIRST'), findsOneWidget);
  });

  testWidgets('button tap commits when valid', (tester) async {
    Character? created;
    await _pumpNameScreen(
      tester,
      onCharacterCreated: (character) async => created = character,
    );

    await tester.enterText(find.byType(TextField), 'Kai');
    await tester.pump();
    await tester.tap(find.text('I AM KAI'));
    await tester.pumpAndSettle();

    expect(created?.characterName, 'Kai');
    expect(find.byType(StartGateScreen), findsOneWidget);
    expect(find.text('Kai'), findsOneWidget);
    expect(find.text('RECRUIT'), findsOneWidget);
    expect(find.text('LV.1'), findsOneWidget);
  });

  testWidgets('back returns to avatar screen and typed name is discarded', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AvatarSelectScreen(
            draft: _baseDraft,
            initialSelectedAvatarId: 'avatar_04',
            onAvatarSelected: (_) async {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('THIS IS ME'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nova');
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(find.byType(AvatarSelectScreen), findsOneWidget);

    await tester.tap(find.text('THIS IS ME'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('name_input_field')),
    );
    expect(field.controller!.text, isEmpty);
  });
}

Future<void> _pumpNameScreen(
  WidgetTester tester, {
  Future<void> Function(Character character)? onCharacterCreated,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // Propagate disableAnimations to pushed routes too (e.g. StartGate).
      builder: (context, child) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: child!,
      ),
      home: NameScreen(
        draft: _baseDraft.copyWith(selectedAvatarId: 'avatar_04'),
        onCharacterCreated: onCharacterCreated ?? (_) async {},
      ),
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
