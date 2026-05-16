import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/rest_models.dart';
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
}
