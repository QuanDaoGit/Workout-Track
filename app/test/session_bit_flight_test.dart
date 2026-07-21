import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/session_bit_flight.dart';

/// Isolated contract tests for the rest-end flight overlay: begin() refuses
/// invalid seal targets (the host keeps the celebration pending), an accepted
/// flight stamps exactly once at the seal beat then lands, and settleNow
/// before the seal cancels the stamp (gen-token safety). Spec:
/// docs/superpowers/specs/2026-07-21-rest-end-bit-flight-design.md
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GlobalKey<SessionBitFlightState> flight;
  late GlobalKey card;
  late GlobalKey slot;
  late int stamps;
  late int dones;

  Widget host() {
    flight = GlobalKey<SessionBitFlightState>();
    card = GlobalKey();
    slot = GlobalKey();
    stamps = 0;
    dones = 0;
    return MaterialApp(
      home: Scaffold(
        body: SessionBitFlight(
          key: flight,
          onStamp: () => stamps++,
          onDone: () => dones++,
          child: Column(
            children: [
              const SizedBox(height: 120),
              SizedBox(key: card, height: 70, width: 300),
              const SizedBox(height: 8),
              Row(
                children: [SizedBox(key: slot, width: 44, height: 44)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool begin({GlobalKey? cardKey, FlightProfile profile = FlightProfile.natural}) {
    return flight.currentState!.begin(
      originGlobal: const Rect.fromLTWH(140, 400, 96, 96),
      finishedCardKey: cardKey ?? card,
      frontierSlotKey: slot,
      profile: profile,
    );
  }

  testWidgets('begin refuses an unmounted seal target', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    final orphan = GlobalKey(); // never mounted
    expect(begin(cardKey: orphan), isFalse);
    expect(flight.currentState!.active, isFalse);
    expect(find.byKey(const ValueKey('flight_bit')), findsNothing);
  });

  testWidgets('accepted flight: one stamp at the seal, one done at landing', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();
    expect(begin(), isTrue);
    await tester.pump();
    expect(find.byKey(const ValueKey('flight_bit')), findsOneWidget);
    // Mid-flight (before the seal at 470ms): no stamp yet.
    await tester.pump(const Duration(milliseconds: 300));
    expect(stamps, 0);
    // Past the seal beat.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(stamps, 1);
    expect(dones, 0);
    // Landing.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(stamps, 1);
    expect(dones, 1);
    expect(flight.currentState!.active, isFalse);
    expect(find.byKey(const ValueKey('flight_bit')), findsNothing);
  });

  testWidgets('settleNow before the seal cancels the stamp, one done', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();
    expect(begin(profile: FlightProfile.skip), isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    flight.currentState!.settleNow();
    await tester.pump();
    expect(find.byKey(const ValueKey('flight_bit')), findsNothing);
    expect(dones, 1);
    // No resurrection: the stamp never fires for the settled flight.
    await tester.pump(const Duration(milliseconds: 800));
    expect(stamps, 0);
    expect(dones, 1);
  });
}
