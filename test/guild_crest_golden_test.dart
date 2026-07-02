import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/guild_models.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/guild/guild_crest.dart';

/// Rendered proof of the ported Crest Forge crest: the 4 banner shapes (top row),
/// the 4 emblems + NONE on a swallowtail (middle), and independent banner/emblem
/// recolour (bottom). Static (reduced-motion → sway off) for a deterministic
/// golden. Regenerate with `flutter test --update-goldens`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guild crest — banners, emblems, recolour', (tester) async {
    tester.view.physicalSize = const Size(540, 430);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Widget crest(GuildCrest c, {Color fb = kCyan}) => GuildCrestBadge(
      crest: c,
      fallbackColor: fb,
      size: 58,
      animate: false,
    );

    const teal = 0xFF37D2CF;
    final tree = MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Material(
          color: kBg,
          child: Center(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // 4 banner shapes (sword emblem, auto → cyan).
                for (var s = 0; s < 4; s++)
                  crest(GuildCrest(shape: s, emblem: 0)),
                // 4 emblems + NONE on a swallowtail, at the authored teal.
                for (var e = 0; e < 4; e++)
                  crest(
                    GuildCrest(
                      shape: 0,
                      emblem: e,
                      bannerColor: teal,
                      emblemColor: teal,
                    ),
                  ),
                crest(
                  const GuildCrest(
                    shape: 0,
                    emblem: GuildCrest.noEmblem,
                    bannerColor: teal,
                    emblemColor: teal,
                  ),
                ),
                // Independent banner + emblem recolour.
                crest(
                  const GuildCrest(
                    shape: 1,
                    emblem: 2,
                    bannerColor: 0xFFFFD700,
                    emblemColor: 0xFFFF2D55,
                  ),
                  fb: kAmber,
                ),
                crest(
                  const GuildCrest(
                    shape: 2,
                    emblem: 3,
                    bannerColor: 0xFF00FF9C,
                    emblemColor: 0xFF00BFFF,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Real async zone so the asset decode + recolour + decodeImageFromPixels
    // (all async) finish before the golden is captured.
    await tester.runAsync(() async {
      await tester.pumpWidget(tree);
      await Future<void>.delayed(const Duration(milliseconds: 900));
    });
    await tester.pump();

    await expectLater(
      find.byType(Wrap),
      matchesGoldenFile('goldens/guild_crest_variants.png'),
    );
  });
}
