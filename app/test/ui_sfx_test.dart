import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/exercise_session.dart';
import 'package:workout_track/services/exercise_kind_cache.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/services/rest_timer_service.dart';
import 'package:workout_track/services/sfx_service.dart';
import 'package:workout_track/services/ui_sound_settings_service.dart';
import 'package:workout_track/widgets/pixel_button.dart';

/// The interaction-tier sound layer: SfxService's pooled micro channel policy
/// (gates, cooldowns, variant rotation, fail-open), the PixelButton
/// intent→sound seam, and the set-logged core-loop beat.
///
/// All assertions ride the `SfxService.onPlayForTest` seam — it records every
/// play that passed its gates *before* the platform call, which has no
/// implementation in the test env (the pool then fails open to silence).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final played = <String>[];
  late DateTime clock;

  void advance(Duration d) => clock = clock.add(d);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SfxService.instance.resetForTest();
    played.clear();
    clock = DateTime(2026, 1, 1, 12);
    SfxService.nowProvider = () => clock;
    SfxService.onPlayForTest = played.add;
  });

  tearDown(() => SfxService.instance.resetForTest());

  group('SfxService interaction tier', () {
    test('tap rotates the 3 variants and wraps', () async {
      for (var i = 0; i < 4; i++) {
        await SfxService.instance.playUiTap();
        advance(const Duration(milliseconds: 100));
      }
      expect(played, [
        'audio/ui_tap_1.wav',
        'audio/ui_tap_2.wav',
        'audio/ui_tap_3.wav',
        'audio/ui_tap_1.wav',
      ]);
    });

    test('tap coalesces repeats inside the 60ms window', () async {
      await SfxService.instance.playUiTap();
      advance(const Duration(milliseconds: 30));
      await SfxService.instance.playUiTap(); // dropped
      advance(const Duration(milliseconds: 61));
      await SfxService.instance.playUiTap(); // allowed
      expect(played.length, 2);
    });

    test('set-logged rotates variants behind a 1s burst cooldown', () async {
      await SfxService.instance.playSetLogged();
      advance(const Duration(milliseconds: 500));
      await SfxService.instance.playSetLogged(); // dropped (burst)
      advance(const Duration(milliseconds: 1000));
      await SfxService.instance.playSetLogged(); // allowed → variant 2
      expect(played, ['audio/set_logged_1.wav', 'audio/set_logged_2.wav']);
    });

    test('the UI-sounds sub-toggle silences taps but not core-loop sounds',
        () async {
      SfxService.uiSoundsEnabled = false;
      await SfxService.instance.playUiTap();
      await SfxService.instance.playSetLogged();
      await SfxService.instance.playUiWarn();
      await SfxService.instance.playRestGo();
      expect(played, [
        'audio/set_logged_1.wav',
        'audio/ui_warn.wav',
        'audio/rest_go.wav',
      ]);
    });

    test('the master Sound toggle silences everything', () async {
      SfxService.enabled = false;
      await SfxService.instance.playUiTap();
      await SfxService.instance.playSetLogged();
      await SfxService.instance.playUiWarn();
      await SfxService.instance.playRestGo();
      expect(played, isEmpty);
    });

    test('playback failure fails open — no throw, later calls still gate-count',
        () async {
      // No audio plugin in the test env: the pool create/play fails and the
      // asset degrades to silence, but nothing escapes to the caller.
      await SfxService.instance.playUiWarn();
      await SfxService.instance.playUiWarn();
      expect(played, ['audio/ui_warn.wav', 'audio/ui_warn.wav']);
    });
  });

  group('UiSoundSettingsService', () {
    test('defaults on, persists a flip', () async {
      expect(await UiSoundSettingsService().isEnabled(), isTrue);
      await UiSoundSettingsService().setEnabled(false);
      expect(await UiSoundSettingsService().isEnabled(), isFalse);
    });
  });

  group('PixelButton intent→sound seam', () {
    Future<void> pumpButton(
      WidgetTester tester, {
      HapticIntent haptic = HapticIntent.tap,
      bool sound = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PixelButton(
              label: 'GO',
              haptic: haptic,
              sound: sound,
              onPressed: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('GO'));
      await tester.pump();
    }

    testWidgets('tap intent plays the keycap tick', (tester) async {
      await pumpButton(tester);
      expect(played, ['audio/ui_tap_1.wav']);
    });

    testWidgets('warning intent plays the destructive buzz', (tester) async {
      await pumpButton(tester, haptic: HapticIntent.warning);
      expect(played, ['audio/ui_warn.wav']);
    });

    testWidgets('success/none intents stay silent (their moments own audio)',
        (tester) async {
      await pumpButton(tester, haptic: HapticIntent.success);
      expect(played, isEmpty);
      await pumpButton(tester, haptic: HapticIntent.none);
      expect(played, isEmpty);
    });

    testWidgets('sound:false opts a handler-owned button out', (tester) async {
      await pumpButton(tester, sound: false);
      expect(played, isEmpty);
    });
  });

  group('set-logged core-loop beat', () {
    testWidgets('logging a set plays exactly one set_logged variant',
        (tester) async {
      RestTimerService.instance.cancel();
      ExerciseKindCache.instance.resetForTest();
      addTearDown(RestTimerService.instance.cancel);
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseSessionPage(
            exercise: Exercise(
              id: 'a',
              name: 'a',
              level: 'beginner',
              images: const [],
              equipment: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '100');
      await tester.enterText(find.byType(TextField).at(1), '5');
      await tester.tap(find.widgetWithText(FilledButton, 'SAVE'));
      await tester.pump();

      expect(
        played.where((a) => a.startsWith('audio/set_logged_')).length,
        1,
      );
    });
  });
}
