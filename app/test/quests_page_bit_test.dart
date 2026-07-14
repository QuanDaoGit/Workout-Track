import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/quests_page.dart';
import 'package:workout_track/widgets/companion/bit_mood_core.dart';

/// BIT is alive on the quest board: one painted core (not a static image) + a
/// state-derived voice line. Under reduced motion he is a still, faced, labelled
/// presence (never a dead ornament), and his line reflects the board state — a
/// quiet board reads forward, never as a guilt-poke.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget board() => const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: QuestsPage(),
        ),
      );

  testWidgets(
    'an empty board shows the painted BIT (labelled) speaking the quiet line',
    (tester) async {
      await tester.pumpWidget(board());
      await tester.pumpAndSettle();

      // The living painted core — not a raster sprite — is present, and carries
      // its Semantics label even with motion frozen (a labelled presence, not a
      // dead ornament). Match the Semantics widget directly (no live a11y tree).
      expect(find.byType(BitMoodCore), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'BIT, your companion',
        ),
        findsOneWidget,
      );

      // The quiet-board line is forward + collaborative, never a guilt-poke.
      expect(
        find.text('Nothing to claim yet. Let us change that.'),
        findsOneWidget,
      );
    },
  );

  testWidgets("BIT's line reflects claimable rewards once a session exists", (
    tester,
  ) async {
    final session = WorkoutSession(
      id: 'today',
      date: DateTime.now(),
      muscleGroup: 'Chest',
      targetMuscleGroups: const ['Chest'],
      targetDurationMinutes: 30,
      actualDurationSeconds: 30 * 60,
      estimatedCalories: 0,
      exercises: const [
        ExerciseLog(
          exerciseId: 'bench',
          exerciseName: 'Bench Press',
          sets: [SetEntry(weight: 100, reps: 10)],
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'workout_sessions': jsonEncode([session.toJson()]),
    });

    await tester.pumpWidget(board());
    await tester.pumpAndSettle();

    // Completing a workout makes several quests claimable → BIT announces them
    // (exact count varies; the state-derived phrasing is the contract).
    expect(find.textContaining('ready to claim'), findsOneWidget);
    expect(
      find.text('Nothing to claim yet. Let us change that.'),
      findsNothing,
    );
  });
}
