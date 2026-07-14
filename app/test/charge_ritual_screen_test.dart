import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/charge_ritual_screen.dart';
import 'package:workout_track/pages/onboarding/start_gate_screen.dart';
import 'package:workout_track/services/sfx_service.dart';
import 'package:workout_track/widgets/companion/bit_mood_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SfxService.enabled = false; // no real audio in tests; the hook still records
  });
  tearDown(() {
    SfxService.enabled = true;
    SfxService.debugOnPlay = null;
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

  Future<void> pumpRitual(WidgetTester tester, {required bool reduced}) {
    return tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: child!,
        ),
        home: ChargeRitualScreen(character: character()),
      ),
    );
  }

  // Drive the engine in small frames — the engine clamps dt to 64ms, so a single
  // long pump would only advance one clamped step.
  Future<void> advance(WidgetTester tester, int ms, {int step = 32}) async {
    for (var t = 0; t < ms; t += step) {
      await tester.pump(Duration(milliseconds: step));
    }
  }

  testWidgets(
    'reduced motion lands on the accessible hold/tap state and a tap ignites to '
    'the gate (name carried through)',
    (tester) async {
      await pumpRitual(tester, reduced: true);
      await tester.pump();

      // No animated reel — the still hold state with the tap CTA + HOLD prompt.
      expect(find.text('CHARGING'), findsOneWidget);
      expect(find.text('HOLD TO CHARGE UP'), findsWidgets); // keycap + prompt
      expect(find.textContaining('BIT pours it'), findsOneWidget);

      // The always-available tap path completes the charge.
      await tester.tap(find.textContaining('BIT pours it'));
      await advance(tester, 3300); // > autoFillMs (3000)
      await tester.pump(const Duration(milliseconds: 300)); // route (fade)
      await tester.pump();

      expect(find.byType(ChargeRitualScreen), findsNothing);
      expect(find.byType(StartGateScreen), findsOneWidget);
      expect(find.text('Nova'), findsOneWidget);
    },
  );

  testWidgets('skip is delayed (~3s) then routes to the gate', (tester) async {
    // Reduced so the Start Gate settles instantly (no pending reveal Timers);
    // the delayed-skip gate reads wall-clock elapsed, independent of motion.
    await pumpRitual(tester, reduced: true);
    await tester.pump();

    // Hidden immediately.
    expect(find.textContaining('continue without charging'), findsNothing);

    // A single long pump advances wall-clock (the skip gate reads raw elapsed).
    await tester.pump(const Duration(milliseconds: 3200));
    expect(find.textContaining('continue without charging'), findsOneWidget);

    await tester.tap(find.textContaining('continue without charging'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // route (flow)
    await tester.pump();

    expect(find.byType(StartGateScreen), findsOneWidget);
  });

  testWidgets(
    'post-reel BIT dialogue advances thank-you → boost cue and BIT cheers',
    (tester) async {
      // Reduced motion opens straight at the hold gate (no reel), so the
      // clock-driven hold sub-sequence runs on _elapsedMs alone.
      await pumpRitual(tester, reduced: true);
      await tester.pump();

      // First: the thank-you line, and BIT stays attentive (neutral).
      expect(find.textContaining('thank you for the message'), findsOneWidget);
      expect(find.textContaining('start strong'), findsNothing);
      expect(
        tester.widget<BitMoodCore>(find.byType(BitMoodCore)).pose,
        BitPose.neutral,
      );

      // After the dwell (> _kHoldThankYouMs) it advances to the boost cue and
      // BIT cheers. ("boost" itself is the amber+shaky bracketed run.)
      await advance(tester, 3900);
      expect(find.textContaining('thank you for the message'), findsNothing);
      expect(find.textContaining('start strong'), findsOneWidget);
      expect(find.textContaining('alright warrior'), findsOneWidget);
      expect(
        tester.widget<BitMoodCore>(find.byType(BitMoodCore)).pose,
        BitPose.cheer,
      );
    },
  );

  testWidgets('tapping the BIT area skips the thank-you read dwell to the boost cue', (
    tester,
  ) async {
    await pumpRitual(tester, reduced: true);
    await tester.pump();
    expect(find.textContaining('thank you for the message'), findsOneWidget);

    // Tap the BIT zone WELL before the ~3.8s dwell → jump straight to boost.
    await tester.tap(find.textContaining('thank you for the message'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('thank you for the message'), findsNothing);
    expect(find.textContaining('start strong'), findsOneWidget);
  });

  testWidgets('boost SFX fire on pour-start / release / ignition edges', (
    tester,
  ) async {
    final sfx = <String>[];
    SfxService.debugOnPlay = sfx.add; // records regardless of `enabled`

    await pumpRitual(tester, reduced: true);
    await tester.pump();

    // Pour-start (early hold) → the charge riser.
    final g = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO CHARGE UP').last),
    );
    await advance(tester, 300);
    expect(sfx, contains('audio/boost_charge.wav'));

    // Release before 100% → the power-down blip, NOT the ignite.
    await g.up();
    await advance(tester, 900);
    expect(sfx, contains('audio/boost_release.wav'));
    expect(sfx, isNot(contains('audio/boost_ignite.wav')));

    // Auto-fill to 100% → the ignition cue.
    await tester.tap(find.textContaining('BIT pours it'));
    await advance(tester, 3300);
    expect(sfx, contains('audio/boost_ignite.wav'));
  });

  testWidgets(
    'early pour that releases back to hold keeps the boost cue (no thank-you replay)',
    (tester) async {
      await pumpRitual(tester, reduced: true);
      await tester.pump();

      // Opens on the thank-you line, well before the ~2.2s dwell.
      expect(find.textContaining('thank you for the message'), findsOneWidget);

      // Press-and-hold the keycap EARLY (< dwell) → pouring → [BOOSTING]. The
      // keycap's label is the last 'HOLD TO CHARGE UP' in the tree (the monitor
      // prompt is the earlier one); its center sits inside the keycap Listener.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('HOLD TO CHARGE UP').last),
      );
      await advance(tester, 300); // < fillMs(1400) → no ignite; < dwell(2200)
      expect(find.textContaining('BOOSTING'), findsOneWidget);

      // Release early → charge drains back to 0.9 → phase returns to hold,
      // still well under the 2.2s dwell.
      await gesture.up();
      await advance(tester, 800);

      // Regression (Codex): the latch must keep the boost cue + cheer — it must
      // NOT regress to the thank-you dwell just because holdElapsed < dwell.
      expect(find.textContaining('thank you for the message'), findsNothing);
      expect(find.textContaining('start strong'), findsOneWidget);
      expect(
        tester.widget<BitMoodCore>(find.byType(BitMoodCore)).pose,
        BitPose.cheer,
      );
    },
  );

  testWidgets('builds under full motion — video falls back to poster, no crash', (
    tester,
  ) async {
    await pumpRitual(tester, reduced: false);
    await tester.pump();
    await advance(tester, 500); // video init fails in test -> poster + watchdog

    expect(find.byType(ChargeRitualScreen), findsOneWidget);
    expect(find.text('CHARGING'), findsOneWidget);
    // Still early — the skip stays hidden.
    expect(find.textContaining('continue without charging'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
