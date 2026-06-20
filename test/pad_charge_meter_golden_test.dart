import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/room/pad_charge_meter.dart';

/// Rendered proof that the ported pad charge meter matches the handoff
/// (`pad-charge-meter/Energy Pad.html` `paintMeter`): the strip repainted as a
/// 3-segment LED lighting 0–3 cyan, with the two notch dividers. Zoomed ×6 over
/// the stage bg so the strip pixels are legible; the composite with the pad
/// sprite + alignment is verified by the room goldens.
/// Regenerate with `flutter test --update-goldens`.
void main() {
  Future<void> shotPulse(WidgetTester t, int charges, double pulse,
      String file) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF07070F),
          body: Center(
            child: SizedBox(
              width: 108 * 6,
              height: 40 * 6,
              child: CustomPaint(
                painter: PadChargeMeterPainter(
                  charges: charges,
                  armed: true,
                  pulse: pulse,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await expectLater(
        find.byType(CustomPaint).first, matchesGoldenFile('goldens/$file'));
  }

  Future<void> shot(WidgetTester t, int charges, String file) async {
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            backgroundColor: const Color(0xFF07070F),
            body: Center(
              child: SizedBox(
                width: 108 * 6,
                height: 40 * 6,
                child: CustomPaint(
                  painter: PadChargeMeterPainter(
                    charges: charges,
                    armed: charges > 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await expectLater(find.byType(CustomPaint).first,
        matchesGoldenFile('goldens/$file'));
  }

  testWidgets('pad meter · 0', (t) => shot(t, 0, 'pad_meter_0.png'));
  testWidgets('pad meter · 1', (t) => shot(t, 1, 'pad_meter_1.png'));
  testWidgets('pad meter · 2', (t) => shot(t, 2, 'pad_meter_2.png'));
  testWidgets('pad meter · 3', (t) => shot(t, 3, 'pad_meter_3.png'));
  testWidgets('pad meter · charge-land flash (2, pulse .6)',
      (t) => shotPulse(t, 2, 0.6, 'pad_meter_pulse.png'));
}
