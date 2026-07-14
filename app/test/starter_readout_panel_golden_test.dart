import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/character_draft.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/onboarding/starter_readout_panel.dart';

/// Human-oracle render of the starter-readout panel (fonts fake as boxes in
/// goldens, but BIT, the pip strip, the accent bar and overall geometry are real).
CharacterDraft _draft() => CharacterDraft(
  calibration: const CalibrationResult(
    goal: BodyGoal.cut,
    freq: TrainingFreq.low,
    exp: Experience.novice,
    bodyWeightKg: 70,
    sex: UserProfileSex.preferNotToSay,
    clazz: CharacterClass.assassin,
  ),
  classConfirmedAt: DateTime(2026, 1, 1),
  selectedProgramId: 'full_body_3x',
  trainingWeekdays: const {1, 3, 5},
);

void main() {
  testWidgets('starter readout panel golden', (tester) async {
    tester.view.physicalSize = const Size(392, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            backgroundColor: kBg,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(kSpace4),
                child: StarterReadoutPanel(draft: _draft(), onEdit: () {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(StarterReadoutPanel),
      matchesGoldenFile('goldens/starter_readout_panel.png'),
    );
  });
}
