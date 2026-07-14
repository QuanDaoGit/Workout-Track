import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/gift_reveal_screen.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/services/sfx_service.dart';
import 'package:workout_track/theme/tokens.dart';

/// Renders the Gift-Reveal beat's key frames to `test/audit/_shots/gift_*.png`
/// (gitignored) so BIT's huge-neutral offer + the fly-in can be eyeballed
/// without a device. Same contract as the ceremony frames: runs ONLY under
/// `flutter test --update-goldens`.
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
    SfxService.enabled = false;
    HapticService.enabled = false;
  });
  tearDown(() {
    SfxService.enabled = true;
    HapticService.enabled = true;
  });

  Character character() => Character(
    name: 'Nova',
    calibration: const CalibrationResult(
      goal: BodyGoal.cut,
      freq: TrainingFreq.mid,
      exp: Experience.beginner,
      bodyWeightKg: 72,
      sex: UserProfileSex.preferNotToSay,
      clazz: CharacterClass.assassin,
    ),
    classConfirmedAt: DateTime(2026, 5, 29, 12),
    characterName: 'Nova',
    createdAt: DateTime(2026, 5, 29, 12),
  );

  Future<void> pumpFor(WidgetTester tester, int ms) async {
    var left = ms;
    while (left > 0) {
      final step = left < 50 ? left : 50;
      await tester.pump(Duration(milliseconds: step));
      left -= step;
    }
  }

  final skip = !autoUpdateGoldenFiles;
  final captureKey = GlobalKey();

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
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
          child: GiftRevealScreen(character: character()),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> shot(String name) => expectLater(
    find.byKey(captureKey),
    matchesGoldenFile('_shots/$name.png'),
  );

  testWidgets('gift reveal frames', (tester) async {
    await start(tester);

    // 0 · OFFER: BIT huge + neutral, headline, speech typed out, YES + skip.
    await pumpFor(tester, 1600);
    await shot('gift_offer');

    // Fly to the Charge Ritual seat.
    await tester.tap(find.text('YES — SHOW ME'));
    await pumpFor(tester, 550); // mid-flight: banked, scaled, thrust trail
    await shot('gift_flight');

    await pumpFor(tester, 800); // late flight → settling toward the seat
    await shot('gift_flight_late');

    await tester.pumpWidget(const SizedBox());
  }, skip: skip, timeout: const Timeout(Duration(seconds: 120)));
}
