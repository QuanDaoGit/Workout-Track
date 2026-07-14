import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/character_draft.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/program_loading_page.dart';
import 'package:workout_track/pages/onboarding/program_selection_page.dart';
import 'package:workout_track/pages/onboarding/name_screen.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/pixel_loader.dart';
import 'package:workout_track/widgets/strobe_flash.dart';
import 'package:workout_track/widgets/weekday_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgramLoadingPage', () {
    testWidgets('renders title, app icon, and quiz-derived status text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ProgramLoadingPage(result: _recompResult, onComplete: _noop),
        ),
      );

      expect(find.text('BUILDING YOUR PROGRAM'), findsOneWidget);
      expect(find.text('Reading goal: recomp'), findsOneWidget);
      expect(find.text('Training rhythm: 4-5 days'), findsOneWidget);
      expect(find.text('Experience level: beginner'), findsOneWidget);
      expect(find.text('Matching program...'), findsOneWidget);

      final logo = tester.widget<Image>(
        find.byKey(const ValueKey('program_loading_app_logo')),
      );
      expect(logo.width, 44);
      expect(logo.height, 44);
    });

    testWidgets('reduced motion shows ready state briefly then completes', (
      tester,
    ) async {
      var completions = 0;
      await tester.pumpWidget(
        _wrap(
          ProgramLoadingPage(
            result: _recompResult,
            onComplete: () => completions++,
          ),
          reducedMotion: true,
        ),
      );

      await tester.pump();
      expect(find.text('PROGRAM READY'), findsOneWidget);
      expect(completions, 0);

      await tester.pump(const Duration(milliseconds: 499));
      expect(completions, 0);

      await tester.pump(const Duration(milliseconds: 1));
      expect(completions, 1);

      await tester.pump(const Duration(seconds: 1));
      expect(completions, 1);
    });

    testWidgets('normal motion completes once after five seconds', (
      tester,
    ) async {
      var completions = 0;
      await tester.pumpWidget(
        _wrap(
          ProgramLoadingPage(
            result: _recompResult,
            onComplete: () => completions++,
          ),
        ),
      );
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 4999));
      expect(completions, 0);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(completions, 1);

      await tester.pump(const Duration(seconds: 1));
      expect(completions, 1);
    });

    testWidgets('readback resolves early and matching owns the wait', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ProgramLoadingPage(result: _recompResult, onComplete: _noop),
        ),
      );
      await tester.pump();

      expect(_statusDotColor(tester, 0), kBorder);
      expect(_statusDotColor(tester, 3), kBorder);
      expect(find.text('PROGRAM READY'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1150));

      expect(_statusDotColor(tester, 0), kNeon);
      expect(_statusDotColor(tester, 1), kNeon);
      expect(_statusDotColor(tester, 2), kNeon);
      expect(_statusDotColor(tester, 3), kBorder);
      expect(find.text('CALIBRATING'), findsOneWidget);
      expect(find.text('PROGRAM READY'), findsNothing);

      await tester.pump(const Duration(milliseconds: 300));

      expect(_statusDotColor(tester, 3), kNeon);
      expect(find.text('PROGRAM READY'), findsNothing);

      await tester.pump(const Duration(milliseconds: 3199));

      expect(find.text('CALIBRATING'), findsOneWidget);
      expect(find.text('PROGRAM READY'), findsNothing);
      expect(_activeSegmentCount(tester), lessThan(12));

      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('PROGRAM READY'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));

      expect(_activeSegmentCount(tester), 12);
    });

    testWidgets('uses no spinner, sparks, or strobe widgets', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProgramLoadingPage(result: _recompResult, onComplete: _noop),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(PixelLoader), findsNothing);
      expect(find.byType(StrobeFlash), findsNothing);
      expect(
        find.byKey(const ValueKey('program_loading_sparks')),
        findsNothing,
      );
    });
  });

  group('ProgramSelectionPage', () {
    test('recommended program matches rhythm and experience', () {
      expect(recommendedProgramIdFor(_lowNoviceResult), 'full_body_3x');
      expect(recommendedProgramIdFor(_recompResult), 'upper_lower');
      expect(recommendedProgramIdFor(_highAdvancedResult), 'ppl');
    });

    testWidgets('start path forwards selected program to the name screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ProgramSelectionPage(
            draft: CharacterDraft(
              calibration: _recompResult,
              classConfirmedAt: DateTime(2026, 6, 6, 10),
            ),
          ),
          reducedMotion: true,
        ),
      );

      expect(find.text('YOUR FIRST PATH'), findsOneWidget);
      expect(find.text('UPPER LOWER'), findsOneWidget);

      await tester.tap(find.text('START THIS PATH'));
      await tester.pumpAndSettle();

      final name = tester.widget<NameScreen>(find.byType(NameScreen));
      expect(name.draft.selectedProgramId, 'upper_lower');
    });

    testWidgets('blocks system back (point of no return)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProgramSelectionPage(
            draft: CharacterDraft(
              calibration: _recompResult,
              classConfirmedAt: DateTime(2026, 6, 6, 10),
            ),
          ),
          reducedMotion: true,
        ),
      );

      // The screen's own guard is the first PopScope under its subtree — backing
      // out used to land on a spent, re-entrancy-locked quiz question.
      final scope = tester.widgetList<PopScope>(find.byType(PopScope)).first;
      expect(scope.canPop, isFalse);

      // And there is no back chevron to pop the route either.
      expect(find.byIcon(Icons.chevron_left_sharp), findsNothing);
    });

    testWidgets('manual path forwards no program id', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProgramSelectionPage(
            draft: CharacterDraft(
              calibration: _recompResult,
              classConfirmedAt: DateTime(2026, 6, 6, 10),
            ),
          ),
          reducedMotion: true,
        ),
      );

      await tester.tap(find.text('TRAIN MANUALLY'));
      await tester.pumpAndSettle();

      final name = tester.widget<NameScreen>(find.byType(NameScreen));
      expect(name.draft.selectedProgramId, isNull);
    });
  });

  group('ProgramSelectionPage — discoverability fix', () {
    Widget page() => _wrap(
      ProgramSelectionPage(
        draft: CharacterDraft(
          calibration: _recompResult, // recommends UPPER LOWER
          classConfirmedAt: DateTime(2026, 6, 6, 10),
        ),
      ),
      reducedMotion: true,
    );

    testWidgets('recommended program is the first card (seen on load)', (
      tester,
    ) async {
      await tester.pumpWidget(page());

      // UPPER LOWER is normally 2nd in library order (after FULL BODY 3X); the
      // reorder puts the recommended one above it. (PPL is below the fold and
      // lazily un-built, so the on-screen pair is the proof.)
      final recommendedY = tester.getTopLeft(find.text('UPPER LOWER')).dy;
      final fullBodyY = tester.getTopLeft(find.text('FULL BODY 3X')).dy;
      expect(recommendedY, lessThan(fullBodyY));
    });

    testWidgets('training-days summary is pinned + visible, and opens the '
        'editor without scrolling', (tester) async {
      await tester.pumpWidget(page());

      // The pinned summary is present on load (no scroll), with the seeded pick.
      expect(find.text('TRAINING DAYS'), findsOneWidget);
      expect(find.text('MON·TUE·THU·FRI'), findsOneWidget); // UL seed = 4 days

      await tester.tap(find.text('TRAINING DAYS'));
      await tester.pumpAndSettle();

      // The editor sheet opens with the shared picker.
      expect(find.text('WHEN WILL YOU TRAIN?'), findsOneWidget);
      expect(find.byType(WeekdayPicker), findsOneWidget);
    });

    testWidgets('editing days in the sheet updates the summary + the draft', (
      tester,
    ) async {
      await tester.pumpWidget(page());

      await tester.tap(find.text('TRAINING DAYS'));
      await tester.pumpAndSettle();

      // Drop Tuesday (scoped to the sheet's picker), then commit.
      await tester.tap(
        find.descendant(
          of: find.byType(WeekdayPicker),
          matching: find.text('TUE'),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      expect(find.text('MON·THU·FRI'), findsOneWidget); // summary updated

      await tester.tap(find.text('START THIS PATH'));
      await tester.pumpAndSettle();
      final name = tester.widget<NameScreen>(find.byType(NameScreen));
      expect(name.draft.trainingWeekdays, {1, 4, 5});
    });

    testWidgets('page golden (recommended-first + pinned summary)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(page());
      await tester.pump();
      await expectLater(
        find.byType(ProgramSelectionPage),
        matchesGoldenFile('goldens/program_selection_discoverability.png'),
      );
    });
  });
}

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    builder: reducedMotion
        ? (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: true, accessibleNavigation: true),
            child: child ?? const SizedBox.shrink(),
          )
        : null,
    home: child,
  );
}

