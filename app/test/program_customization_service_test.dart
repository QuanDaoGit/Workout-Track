import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/program_models.dart';
import 'package:workout_track/services/program_customization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProgramCustomizationService service() => ProgramCustomizationService();

  test('no swaps by default', () async {
    expect(await service().swapsFor('full_body_3x'), isEmpty);
  });

  test('set/get round-trips and isolates per program', () async {
    final s = service();
    await s.setSwap('full_body_3x', 'Barbell_Squat', 'Goblet_Squat');
    expect(await s.swapsFor('full_body_3x'), {'Barbell_Squat': 'Goblet_Squat'});
    expect(await s.swapsFor('ppl'), isEmpty);
  });

  test('a self-swap clears rather than stores', () async {
    final s = service();
    await s.setSwap('full_body_3x', 'Barbell_Squat', 'Goblet_Squat');
    await s.setSwap('full_body_3x', 'Barbell_Squat', 'Barbell_Squat');
    expect(await s.swapsFor('full_body_3x'), isEmpty);
  });

  test('removeSwap reverts one lift, leaving others', () async {
    final s = service();
    await s.setSwap('full_body_3x', 'A', 'B');
    await s.setSwap('full_body_3x', 'C', 'D');
    await s.removeSwap('full_body_3x', 'A');
    expect(await s.swapsFor('full_body_3x'), {'C': 'D'});
  });

  test('clearSwaps drops all swaps for one program only', () async {
    final s = service();
    await s.setSwap('full_body_3x', 'A', 'B');
    await s.setSwap('ppl', 'C', 'D');
    await s.clearSwaps('full_body_3x');
    expect(await s.swapsFor('full_body_3x'), isEmpty);
    expect(await s.swapsFor('ppl'), {'C': 'D'});
  });

  test('swaps survive across service instances (persisted)', () async {
    await service().setSwap('full_body_3x', 'A', 'B');
    expect(await service().swapsFor('full_body_3x'), {'A': 'B'});
  });

  test('effectiveDay applies stored swaps to the loadout', () async {
    final s = service();
    await s.setSwap('full_body_3x', 'Barbell_Squat', 'Goblet_Squat');
    const day = ProgramDay(
      dayNumber: 1,
      type: ProgramDayType.workout,
      label: 'FULL BODY A',
      focus: MuscleFocus.fullBody,
      suggestedExerciseIds: ['Barbell_Squat', 'Barbell_Bench_Press'],
      prescription: {
        'Barbell_Squat': SetRepScheme(sets: 3, repMin: 8),
        'Barbell_Bench_Press': SetRepScheme(sets: 3, repMin: 8),
      },
    );
    final eff = await s.effectiveDay('full_body_3x', day);
    expect(eff.suggestedExerciseIds, ['Goblet_Squat', 'Barbell_Bench_Press']);
    expect(eff.prescription['Goblet_Squat']?.repMin, 8);
  });
}
