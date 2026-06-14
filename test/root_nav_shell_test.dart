import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/root_page.dart';
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
}
