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
import 'package:workout_track/pages/onboarding/charge_ritual_screen.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/services/sfx_service.dart';
import 'package:workout_track/theme/tokens.dart';

/// Renders the CRT **power-cycle** transition to `test/audit/_shots/transition_*.png`
/// (gitignored) so the collapse (line → dot → near-black) and the Start Gate
/// power-on can be eyeballed without a device. Driven under FULL motion to
/// ignition via the accessible auto-fill tap. `--update-goldens` only.
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

  Future<void> advance(WidgetTester tester, int ms, {int step = 32}) async {
    for (var t = 0; t < ms; t += step) {
      await tester.pump(Duration(milliseconds: step));
    }
  }

  final skip = !autoUpdateGoldenFiles;
  final appKey = GlobalKey();

  Future<void> shot(String name) => expectLater(
    find.byKey(appKey),
    matchesGoldenFile('_shots/$name.png'),
  );

  testWidgets('charge ritual power-cycle frames', (tester) async {
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
        // Wrap ABOVE the navigator so the capture key survives the route push
        // (so the Start Gate power-on frame is captured too). FULL motion.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: false),
          child: RepaintBoundary(key: appKey, child: child!),
        ),
        home: ChargeRitualScreen(
          character: character(),
          avatarSpec: AvatarSpec.fallback,
        ),
      ),
    );
    await tester.pump();
    await advance(tester, 700); // video init fails in test → poster → hold gate

    // Accessible auto-fill to 100% → ignition → the collapse begins.
    await tester.tap(find.textContaining('BIT pours it'));
    await advance(tester, 3050); // > autoFillMs (3000) → ignite → _collapse.forward

    // Collapse beats (on the charge screen, before the route push).
    await tester.pump(const Duration(milliseconds: 250)); // ~mid vertical squash
    await shot('transition_collapse_line');
    await tester.pump(const Duration(milliseconds: 230)); // ~line → dot
    await shot('transition_collapse_dot');

    // Let the collapse finish → route push → Start Gate power-on bloom.
    await tester.pump(const Duration(milliseconds: 260)); // collapse completes
    await tester.pump(const Duration(milliseconds: 240)); // power-on well into bloom
    await shot('transition_poweron');

    await tester.pumpWidget(const SizedBox());
  }, skip: skip, timeout: const Timeout(Duration(seconds: 120)));
}
