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

  testWidgets('successful GO pops the map back to the root route', (
    tester,
  ) async {
    await seed(AdventureState(charges: 1));
    // Push the map over a base route: the dispatch payoff is the home room's
    // launch send-off, so GO must collapse back to the shell no matter the
    // stacking (popUntil-to-root, the summary's return idiom).
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdventurePage()),
                  ),
                  child: const Text('OPEN MAP'),
                ),
              ),
            ),
          ),
        ),
      );
    });
    await tester.tap(find.text('OPEN MAP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350)); // push transition
    expect(find.byType(AdventurePage), findsOneWidget);
    // _load is real-async prefs work — poll (bounded) until the stage loads.
    for (
      var i = 0;
      i < 30 && find.byType(PixelLoader).evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(PixelLoader), findsNothing);

    await tester.tap(find.text('IRON VAULT'));
    await tester.pump();
    await tester.tap(find.textContaining('GO ON ADVENTURE'));
    // The dispatch is real-async prefs work — poll (bounded) until the pop
    // lands instead of guessing one fixed delay.
    for (
      var i = 0;
      i < 30 && find.byType(AdventurePage).evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 350)); // pop transition
    expect(
      find.byType(AdventurePage),
      findsNothing,
      reason: 'a successful dispatch returns to the shell for the send-off',
    );
    expect(find.text('OPEN MAP'), findsOneWidget);
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
