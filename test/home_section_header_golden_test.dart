import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/home_section_header.dart';

/// Rendered-artifact lock for the Home section header: a white PressStart2P
/// title on the left, a green ShareTechMono action link right-aligned to the
/// card edge, on the dark chamber background. (Custom fonts render as boxes in
/// goldens — this pins layout / alignment / colour, not glyph shapes.)
/// Regenerate with `flutter test --update-goldens`.
void main() {
  testWidgets('home section header — title left, neon link right', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 120);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: kBg,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(kHomeHorizontalPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  HomeSectionHeader(
                    title: 'QUESTS',
                    actionLabel: 'DETAILS >',
                    onAction: _noop,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HomeSectionHeader),
      matchesGoldenFile('goldens/home_section_header.png'),
    );
  });
}

void _noop() {}
