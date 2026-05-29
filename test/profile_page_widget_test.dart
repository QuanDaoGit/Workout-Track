import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/profile_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Profile guild card renders compact glance metrics', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('CHARACTER'), findsOneWidget);
    expect(find.text('TRAINING'), findsOneWidget);
    expect(find.text('DAYS THIS WK'), findsOneWidget);
    expect(find.text('QUESTS'), findsOneWidget);
    expect(find.text('CLEARED'), findsOneWidget);
    expect(find.text('TITLES'), findsOneWidget);
    expect(find.text('EARNED'), findsOneWidget);
  });
}
