import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/programs_library.dart';
import 'package:workout_track/models/program_models.dart';

void main() {
  ProgramDay workoutDay() => const ProgramDay(
    dayNumber: 1,
    type: ProgramDayType.workout,
    label: 'FULL BODY A',
    focus: MuscleFocus.fullBody,
    suggestedExerciseIds: [
      'Barbell_Squat',
      'Barbell_Bench_Press',
      'Barbell_Deadlift',
    ],
    prescription: {
      'Barbell_Squat': SetRepScheme(sets: 3, repMin: 8),
      'Barbell_Bench_Press': SetRepScheme(sets: 3, repMin: 8),
      'Barbell_Deadlift': SetRepScheme(sets: 3, repMin: 5),
    },
  );

  group('applyProgramSwaps', () {
    test('empty swaps returns the same day instance', () {
      final day = workoutDay();
      expect(identical(applyProgramSwaps(day, const {}), day), isTrue);
    });

    test('rest day is never modified', () {
      const rest = ProgramDay(
        dayNumber: 7,
        type: ProgramDayType.rest,
        label: 'REST',
      );
      expect(
        identical(applyProgramSwaps(rest, const {'x': 'y'}), rest),
        isTrue,
      );
    });

    test('a swap that does not touch this day returns the same instance', () {
      final day = workoutDay();
      final out = applyProgramSwaps(day, const {'Some_Other': 'Whatever'});
      expect(identical(out, day), isTrue);
    });

    test('remaps the id in order and re-keys the prescription', () {
      final out = applyProgramSwaps(
        workoutDay(),
        const {'Barbell_Squat': 'Goblet_Squat'},
      );
      expect(out.suggestedExerciseIds, [
        'Goblet_Squat',
        'Barbell_Bench_Press',
        'Barbell_Deadlift',
      ]);
      expect(out.prescription.containsKey('Barbell_Squat'), isFalse);
      // Replacement inherits the original's scheme.
      expect(out.prescription['Goblet_Squat']?.repMin, 8);
      // Untouched lift keeps its own scheme.
      expect(out.prescription['Barbell_Deadlift']?.repMin, 5);
      // Day metadata is preserved.
      expect(out.dayNumber, 1);
      expect(out.label, 'FULL BODY A');
      expect(out.focus, MuscleFocus.fullBody);
    });

    test('dedupes when a replacement collides with an existing lift', () {
      final out = applyProgramSwaps(
        workoutDay(),
        const {'Barbell_Deadlift': 'Barbell_Bench_Press'},
      );
      expect(out.suggestedExerciseIds, [
        'Barbell_Squat',
        'Barbell_Bench_Press',
      ]);
      expect(
        out.suggestedExerciseIds
            .where((e) => e == 'Barbell_Bench_Press')
            .length,
        1,
      );
    });

    test('a swap on a lift that recurs across days fixes each occurrence', () {
      const dayA = ProgramDay(
        dayNumber: 1,
        type: ProgramDayType.workout,
        label: 'A',
        focus: MuscleFocus.fullBody,
        suggestedExerciseIds: ['Barbell_Squat', 'Pullups'],
        prescription: {'Barbell_Squat': SetRepScheme(sets: 3, repMin: 8)},
      );
      const dayC = ProgramDay(
        dayNumber: 5,
        type: ProgramDayType.workout,
        label: 'C',
        focus: MuscleFocus.fullBody,
        suggestedExerciseIds: ['Barbell_Squat', 'Pushups'],
        prescription: {'Barbell_Squat': SetRepScheme(sets: 3, repMin: 8)},
      );
      const swaps = {'Barbell_Squat': 'Goblet_Squat'};
      expect(applyProgramSwaps(dayA, swaps).suggestedExerciseIds.first,
          'Goblet_Squat');
      expect(applyProgramSwaps(dayC, swaps).suggestedExerciseIds.first,
          'Goblet_Squat');
    });
  });
}
