import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/programs_library.dart';
import 'package:workout_track/models/rest_models.dart';
import 'package:workout_track/services/loot_service.dart';
import 'package:workout_track/services/program_customization_service.dart';
import 'package:workout_track/services/program_service.dart';
import 'package:workout_track/services/rest_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts program at week 1, workout 0', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));

    final progress = await service.startProgram('full_body_3x');

    expect(progress.programId, 'full_body_3x');
    expect(progress.currentWeek, 1);
    expect(progress.workoutIndex, 0);
    expect(progress.completedSessions, 0);
  });

  test('a completed workout advances the workout-only index by one', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('full_body_3x');

    final progress = await service.advanceDay(now: DateTime(2026, 5, 11));

    expect(progress?.workoutIndex, 1);
    expect(progress?.completedSessions, 1);
  });

  test('a full cycle of workouts wraps the week (rest slots dropped)', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('ppl'); // 6 workouts

    for (var i = 0; i < 6; i++) {
      await service.advanceDay(now: DateTime(2026, 5, 11 + i));
    }
    final progress = await service.getActiveProgress(
      now: DateTime(2026, 5, 17),
    );

    expect(progress?.currentWeek, 2);
    expect(progress?.workoutIndex, 0); // wrapped 0..5 -> 0
    expect(progress?.completedSessions, 6);
  });

  test('double completion on same date does not advance twice', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('upper_lower');

    await service.advanceDay(now: DateTime(2026, 5, 11));
    await service.advanceDay(now: DateTime(2026, 5, 11));
    final progress = await service.getActiveProgress(
      now: DateTime(2026, 5, 11),
    );

    expect(progress?.workoutIndex, 1);
    expect(progress?.completedSessions, 1);
  });

  test('getTodayDay surfaces the next workout on a training weekday', () async {
    // 2026-05-11 is a Monday; default training weekdays {1,3,5} include it.
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('full_body_3x');

    final day = await service.getTodayDay(now: DateTime(2026, 5, 11));
    expect(day?.isWorkout, isTrue);
    expect(day?.label, 'FULL BODY A');
  });

  test('getTodayDay returns calendar REST on a non-training weekday', () async {
    // 2026-05-12 is a Tuesday; {1,3,5} excludes it -> calendar rest.
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 12));
    await service.startProgram('full_body_3x');

    final day = await service.getTodayDay(now: DateTime(2026, 5, 12));
    expect(day?.isWorkout, isFalse);
    expect(day?.label, 'REST');
  });

  test('quit clears active progress', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('ppl');

    await service.quitProgram();

    expect(await service.getActiveProgress(), isNull);
  });

  test('program rest date can be registered with RestService', () async {
    final restService = RestService(nowProvider: () => DateTime(2026, 5, 12));
    final state = await restService.addProgramPlannedRestDate(
      DateTime(2026, 5, 12),
    );

    final info = restService.dayInfoForState(
      day: DateTime(2026, 5, 12),
      sessions: const [],
      state: state,
      now: DateTime(2026, 5, 12),
    );

    expect(state.programRestDateKeys, contains('2026-05-12'));
    expect(info.kind, RestDayKind.plannedRest);
  });

  test('program rest date is not treated as missed training', () async {
    final restService = RestService(nowProvider: () => DateTime(2026, 5, 12));
    final state = await restService.addProgramPlannedRestDate(
      DateTime(2026, 5, 11),
    );

    final missed = restService.missedTrainingDaysSinceForState(
      sessions: const [],
      state: state,
      since: DateTime(2026, 5, 10),
      now: DateTime(2026, 5, 12),
    );

    expect(missed, isEmpty);
  });

  test(
    'program training date blocks automatic recovery on rest weekday',
    () async {
      final restService = RestService(nowProvider: () => DateTime(2026, 5, 12));
      final state = await restService.addProgramTrainingDate(
        DateTime(2026, 5, 12),
      );

      final updated = await restService.ensureAutomaticRecoveryForToday(
        sessions: const [],
        baseXP: 0,
        state: state,
      );
      final info = restService.dayInfoForState(
        day: DateTime(2026, 5, 12),
        sessions: const [],
        state: updated,
        now: DateTime(2026, 5, 12),
      );

      expect(updated.programTrainingDateKeys, contains('2026-05-12'));
      expect(info.kind, RestDayKind.trainingDay);
      expect(updated.recoveryClaims, isEmpty);
    },
  );

  test('targetSessions is daysPerWeek times recommendedWeeks', () {
    expect(programById('full_body_3x')!.targetSessions, 24);
    expect(programById('upper_lower')!.targetSessions, 32);
    expect(programById('ppl')!.targetSessions, 48);
  });

  test('arc progress increments once per completed workout', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('full_body_3x');

    await service.advanceDay(now: DateTime(2026, 5, 11));
    final afterOne = await service.getActiveProgress(now: DateTime(2026, 5, 11));
    await service.advanceDay(now: DateTime(2026, 5, 13));
    final afterTwo = await service.getActiveProgress(now: DateTime(2026, 5, 13));

    expect(afterOne?.arcSessions, 1);
    expect(afterTwo?.arcSessions, 2);
  });

  test('completion fires once at target, grants title, sets arc', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('full_body_3x');
    await _seedCompletedSessions(24);

    final completion = await service.evaluateCompletion(
      now: DateTime(2026, 5, 11),
    );
    expect(completion, isNotNull);
    expect(completion!.programId, 'full_body_3x');
    expect(completion.titleId, 'title_foundation_forged');
    expect(completion.sessions, 24);

    final owned = await LootService().getInventory();
    expect(owned.any((i) => i.id == 'title_foundation_forged'), isTrue);

    final progress = await service.getActiveProgress(
      now: DateTime(2026, 5, 11),
    );
    expect(progress?.completedArc, isTrue);

    // Second call must not re-fire.
    final again = await service.evaluateCompletion(now: DateTime(2026, 5, 11));
    expect(again, isNull);
    expect((await service.completedPrograms()).length, 1);
  });

  test('evaluateCompletion returns null before target', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('full_body_3x');
    await _seedCompletedSessions(23);
    expect(
      await service.evaluateCompletion(now: DateTime(2026, 5, 11)),
      isNull,
    );
  });

  test('pending completion reveal is consumed exactly once', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('full_body_3x');
    await _seedCompletedSessions(24);
    await service.evaluateCompletion(now: DateTime(2026, 5, 11));

    final first = await service.consumePendingCompletionReveal();
    final second = await service.consumePendingCompletionReveal();
    expect(first?.titleId, 'title_foundation_forged');
    expect(second, isNull);
  });

  test('beginNextPath starts the chained program with a fresh arc', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('full_body_3x');
    await _seedCompletedSessions(24);
    await service.evaluateCompletion(now: DateTime(2026, 5, 11));

    final next = await service.beginNextPath();
    expect(next?.programId, 'upper_lower');
    expect(next?.completedSessions, 0);
    expect(next?.arcStartSessions, 0);
    expect(next?.completedArc, isFalse);
  });

  test(
    'stayWithProgram rolls the arc baseline without wiping history',
    () async {
      final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
      await service.startProgram('ppl');
      await _seedCompletedSessions(48);
      await service.evaluateCompletion(now: DateTime(2026, 5, 11));

      final rolled = await service.stayWithProgram();
      expect(rolled?.programId, 'ppl');
      expect(rolled?.completedSessions, 48); // lifetime history kept
      expect(rolled?.arcStartSessions, 48); // fresh finish line
      expect(rolled?.arcSessions, 0);
      expect(rolled?.completedArc, isFalse);
    },
  );

  group('prescriptionsForOngoingSession', () {
    test('empty for a session not marked as a program session', () async {
      final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
      await service.startProgram('full_body_3x');
      await service.markOngoingProgramSession('session-a');

      expect(await service.prescriptionsForOngoingSession('other'), isEmpty);
    });

    test('rebuilds the current workout day prescriptions', () async {
      final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
      await service.startProgram('full_body_3x');
      await service.markOngoingProgramSession('session-a');

      final prescriptions = await service.prescriptionsForOngoingSession(
        'session-a',
      );

      // FULL BODY A (day 1) prescribes 5 lifts.
      expect(prescriptions.length, 5);
      expect(prescriptions['Barbell_Squat']?.sets, 3);
      expect(prescriptions['Barbell_Squat']?.repMin, 8);
    });

    test('re-keys prescriptions through permanent swaps', () async {
      final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
      await service.startProgram('full_body_3x');
      await ProgramCustomizationService().setSwap(
        'full_body_3x',
        'Barbell_Squat',
        'Goblet_Squat',
      );
      await service.markOngoingProgramSession('session-a');

      final prescriptions = await service.prescriptionsForOngoingSession(
        'session-a',
      );

      expect(prescriptions.containsKey('Barbell_Squat'), isFalse);
      expect(prescriptions['Goblet_Squat']?.repMin, 8);
    });

    test('off-anchor (forgiveness) training still gets its prescriptions',
        () async {
      // Under the weekday-anchored schedule the in-session workout is the active
      // workout-index slot regardless of weekday, so an off-anchor session keeps
      // its TARGET banners (the prescriptions are not empty).
      final service = ProgramService(nowProvider: () => DateTime(2026, 5, 12));
      await service.startProgram('full_body_3x');
      await service.advanceDay(now: DateTime(2026, 5, 11)); // now on FULL BODY B
      await service.markOngoingProgramSession(
        'session-a',
        restDayWorkout: true,
      );

      final prescriptions =
          await service.prescriptionsForOngoingSession('session-a');
      expect(prescriptions.length, 5); // FULL BODY B's five lifts
    });
  });
}

/// Seeds the stored arc counter directly so completion can be exercised without
/// logging dozens of real workout days. Honest in tests: only the counter the
/// real advance flow would have produced is written.
Future<void> _seedCompletedSessions(int value) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(ProgramService.progressKey)!;
  final json = jsonDecode(raw) as Map<String, dynamic>;
  json['completedSessions'] = value;
  await prefs.setString(ProgramService.progressKey, jsonEncode(json));
}
