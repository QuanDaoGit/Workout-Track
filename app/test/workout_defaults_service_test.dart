import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/services/workout_defaults_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('duration defaults to 90 minutes when unset', () async {
    expect(
      await WorkoutDefaultsService().getDurationMinutes(),
      WorkoutDefaultsService.defaultDurationMinutes,
    );
  });

  test('duration persists and clamps to supported range', () async {
    final service = WorkoutDefaultsService();

    await service.setDurationMinutes(120);
    expect(await service.getDurationMinutes(), 120);

    await service.setDurationMinutes(5);
    expect(
      await service.getDurationMinutes(),
      WorkoutDefaultsService.minDurationMinutes,
    );

    await service.setDurationMinutes(999);
    expect(
      await service.getDurationMinutes(),
      WorkoutDefaultsService.maxDurationMinutes,
    );
  });

  test('rest seconds persists through existing rest preference key', () async {
    final service = WorkoutDefaultsService();

    await service.setRestSeconds(75);
    expect(await service.getRestSeconds(), 75);

    await service.setRestSeconds(5);
    expect(await service.getRestSeconds(), 30);

    await service.setRestSeconds(999);
    expect(await service.getRestSeconds(), 300);
  });
}
