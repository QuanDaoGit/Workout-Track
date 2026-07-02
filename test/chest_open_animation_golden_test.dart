import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/chest_open_animation.dart';

/// Rendered proof that the ported chest-open FX paint (the open-phase pop + the
/// amber/neon pixel burst), captured mid-animation on `kBg`. NOTE: a golden can
/// only prove a *frame* renders — the full motion timeline (rattle → pop → settle)
/// matching the handoff is a NAMED on-device sign-off residual (port-handoff). The
/// chest body here is the painted fallback (sprites aren't precached); the real
/// sprite is proven static by the quest_progress_bar goldens.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chest-open — open-phase burst frame', (tester) async {
    tester.view.physicalSize = const Size(220, 250);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        // Motion ON so the one-shot plays (reduced motion would freeze it open).
        home: Scaffold(
          backgroundColor: kBg,
          body: Center(
            child: ChestOpenAnimation(height: 200, open: true, play: true),
          ),
        ),
      ),
    );
    // Advance into the open phase (rattle 650ms done; ~150ms into open → pop +
    // ring + beams + flash). Bounded pump — the one-shot never settles mid-run.
    await tester.pump(const Duration(milliseconds: 800));

    await expectLater(
      find.byType(ChestOpenAnimation),
      matchesGoldenFile('goldens/chest_open_burst.png'),
    );
  });
}
