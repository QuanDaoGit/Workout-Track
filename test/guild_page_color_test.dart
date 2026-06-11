import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/guild_page.dart';
import 'package:workout_track/theme/tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('guild page keeps recap chrome neutral and reward cues amber', (
    tester,
  ) async {
    // Members render in a lazy ListView; the off-screen NPC tiles (and the amber
    // nod icon) only build if the render surface is tall enough. Enlarge it so
    // find.byKey('guild_member_npc_0') resolves regardless of sort order.
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = WorkoutSession(
      id: 'guild_top_session',
      date: DateTime.now(),
      muscleGroup: 'Chest',
      targetMuscleGroups: const ['Chest'],
      targetDurationMinutes: 45,
      actualDurationSeconds: 45 * 60,
      estimatedCalories: 0,
      exercises: const [
        ExerciseLog(
          exerciseId: 'bench',
          exerciseName: 'Bench Press',
          sets: [SetEntry(weight: 100000, reps: 10)],
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
          child: GuildPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final recapCard = tester.widget<Container>(
      find.byKey(const ValueKey('guild_weekly_recap_card')),
    );
    final recapDecoration = recapCard.decoration! as BoxDecoration;
    final recapBorder = recapDecoration.border! as Border;
    final recapLabel = tester.widget<Text>(find.text('WEEKLY RECAP'));
    final fragmentText = tester.widget<Text>(
      find.byKey(const ValueKey('guild_fragment_earned_text')),
    );
    final playerTile = tester.widget<Container>(
      find.byKey(const ValueKey('guild_member_player')),
    );
    final npcTile = tester.widget<Container>(
      find.byKey(const ValueKey('guild_member_npc_0')),
    );
    final activeNodIcon = tester
        .widgetList<Icon>(find.byIcon(Icons.bolt_sharp))
        .firstWhere((icon) => icon.color == kAmber);

    expect(recapDecoration.color, kCard);
    expect(recapBorder.top.color, kBorder);
    expect(recapBorder.top.color, isNot(kAmber));
    expect(recapLabel.style?.color, kMutedText);
    expect(fragmentText.style?.color, kAmber);
    expect(_borderColor(playerTile), kNeon);
    expect(_borderColor(npcTile), kBorder);
    expect(activeNodIcon.color, kAmber);
  });
}

Color _borderColor(Container container) {
  final decoration = container.decoration! as BoxDecoration;
  final border = decoration.border! as Border;
  return border.top.color;
}
