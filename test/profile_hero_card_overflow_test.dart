import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/profile_page.dart';
import 'package:workout_track/widgets/pixel_loader.dart';

/// The redesigned hero identity card must lay out without overflow at the
/// stress corner of the support matrix: the narrowest common width (320 dp) at
/// large text (textScale 1.3). A single full-page pump (its own isolate) so the
/// async service load doesn't race a sibling test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('hero card lays out without overflow at 320dp x 1.3 text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: const TextScaler.linear(1.3),
          ),
          child: child!,
        ),
        home: const ProfilePage(),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      if (find.byType(PixelLoader).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();

    // pumpAndSettle would have surfaced any RenderFlex overflow as an exception.
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('profile_guild_card')), findsOneWidget);
  });
}
