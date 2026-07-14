import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/feature_gate_service.dart';
import 'package:workout_track/widgets/unlock_ceremony.dart';

Widget _host(
  Widget child, {
  bool reduceMotion = false,
  Size size = const Size(400, 800),
}) {
  // Deliberately NO Scaffold/Material: production mounts the ceremony on a
  // bare transparent PageRouteBuilder, so the widget's own Material wrapper
  // must be the only one — a regression re-paints the yellow no-Material
  // underline in the goldens (caught on-device 2026-07-14).
  return MediaQuery(
    data: MediaQueryData(size: size, disableAnimations: reduceMotion),
    child: MaterialApp(home: SizedBox.expand(child: child)),
  );
}

void main() {
  group('FeatureUnlockCeremony', () {
    testWidgets('reduced motion renders the settled card with live actions',
        (tester) async {
      FeatureGate? went;
      await tester.pumpWidget(
        _host(
          reduceMotion: true,
          FeatureUnlockCeremony(
            gates: const [FeatureGate.guild],
            onGo: (g) => went = g,
            onDismiss: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('GUILD'), findsOneWidget);
      expect(find.text('OPEN GUILD'), findsOneWidget);
      expect(find.text('LATER'), findsOneWidget);
      expect(find.text('TAP TO SKIP'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('New system online: GUILD')),
        findsOneWidget,
      );
      await tester.tap(find.text('OPEN GUILD'));
      await tester.pump();
      expect(went, FeatureGate.guild);
    });

    testWidgets('cinematic settles on its own and enables the buttons',
        (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        _host(
          FeatureUnlockCeremony(
            gates: const [FeatureGate.shop],
            onGo: (_) {},
            onDismiss: () => dismissed++,
          ),
        ),
      );
      // Mid-cinematic: actions are not yet interactive.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('LATER'), warnIfMissed: false);
      await tester.pump();
      expect(dismissed, 0, reason: 'pre-settle taps must be ignored');
      // Past the settle threshold (+ spark drain), the card is live.
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('LATER'));
      await tester.pump();
      expect(dismissed, 1);
    });

    testWidgets('tap-to-skip jumps straight to the settled card',
        (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        _host(
          FeatureUnlockCeremony(
            gates: const [FeatureGate.quests],
            onGo: (_) {},
            onDismiss: () => dismissed++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('unlock_ceremony_skip')));
      await tester.pump();
      expect(find.text('TAP TO SKIP'), findsNothing);
      await tester.tap(find.text('LATER'));
      await tester.pump();
      expect(dismissed, 1);
    });

    testWidgets('an action fires exactly once (double-tap guard)',
        (tester) async {
      var went = 0;
      var dismissed = 0;
      await tester.pumpWidget(
        _host(
          reduceMotion: true,
          FeatureUnlockCeremony(
            gates: const [FeatureGate.adventure],
            onGo: (_) => went++,
            onDismiss: () => dismissed++,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('OPEN EXPEDITIONS'));
      await tester.tap(find.text('LATER'));
      await tester.pump();
      expect(went, 1);
      expect(dismissed, 0, reason: 'the first action wins; no double-settle');
    });

    testWidgets('coalesced catch-up lists every gate under one CONTINUE',
        (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        _host(
          reduceMotion: true,
          FeatureUnlockCeremony(
            gates: const [FeatureGate.quests, FeatureGate.shop],
            onGo: (_) {},
            onDismiss: () => dismissed++,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('QUESTS'), findsOneWidget);
      expect(find.text('SHOP'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.textContaining('OPEN'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('New systems online: QUESTS, SHOP')),
        findsOneWidget,
      );
      await tester.tap(find.text('CONTINUE'));
      await tester.pump();
      expect(dismissed, 1);
    });

    testWidgets('golden: settled single-gate card', (tester) async {
      await tester.pumpWidget(
        _host(
          reduceMotion: true,
          FeatureUnlockCeremony(
            gates: const [FeatureGate.guild],
            onGo: (_) {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(FeatureUnlockCeremony),
        matchesGoldenFile('goldens/unlock_ceremony_single.png'),
      );
    });

    testWidgets('golden: coalesced catch-up card', (tester) async {
      await tester.pumpWidget(
        _host(
          reduceMotion: true,
          FeatureUnlockCeremony(
            gates: const [
              FeatureGate.quests,
              FeatureGate.shop,
              FeatureGate.guild,
            ],
            onGo: (_) {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(FeatureUnlockCeremony),
        matchesGoldenFile('goldens/unlock_ceremony_coalesced.png'),
      );
    });
  });
}
