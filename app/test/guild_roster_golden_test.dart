import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/avatar_spec.dart';
import 'package:workout_track/models/guild_models.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/guild/guild_roster.dart';

/// Rendered proof of the guild roster (solo-honest v1): the player tile over the
/// OPEN slots awaiting future guildmates, on `kBg` so the pixel-arcade tints are
/// verifiable. Regenerate with `flutter test --update-goldens`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Future<ByteData> font(String path) async =>
        ByteData.view((await File(path).readAsBytes()).buffer);
    await (FontLoader('ShareTechMono')
          ..addFont(font('fonts/sharetechmono/ShareTechMono-Regular.ttf')))
        .load();
    await (FontLoader('PressStart2P')
          ..addFont(font('fonts/pressstart2p/PressStart2P-Regular.ttf')))
        .load();
  });

  testWidgets('guild roster — player + 5 OPEN slots', (tester) async {
    tester.view.physicalSize = const Size(400, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final tree = MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        // Material ancestor (not a bare ColoredBox) so the Text widgets don't
        // render the "no Material" yellow debug underline — matches the page
        // golden, which gets Material from GuildPage's Scaffold.
        child: Material(
          color: kBg,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: GuildRoster(
              player: const GuildMember(
                name: 'Quan',
                avatarSpec: AvatarSpec.fallback,
                activeDays: 3,
              ),
              openSlots: 5,
            ),
          ),
        ),
      ),
    );
    // Render inside a real async zone so the FontLoader glyphs register before
    // layout (otherwise the first frame falls back → the yellow missing-font
    // underline). Mirrors the guild_page golden's pattern.
    await tester.runAsync(() async {
      await tester.pumpWidget(tree);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    await expectLater(
      find.byType(GuildRoster),
      matchesGoldenFile('goldens/guild_roster.png'),
    );
  });
}
