import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/profile_page.dart';
import 'package:workout_track/theme/tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Profile renders coherent guild, stats, and loadout colors', (
    tester,
  ) async {
    await _pumpLoadedProfile(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('CHARACTER'), findsOneWidget);
    expect(find.text('TRAINING'), findsOneWidget);
    expect(find.text('DAYS THIS WK'), findsOneWidget);
    expect(find.text('QUESTS'), findsOneWidget);
    expect(find.text('CLEARED'), findsOneWidget);
    expect(find.text('TITLES'), findsOneWidget);
    expect(find.text('EARNED'), findsOneWidget);

    final guildCard = tester.widget<Container>(
      find.byKey(const ValueKey('profile_guild_card')),
    );
    final guildDecoration = guildCard.decoration! as BoxDecoration;
    expect(
      (guildDecoration.border! as Border).top.color,
      isNot(CharacterClass.bruiser.themeColor),
    );
    expect(guildDecoration.boxShadow, isNull);

    final classSection = tester.widget<Container>(
      find.byKey(const ValueKey('profile_class_section')),
    );
    final classDecoration = classSection.decoration! as BoxDecoration;
    expect(
      (classDecoration.border! as Border).top.color,
      isNot(CharacterClass.bruiser.themeColor),
    );
    expect(classDecoration.boxShadow, isNull);

    final accentRail = tester.widget<Container>(
      find.byKey(const ValueKey('profile_class_accent_rail')),
    );
    expect(accentRail.color, CharacterClass.bruiser.themeColor);

    // The identity frame is the avatar-edit entry (neon brush affordance).
    final editChip = find.byKey(const ValueKey('profile_avatar_edit_chip'));
    expect(editChip, findsOneWidget);
    final editIcon = tester.widget<ImageIcon>(
      find.descendant(of: editChip, matching: find.byType(ImageIcon)),
    );
    expect(editIcon.color, kNeon);

    // Loadout no longer carries the old avatar grid — cosmetics only.
    await tester.tap(find.text('LOADOUT'));
    await tester.pumpAndSettle();

    expect(find.text('COSMETICS'), findsOneWidget);
    expect(find.text('AVATAR'), findsNothing);
  });
}

Future<void> _pumpLoadedProfile(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pumpAndSettle();
  expect(find.text('CHARACTER'), findsOneWidget);
}
