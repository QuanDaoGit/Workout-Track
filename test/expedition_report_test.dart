import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/adventure_models.dart';
import 'package:workout_track/pages/expedition_report_page.dart';

/// The report ceremony — gems/find reveal + tap-to-skip. The juice is pure
/// presentation (settlement already happened); reduced motion lands it instantly.
void main() {
  Expedition exp() => Expedition(
    id: 'e1',
    routeId: 'iron_vault',
    day: '2026-06-12',
    rank: 'C',
    payout: 14,
    flavorIdx: 0,
    durationMinutes: 360,
    multiplier: 1.2,
    vitAtDispatch: 55,
    returnsAtIso: '2026-06-12T17:00:00.000',
    settledAtIso: '2026-06-12T17:00:00.000',
  );

  Widget host({bool reduce = true}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: ExpeditionReportPage(
        report: ExpeditionReport(expedition: exp(), classDefaultOrders: false),
      ),
    ),
  );

  testWidgets('reduced motion reveals the report instantly + CONTINUE', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.textContaining('GEMS'), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);
  });

  testWidgets('tap-to-skip the staged reveal does not crash (motion)', (
    t,
  ) async {
    await t.pumpWidget(host(reduce: false));
    await t.pump(); // post-frame starts the stagger
    await t.tap(find.text('EXPEDITION REPORT')); // tap the body → skip
    await t.pump(const Duration(milliseconds: 100));
    expect(t.takeException(), isNull);
    expect(find.textContaining('GEMS'), findsOneWidget);
    await t.pumpWidget(const SizedBox()); // dispose the diorama ticker
  });
}
