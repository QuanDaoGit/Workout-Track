import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/root_page.dart';
import 'package:workout_track/widgets/start_training_dialog.dart';

/// Base restructure contract: the 4-places + center-Train shell. The confirm
/// gate is unit-pumped on its own; the shell smoke-test asserts the new nav
/// renders and a cold Train tap routes through the confirm (the inactive branch
/// of the Train state machine — Codex #2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('showStartTrainingDialog', () {
    Future<bool?> openDialog(WidgetTester tester) async {
      bool? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async =>
                      captured = await showStartTrainingDialog(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('START TRAINING?'), findsOneWidget);
      return captured;
    }

    testWidgets("LET'S GO confirms", (tester) async {
      await openDialog(tester);
      await tester.tap(find.text("LET'S GO"));
      await tester.pumpAndSettle();
      expect(find.text('START TRAINING?'), findsNothing);
    });

    testWidgets('NOT YET cancels', (tester) async {
      await openDialog(tester);
      await tester.tap(find.text('NOT YET'));
      await tester.pumpAndSettle();
      expect(find.text('START TRAINING?'), findsNothing);
    });
  });

  group('RootPage shell', () {
    // RootPage runs a periodic timer + async service loads in initState, so it
    // never settles — pump the widget inside runAsync to let the SharedPreferences
    // futures resolve, then a plain pump reflects the loaded state (no
    // pumpAndSettle).
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

    testWidgets('cold Train tap (no live session) shows the confirm', (
      tester,
    ) async {
      await pumpShell(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('TRAIN'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(find.text('START TRAINING?'), findsOneWidget);
    });
  });
}