void _noop() {}

Color _statusDotColor(WidgetTester tester, int index) {
  final dot = tester.widget<Container>(
    find.byKey(ValueKey('program_loading_status_dot_$index')),
  );
  return (dot.decoration! as BoxDecoration).color!;
}

int _activeSegmentCount(WidgetTester tester) {
  var count = 0;
  for (var i = 0; i < 12; i++) {
    final segment = tester.widget<Container>(
      find.byKey(ValueKey('program_loading_progress_segment_$i')),
    );
    if ((segment.decoration! as BoxDecoration).color == kNeon) {
      count++;
    }
  }
  return count;
}

const _recompResult = CalibrationResult(
  goal: BodyGoal.recomp,
  freq: TrainingFreq.mid,
  exp: Experience.beginner,
  bodyWeightKg: 80,
  sex: UserProfileSex.preferNotToSay,
  clazz: CharacterClass.bruiser,
);

const _lowNoviceResult = CalibrationResult(
  goal: BodyGoal.cut,
  freq: TrainingFreq.low,
  exp: Experience.novice,
  bodyWeightKg: 72,
  sex: UserProfileSex.preferNotToSay,
  clazz: CharacterClass.assassin,
);

const _highAdvancedResult = CalibrationResult(
  goal: BodyGoal.bulk,
  freq: TrainingFreq.high,
  exp: Experience.advanced,
  bodyWeightKg: 90,
  sex: UserProfileSex.male,
  clazz: CharacterClass.tank,
);
