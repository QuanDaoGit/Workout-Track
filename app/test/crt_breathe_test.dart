import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/motion/crt_breathe.dart';

const _cyan = TextStyle(fontSize: 10, color: Color(0xFF00BFFF));

Widget _host({required bool reduceMotion, required Widget child}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
}

double _labelAlpha(WidgetTester tester) {
  final t = tester.widget<Text>(find.byType(Text));
  return t.style!.color!.a;
}

void main() {
  testWidgets('breathes: dim at the exhale trough, full at the inhale peak', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        reduceMotion: false,
        child: const CrtBreathe(
          text: "TODAY'S MISSION",
          style: _cyan,
          period: Duration(milliseconds: 4500),
          minBrightness: 0.6,
        ),
      ),
    );

    // Cycle starts at the trough (value 0 → brightness = minBrightness).
    final trough = _labelAlpha(tester);
    expect(trough, closeTo(0.6, 0.03), reason: 'exhale floor ≈ minBrightness');

    // Half a period in → the inhale peak (value 0.5 → full base alpha).
    await tester.pump(const Duration(milliseconds: 2250));
    final peak = _labelAlpha(tester);
    expect(peak, closeTo(1.0, 0.03), reason: 'inhale peak ≈ full brightness');
    expect(peak, greaterThan(trough));

    await tester.pumpWidget(const SizedBox()); // dispose the repeating controller
  });

  testWidgets('reduced motion is a steady full-brightness label, no breath', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        reduceMotion: true,
        child: const CrtBreathe(text: 'ABC', style: _cyan),
      ),
    );

    expect(_labelAlpha(tester), closeTo(1.0, 0.001));
    // Time passes, nothing breathes.
    await tester.pump(const Duration(milliseconds: 2250));
    expect(_labelAlpha(tester), closeTo(1.0, 0.001));
    expect(find.text('ABC'), findsOneWidget);
  });
}
