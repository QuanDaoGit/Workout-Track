import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/programs_library.dart';
import 'package:workout_track/models/program_models.dart';

void main() {
  group('SetRepScheme.label', () {
    test('fixed reps render as "sets × reps"', () {
      expect(const SetRepScheme(sets: 3, repMin: 8).label(), '3 × 8');
    });

    test('a range renders as "sets × min–max"', () {
      expect(
        const SetRepScheme(sets: 3, repMin: 8, repMax: 12).label(),
        '3 × 8–12',
      );
    });

    test('repMax defaults to repMin (fixed)', () {
      const s = SetRepScheme(sets: 3, repMin: 8);
      expect(s.repMax, 8);
      expect(s.isFixed, isTrue);
    });

    test('verboseLabel spells out sets and reps', () {
      expect(
        const SetRepScheme(sets: 3, repMin: 8).verboseLabel(),
        '3 sets × 8 reps',
      );
      expect(
        const SetRepScheme(sets: 3, repMin: 8, repMax: 12).verboseLabel(),
        '3 sets × 8–12 reps',
      );
    });
  });

  group('library prescriptions', () {
    test('every workout day prescribes all of its suggested exercises', () {
      for (final program in programsLibrary) {
        for (final day in program.weekSchedule.where((d) => d.isWorkout)) {
          for (final id in day.suggestedExerciseIds) {
            expect(
              day.prescription[id],
              isNotNull,
              reason: '${program.id} / ${day.label} missing prescription for $id',
            );
          }
        }
      }
    });

    test('rest days carry no prescription', () {
      for (final program in programsLibrary) {
        for (final day in program.weekSchedule.where((d) => !d.isWorkout)) {
          expect(day.prescription, isEmpty);
        }
      }
    });

    test('full body is linear; the splits are double progression', () {
      expect(
        programById('full_body_3x')!.progression,
        ProgressionScheme.linear,
      );
      expect(
        programById('upper_lower')!.progression,
        ProgressionScheme.doubleProgression,
      );
      expect(programById('ppl')!.progression, ProgressionScheme.doubleProgression);
    });
  });
}
