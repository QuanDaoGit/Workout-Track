import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/avatar_spec.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/reminders_primer_page.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/theme/tokens.dart';

/// Renders the onboarding guidance step (embedded in RemindersPrimerPage) to
/// `test/audit/_shots/primer_*.png` (gitignored) so the "Compact / Extra
/// suggestions" card + its swapping preview can be eyeballed without a device.
/// Runs ONLY under `flutter test --update-goldens`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Future<ByteData> bytes(String path) async =>
        ByteData.view((await File(path).readAsBytes()).buffer);
    const specs = <String, String>{
      'PressStart2P': 'fonts/pressstart2p/PressStart2P-Regular.ttf',
      'ShareTechMono': 'fonts/sharetechmono/ShareTechMono-Regular.ttf',
    };
    for (final entry in specs.entries) {
      if (!File(entry.value).existsSync()) continue;
      await (FontLoader(entry.key)..addFont(bytes(entry.value))).load();
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HapticService.enabled = false;
  });
  tearDown(() => HapticService.enabled = true);

  Character character() => Character(
    name: 'Nova',
    calibration: const CalibrationResult(
      goal: BodyGoal.cut,
      freq: TrainingFreq.mid,
      exp: Experience.intermediate, // → Compact preselected
      bodyWeightKg: 72,
      sex: UserProfileSex.preferNotToSay,
      clazz: CharacterClass.assassin,
    ),
    classConfirmedAt: DateTime(2026, 5, 29, 12),
    characterName: 'Nova',
    createdAt: DateTime(2026, 5, 29, 12),
  );

  final skip = !autoUpdateGoldenFiles;
  final captureKey = GlobalKey();

  Future<void> start(WidgetTester tester) async {
    // Tall viewport so the whole primer (BIT ask + guidance card + footer)
    // renders in one frame.
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'ShareTechMono',
          scaffoldBackgroundColor: kBg,
        ),
        home: RepaintBoundary(
          key: captureKey,
          child: RemindersPrimerPage(
            character: character(),
            avatarSpec: AvatarSpec.fallback,
            trainingWeekdays: const {1, 3, 5},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pump();
    await tester.tap(find.text(text));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // settle AnimatedSize
  }

  Future<void> shot(String name) => expectLater(
    find.byKey(captureKey),
    matchesGoldenFile('_shots/$name.png'),
  );

  testWidgets('primer guidance frames', (tester) async {
    await start(tester);

    // Compact preselected (intermediate).
    await shot('primer_compact');

    // Flip to Extra suggestions.
    await tapText(tester, 'EXTRA SUGGESTIONS');
    await shot('primer_extra');

    // Reveal the preview (Extra → shows warm-up + TRY).
    await tapText(tester, 'SEE THE DIFFERENCE');
    await shot('primer_preview_extra');

    // Flip back to Compact with the preview open → the mock strips the extras.
    await tapText(tester, 'COMPACT');
    await shot('primer_preview_compact');

    await tester.pumpWidget(const SizedBox());
  }, skip: skip, timeout: const Timeout(Duration(seconds: 120)));
}
