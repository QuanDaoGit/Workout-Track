import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/services/weekly_goal_service.dart';

/// The weekly train-days goal was untested. Pins the self-contained contract:
/// the [minGoalDays, maxGoalDays] clamp on both read and write, that a stored
/// value wins over the seed, and the default seed when there is no program or
/// calibration signal. (The program/freq seed branches are exercised elsewhere
/// via their owning services.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to the default seed with no program / calibration signal', () async {
    expect(
      await WeeklyGoalService().getGoalDays(),
      WeeklyGoalService.defaultGoalDays,
    );
  });

  test('setGoalDays clamps to [2, 7] on write', () async {
    final svc = WeeklyGoalService();

    await svc.setGoalDays(10);
    expect(await svc.getGoalDays(), 7);

    await svc.setGoalDays(1);
    expect(await svc.getGoalDays(), 2);

    await svc.setGoalDays(4);
    expect(await svc.getGoalDays(), 4);
  });

  test('a stored value wins over the seed', () async {
    final svc = WeeklyGoalService();
    await svc.setGoalDays(2); // seed would be 3; the explicit choice must win
    expect(await svc.getGoalDays(), 2);
  });

  test('getGoalDays re-clamps a corrupt out-of-range stored value', () async {
    // A directly-written out-of-band value (e.g. from a future/legacy build)
    // must still read back inside the band, never raw.
    SharedPreferences.setMockInitialValues({WeeklyGoalService.goalKey: 99});
    expect(await WeeklyGoalService().getGoalDays(), 7);
  });
}
