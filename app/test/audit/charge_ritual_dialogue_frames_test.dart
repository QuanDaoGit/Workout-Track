import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/charge_ritual_screen.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/services/sfx_service.dart';
import 'package:workout_track/theme/tokens.dart';

import '../helpers/fake_video_platform.dart';

/// Renders the new video-synced BIT dialogue on the Charge Ritual screen to
/// `test/audit/_shots/charge_dialogue_*.png` (gitignored) so the amber+shaky
/// `[boost]`/`[BOOSTING]` words and line wrapping can be eyeballed without a
/// device. Reduced motion opens straight at the hold gate (no reel), so we can
/// walk the post-reel dialogue on the clock. Runs ONLY under `--update-goldens`.
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
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child!,
        ),
        home: RepaintBoundary(
          key: captureKey,
          child: ChargeRitualScreen(character: character()),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> shot(String name) => expectLater(
    find.byKey(captureKey),
    matchesGoldenFile('_shots/$name.png'),
  );

  testWidgets('charge ritual dialogue frames', (tester) async {
    await start(tester);

    // Hold gate, before the dwell → the thank-you line.
    await shot('charge_dialogue_thankyou');

    // After the dwell → the boost cue with amber [boost] (BIT cheering).
    await advance(tester, 3900);
    await shot('charge_dialogue_boostcue');

    // Tap the always-available pour path → mid auto-fill is `pouring` → the
    // amber [BOOSTING] status word.
    await tester.tap(find.textContaining('BIT pours it'));
    await advance(tester, 400); // < autoFillMs (1000): still pouring
    await shot('charge_dialogue_boosting');

    await tester.pumpWidget(const SizedBox());
  }, skip: skip, timeout: const Timeout(Duration(seconds: 120)));

  // Phase B: show the lights-down beat. Reduced motion (used above) has no
  // reel, so to render the dim we must drive the real reel path — a
  // FakeVideoPlayerPlatform (mirroring charge_ritual_screen_test.dart's Task
  // A1/A2 setup) so VideoPlayerController.initialize() actually succeeds and
  // the widget reaches the `reel` phase instead of the failed-video watchdog.
  testWidgets('charge ritual reel-dim frame', (tester) async {
    final originalPlatform = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    addTearDown(() => VideoPlayerPlatform.instance = originalPlatform);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dimKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'ShareTechMono',
          scaffoldBackgroundColor: kBg,
        ),
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: child!,
        ),
        home: RepaintBoundary(
          key: dimKey,
          child: ChargeRitualScreen(character: character()),
        ),
      ),
    );
    await tester.pump();
    await advance(tester, 1400); // video initializes; entry eases to Beat C

    await tester.tap(find.text('START BOOSTING'));
    await tester.pump();
    await advance(tester, 600); // > _kReelDimRampMs (500): fully at the floor

    await expectLater(
      find.byKey(dimKey),
      matchesGoldenFile('_shots/charge_reel_dim.png'),
    );

    await tester.pumpWidget(const SizedBox());
  }, skip: skip, timeout: const Timeout(Duration(seconds: 120)));
}
