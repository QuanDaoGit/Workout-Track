import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/root_page.dart';
import 'package:workout_track/services/feature_gate_service.dart';
import 'package:workout_track/widgets/train_nav_button.dart';

/// Shell contract: the 4-places + center-Train bar, the Train button's mode
/// states (idle / armed / live) with accessible labels, and the cold Train tap
/// opening the in-shell selection surface (no front confirm — the single confirm
/// now lives at the commit).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
    home: reduceMotion
        ? MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(body: Center(child: child)),
          )
        : Scaffold(body: Center(child: child)),
  );

  Finder semanticsLabel(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  );

  group('TrainNavButton modes', () {
    testWidgets('live shows the mm:ss timer, not the sword', (tester) async {
      await tester.pumpWidget(
        host(
          TrainNavButton(
            mode: TrainButtonMode.live,
            elapsedLabel: '12:34',
            onTap: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('12:34'), findsOneWidget);
      expect(find.byType(ImageIcon), findsNothing);
      expect(semanticsLabel('Resume workout'), findsOneWidget);
    });

    testWidgets('idle shows the sword + "Start training" label, settles', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          TrainNavButton(mode: TrainButtonMode.idle, onTap: () {}),
          reduceMotion: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImageIcon), findsOneWidget);
      expect(semanticsLabel('Start training'), findsOneWidget);
    });

    testWidgets('armedReady carries the start-selected label', (tester) async {
      await tester.pumpWidget(
        host(TrainNavButton(mode: TrainButtonMode.armedReady, onTap: () {})),
      );
      await tester.pump();
      expect(semanticsLabel('Start selected workout'), findsOneWidget);
    });

    testWidgets('armedLocked carries the pick-one label, settles', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          TrainNavButton(mode: TrainButtonMode.armedLocked, onTap: () {}),
          reduceMotion: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        semanticsLabel('Pick at least one exercise to start'),
        findsOneWidget,
      );
    });
  });

  group('RootPage shell', () {
    Future<void> pumpShell(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        await tester.pumpWidget(const MaterialApp(home: RootPage()));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
    }

    testWidgets('renders the four destinations + center Train', (tester) async {
      await pumpShell(tester);
      expect(find.text('Items'), findsOneWidget);
      expect(find.text('Guild'), findsWidgets);
      expect(find.text('Labs'), findsWidgets);
      expect(find.text('TRAIN'), findsOneWidget);
    });

    testWidgets('cold Train tap opens in-shell selection, nav stays visible', (
      tester,
    ) async {
      await pumpShell(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('TRAIN'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      // Selection surface is now in-shell (header), and the nav (TRAIN) persists.
      expect(find.text('SELECT WORKOUT'), findsOneWidget);
      expect(find.text('TRAIN'), findsOneWidget);
    });
  });

  group('RootPage earned gates (fresh user, everything locked)', () {
    // The static gate snapshot leaks across tests in one isolate — always
    // reset (widget-test prefs-isolation learning).
    tearDown(FeatureGateService.resetForTest);

    Future<void> pumpLockedShell(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      FeatureGateService.resetForTest();
      // A loaded EMPTY snapshot = a genuinely fresh user: all gates locked.
      await FeatureGateService().load();
      await tester.runAsync(() async {
        await tester.pumpWidget(const MaterialApp(home: RootPage()));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
    }

    testWidgets('locked Guild tab: no tab switch, invitation notice instead', (
      tester,
    ) async {
      await pumpLockedShell(tester);
      await tester.tap(find.text('Guild').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('Complete 3 workouts to found your guild'),
        findsOneWidget,
        reason: 'the locked tap shows the invitation notice',
      );
      // The destination IndexedStack (4 tabs) must still sit on Home (0).
      final destinationStack = tester
          .widgetList<IndexedStack>(find.byType(IndexedStack))
          .firstWhere((s) => s.children.length == 4);
      expect(destinationStack.index, 0,
          reason: 'the guild page must not become the active destination');
    });

    testWidgets('locked tabs announce their unlock condition', (tester) async {
      await pumpLockedShell(tester);
      expect(
        find.bySemanticsLabel(
          RegExp('Guild — locked. Complete 3 workouts'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp('Items — locked. Earn your first item'),
        ),
        findsOneWidget,
      );
    });

    // NOTE: "an unloaded snapshot fails toward unlocked" is a service-level
    // contract (covered in feature_gate_service_test) — the shell evaluates
    // gates in its first postFrame, so a fresh user correctly shows locks
    // moments after mount; there is no shell state where the snapshot stays
    // unloaded.
  });
}
