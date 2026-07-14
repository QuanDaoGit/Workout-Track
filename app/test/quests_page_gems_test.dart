import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/quests_page.dart';
import 'package:workout_track/services/gem_service.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/pixel_button.dart';
import 'package:workout_track/widgets/quest_claim_flight.dart';

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

    expect(find.text('CLAIM'), findsWidgets);
    // The card never quotes the gem amount (no price tag).
    expect(find.text('+5 GEMS'), findsNothing);
    expect(find.text('+5 XP'), findsNothing);

    // The slim magenta gem wallet is present — the flight destination + readout.
    expect(find.byType(GemWallet), findsOneWidget);

    final claimButton = tester.widget<PixelButton>(
      find.widgetWithText(PixelButton, 'CLAIM').first,
    );
    expect(claimButton.color, isNull);
    expect(claimButton.onPressed, isNotNull);

    await tester.tap(find.text('CLAIM').first);
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

    // The gems landed in the ledger, and the wallet counted up to them (reduced
    // motion snaps the count to the new total).
    expect(await GemService().balance(), 5);
    expect(
      find.descendant(of: find.byType(GemWallet), matching: find.text('5')),
      findsOneWidget,
    );
  });

  testWidgets('in-progress quests show a dim box with no gem amount', (
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

    final inProgress = find.byKey(const ValueKey('quest_status_in_progress'));
    expect(inProgress, findsWidgets);
    expect(
      find.descendant(of: inProgress.first, matching: find.text('IN PROGRESS')),
      findsOneWidget,
    );
    // No gem amount and no gem image inside the in-progress marker.
    expect(find.text('+5'), findsNothing);
    expect(
      find.descendant(of: inProgress.first, matching: find.byType(Image)),
      findsNothing,
    );

    final badge = tester.widget<Container>(
      find
          .descendant(of: inProgress.first, matching: find.byType(Container))
          .first,
    );
    final border = (badge.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, kMutedText);
  });
}
