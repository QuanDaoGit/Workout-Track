import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/adventure_models.dart';
import 'package:workout_track/pages/adventure_page.dart';
import 'package:workout_track/services/adventure_service.dart';
import 'package:workout_track/utils/iso_week.dart';
import 'package:workout_track/widgets/adventure/route_diorama.dart';
import 'package:workout_track/widgets/pixel_loader.dart';

/// v3 stage-select widget contract: per-state rendering, the single-animation
/// owner invariant (Codex plan #2), GO gating, cancel-from-armed, and the
/// reduced-motion path. The pure out→returned transition is unit-tested in
/// adventure_phase_test.dart (the page consumes that same predicate).
void main() {
  Expedition exp({required String returnsAtIso}) => Expedition(
    id: 'e1',
    routeId: 'iron_vault',
    day: '2026-06-12',
    rank: 'D',
    payout: 8,
    flavorIdx: 0,
    dispatchedAtIso: DateTime.now().toIso8601String(),
    returnsAtIso: returnsAtIso,
    durationMinutes: 300,
    multiplier: 1.2,
    vitAtDispatch: 50,
  );

  // Write through the live SharedPreferences instance (not just
  // setMockInitialValues) — once getInstance() is cached in the isolate, a
  // later setMockInitialValues won't refresh it, so seeded state would leak
  // from the previous test. setString updates the live cache.
  Future<void> seed(AdventureState state) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'combat_stats',
      '{"STR":10,"AGI":10,"END":10,"VIT":50,"LCK":0}',
    );
    await prefs.setString('workout_sessions', '[]');
    await prefs.setString(AdventureService.stateKey, jsonEncode(state.toJson()));
  }

  Future<void> pumpPage(WidgetTester tester, {bool reduceMotion = false}) async {
    final app = MaterialApp(
      home: reduceMotion
          ? const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: AdventurePage(),
            )
          : const AdventurePage(),
    );
    // initState's _load awaits SharedPreferences, which only resolves in
    // real-async — so pump the widget INSIDE runAsync and let those futures
    // settle, then a plain pump reflects the loaded state.
    await tester.runAsync(() async {
      await tester.pumpWidget(app);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump();
    expect(find.byType(PixelLoader), findsNothing);
  }

  int animatingDioramas(WidgetTester tester) => tester
      .widgetList<RouteDiorama>(find.byType(RouteDiorama))
      .where((d) => d.animate)
      .length;

  testWidgets('idle 0-charge: inspect-only, no animation, no GO bar', (
    tester,
  ) async {
    await seed(AdventureState(charges: 0));
    await pumpPage(tester);

    expect(find.textContaining('Do a workout'), findsWidgets);
    expect(find.byType(RouteDiorama), findsNWidgets(3));
    expect(animatingDioramas(tester), 0);
    expect(find.textContaining('GO ON ADVENTURE'), findsNothing);
  });

  testWidgets('arming a route animates exactly one tile + shows GO; cancel '
      'clears it', (tester) async {
    await seed(AdventureState(charges: 2));
    await pumpPage(tester);
    expect(animatingDioramas(tester), 0);

    await tester.tap(find.text('IRON VAULT'));
    await tester.pump();
    expect(find.textContaining('GO ON ADVENTURE'), findsOneWidget);
    expect(animatingDioramas(tester), 1); // single animation owner

    // Re-tap the armed tile → cancel.
    await tester.tap(find.text('IRON VAULT'));
    await tester.pump();
    expect(find.textContaining('GO ON ADVENTURE'), findsNothing);
    expect(animatingDioramas(tester), 0);
  });

  testWidgets('weekly-capped: armed shows GO disabled with a reason', (
    tester,
  ) async {
    await seed(
      AdventureState(
        charges: 1,
        weekIso: isoWeekKey(DateTime.now()),
        weekCount: 5,
      ),
    );
    await pumpPage(tester);

    await tester.tap(find.text('IRON VAULT'));
    await tester.pump();
    expect(find.textContaining('GO ON ADVENTURE'), findsOneWidget);
    final go = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'GO ON ADVENTURE · IRON VAULT'),
    );
    expect(go.onPressed, isNull); // disabled
    expect(find.text('Weekly limit reached.'), findsOneWidget);
  });

  testWidgets('out: active tile animates, shows countdown, no GO bar', (
    tester,
  ) async {
    await seed(
      AdventureState(
        pending: exp(
          returnsAtIso: DateTime.now()
              .add(const Duration(hours: 5))
              .toIso8601String(),
        ),
      ),
    );
    await pumpPage(tester);

    expect(find.textContaining('BACK IN'), findsOneWidget);
    expect(animatingDioramas(tester), 1); // only the active route
    expect(find.textContaining('GO ON ADVENTURE'), findsNothing);
  });

  testWidgets('returned: COLLECT shown, nothing animates', (tester) async {
    await seed(
      AdventureState(
        pending: exp(
          returnsAtIso: DateTime.now()
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
        ),
      ),
    );
    await pumpPage(tester);

    expect(find.text('RETURNED'), findsOneWidget);
    expect(find.text('COLLECT'), findsOneWidget);
    expect(animatingDioramas(tester), 0);
  });

  testWidgets('reduced motion + out: static "BACK IN ~Xh", no crash', (
    tester,
  ) async {
    await seed(
      AdventureState(
        pending: exp(
          returnsAtIso: DateTime.now()
              .add(const Duration(hours: 5))
              .toIso8601String(),
        ),
      ),
    );
    await pumpPage(tester, reduceMotion: true);

    expect(find.textContaining('BACK IN ~'), findsOneWidget);
    // Under reduced motion the diorama controllers are stopped; the tree is
    // settle-able (no perpetual ticker).
    await tester.pumpAndSettle();
  });
}
