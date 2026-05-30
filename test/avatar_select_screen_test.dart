import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/character_draft.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/avatar_select_screen.dart';
import 'package:workout_track/pages/onboarding/name_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'reduced motion shows prompt, eight avatars, and disabled commit',
    (tester) async {
      var selectedCount = 0;
      await _pumpAvatarScreen(
        tester,
        onAvatarSelected: (_) async => selectedCount++,
      );

      expect(find.text('CHOOSE YOUR FACE'), findsOneWidget);
      for (var i = 1; i <= 8; i++) {
        expect(find.bySemanticsLabel('Avatar $i of eight'), findsOneWidget);
      }
      expect(find.text('THIS IS ME'), findsOneWidget);

      await tester.tap(find.text('THIS IS ME'));
      await tester.pumpAndSettle();

      expect(selectedCount, 0);
      expect(find.byType(NameScreen), findsNothing);
    },
  );

  testWidgets('selecting an avatar enables commit and shows star indicator', (
    tester,
  ) async {
    await _pumpAvatarScreen(tester);

    await tester.tap(find.bySemanticsLabel('Avatar 3 of eight'));
    await tester.pumpAndSettle();

    expect(find.byType(ImageIcon), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Avatar 3 of eight'));
    await tester.pumpAndSettle();

    expect(find.byType(ImageIcon), findsOneWidget);
  });

  testWidgets('selecting an avatar shows the class preview label', (
    tester,
  ) async {
    await _pumpAvatarScreen(tester);

    // Nothing chosen yet → preview prompts the user.
    expect(find.text('PICK ONE'), findsOneWidget);
    expect(find.text('ASSASSIN'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Avatar 3 of eight'));
    await tester.pumpAndSettle();

    // Preview now names the class derived earlier (draft class = assassin).
    expect(find.text('ASSASSIN'), findsOneWidget);
    expect(find.text('PICK ONE'), findsNothing);
  });

  testWidgets('commit pushes NameScreen with selected avatar in draft', (
    tester,
  ) async {
    CharacterDraft? committed;
    await _pumpAvatarScreen(
      tester,
      onAvatarSelected: (draft) async => committed = draft,
    );

    await tester.tap(find.bySemanticsLabel('Avatar 4 of eight'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('THIS IS ME'));
    await tester.pumpAndSettle();

    expect(committed?.selectedAvatarId, 'avatar_04');
    expect(find.byType(NameScreen), findsOneWidget);
    expect(find.text('NAME YOUR CHARACTER'), findsOneWidget);
  });

  testWidgets('initial selected avatar is restored from route state', (
    tester,
  ) async {
    await _pumpAvatarScreen(tester, initialSelectedAvatarId: 'avatar_06');

    expect(find.byType(ImageIcon), findsOneWidget);

    await tester.tap(find.text('THIS IS ME'));
    await tester.pumpAndSettle();

    expect(find.byType(NameScreen), findsOneWidget);
    expect(find.text('NAME YOUR CHARACTER'), findsOneWidget);
  });

  testWidgets('avatar assets exist and decode', (tester) async {
    await tester.runAsync(() async {
      for (final option in onboardingAvatarOptions) {
        final data = await rootBundle.load(option.assetPath);
        final bytes = data.buffer.asUint8List();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      }
    });
  });
}

Future<void> _pumpAvatarScreen(
  WidgetTester tester, {
  String? initialSelectedAvatarId,
  AvatarSelectedCallback? onAvatarSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: AvatarSelectScreen(
          draft: _draft,
          initialSelectedAvatarId: initialSelectedAvatarId,
          onAvatarSelected: onAvatarSelected ?? (_) async {},
        ),
      ),
    ),
  );
  await tester.pump();
}

final _draft = CharacterDraft(
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
