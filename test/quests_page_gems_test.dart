import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/quests_page.dart';
import 'package:workout_track/services/gem_service.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/count_up_text.dart';
import 'package:workout_track/widgets/pixel_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('claimable quest rewards render and claim as gems', (
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

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: QuestsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+5 GEMS'), findsWidgets);
    expect(find.text('+5 XP'), findsNothing);

    final gemCounter = tester.widget<CountUpText>(
      find.descendant(
        of: find.byKey(const ValueKey('quests_gem_balance_counter')),
        matching: find.byType(CountUpText),
      ),
    );
    final claimButton = tester.widget<PixelButton>(
      find.widgetWithText(PixelButton, '+5 GEMS').first,
    );

    expect(
      find.byKey(const ValueKey('quests_gem_balance_icon')),
      findsOneWidget,
    );
    expect(gemCounter.style?.color, kText);
    expect(claimButton.color, isNull);
    expect(claimButton.onPressed, isNotNull);

    await tester.tap(find.text('+5 GEMS').first);
    await tester.pumpAndSettle();

    // The quest flips to CLAIMED — the juice replaces the old SnackBar.
    expect(find.text('CLAIMED'), findsWidgets);
    expect(find.text('Claimed +5 gems'), findsNothing);
    final claimedBadge = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('quest_status_claimed')).first,
            matching: find.byType(Container),
          )
          .first,
    );
    final claimedDecoration = claimedBadge.decoration! as BoxDecoration;
    final claimedBorder = claimedDecoration.border! as Border;
    expect(claimedBorder.top.color, kMutedText);

    // The gems actually landed in the ledger.
    expect(await GemService().balance(), 5);
  });

  testWidgets('locked quest reward badges use amber as value color', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: QuestsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rewardBadge = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('quest_reward_badge_5')).first,
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = rewardBadge.decoration! as BoxDecoration;
    final border = decoration.border! as Border;

    expect(border.top.color, kAmber);
  });
}
