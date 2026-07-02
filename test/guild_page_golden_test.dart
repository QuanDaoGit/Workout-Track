import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/guild_page.dart';

/// Rendered proof of the integrated Guild surface: the hall with the crest in
/// its centre bay, the BIT identity header (level + XP bar + customize), and the
/// roster below. Fresh user (0 sessions → LV.1, bruiser-red auto crest).
/// Regenerate with `flutter test --update-goldens`.
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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('guild page — hall + crest + identity + roster', (tester) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const tree = MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: GuildPage(),
      ),
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(tree);
      // 1) Let reload() (hall + ~10 services) settle, then pump so guild != null
      //    and the centre-bay crest MOUNTS — inside runAsync, so its async image
      //    build (decodeImageFromPixels engine callbacks) can actually fire.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump();
      // 2) Let the crest's recolour + decode complete, then render it.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await tester.pump();
    });
    await tester.pump();

    await expectLater(
      find.byType(GuildPage),
      matchesGoldenFile('goldens/guild_page.png'),
    );
  });
}
