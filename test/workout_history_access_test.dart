import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/profile_page.dart';

/// Workout history (logs + calendar + stats) used to be reachable only by an
/// unlabelled tap on Home's LCK pip — undiscoverable. The fix adds two visible
/// doors: a Home last-workout "VIEW LOG →" card and the Labs "Training Log" row.
///
/// This pins the Labs door. The Home card is verified on-device: pumping the
/// full HomePage with a seeded completed session hangs the test binding on the
/// repeat-last-mission panel's ambient ticker (a pre-existing HomePage
/// testability limit), and this env can't screenshot Flutter either.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Labs surfaces a discoverable "Training Log" row', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // The log row lives on the SETTINGS tab, not the default Character tab.
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();

    expect(find.text('Training Log'), findsOneWidget);
    expect(find.text('History, calendar, and stats.'), findsOneWidget);
  });
}
