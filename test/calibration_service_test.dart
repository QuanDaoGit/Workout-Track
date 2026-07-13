import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/strength_standards.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/calibration_service.dart';
import 'package:workout_track/services/stat_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // exerciseId -> primary muscle, mirroring StatEngine's catalog shape.
  const catalog = {
    'bench': 'chest', // STR
    'row': 'lats', // STR (back)
    'squat': 'quadriceps', // STR/END (legs)
    'press': 'shoulders', // AGI
  };

  StatEngine engine(DateTime now) =>
      StatEngine(nowProvider: () => now, catalog: catalog);
  CalibrationService service(DateTime now) =>
      CalibrationService(statEngine: engine(now));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Epley estimates 1RM and ignores high-rep / unweighted sets', () {
    expect(CalibrationService.epley1Rm(80, 8), closeTo(101.33, 0.01));

    final log = ExerciseLog(
      exerciseId: 'bench',
      exerciseName: 'bench',
      sets: const [
        SetEntry(weight: 80, reps: 8), // 101.33 (best)
        SetEntry(weight: 60, reps: 20), // ignored (>12 reps)
        SetEntry(weight: 0, reps: 5), // ignored (no load)
      ],
    );
    expect(CalibrationService.bestOneRmForLog(log), closeTo(101.33, 0.01));
  });

  test(
    'seed lands the stat in the intended tier/rank (with bodyweight)',
    () async {
      final now = DateTime(2026, 5, 14, 10);
      // 100kg x 5 -> 1RM 116.67; at 80kg BW ratio 1.458 -> advanced -> target 650.
      final session = _session(now, [_log('bench', weight: 100, reps: 5)]);
      await _seedSessions([session]);

      final svc = service(now);
      await svc.saveCalibrationInputs(
        bodyweightKg: 80,
        sex: UserProfileSex.male,
      );
      await svc.recordCalibrationWorkout(session, catalog: catalog);

      final stats = await engine(now).calculateAllStats();
      expect(stats['STR'], 650);
      expect(engine(now).getRank(stats['STR']!), 'A');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(CalibrationService.calibrationSeedSourceKey),
        CalibrationService.workoutSeedSource,
      );
    },
  );

  test('intermediate ratio yields a felt D->B leap', () async {
    final now = DateTime(2026, 5, 14, 10);
    // 100kg x 5 -> 1RM 116.67; at 110kg BW ratio 1.06 -> intermediate -> 420 (B).
    final session = _session(now, [_log('bench', weight: 100, reps: 5)]);
    await _seedSessions([session]);

    final svc = service(now);
    await svc.saveCalibrationInputs(
      bodyweightKg: 110,
      sex: UserProfileSex.male,
    );
    await svc.recordCalibrationWorkout(session, catalog: catalog);

    final stats = await engine(now).calculateAllStats();
    expect(stats['STR'], 420);
    expect(engine(now).getRank(stats['STR']!), 'B');
  });

  test('ratchet never lowers an established seed', () async {
    final now = DateTime(2026, 5, 14, 10);
    final svc = service(now);
    await svc.saveCalibrationInputs(bodyweightKg: 80, sex: UserProfileSex.male);

    // Session 1: heavy -> advanced seed.
    final heavy = _session(now, [_log('bench', weight: 100, reps: 5)]);
    await svc.recordCalibrationWorkout(heavy, catalog: catalog);
    final seedAfterHeavy = (await svc.seedVolumes())['STR']!;

    // Session 2: light -> would only justify a beginner seed.
    final light = _session(now, [_log('bench', weight: 40, reps: 5)]);
    await svc.recordCalibrationWorkout(light, catalog: catalog);
    final seedAfterLight = (await svc.seedVolumes())['STR']!;

    expect(seedAfterLight, seedAfterHeavy);
  });

  test('no-bodyweight fallback caps at intermediate', () async {
    final now = DateTime(2026, 5, 14, 10);
    // Very heavy single -> would be elite with BW, but no BW means cap at
    // intermediate (target 420 / rank B), never advanced/elite.
    final session = _session(now, [_log('bench', weight: 200, reps: 5)]);
    await _seedSessions([session]);

    final svc = service(now);
    await svc.saveCalibrationInputs(sex: UserProfileSex.preferNotToSay);
    await svc.recordCalibrationWorkout(session, catalog: catalog);

    final stats = await engine(now).calculateAllStats();
    expect(stats['STR'], 420);
    expect(engine(now).getRank(stats['STR']!), 'B');
    expect(
      StrengthStandards.tierForAbsolute1RM(1000),
      StrengthTier.intermediate,
    );
  });

  test('calibration freezes after 3 sessions', () async {
    final now = DateTime(2026, 5, 14, 10);
    final svc = service(now);
    await svc.saveCalibrationInputs(bodyweightKg: 80, sex: UserProfileSex.male);

    final s = _session(now, [_log('bench', weight: 100, reps: 5)]);
    await svc.recordCalibrationWorkout(s, catalog: catalog);
    expect(await svc.isComplete(), isFalse);
    await svc.recordCalibrationWorkout(s, catalog: catalog);
    expect(await svc.isComplete(), isFalse);
    await svc.recordCalibrationWorkout(s, catalog: catalog);
    expect(await svc.isComplete(), isTrue);

    // Further heavy sessions are ignored once frozen.
    final frozen = (await svc.seedVolumes())['STR']!;
    final heavier = _session(now, [_log('bench', weight: 300, reps: 5)]);
    await svc.recordCalibrationWorkout(heavier, catalog: catalog);
    expect((await svc.seedVolumes())['STR']!, frozen);
  });

  test(
    'Gap-1: seeded stats persist through recompute; deltas exclude the seed',
    () async {
      final day1 = DateTime(2026, 5, 13, 10);
      final day2 = DateTime(2026, 5, 14, 10);
      final calibration = _session(day1, [
        _log('bench', weight: 100, reps: 5),
      ], id: 'cal');

      // Seed STR from the calibration session.
      await _seedSessions([calibration]);
      final svc = service(day1);
      await svc.saveCalibrationInputs(
        bodyweightKg: 80,
        sex: UserProfileSex.male,
      );
      await svc.recordCalibrationWorkout(calibration, catalog: catalog);

      // Establish the board the user sees after calibration (seeded STR) so the
      // next recompute measures its delta against the already-seeded value —
      // the seed is a constant in both, so it never shows as a per-session gain.
      await engine(day1).calculateAllStats();

      // A later, unrelated normal session that trains a DIFFERENT stat than the
      // seeded STR — shoulder press feeds AGI (chest/back/legs all feed STR, so
      // press gives a clean non-STR signal).
      final later = _session(day2, [
        _log('press', weight: 100, reps: 5),
      ], id: 'later');
      await _seedSessions([calibration, later]);

      final eng = engine(day2);
      final stats = await eng.calculateAllStats();
      final delta = await eng.getLastSessionDelta();

      // Calibrated STR survives the recompute (not erased by the new session).
      expect(stats['STR'], 650);
      // The new session touched AGI, not STR; the constant seed never appears
      // as a per-session delta.
      expect(delta.containsKey('STR'), isFalse);
      expect(delta['AGI'], greaterThan(0));
    },
  );

  group('quiz preferences do not seed stats', () {
    test('saving experience keeps no-workout stats at baseline', () async {
      final now = DateTime(2026, 5, 14, 10);
      final svc = service(now);

      await svc.saveTrainingPreferences(
        freq: TrainingFreq.mid,
        exp: Experience.intermediate,
      );

      expect(await svc.trainingFreq(), TrainingFreq.mid);
      expect(await svc.experience(), Experience.intermediate);
      expect(await svc.seedVolumes(), isEmpty);
      expect(await svc.isComplete(), isFalse);

      final stats = await engine(now).calculateAllStats();
      expect(stats['STR'], StatEngine.baseOutputStatValue);
      expect(stats['AGI'], StatEngine.baseOutputStatValue);
      expect(stats['END'], StatEngine.baseOutputStatValue);
      expect(stats['VIT'], StatEngine.baseOutputStatValue);
      expect(stats['LCK'], 0);
    });
  });

  group('auto-calibration on early workouts', () {
    test('calibrates within the opening session window', () async {
      final now = DateTime(2026, 5, 14, 10);
      final session = _session(now, [
        _log('bench', weight: 100, reps: 5),
      ], id: 'w1');
      final svc = service(now);
      await svc.saveCalibrationInputs(
        bodyweightKg: 80,
        sex: UserProfileSex.male,
      );

      await svc.maybeCalibrateEarlyWorkout(
        session,
        completedSessionCount: 1,
        catalog: catalog,
      );

      // 100x5 @ 80kg BW -> advanced -> a STR seed is written.
      expect((await svc.seedVolumes())['STR'], greaterThan(0));
    });

    test('does not seed an established user (beyond the window)', () async {
      final now = DateTime(2026, 5, 14, 10);
      final session = _session(now, [
        _log('bench', weight: 100, reps: 5),
      ], id: 'w');
      final svc = service(now);
      await svc.saveCalibrationInputs(
        bodyweightKg: 80,
        sex: UserProfileSex.male,
      );

      await svc.maybeCalibrateEarlyWorkout(
        session,
        completedSessionCount: 50,
        catalog: catalog,
      );

      // No seed written → no retroactive inflation of earned stats.
      expect(await svc.seedVolumes(), isEmpty);
    });
  });
}

Future<void> _seedSessions(List<WorkoutSession> sessions) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'workout_sessions',
    jsonEncode(sessions.map((s) => s.toJson()).toList()),
  );
}

WorkoutSession _session(
  DateTime date,
  List<ExerciseLog> logs, {
  String id = 'session',
}) {
  return WorkoutSession(
    id: id,
    date: date,
    muscleGroup: 'Chest',
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    exercises: logs,
    estimatedCalories: 100,
  );
}

ExerciseLog _log(String id, {double weight = 50, int reps = 5, int sets = 1}) {
  return ExerciseLog(
    exerciseId: id,
    exerciseName: id,
    sets: [for (var i = 0; i < sets; i++) SetEntry(weight: weight, reps: reps)],
  );
}
