import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/companion/bit_companion.dart';
import 'package:workout_track/widgets/companion/bit_core_engine.dart'
    show BitMood;

/// Behavioral contract for the companion BIT: it announces itself, is a generous
/// tap target, reacts to a tap, and stays a still, legible (still-announced)
/// control under reduced motion.
void main() {
  Widget host(
    BitMood mood, {
    bool reduce = false,
    int cheerTick = 0,
    bool armed = true,
    ValueChanged<bool>? onRestEasterEgg,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Scaffold(
        body: Center(
          child: BitCompanion(
            mood: mood,
            size: 92,
            cheerTick: cheerTick,
            spamRestArmed: armed,
            onRestEasterEgg: onRestEasterEgg,
          ),
        ),
      ),
    ),
  );

  testWidgets('announces itself via Semantics', (tester) async {
    await tester.pumpWidget(host(BitMood.neutral));
    await tester.pump();
    expect(find.bySemanticsLabel('BIT, your companion'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // dispose the idle ticker
  });

  testWidgets('tap target is at least 44px', (tester) async {
    await tester.pumpWidget(host(BitMood.neutral));
    await tester.pump();
    final size = tester.getSize(find.byType(BitCompanion));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tap is accepted and reacts without error', (tester) async {
    await tester.pumpWidget(host(BitMood.neutral));
    await tester.pump();
    await tester.tap(find.byType(BitCompanion));
    // Advance through the 950ms spin without pumpAndSettle (idle ticker is
    // perpetual); the widget must keep rendering throughout.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(BitCompanion), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion freezes to a still, still-announced frame', (
    tester,
  ) async {
    await tester.pumpWidget(host(BitMood.neutral, reduce: true));
    // With motion off there is no perpetual ticker, so the tree settles.
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('BIT, your companion'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cheerTick fires the spin programmatically (COLLECT cheer)', (
    tester,
  ) async {
    await tester.pumpWidget(host(BitMood.neutral, cheerTick: 0));
    await tester.pump();
    await tester.pumpWidget(host(BitMood.neutral, cheerTick: 1)); // bump
    // The orbit runs without a user tap; the widget keeps rendering throughout.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(BitCompanion), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cheerTick under reduced motion is a no-op (no flicker)', (
    tester,
  ) async {
    await tester.pumpWidget(host(BitMood.neutral, reduce: true, cheerTick: 0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(BitMood.neutral, reduce: true, cheerTick: 1));
    // No controller spins up → the tree still settles (no perpetual ticker).
    await tester.pumpAndSettle();
    expect(find.byType(BitCompanion), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // ── Spam-tap easter egg ────────────────────────────────────────────────────
  // Five rapid taps tire BIT to REST; he reports the episode so the host can
  // swap his bubble to the sigh, holds ~3s, then recovers. Reduced motion makes
  // the slump instant + the 3s hold deterministic under the fake clock.

  testWidgets('five rapid taps tire BIT to rest, then he recovers', (
    tester,
  ) async {
    final events = <bool>[];
    await tester.pumpWidget(
      host(BitMood.neutral, reduce: true, onRestEasterEgg: events.add),
    );
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byType(BitCompanion));
      await tester.pump();
    }
    expect(events, [true]); // entered rest exactly once on the 5th tap
    // Holds, then perks back up after the 3s recovery window.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(events, [true, false]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('four rapid taps do NOT tire BIT (no rest)', (tester) async {
    final events = <bool>[];
    await tester.pumpWidget(
      host(BitMood.neutral, reduce: true, onRestEasterEgg: events.add),
    );
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byType(BitCompanion));
      await tester.pump();
    }
    expect(events, isEmpty);
    // Flush the reduced-motion cheer-flash timers each tap scheduled.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disarmed: spamming never rests BIT', (tester) async {
    final events = <bool>[];
    await tester.pumpWidget(
      host(
        BitMood.neutral,
        reduce: true,
        armed: false,
        onRestEasterEgg: events.add,
      ),
    );
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byType(BitCompanion));
      await tester.pump();
    }
    expect(events, isEmpty);
    // Flush the reduced-motion cheer-flash timers each tap scheduled.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
  });
}
