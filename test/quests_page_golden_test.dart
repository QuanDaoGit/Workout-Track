import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/quests_page.dart';
import 'package:workout_track/services/gem_service.dart';

/// Rendered-artifact proof of the ported Quest Claim board: the pinned header
/// (faced BIT + state line + the slim magenta gem wallet) over the scrolling
/// daily/weekly/side cards (CLAIM / CLAIMED / IN PROGRESS). Deterministic under
/// reduced motion (BIT frozen, no flight, counter snapped). The gem-fly + the
/// count-up are motion the golden can't capture — those stay an on-device check.
/// Regenerate with `flutter test --update-goldens`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Future<ByteData> font(String path) async =>
        ByteData.view((await File(path).readAsBytes()).buffer);
    await (FontLoader('ShareTechMono')
          ..addFont(font('fonts/sharetechmono/ShareTechMono-Regular.ttf')))
        .load();
    await (FontLoader('PressStart2P')
          ..addFont(font('fonts/pressstart2p/PressStart2P-Regular.ttf')))
        .load();
  });

  testWidgets('quests board — pinned header + claim states', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // The board is a deterministic-per-DATE rotation (an FNV hash of the period
    // key seeds the daily/weekly pick), so the golden must pin the clock —
    // otherwise it renders a different selection/state on any other day and
    // mismatches with no code change. Pin both the page clock and the seeded
    // session's date to one fixed day so the session counts as "today".
    final fixedNow = DateTime(2026, 6, 21, 9, 0);

    final session = WorkoutSession(
      id: 'today',
      date: fixedNow,
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
    await GemService().awardDemoGems(packId: 'seed', amount: 120, label: 'Seed');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: QuestsPage(nowProvider: () => fixedNow),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(QuestsPage),
      matchesGoldenFile('goldens/quests_board.png'),
    );
  });
}
