import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/character_draft.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/program_selection_page.dart';
import 'package:workout_track/widgets/program_day_card.dart';

/// The onboarding program gate's opt-in, INFO-ONLY exercise preview: a second
/// affordance on the SELECTED card expands a read-only week plan (no swap
/// controls — adjustment is deferred to Programs). Collapses on program switch.
const _recompResult = CalibrationResult(
  goal: BodyGoal.recomp, // recommends UPPER LOWER
  freq: TrainingFreq.mid,
  exp: Experience.beginner,
  bodyWeightKg: 80,
  sex: UserProfileSex.preferNotToSay,
  clazz: CharacterClass.bruiser,
);

Widget _page() => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(disableAnimations: true, accessibleNavigation: true),
    child: child ?? const SizedBox.shrink(),
  ),
  home: ProgramSelectionPage(
    draft: CharacterDraft(
      calibration: _recompResult,
      classConfirmedAt: DateTime(2026, 6, 6, 10),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_page());
    await tester.pump();
  }

  testWidgets('only the selected card offers the preview affordance', (
    tester,
  ) async {
    await pump(tester);
    // Recommended (UPPER LOWER) is selected by default → exactly one affordance.
    expect(find.text('VIEW EXERCISES'), findsOneWidget);
    expect(find.byType(ProgramDayCard), findsNothing); // collapsed by default
  });

  testWidgets('expanding shows a READ-ONLY week plan (no swap controls)', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('VIEW EXERCISES'));
    await tester.pump();

    expect(find.text('WEEK PLAN'), findsOneWidget);
    expect(find.byType(ProgramDayCard), findsWidgets); // workout days listed
    expect(
      find.text('Customize exercises anytime in Programs.'),
      findsOneWidget,
    );
    expect(find.text('HIDE EXERCISES'), findsOneWidget);
    // Info-only: the adjust affordance from the detail page must NOT appear here.
    expect(find.byIcon(Icons.swap_horiz_sharp), findsNothing);
  });

  testWidgets('toggling again collapses the preview', (tester) async {
    await pump(tester);

    await tester.tap(find.text('VIEW EXERCISES'));
    await tester.pump();
    expect(find.byType(ProgramDayCard), findsWidgets);

    await tester.tap(find.text('HIDE EXERCISES'));
    await tester.pump();
    expect(find.byType(ProgramDayCard), findsNothing);
    expect(find.text('VIEW EXERCISES'), findsOneWidget);
  });

  testWidgets('switching program collapses an open preview', (tester) async {
    // Tall surface so the expanded card AND the next card are both on-screen —
    // so findsNothing below means "collapsed", not "scrolled out of view".
    tester.view.physicalSize = const Size(420, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_page());
    await tester.pump();

    await tester.tap(find.text('VIEW EXERCISES'));
    await tester.pump();
    expect(find.byType(ProgramDayCard), findsWidgets);

    // Select a different program — the preview collapses, the affordance moves.
    await tester.tap(find.text('FULL BODY 3X'));
    await tester.pump();
    expect(find.byType(ProgramDayCard), findsNothing);
    expect(find.text('VIEW EXERCISES'), findsOneWidget);
  });

  testWidgets('expanded preview golden', (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_page());
    await tester.pump();
    await tester.tap(find.text('VIEW EXERCISES'));
    await tester.pumpAndSettle(); // let exercise names resolve

    await expectLater(
      find.byType(ProgramSelectionPage),
      matchesGoldenFile('goldens/program_selection_expanded.png'),
    );
  });
}
