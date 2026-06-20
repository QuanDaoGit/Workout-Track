import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/room/energy_cell.dart';

/// Rendered proof that the ported energy cell matches the handoff
/// (`assets/handoff_BIT_expedition/energy-cell`): FULL (charged) + DEPLETED
/// (dead) at an in-app integer scale, plus a pip row (charged/spent). Reduced
/// motion → the bloom is off, so these are deterministic.
/// Regenerate with `flutter test --update-goldens`.
void main() {
  Future<void> shot(WidgetTester t, Widget child, String file) async {
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            backgroundColor: const Color(0xFF07070F),
            body: Center(child: child),
          ),
        ),
      ),
    );
    await t.pump();
    await expectLater(find.byType(Padding).first, matchesGoldenFile(file));
  }

  testWidgets('energy cell — FULL ×8', (t) => shot(
        t,
        const Padding(
          padding: EdgeInsets.all(24),
          child: EnergyCell(scale: 8, glow: false),
        ),
        'goldens/energy_cell_full.png',
      ));

  testWidgets('energy cell — DEPLETED ×8', (t) => shot(
        t,
        const Padding(
          padding: EdgeInsets.all(24),
          child: EnergyCell(scale: 8, dead: true),
        ),
        'goldens/energy_cell_dead.png',
      ));

  testWidgets('energy cell — pip row (2 charged, 1 spent) ×3', (t) => shot(
        t,
        const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EnergyCell(scale: 3, glow: false),
              SizedBox(width: 8),
              EnergyCell(scale: 3, glow: false),
              SizedBox(width: 8),
              EnergyCell(scale: 3, dead: true),
            ],
          ),
        ),
        'goldens/energy_cell_pips.png',
      ));
}
