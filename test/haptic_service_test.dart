import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/services/haptic_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HapticService', () {
    final calls = <MethodCall>[];

    void mockPlatform(Future<Object?>? Function(MethodCall)? handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, handler);
    }

    setUp(() {
      calls.clear();
      HapticService.enabled = true;
      mockPlatform((call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call);
        return null;
      });
    });

    tearDown(() {
      mockPlatform(null);
      HapticService.enabled = true;
    });

    List<Object?> hapticArgs() => calls.map((c) => c.arguments).toList();

    test('semantic methods route to the intended HapticFeedback types', () async {
      await HapticService.instance.selection();
      await HapticService.instance.tap();
      await HapticService.instance.success();
      await HapticService.instance.reward();
      await HapticService.instance.warning();

      expect(hapticArgs(), <Object?>[
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        // reward == medium for now; the single seam for the landmark upgrade.
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });

    test('fire(intent) dispatches to the matching method; none is a no-op', () async {
      await HapticService.instance.fire(HapticIntent.none);
      expect(calls, isEmpty, reason: 'none must send nothing');

      await HapticService.instance.fire(HapticIntent.selection);
      await HapticService.instance.fire(HapticIntent.tap);
      await HapticService.instance.fire(HapticIntent.success);
      await HapticService.instance.fire(HapticIntent.reward);
      await HapticService.instance.fire(HapticIntent.warning);

      expect(hapticArgs(), <Object?>[
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });

    test('disabled mutes every haptic', () async {
      HapticService.enabled = false;
      await HapticService.instance.selection();
      await HapticService.instance.tap();
      await HapticService.instance.success();
      await HapticService.instance.reward();
      await HapticService.instance.warning();
      expect(calls, isEmpty);
    });

    test('a failing platform impl never throws (fail-open)', () async {
      mockPlatform((call) async {
        throw PlatformException(code: 'boom');
      });
      // Must complete normally — a haptic failure is non-essential and is
      // swallowed so it can never break the flow that triggered it.
      await HapticService.instance.success();
    });

    group('fireCoalesced (the broad wrapper layer rate-limit)', () {
      // The singleton carries `_lastCoalescedAt` across tests, so advance the
      // fake clock monotonically (a big step each test) to clear any prior mark.
      var epoch = 0;
      late DateTime fakeNow;
      setUp(() {
        epoch += 1;
        fakeNow = DateTime(2026).add(Duration(minutes: epoch));
        HapticService.nowProvider = () => fakeNow;
        HapticService.coalesceWindow = const Duration(milliseconds: 30);
      });
      tearDown(() {
        HapticService.nowProvider = DateTime.now;
        HapticService.coalesceWindow = const Duration(milliseconds: 30);
      });

      test('a repeat inside the window is dropped', () async {
        await HapticService.instance.fireCoalesced(HapticIntent.selection);
        fakeNow = fakeNow.add(const Duration(milliseconds: 10)); // < 30ms
        await HapticService.instance.fireCoalesced(HapticIntent.selection);
        expect(hapticArgs(), <Object?>['HapticFeedbackType.selectionClick'],
            reason: 'the second tick is coalesced away');
      });

      test('a repeat past the window fires again', () async {
        await HapticService.instance.fireCoalesced(HapticIntent.selection);
        fakeNow = fakeNow.add(const Duration(milliseconds: 40)); // > 30ms
        await HapticService.instance.fireCoalesced(HapticIntent.selection);
        expect(hapticArgs(), <Object?>[
          'HapticFeedbackType.selectionClick',
          'HapticFeedbackType.selectionClick',
        ]);
      });

      test('none is always a no-op and does not start the window', () async {
        await HapticService.instance.fireCoalesced(HapticIntent.none);
        await HapticService.instance.fireCoalesced(HapticIntent.selection);
        expect(hapticArgs(), <Object?>['HapticFeedbackType.selectionClick']);
      });
    });
  });

  group('HapticSettingsService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults on', () async {
      expect(await HapticSettingsService().isEnabled(), isTrue);
    });

    test('persists the user choice', () async {
      await HapticSettingsService().setEnabled(false);
      expect(await HapticSettingsService().isEnabled(), isFalse);
      await HapticSettingsService().setEnabled(true);
      expect(await HapticSettingsService().isEnabled(), isTrue);
    });
  });
}
