import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/guild_page.dart';
import 'package:workout_track/widgets/guild/guild_crest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('guild page renders BIT identity, crest, and roster', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: GuildPage(),
          ),
        ),
      );
      // hall PNG decode + the guild/identity/roster service loads (all async)
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('BIT'), findsOneWidget);
    expect(find.text('LV.1'), findsOneWidget); // fresh user, 0 sessions
    expect(find.byType(GuildCrestBadge), findsOneWidget); // centre-bay crest
    expect(
      find.byKey(const ValueKey('guild_identity_header')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('guild_roster_player')), findsOneWidget);
    expect(find.text('OPEN'), findsNWidgets(5));
    expect(find.byKey(const ValueKey('guild_weekly_cache')), findsOneWidget);
    expect(find.byKey(const ValueKey('guild_legends')), findsOneWidget);
    expect(find.byKey(const ValueKey('guild_bit_strip')), findsOneWidget);
  });
}
