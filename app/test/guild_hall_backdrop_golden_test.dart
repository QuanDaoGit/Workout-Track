import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/guild/guild_hall_backdrop.dart';

/// Rendered proof that the ported Guild Hall backdrop composes its real PNG
/// assets (base + extracted flame light) plus the additive torch glow and teal
/// indicator lights into the handoff's **reduced-motion static frame**
/// (un-warped flames @0.96, lights @p=0.6, no embers/dust). A golden can only
/// prove a *frame* renders — the live motion (flame warp/flicker, light
/// stutter, embers, dust at ~14fps) is a NAMED on-device sign-off residual
/// (port-handoff: goldens can't see motion). Regenerate with
/// `flutter test --update-goldens`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guild hall backdrop — reduced-motion static frame',
      (tester) async {
    tester.view.physicalSize = const Size(540, 324);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const tree = MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        // Reduced motion → the handoff's computed static frame, no ticker.
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(
          backgroundColor: Color(0xFF0D0F17),
          body: Center(child: GuildHallBackdrop()),
        ),
      ),
    );

    // The backdrop self-loads its PNGs via rootBundle + instantiateImageCodec
    // (real async). Drive that under runAsync so the decode actually completes,
    // then pump (outside) to apply the loaded rebuild and paint the frame.
    await tester.runAsync(() async {
      await tester.pumpWidget(tree);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    await expectLater(
      find.byType(GuildHallBackdrop),
      matchesGoldenFile('goldens/guild_hall_backdrop_static.png'),
    );
  });
}
