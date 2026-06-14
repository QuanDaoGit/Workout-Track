import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/unit_models.dart';
import 'package:workout_track/services/unit_settings_service.dart';
import 'package:workout_track/widgets/motion/phosphor_tap.dart';
import 'package:workout_track/widgets/plate_calculator_sheet.dart';

void main() {
  setUp(() {
    Units.weight = WeightUnit.kg;
  });

  double? result;

  Future<void> openSheet(WidgetTester tester, {double? initialTargetKg}) async {
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await PlateCalculatorSheet.show(
                    context,
                    initialTargetKg: initialTargetKg,
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  // Scope to the plate-chip Wrap: the bar selector now renders chips with the
  // same numeric labels (20/15/10 kg, 45/35/25 lb), so an unscoped finder would
  // collide.
  Finder chip(String label) => find.descendant(
    of: find.byKey(const ValueKey('plate_chips')),
    matching: find.widgetWithText(PhosphorTap, label),
  );

  // Chip taps flash an 80ms phosphor halo; plate removal animates for 120ms
  // before the entry is deleted. 200ms settles both.
  Future<void> settleMotion(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 200));

  Finder removablePlates() => find.byWidgetPredicate(
    (w) => w is Container && w.constraints?.minWidth == 24,
  );

  Finder ghostSlots() => find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == '_GhostPlateSlot',
  );

  testWidgets('opens in forward mode with both fields and plate solution', (
    tester,
  ) async {
    await openSheet(tester, initialTargetKg: 60);

    expect(find.text('TARGET>PLATES'), findsOneWidget);
    expect(find.text('PLATES>TOTAL'), findsOneWidget);
    // 60 kg on a 20 kg bar = one 20 per side; labeled plate + caption.
    expect(find.text('20 kg per side'), findsOneWidget);
    // Olympic bar chip ('20') + 2 mirrored plate visuals.
    expect(find.text('20'), findsNWidgets(3));
    expect(find.text('APPLY'), findsOneWidget);
  });

  testWidgets('toggle switches to reverse mode and back', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('PLATES>TOTAL'));
    await tester.pumpAndSettle();
    expect(find.text('TAP TO ADD · PER SIDE'), findsOneWidget);
    expect(find.text('TARGET'), findsNothing);
    // Empty stack → bare bar with dashed ghost slots, total is just the bar.
    expect(removablePlates(), findsNothing);
    expect(ghostSlots(), findsNWidgets(2));
    expect(find.text('TOTAL  20 kg', findRichText: true), findsOneWidget);

    await tester.tap(find.text('TARGET>PLATES'));
    await tester.pumpAndSettle();
    expect(find.text('TARGET'), findsOneWidget);
    expect(find.text('TAP TO ADD · PER SIDE'), findsNothing);
  });

  testWidgets('tapping chips builds the stack and updates total + breakdown', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('PLATES>TOTAL'));
    await tester.pumpAndSettle();

    await tester.tap(chip('10'));
    await settleMotion(tester);
    await tester.tap(chip('20'));
    await settleMotion(tester);

    // 20 + 2 × (20 + 10) = 80; mirrored bar renders each plate twice.
    expect(find.text('TOTAL  80 kg', findRichText: true), findsOneWidget);
    expect(removablePlates(), findsNWidgets(4));
    expect(ghostSlots(), findsNothing);
    expect(find.text('tap a plate to remove it'), findsOneWidget);
    // Plates are labeled with their weight.
    expect(
      find.descendant(of: removablePlates(), matching: find.text('20')),
      findsNWidgets(2),
    );
  });

  testWidgets('tapping a plate on the bar removes that instance', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('PLATES>TOTAL'));
    await tester.pumpAndSettle();

    await tester.tap(chip('20'));
    await settleMotion(tester);
    await tester.tap(chip('10'));
    await settleMotion(tester);

    // Left (mirrored) stack renders ascending, so its first plate is the 10.
    await tester.tap(removablePlates().first);
    await tester.pump();

    // The total drops immediately (10 removed → 20 + 2 × 20 = 60) while the
    // plate is still on the bar animating out.
    expect(find.text('TOTAL  60 kg', findRichText: true), findsOneWidget);
    expect(removablePlates(), findsNWidgets(4));

    // Pop-off animation done → the plate leaves the bar. Mirrored → 2 left.
    await settleMotion(tester);
    expect(removablePlates(), findsNWidgets(2));
  });

  testWidgets('tapping a plate mid pop-off removes only one instance', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('PLATES>TOTAL'));
    await tester.pumpAndSettle();

    await tester.tap(chip('20'));
    await settleMotion(tester);
    await tester.tap(chip('20'));
    await settleMotion(tester);

    // Two taps on the same plate while it animates out: the second is a no-op.
    await tester.tap(removablePlates().first);
    await tester.pump();
    await tester.tap(removablePlates().first, warnIfMissed: false);
    await settleMotion(tester);

    expect(find.text('TOTAL  60 kg', findRichText: true), findsOneWidget);
    expect(removablePlates(), findsNWidgets(2));
  });

  testWidgets('CLEAR empties the stack', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('PLATES>TOTAL'));
    await tester.pumpAndSettle();

    await tester.tap(chip('20'));
    await settleMotion(tester);
    expect(find.text('CLEAR'), findsOneWidget);

    await tester.tap(find.text('CLEAR'));
    await tester.pump();

    expect(removablePlates(), findsNothing);
    expect(find.text('TOTAL  20 kg', findRichText: true), findsOneWidget);
    expect(find.text('CLEAR'), findsNothing);
    expect(find.text('tap a plate to remove it'), findsNothing);
  });

  testWidgets('USE WEIGHT pops with the total in canonical kg', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('PLATES>TOTAL'));
    await tester.pumpAndSettle();

    await tester.tap(chip('20'));
    await settleMotion(tester);
    await tester.tap(chip('10'));
    await settleMotion(tester);

    await tester.tap(find.text('USE WEIGHT'));
    await tester.pumpAndSettle();

    expect(result, 80.0);
    expect(find.text('USE WEIGHT'), findsNothing);
  });

  testWidgets('lb mode: lb plate set, 45 bar, result converted to kg', (
    tester,
  ) async {
    Units.weight = WeightUnit.lbs;
    await openSheet(tester);
    await tester.tap(find.text('PLATES>TOTAL'));
    await tester.pumpAndSettle();

    for (final label in ['45', '35', '25', '10', '5', '2.5']) {
      expect(chip(label), findsOneWidget);
    }

    await tester.tap(chip('45'));
    await settleMotion(tester);
    await tester.tap(chip('45'));
    await settleMotion(tester);

    // 45 bar + 2 × (45 + 45) = 225 lbs.
    expect(find.text('TOTAL  225 lbs', findRichText: true), findsOneWidget);

    await tester.tap(find.text('USE WEIGHT'));
    await tester.pumpAndSettle();

    expect(result, closeTo(lbsToKg(225), 1e-9));
  });

  testWidgets('lb mode: a kg round-trip seeds the TARGET clean (no FP noise)', (
    tester,
  ) async {
    // 150 lbs stored as canonical kg then shown back in lbs lands on
    // 149.99999999999997 — the TARGET must read 150, not the raw noise.
    Units.weight = WeightUnit.lbs;
    await openSheet(tester, initialTargetKg: lbsToKg(150));

    final target = tester.widget<TextField>(find.byType(TextField).first);
    expect(target.controller!.text, '150');
    expect(find.textContaining('149.99'), findsNothing);
  });

  testWidgets('kg mode: fractional plate chips keep 2-decimal labels', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('PLATES>TOTAL'));
    await tester.pumpAndSettle();

    // 1.25 must not round to "1.3"; 2.5 stays "2.5".
    expect(chip('1.25'), findsOneWidget);
    expect(chip('2.5'), findsOneWidget);
  });

  testWidgets('APPLY is disabled until the target parses', (tester) async {
    await openSheet(tester);

    final apply = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'APPLY'),
    );
    expect(apply.onPressed, isNull);
  });

  testWidgets('APPLY pops with the typed target in canonical kg', (
    tester,
  ) async {
    await openSheet(tester, initialTargetKg: 60);

    await tester.tap(find.text('APPLY'));
    await tester.pumpAndSettle();

    expect(result, 60.0);
    expect(find.text('APPLY'), findsNothing);
  });

  testWidgets('lb mode: APPLY converts the typed target back to kg', (
    tester,
  ) async {
    Units.weight = WeightUnit.lbs;
    await openSheet(tester);

    // First field in the sheet is TARGET. Settle the AnimatedSize growth
    // (hint → bar + caption) before tapping below it.
    await tester.enterText(find.byType(TextField).first, '225');
    await tester.pumpAndSettle();

    await tester.tap(find.text('APPLY'));
    await tester.pumpAndSettle();

    expect(result, closeTo(lbsToKg(225), 1e-9));
  });

  testWidgets('reduced motion: plate removal is immediate', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => PlateCalculatorSheet.show(context),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLATES>TOTAL'));
    await tester.pumpAndSettle();

    await tester.tap(chip('20'));
    await settleMotion(tester);
    expect(removablePlates(), findsNWidgets(2));

    // No 120ms pop-off under reduced motion — gone on the next frame.
    await tester.tap(removablePlates().first);
    await tester.pump();
    expect(removablePlates(), findsNothing);
    expect(find.text('TOTAL  20 kg', findRichText: true), findsOneWidget);
  });

  // --- Bar selector (replaces the old free-text BAR field) -----------------

  Finder customBarField() => find.descendant(
    of: find.byKey(const ValueKey('custom_bar_field')),
    matching: find.byType(TextField),
  );

  testWidgets('bar selector defaults to Olympic (20 kg) — no field, plates from 20', (
    tester,
  ) async {
    await openSheet(tester, initialTargetKg: 60);

    // Four chips present; the Custom free-entry field stays hidden until chosen.
    expect(find.byKey(const ValueKey('bar_olympic')), findsOneWidget);
    expect(find.byKey(const ValueKey('bar_custom')), findsOneWidget);
    expect(find.text('OLYMPIC'), findsOneWidget); // type tag over the weight
    expect(find.text('CUSTOM BAR'), findsNothing);
    // Olympic 20 kg bar: (60 - 20) / 2 = 20 per side.
    expect(find.text('20 kg per side'), findsOneWidget);
  });

  testWidgets("selecting Women's recomputes plates from a 15 kg bar", (tester) async {
    await openSheet(tester, initialTargetKg: 60);

    await tester.tap(find.byKey(const ValueKey('bar_womens')));
    await tester.pumpAndSettle();

    // 15 kg bar: (60 - 15) / 2 = 22.5 per side.
    expect(find.text('22.5 kg per side'), findsOneWidget);
  });

  testWidgets('CUSTOM reveals a free-entry bar field that feeds the calc', (
    tester,
  ) async {
    await openSheet(tester, initialTargetKg: 60);

    expect(find.text('CUSTOM BAR'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('bar_custom')));
    await tester.pumpAndSettle();
    expect(find.text('CUSTOM BAR'), findsOneWidget);

    await tester.enterText(customBarField(), '10');
    await tester.pump(const Duration(milliseconds: 300));

    // Custom 10 kg bar: (60 - 10) / 2 = 25 per side.
    expect(find.text('25 kg per side'), findsOneWidget);
  });

  testWidgets('the chosen bar is shared across both modes', (tester) async {
    await openSheet(tester);

    await tester.tap(find.byKey(const ValueKey('bar_womens')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLATES>TOTAL'));
    await tester.pumpAndSettle();

    // Empty stack in reverse mode → TOTAL equals the carried 15 kg bar.
    expect(find.text('TOTAL  15 kg', findRichText: true), findsOneWidget);
  });

  testWidgets('preset bar labels follow the active unit (lbs)', (tester) async {
    Units.weight = WeightUnit.lbs;
    await openSheet(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bar_olympic')),
        matching: find.text('45'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bar_womens')),
        matching: find.text('35'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bar_ez')),
        matching: find.text('25'),
      ),
      findsOneWidget,
    );
  });
}
