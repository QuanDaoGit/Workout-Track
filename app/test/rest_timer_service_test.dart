import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/rest_timer_service.dart';

/// `RestTimerService.adjust()` — the ±15s controls on the between-exercise rest
/// panel. The endsAt timestamp stays the source of truth; the totalSeconds
/// denominator only ever GROWS to cover remaining (so a progress fraction can
/// never exceed 1), extension is capped, and a −adjust past zero is a skip.
void main() {
  setUp(() => RestTimerService.instance.cancel());
  tearDown(() => RestTimerService.instance.cancel());

  RestSnapshot seed(int remainingSeconds, {int? total}) {
    final snap = RestSnapshot(
      endsAt: DateTime.now().add(Duration(seconds: remainingSeconds)),
      totalSeconds: total ?? remainingSeconds,
    );
    RestTimerService.instance.current.value = snap;
    return snap;
  }

  test('+15 extends the remaining rest', () {
    seed(60);
    RestTimerService.instance.adjust(15);
    final snap = RestTimerService.instance.current.value!;
    expect(snap.isActive, isTrue);
    expect(snap.remaining.inSeconds, inInclusiveRange(73, 75));
  });

  test('+15 is capped at maxRestSeconds (no unbounded growth)', () {
    seed(RestTimerService.maxRestSeconds - 5);
    RestTimerService.instance.adjust(15);
    final snap = RestTimerService.instance.current.value!;
    expect(
      snap.remaining.inSeconds,
      lessThanOrEqualTo(RestTimerService.maxRestSeconds),
    );
  });

  test('the progress fraction stays within [0,1] after +15 (denominator grows)',
      () {
    seed(60, total: 60);
    RestTimerService.instance.adjust(15);
    final snap = RestTimerService.instance.current.value!;
    final fraction = snap.remaining.inMilliseconds / (snap.totalSeconds * 1000);
    expect(fraction, lessThanOrEqualTo(1.0));
    expect(snap.totalSeconds, greaterThanOrEqualTo(snap.remaining.inSeconds));
  });

  test('−15 shortens but never shrinks the denominator', () {
    seed(60, total: 60);
    RestTimerService.instance.adjust(-15);
    final snap = RestTimerService.instance.current.value!;
    expect(snap.remaining.inSeconds, inInclusiveRange(43, 45));
    expect(snap.totalSeconds, 60); // denominator unchanged on a shorten
  });

  test('−15 past zero cancels (acts as skip)', () {
    seed(8);
    RestTimerService.instance.adjust(-15);
    expect(RestTimerService.instance.current.value, isNull);
  });

  test('adjust is a no-op when no rest is active', () {
    RestTimerService.instance.cancel();
    RestTimerService.instance.adjust(15);
    expect(RestTimerService.instance.current.value, isNull);
  });
}
