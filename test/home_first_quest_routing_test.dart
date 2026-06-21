import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/program_models.dart';
import 'package:workout_track/models/rest_models.dart';
import 'package:workout_track/pages/home.dart';

void main() {
  const day1 = ProgramDay(
    dayNumber: 1,
    type: ProgramDayType.workout,
    focus: MuscleFocus.fullBody,
    label: 'FULL BODY A',
  );

  ProgramProgress freshProgress() => ProgramProgress(
    programId: 'full_body_3x',
    currentWeek: 1,
    currentDayIndex: 0,
    workoutIndex: 0,
    startedAt: DateTime(2026, 1, 1),
    completedSessions: 0,
  );

  test('new user with a program → program Day-1 card (not a separate quest)', () {
    // The first session day is the program's weekday-agnostic active workout, so
    // it is always a workout (Day 1) — the headline merges into the program card.
    expect(newUserMissionShowsProgramDayOne(freshProgress(), day1), isTrue);
  });

  test('new user without a program → manual FIRST QUEST card', () {
    expect(newUserMissionShowsProgramDayOne(null, null), isFalse);
  });

  test('a non-workout first-session day never routes to the program card', () {
    const rest = ProgramDay(
      dayNumber: 0,
      type: ProgramDayType.rest,
      label: 'REST',
    );
    expect(newUserMissionShowsProgramDayOne(freshProgress(), rest), isFalse);
  });

  group('showsRestDayTrainPrompt — first-ever session bypasses the rest gate', () {
    RestDayInfo restDay({
      RestDayKind kind = RestDayKind.plannedRest,
      bool hasCompletedWorkout = false,
    }) => RestDayInfo(
      dateKey: '2026-06-21',
      kind: kind,
      isScheduledTrainingDay: kind == RestDayKind.trainingDay,
      hasCompletedWorkout: hasCompletedWorkout,
      hasRecoveryClaim: false,
      isProtected: false,
      recoveryXP: 0,
      shieldCharges: 0,
    );

    test('a brand-new user is exempt on a planned-rest day (no prompt)', () {
      expect(
        showsRestDayTrainPrompt(
          trainAnyway: false,
          isNewUser: true,
          restInfo: restDay(),
        ),
        isFalse,
      );
    });

    test('an established user still gets the prompt on a planned-rest day', () {
      expect(
        showsRestDayTrainPrompt(
          trainAnyway: false,
          isNewUser: false,
          restInfo: restDay(),
        ),
        isTrue,
      );
    });

    test('trainAnyway always bypasses the prompt', () {
      expect(
        showsRestDayTrainPrompt(
          trainAnyway: true,
          isNewUser: false,
          restInfo: restDay(),
        ),
        isFalse,
      );
    });

    test('no prompt when there is no rest info', () {
      expect(
        showsRestDayTrainPrompt(
          trainAnyway: false,
          isNewUser: false,
          restInfo: null,
        ),
        isFalse,
      );
    });

    test('no prompt on a training day', () {
      expect(
        showsRestDayTrainPrompt(
          trainAnyway: false,
          isNewUser: false,
          restInfo: restDay(kind: RestDayKind.trainingDay),
        ),
        isFalse,
      );
    });

    test('no prompt once the day already has a completed workout', () {
      expect(
        showsRestDayTrainPrompt(
          trainAnyway: false,
          isNewUser: false,
          restInfo: restDay(hasCompletedWorkout: true),
        ),
        isFalse,
      );
    });
  });
}
