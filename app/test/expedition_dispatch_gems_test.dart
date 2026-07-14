import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/room/expedition_dispatch_sheet.dart';

/// The dispatch sheet shows each route's approximate gem haul as the only
/// right-side cue: one "~N" per route, N a positive multiple of 10, gem-magenta.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openSheet(
    WidgetTester tester, {
    required Map<String, int> stats,
    required int vit,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showExpeditionDispatchSheet(
                  context,
                  charges: 3,
                  vit: vit,
                  stats: stats,
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
  }

  testWidgets('one ~N gem readout per route, each a positive multiple of 10', (
    tester,
  ) async {
    await openSheet(
      tester,
      stats: const {'STR': 50, 'AGI': 30, 'END': 70, 'VIT': 55},
      vit: 55,
    );

    final approxTexts = find.byWidgetPredicate(
      (w) => w is Text && (w.data?.startsWith('~') ?? false),
    );
    // One per route (the three adventure routes).
    expect(approxTexts, findsNWidgets(3));

    for (final element in approxTexts.evaluate()) {
      final text = (element.widget as Text);
      final value = int.parse(text.data!.substring(1));
      expect(value > 0, isTrue, reason: 'never promises ~0');
      expect(value % 10, 0, reason: 'rounded to a multiple of 10');
      expect(text.style?.color, kGemMagenta, reason: 'reads as gem currency');
    }

    // The old "STAT · GRADE · ~Hh" row string is gone (the duration token in
    // particular — the SEND button still legitimately uses " · ").
    expect(find.textContaining('~6H'), findsNothing);
    expect(find.textContaining('STR ·'), findsNothing);
  });

  testWidgets('low stats + floor VIT still pay a visible (multiple-of-10) haul', (
    tester,
  ) async {
    await openSheet(
      tester,
      stats: const {'STR': 0, 'AGI': 0, 'END': 0, 'VIT': 10},
      vit: 10,
    );

    final approxTexts = find.byWidgetPredicate(
      (w) => w is Text && (w.data?.startsWith('~') ?? false),
    );
    expect(approxTexts, findsNWidgets(3));
    for (final element in approxTexts.evaluate()) {
      final value = int.parse((element.widget as Text).data!.substring(1));
      expect(value >= 10, isTrue, reason: 'floor haul still rounds up to ~10');
    }
  });
}
