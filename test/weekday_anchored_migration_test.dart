import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/programs_library.dart';
import 'package:workout_track/models/program_models.dart';
import 'package:workout_track/services/migration_service.dart';
import 'package:workout_track/services/program_service.dart';

/// Pins the legacy 7-slot `currentDayIndex` → workout-only `workoutIndex`
/// mapping and the one-shot migration that seeds it, so a mid-program user is
/// neither stranded nor double-counted on first load after the weekday-anchor
/// update (Codex review finding #5).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fullBody = programById('full_body_3x')!; // [W,R,W,R,W,R,R] -> workouts A,B,C
  final ppl = programById('ppl')!; // [W,W,W,W,W,W,R] -> 6 workouts

  group('workoutIndexForLegacyDayIndex (pure)', () {
    test('legacy index on a workout slot maps to that workout position', () {
      // full body slot 2 (0-based) = FULL BODY B = workout position 1.
      expect(workoutIndexForLegacyDayIndex(fullBody, 2), 1);
      // slot 4 = FULL BODY C = position 2.
      expect(workoutIndexForLegacyDayIndex(fullBody, 4), 2);
    });

    test('legacy index parked on a REST slot resolves to the NEXT workout', () {
      // slot 1 = REST, next workout is slot 2 (B) = position 1.
      expect(workoutIndexForLegacyDayIndex(fullBody, 1), 1);
      // slot 3 = REST, next workout is slot 4 (C) = position 2.
      expect(workoutIndexForLegacyDayIndex(fullBody, 3), 2);
    });

    test('end-of-week rest slots wrap to the first workout', () {
      // slots 5 and 6 are REST; wrap to slot 0 (A) = position 0.
      expect(workoutIndexForLegacyDayIndex(fullBody, 5), 0);
      expect(workoutIndexForLegacyDayIndex(fullBody, 6), 0);
    });

    test('ppl with a single trailing rest maps the workout block directly', () {
      expect(workoutIndexForLegacyDayIndex(ppl, 0), 0);
      expect(workoutIndexForLegacyDayIndex(ppl, 5), 5);
      // slot 6 = REST, wraps to slot 0 = position 0.
      expect(workoutIndexForLegacyDayIndex(ppl, 6), 0);
    });
  });

  group('runWeekdayAnchoredScheduleOnce', () {
    test('seeds workoutIndex from a legacy rest-slot cursor', () async {
      final legacy = ProgramProgress(
        programId: 'full_body_3x',
        currentWeek: 1,
        currentDayIndex: 3, // a REST slot
        startedAt: DateTime(2026, 6, 1),
        completedSessions: 5,
        // workoutIndex left at default 0 (as legacy data would be)
      );
      SharedPreferences.setMockInitialValues({
        ProgramService.progressKey: jsonEncode(legacy.toJson()),
      });

      await MigrationService.runWeekdayAnchoredScheduleOnce();

      final prefs = await SharedPreferences.getInstance();
      final migrated = ProgramProgress.fromJson(
        jsonDecode(prefs.getString(ProgramService.progressKey)!)
            as Map<String, dynamic>,
      );
      expect(migrated.workoutIndex, 2); // slot 3 rest -> next workout C (pos 2)
      expect(migrated.completedSessions, 5); // untouched
      expect(prefs.getBool('migration_v_weekday_anchored_schedule_done'), true);
    });

    test('is idempotent and a second run does not re-map', () async {
      final legacy = ProgramProgress(
        programId: 'full_body_3x',
        currentWeek: 1,
        currentDayIndex: 2,
        startedAt: DateTime(2026, 6, 1),
        completedSessions: 0,
      );
      SharedPreferences.setMockInitialValues({
        ProgramService.progressKey: jsonEncode(legacy.toJson()),
      });

      await MigrationService.runWeekdayAnchoredScheduleOnce();
      final prefs = await SharedPreferences.getInstance();
      // Simulate later advancement, then re-run: must NOT clobber back.
      final advanced = ProgramProgress.fromJson(
        jsonDecode(prefs.getString(ProgramService.progressKey)!)
            as Map<String, dynamic>,
      ).copyWith(workoutIndex: 0);
      await prefs.setString(
        ProgramService.progressKey,
        jsonEncode(advanced.toJson()),
      );

      await MigrationService.runWeekdayAnchoredScheduleOnce();

      final after = ProgramProgress.fromJson(
        jsonDecode(prefs.getString(ProgramService.progressKey)!)
            as Map<String, dynamic>,
      );
      expect(after.workoutIndex, 0); // unchanged by the no-op second run
    });

    test('no active program is a clean no-op', () async {
      SharedPreferences.setMockInitialValues({});
      await MigrationService.runWeekdayAnchoredScheduleOnce();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ProgramService.progressKey), isNull);
      expect(prefs.getBool('migration_v_weekday_anchored_schedule_done'), true);
    });
  });
}
