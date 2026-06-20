import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/lck_pips.dart';

/// Rendered-artifact proof for [LckPips] across 0–4 filled diamonds (lck
/// thresholds 1/3/6/10). Regenerate with `flutter test --update-goldens`.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('lck pips 0..4', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: kBg,
          body: Center(
            child: SizedBox(
              key: const ValueKey('pips'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  LckPips(lck: 0, size: 20),
                  SizedBox(height: 14),
                  LckPips(lck: 1, size: 20),
                  SizedBox(height: 14),
                  LckPips(lck: 3, size: 20),
                  SizedBox(height: 14),
                  LckPips(lck: 6, size: 20),
                  SizedBox(height: 14),
                  LckPips(lck: 10, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byKey(const ValueKey('pips')),
      matchesGoldenFile('goldens/lck_pips.png'),
    );
  });
}
