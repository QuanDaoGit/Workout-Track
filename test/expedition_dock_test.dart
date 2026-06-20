import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/bit_room_copy.dart';
import 'package:workout_track/models/adventure_models.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/companion/bit_companion.dart';
import 'package:workout_track/widgets/room/coffer.dart';
import 'package:workout_track/widgets/room/pad_charge_meter.dart';
import 'package:workout_track/widgets/room/room_scene.dart';

final cofferFinder = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is CofferPainter,
);

/// The pad charge meter; pass [armed] to assert the dispatch-possible glow state.
Finder meterFinder({bool? armed}) => find.byWidgetPredicate(
  (w) =>
      w is CustomPaint &&
      w.painter is PadChargeMeterPainter &&
      (armed == null || (w.painter as PadChargeMeterPainter).armed == armed),
);

/// The home-room pad's Expedition-dock state machine: the right signifier,
/// Semantics, BIT presence, and tap routing per phase — plus the reduced-motion
/// guarantee that an idle→out flip lands on the static `out` dock with no launch
/// (a frozen controller can't strand the dock or hang a settle).
void main() {
  Future<void> pumpDock(
    WidgetTester tester,
    RoomAdventureView? adv, {
    VoidCallback? onDispatchTap,
    VoidCallback? onStatusTap,
    VoidCallback? onCollect,
    bool reduceMotion = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: SizedBox(
                width: 390,
                child: HomeRoomScene(
                  height: 700,
                  name: 'VALEN',
                  level: 7,
                  title: 'KNIGHT',
                  adventure: adv,
                  onDispatchTap: onDispatchTap,
                  onStatusTap: onStatusTap,
                  onCollect: onCollect,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  RoomAdventureView view({
    required AdventurePhase phase,
    int charges = 0,
    bool canDispatch = false,
    bool haulReady = false,
    bool greeted = false,
    String? routeName,
    Color? routeAccent,
    int? backInHours,
  }) => RoomAdventureView(
    phase: phase,
    charges: charges,
    canDispatch: canDispatch,
    haulReady: haulReady,
    routeName: routeName,
    routeAccent: routeAccent,
    backInHours: backInHours,
    voice: BitRoomVoice.select(
      phase: phase,
      haulReady: haulReady,
      greeted: greeted,
      adviceIndex: 0,
      routeName: routeName,
      backInHours: backInHours,
    ),
  );

  final idleReady = view(phase: AdventurePhase.idle, charges: 2, canDispatch: true);
  final idleNoCharge =
      view(phase: AdventurePhase.idle, charges: 0, canDispatch: false);
  // out, first hologram appearance → BIT greets "I'm back"; once greeted, the
  // away status takes over.
  final outGreeting = view(
    phase: AdventurePhase.out,
    routeName: 'SKY TRACER',
    routeAccent: kCyan,
    backInHours: 5,
  );
  final outScouting = view(
    phase: AdventurePhase.out,
    greeted: true,
    routeName: 'SKY TRACER',
    routeAccent: kCyan,
    backInHours: 5,
  );
  final returnedView = view(
    phase: AdventurePhase.returned,
    haulReady: true,
    routeName: 'SKY TRACER',
    routeAccent: kCyan,
  );
  // The settled-on-open shape Home actually passes: pending is cleared (phase
  // idle) but an unviewed haul sits → coffer, dispatch blocked.
  final idleHaulReady = view(
    phase: AdventurePhase.idle,
    charges: 2,
    haulReady: true,
    routeName: 'SKY TRACER',
    routeAccent: kCyan,
  );

  testWidgets('idle + a charge: pad meter is ARMED and BIT is home', (
    t,
  ) async {
    await pumpDock(t, idleReady);
    expect(meterFinder(armed: true), findsOneWidget); // lit + armed glow
    expect(find.byType(BitCompanion), findsOneWidget); // BIT home
    expect(
      find.bySemanticsLabel('Expedition dock. Dispatch BIT.'),
      findsOneWidget,
    );
  });

  testWidgets('idle + no charge: meter shows empty (not armed), still tappable', (
    t,
  ) async {
    await pumpDock(t, idleNoCharge);
    expect(meterFinder(armed: false), findsOneWidget); // empty recess, no glow
    expect(
      find.bySemanticsLabel('Expedition dock. Train to earn a charge.'),
      findsOneWidget,
    );
  });

  PadChargeMeterPainter meterPainter(WidgetTester t) =>
      t.widget<CustomPaint>(meterFinder()).painter as PadChargeMeterPainter;

  testWidgets('a banked-charge increase flashes the meter (motion only)', (
    t,
  ) async {
    await pumpDock(t, view(phase: AdventurePhase.idle, charges: 1),
        reduceMotion: false);
    expect(meterPainter(t).pulse, 0); // steady before
    await pumpDock(t, view(phase: AdventurePhase.idle, charges: 2),
        reduceMotion: false); // a workout banked one
    await t.pump(const Duration(milliseconds: 200)); // mid-flash
    expect(meterPainter(t).pulse, greaterThan(0));
    await t.pump(const Duration(milliseconds: 500)); // let the flash finish
  });

  testWidgets('reduced motion: a charge increase does NOT flash', (t) async {
    await pumpDock(t, view(phase: AdventurePhase.idle, charges: 1));
    await pumpDock(t, view(phase: AdventurePhase.idle, charges: 2));
    await t.pump(const Duration(milliseconds: 200));
    expect(meterPainter(t).pulse, 0);
  });

  testWidgets('a dispatch (charge drop) does NOT flash', (t) async {
    await pumpDock(t, view(phase: AdventurePhase.idle, charges: 2),
        reduceMotion: false);
    await pumpDock(t, view(phase: AdventurePhase.idle, charges: 1),
        reduceMotion: false); // spent one
    await t.pump(const Duration(milliseconds: 200));
    expect(meterPainter(t).pulse, 0); // a drop never flashes
  });

  testWidgets('out first appearance: BIT greets "I\'m back"', (t) async {
    await pumpDock(t, outGreeting);
    expect(find.byType(BitCompanion), findsNothing); // BIT is away
    expect(find.text("It's me again"), findsOneWidget);
    expect(find.text('SCOUTING'), findsNothing); // status follows the greeting
  });

  testWidgets('out once greeted: the away status sits in the voice bubble', (
    t,
  ) async {
    await pumpDock(t, outScouting);
    expect(find.byType(BitCompanion), findsNothing); // BIT is away
    expect(find.text('SCOUTING'), findsOneWidget);
    expect(find.text('SKY TRACER'), findsOneWidget);
    expect(find.text('BACK IN ~5H'), findsOneWidget);
    expect(find.text('DISPATCH'), findsNothing); // no false affordance
  });

  testWidgets('haul-ready shows the coffer + the loots prompt with BIT home', (
    t,
  ) async {
    await pumpDock(t, returnedView);
    expect(cofferFinder, findsOneWidget); // the haul on the pad
    // The loots prompt is a tappable speech bubble; its line is a Text.rich with
    // the magenta "loots" run, so assert via the bubble's Semantics label.
    expect(
      find.bySemanticsLabel('Check out the loot. Tap to collect.'),
      findsOneWidget,
    );
    expect(find.byType(BitCompanion), findsOneWidget); // BIT is home
  });

  testWidgets('settled idle + haul shows the coffer, blocks dispatch, collects', (
    t,
  ) async {
    var dispatch = 0, collect = 0;
    await pumpDock(
      t,
      idleHaulReady,
      onDispatchTap: () => dispatch++,
      onCollect: () => collect++,
    );
    expect(cofferFinder, findsOneWidget);
    expect(find.text('DISPATCH'), findsNothing); // dispatch suppressed
    expect(
      find.bySemanticsLabel('BIT has returned. Collect the haul.'),
      findsOneWidget,
    );
    await t.tap(find.bySemanticsLabel('BIT has returned. Collect the haul.'));
    expect([dispatch, collect], [0, 1]); // collects, never dispatches
  });

  testWidgets('tapping the haul coffer itself also claims it (not just the pad)',
      (t) async {
    var collect = 0;
    await pumpDock(t, idleHaulReady, onCollect: () => collect++);
    await t.tap(cofferFinder); // the loot, not the pad
    expect(collect, 1);
  });

  testWidgets('collect dissolve fires onCollect once despite a double-tap', (
    t,
  ) async {
    var collect = 0;
    await pumpDock(
      t,
      returnedView,
      onCollect: () => collect++,
      reduceMotion: false,
    );
    final pad = find.bySemanticsLabel('BIT has returned. Collect the haul.');
    await t.tap(pad);
    await t.pump(const Duration(milliseconds: 60));
    await t.tap(pad); // mid-dissolve — must be ignored (re-entry guard)
    await t.pump(const Duration(milliseconds: 700)); // let the dissolve finish
    expect(collect, 1);
  });

  testWidgets('pad tap routes to the phase-correct callback', (t) async {
    var dispatch = 0, status = 0, collect = 0;

    await pumpDock(
      t,
      idleReady,
      onDispatchTap: () => dispatch++,
      onStatusTap: () => status++,
      onCollect: () => collect++,
    );
    await t.tap(find.bySemanticsLabel('Expedition dock. Dispatch BIT.'));
    expect([dispatch, status, collect], [1, 0, 0]);

    await pumpDock(
      t,
      outScouting,
      onDispatchTap: () => dispatch++,
      onStatusTap: () => status++,
      onCollect: () => collect++,
    );
    await t.tap(find.bySemanticsLabel('BIT is scouting SKY TRACER. Back in about 5 hours.'));
    expect([dispatch, status, collect], [1, 1, 0]);

    await pumpDock(
      t,
      returnedView,
      onDispatchTap: () => dispatch++,
      onStatusTap: () => status++,
      onCollect: () => collect++,
    );
    await t.tap(find.bySemanticsLabel('BIT has returned. Collect the haul.'));
    expect([dispatch, status, collect], [1, 1, 1]);
  });

  testWidgets('reduced motion: idle→out lands on the static out dock, no launch', (
    t,
  ) async {
    await pumpDock(t, idleReady); // BIT home
    expect(find.byType(BitCompanion), findsOneWidget);
    await pumpDock(t, outGreeting); // flip to out under reduced motion
    // No launch overlay runs — BIT is gone immediately, the dock is legible (the
    // greeting shows even under reduced motion: it's tied to phase, not the
    // ignition animation — the Codex RM-safety point).
    expect(find.byType(BitCompanion), findsNothing);
    expect(find.text("It's me again"), findsOneWidget);
  });

  testWidgets('null adventure renders the plain home (no dock affordance)', (
    t,
  ) async {
    await pumpDock(t, null);
    expect(find.byType(BitCompanion), findsOneWidget);
    expect(find.text('DISPATCH'), findsNothing);
    expect(find.text('SCOUTING'), findsNothing);
  });
}
