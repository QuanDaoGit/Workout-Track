import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/profile_page.dart';
import 'package:workout_track/widgets/pixel_loader.dart';

/// Rendered-artifact lock for the redesigned Profile hero identity card
/// (character-as-hero: a large centred framed pixel-face avatar, the centred
/// name + title epithet, one typographic competence stamp line — rank headline
/// + muted level — and the neon XP meter).
///
/// Deterministic by construction: a default profile (empty SharedPreferences),
/// animations disabled (the ArcadeBar snaps; IronbitAvatar is a static paint),
/// settled before capture. One full-page pump per file (the page loads ~10
/// services async; two pumps in one isolate race each other). Regenerate with
/// `flutter test --update-goldens`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('profile hero card — the character is the visual hero', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const ProfilePage(),
      ),
    );
    // Poll: advance real async, pump a frame, stop once the loader clears.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      if (find.byType(PixelLoader).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile_guild_card')), findsOneWidget);
    await expectLater(
      find.byKey(const ValueKey('profile_guild_card')),
      matchesGoldenFile('goldens/profile_hero_card.png'),
    );
  });
}
