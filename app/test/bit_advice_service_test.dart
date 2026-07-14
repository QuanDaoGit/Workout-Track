import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/services/bit_advice_service.dart';

/// The wildcard daily cap is the only persisted fact behind BIT's advice
/// rotation — it must survive a restart (a new service instance reading the same
/// store) and roll over at the day boundary. now() is injected so the boundary
/// is deterministic.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  DateTime fixed(int y, int m, int d) => DateTime(y, m, d, 13, 0);

  test('un-shown by default → wildcard allowed', () async {
    final svc = BitAdviceService(nowProvider: () => fixed(2026, 6, 30));
    expect(await svc.wasWildcardShownToday(), isFalse);
  });

  test('marking spends the slot for the rest of today, across restarts', () async {
    final day = fixed(2026, 6, 30);
    await BitAdviceService(nowProvider: () => day).markWildcardShown();
    // A fresh instance (simulating an app restart) still sees the cap spent.
    final reopened = BitAdviceService(nowProvider: () => day);
    expect(await reopened.wasWildcardShownToday(), isTrue);
  });

  test('the cap rolls over on the next day', () async {
    await BitAdviceService(nowProvider: () => fixed(2026, 6, 30))
        .markWildcardShown();
    final tomorrow = BitAdviceService(nowProvider: () => fixed(2026, 7, 1));
    expect(await tomorrow.wasWildcardShownToday(), isFalse);
  });
}
