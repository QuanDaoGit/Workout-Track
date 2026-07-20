import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HapticService.enabled = true;
    HapticService.nowProvider = DateTime.now;
  });
  tearDown(() {
    HapticService.enabled = true;
    HapticService.nowProvider = DateTime.now;
  });

  test('bitPurr fires once and drops a re-fire inside the envelope window',
      () async {
    var now = DateTime(2026, 7, 20, 10, 0, 0);
    HapticService.nowProvider = () => now;
    expect(await HapticService.instance.bitPurr(), isTrue);
    // 100ms later — still inside the ~300ms envelope: dropped (the motor must
    // never cancel-restart mid-purr).
    now = now.add(const Duration(milliseconds: 100));
    expect(await HapticService.instance.bitPurr(), isFalse);
    // Past the window: fires again.
    now = now.add(const Duration(milliseconds: 300));
    expect(await HapticService.instance.bitPurr(), isTrue);
  });

  test('bitPurr is a silent no-op when haptics are disabled', () async {
    HapticService.enabled = false;
    expect(await HapticService.instance.bitPurr(), isFalse);
  });
}
