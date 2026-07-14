import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/programs_library.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/character_draft.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/widgets/onboarding/starter_readout_panel.dart';

/// The onboarding starter-readout panel: a reversible, body-neutral recommendation
/// BIT presents before the irreversible naming commit. Tests pin the two user
/// archetypes (recommended program vs TRAIN MANUALLY / missing-data), the editable
/// affordance, and that BIT freezes under reduced motion (no ticker hang).
CharacterDraft _draft({
  String? programId,
  Set<int>? weekdays,
  CharacterClass clazz = CharacterClass.assassin,
}) => CharacterDraft(
  calibration: CalibrationResult(
    goal: BodyGoal.cut,
    freq: TrainingFreq.low,
    exp: Experience.novice,
    bodyWeightKg: 70,
    sex: UserProfileSex.preferNotToSay,
    clazz: clazz,
  ),
  classConfirmedAt: DateTime(2026, 1, 1),
  selectedProgramId: programId,
  trainingWeekdays: weekdays,
);

Future<void> _pump(
  WidgetTester tester,
  Widget panel, {
  bool reduceMotion = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SingleChildScrollView(child: panel),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('recommended-program archetype shows the built plan', (
    tester,
  ) async {
    await _pump(
      tester,
      StarterReadoutPanel(
        draft: _draft(programId: 'full_body_3x', weekdays: const {1, 3, 5}),
        onEdit: () {},
      ),
    );
    await tester.pumpAndSettle(); // proves the BIT ticker is frozen (no hang)

    expect(find.text('Your program is built, warrior.'), findsOneWidget);
    expect(find.text('Tap to edit'), findsOneWidget);
    expect(find.text('EDIT'), findsOneWidget);
    expect(find.text('ASSASSIN'), findsOneWidget);
    expect(find.text(programById('full_body_3x')!.name), findsOneWidget);
    expect(find.text('TRAINING DAYS'), findsOneWidget);
  });

  testWidgets('manual archetype (no program) drops the program/days framing', (
    tester,
  ) async {
    await _pump(
      tester,
      StarterReadoutPanel(
        draft: _draft(clazz: CharacterClass.tank),
        onEdit: () {},
      ),
    );

    // No program built → the headline + manual line, no day strip.
    expect(find.text('Your path is set, warrior.'), findsOneWidget);
    expect(find.text('Your program is built, warrior.'), findsNothing);
    expect(find.text('MANUAL TRAINING'), findsOneWidget);
    expect(find.text('TRAINING DAYS'), findsNothing);
    // Class identity still reads.
    expect(find.text('TANK'), findsOneWidget);
  });

  testWidgets('tapping the card edits (routes back via onEdit)', (tester) async {
    var edited = false;
    await _pump(
      tester,
      StarterReadoutPanel(
        draft: _draft(programId: 'full_body_3x', weekdays: const {1, 3, 5}),
        onEdit: () => edited = true,
      ),
    );

    await tester.tap(find.text('STARTER PLAN'));
    await tester.pump();
    expect(edited, isTrue);
  });

  testWidgets('the card merges to a single labelled node for screen readers', (
    tester,
  ) async {
    await _pump(
      tester,
      StarterReadoutPanel(
        draft: _draft(programId: 'full_body_3x', weekdays: const {1, 3, 5}),
        onEdit: () {},
      ),
    );

    // excludeSemantics folds the inner Texts into ONE node carrying the plan +
    // "Tap to edit"; its button role is exercised by the tap test above.
    expect(
      find.bySemanticsLabel(
        RegExp(r'Starter plan\. Class ASSASSIN.*Tap to edit\.'),
      ),
      findsOneWidget,
    );
  });
}
