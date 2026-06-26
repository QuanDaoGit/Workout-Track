import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/room/expedition_dispatch_sheet.dart';

/// Rendered-artifact lock for the Expedition dispatch sheet: each route row's
/// right side now shows the approximate gem haul (a multiple of 10, gem-magenta
/// with the gem icon) instead of the old "STAT · GRADE · ~Hh" string. Custom
/// fonts + the gem PNG render as boxes / the fallback glyph here — this pins the
/// layout, the magenta readout, and the right-alignment, not glyph shapes.
/// Regenerate with `flutter test --update-goldens`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('dispatch sheet — rows show the approximate gem haul', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(scaffoldBackgroundColor: kBg),
        home: Scaffold(
          backgroundColor: kBg,
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showExpeditionDispatchSheet(
                  context,
                  charges: 3,
                  vit: 55,
                  stats: const {'STR': 50, 'AGI': 30, 'END': 70, 'VIT': 55},
                  selectedRouteId: 'iron_vault',
                  onSend: (_) async => true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('WHERE DOES BIT SCOUT?'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/expedition_dispatch_sheet.png'),
    );
  });
}
