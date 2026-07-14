import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/home.dart';
import 'package:workout_track/theme/tokens.dart';

/// Rendered-artifact proof for the Home level/XP strip (the Flutter web preview
/// cannot screenshot here). Pinned size + reduced motion + a fixed XP value, so
/// the bar fill and "today" tag are deterministic.
/// Regenerate with `flutter test --update-goldens`.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home level strip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: SizedBox(
                width: 390,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kHomeHorizontalPadding,
                  ),
                  child: HomeLevelStrip(
                    // 2200 XP ≈ 47% into level 10 → a clear partial fill.
                    level: 10,
                    totalXP: 2200,
                    todayXP: 120,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Let the XP bar's fill tween settle so the golden shows the real fraction.
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(HomeLevelStrip),
      matchesGoldenFile('goldens/home_level_strip.png'),
    );
  });
}
