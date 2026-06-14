import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/ongoing_program_swap_service.dart';
import 'package:workout_track/services/workout_storage_service.dart';

WorkoutSession _session(String id, {bool isPartial = false, bool isAbandoned = false}) =>
    WorkoutSession(
      id: id,
      date: DateTime(2026, 5, 10),
      muscleGroup: 'Chest',
      targetMuscleGroups: const ['Chest'],
      targetDurationMinutes: 30,
      actualDurationSeconds: 600,
      exercises: const [],
      estimatedCalories: 50,
      isPartial: isPartial,
      isAbandoned: isAbandoned,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round-trips and clears per session id', () async {
    final svc = OngoingProgramSwapService();
    await svc.setSwaps('s1', {'a': 'b'});
    await svc.setSwaps('s2', {'c': 'd'});
    expect(await svc.swapsFor('s1'), {'a': 'b'});
    expect(await svc.swapsFor('s2'), {'c': 'd'});

    await svc.clear('s1');
    expect(await svc.swapsFor('s1'), isEmpty);
    expect(await svc.swapsFor('s2'), {'c': 'd'});
  });

  test('setSwaps with an empty map clears the row', () async {
    final svc = OngoingProgramSwapService();
    await svc.setSwaps('s1', {'a': 'b'});
    await svc.setSwaps('s1', {});
    expect(await svc.swapsFor('s1'), isEmpty);
  });

  group('storage terminal paths clear the swap store (F3)', () {
    test('finish (completed saveSession) clears', () async {
      await OngoingProgramSwapService().setSwaps('s1', {'a': 'b'});
      await WorkoutStorageService().saveSession(_session('s1'));
      expect(await OngoingProgramSwapService().swapsFor('s1'), isEmpty);
    });

    test('discard (deleteSession) clears', () async {
      await OngoingProgramSwapService().setSwaps('s1', {'a': 'b'});
      await WorkoutStorageService().deleteSession('s1');
      expect(await OngoingProgramSwapService().swapsFor('s1'), isEmpty);
    });

    test('abandon (replaceOngoingWithAbandoned) clears', () async {
      await OngoingProgramSwapService().setSwaps('s1', {'a': 'b'});
      await WorkoutStorageService()
          .replaceOngoingWithAbandoned(_session('s1', isPartial: true, isAbandoned: true));
      expect(await OngoingProgramSwapService().swapsFor('s1'), isEmpty);
    });
  });
}
