import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/Workout session/workout_summary.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/services/sfx_service.dart';
import 'package:workout_track/theme/tokens.dart';

/// Renders the Session-Complete ceremony's key frames to
/// `test/audit/_shots/ceremony_*.png` (gitignored) so the moment can be
/// eyeballed without a device. Same contract as the audit captures: runs ONLY
/// under `flutter test --update-goldens` (a plain test run skips).
///
/// Unlike `captureSurface` this pumps with **normal motion** — the ceremony is
/// the subject — advancing the clock in ≤50ms steps (the overlay clamps a
/// single tick to 60ms, like the prototype's rAF guard).
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
          child: const ColoredBox(
            color: kBg,
            child: WorkoutSummaryPage(
              muscleGroup: 'Chest',
              durationMinutes: 45,
              elapsedSeconds: 45 * 60,
              exerciseLogs: [],
              debugShowcase: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump(); // post-frame: showcase load + ceremony start
  }

  Future<void> shot(String name) => expectLater(
    find.byKey(captureKey),
    matchesGoldenFile('_shots/$name.png'),
  );

  testWidgets('ceremony frames', (tester) async {
    await start(tester);

    // 0 · ARRIVAL/INHALE (~350ms): scrim, dust, brackets, dormant BIT.
    await pumpFor(tester, 350);
    await shot('ceremony_dormant');

    // 2 · SURGE (~580ms): amber flood + cheer + spark ring.
    await pumpFor(tester, 230);
    await shot('ceremony_surge');

    // 4 · HANDOFF (~1800ms): banked mid-flight, scaled, thrust trail.
    await pumpFor(tester, 1220);
    await shot('ceremony_flight');

    // Touchdown + the first reveal beats (~3500ms): seat + XP + meter.
    await pumpFor(tester, 1700);
    await shot('ceremony_seated');

    // Full reveal (~7100ms): breakdown, receipts, BIT's typed line, CTA.
    await pumpFor(tester, 3600);
    await shot('ceremony_reveal_full');

    await tester.pumpWidget(const SizedBox());
  }, skip: skip, timeout: const Timeout(Duration(seconds: 120)));
}
