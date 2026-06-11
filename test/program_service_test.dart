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

  test('starts program at week 1 day 1', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));

    final progress = await service.startProgram('full_body_3x');

    expect(progress.programId, 'full_body_3x');
    expect(progress.currentWeek, 1);
    expect(progress.currentDayIndex, 0);
    expect(progress.completedSessions, 0);
  });

  test('workout day advances and increments completed sessions', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('full_body_3x');

    final progress = await service.advanceDay(now: DateTime(2026, 5, 11));

    expect(progress?.currentDayIndex, 1);
    expect(progress?.completedSessions, 1);
  });

  test('rest day advances without incrementing completed sessions', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('full_body_3x');
    await service.advanceDay(now: DateTime(2026, 5, 11));

    final progress = await service.advanceDay(now: DateTime(2026, 5, 12));

    expect(progress?.currentDayIndex, 2);
    expect(progress?.completedSessions, 1);
  });

  test('credited rest day stays visible today and rolls tomorrow', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('full_body_3x');
    await service.advanceDay(now: DateTime(2026, 5, 11));

    final snapshot = await service.creditRestDayForToday(
      now: DateTime(2026, 5, 12),
    );
    final sameDay = await service.getActiveProgress(now: DateTime(2026, 5, 12));
    final nextDay = await service.getActiveProgress(now: DateTime(2026, 5, 13));

    expect(snapshot?.dayIndex, 1);
    expect(sameDay?.currentDayIndex, 1);
    expect(nextDay?.currentDayIndex, 2);
    expect(nextDay?.completedSessions, 1);
  });

  test('end of week wraps to next week', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('ppl');

    for (var i = 0; i < 7; i++) {
      await service.advanceDay(now: DateTime(2026, 5, 11 + i));
    }
    final progress = await service.getActiveProgress(
      now: DateTime(2026, 5, 18),
    );

    expect(progress?.currentWeek, 2);
    expect(progress?.currentDayIndex, 0);
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

    expect(progress?.currentDayIndex, 1);
    expect(progress?.completedSessions, 1);
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

  test('arc progress counts only workout-day completions', () async {
    final service = ProgramService(nowProvider: () => DateTime(2026, 5, 11));
    await service.startProgram('full_body_3x');

    await service.advanceDay(now: DateTime(2026, 5, 11)); // workout day
    final afterWorkout = await service.getActiveProgress(
      now: DateTime(2026, 5, 11),
    );
    await service.advanceDay(now: DateTime(2026, 5, 12)); // rest day
    final afterRest = await service.getActiveProgress(
      now: DateTime(2026, 5, 12),
    );

    expect(afterWorkout?.arcSessions, 1);
    expect(afterRest?.arcSessions, 1);
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

    test('empty for a rest-day workout session', () async {
      final service = ProgramService(nowProvider: () => DateTime(2026, 5, 12));
      await service.startProgram('full_body_3x');
      // Advance past FULL BODY A onto the day-2 rest slot.
      await service.advanceDay(now: DateTime(2026, 5, 11));
      await service.markOngoingProgramSession(
        'session-a',
        restDayWorkout: true,
      );

      expect(
        await service.prescriptionsForOngoingSession('session-a'),
        isEmpty,
      );
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
