import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/migration_service.dart';
import 'package:workout_track/services/stat_engine.dart';

/// v3 intensity-currency rework: STR/AGI accumulate Epley e1RM-equivalent
/// credit per set (reps capped at 12) instead of raw tonnage; bodyweight sets
/// load %BW × per-session snapshot instead of a flat 40 kg; existing users are
/// grandfathered so the rules change never reads as lost progress.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const catalog = {'bench': 'chest', 'pushup': 'chest', 'dip': 'triceps'};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  StatEngine engine(DateTime now) =>
      StatEngine(nowProvider: () => now, catalog: catalog);

  test('heavy and light sessions of equal tonnage diverge in STR', () async {
    final now = DateTime(2026, 6, 1, 10);

    // Identical tonnage (1500 kg): heavy 3×5 @ 100 vs light 3×25 @ 20.
    await _seedSessions([
      _session(now, [_log('bench', weight: 100, reps: 5, sets: 3)]),
    ]);
    final heavy = (await engine(now).calculateAllStats())['STR']!;

    SharedPreferences.setMockInitialValues({});
    await _seedSessions([
      _session(now, [_log('bench', weight: 20, reps: 25, sets: 3)]),
    ]);
    final light = (await engine(now).calculateAllStats())['STR']!;

    expect(heavy, greaterThan(light));
    // Light work still moves the number — the hook survives the fidelity fix.
    expect(light, greaterThan(StatEngine.baseOutputStatValue));
  });

  test('a single heavy set cannot dominate consistent training', () async {
    final now = DateTime(2026, 6, 1, 10);

    await _seedSessions([
      _session(now, [_log('bench', weight: 180, reps: 1, sets: 1)]),
    ]);
    final oneMax = (await engine(now).calculateAllStats())['STR']!;

    SharedPreferences.setMockInitialValues({});
    await _seedSessions([
      _session(now, [_log('bench', weight: 100, reps: 5, sets: 5)]),
    ]);
    final consistent = (await engine(now).calculateAllStats())['STR']!;

    expect(consistent, greaterThan(oneMax));
  });

  test('reps above 12 stop adding strength credit (no high-rep farming)', () {
    expect(
      StatEngine.intensityCreditForSet(20, 25),
      StatEngine.intensityCreditForSet(20, 12),
    );
    expect(
      StatEngine.intensityCreditForSet(20, 12),
      greaterThan(StatEngine.intensityCreditForSet(20, 8)),
    );
  });

  test('heavy bench outranks bodyweight push-ups for STR', () async {
    final now = DateTime(2026, 6, 1, 10);

    // The old flat-40 tonnage model scored 3×25 push-ups (3000 kg) above a
    // heavy 3×5 bench (1500 kg). Inverted now.
    await _seedSessions([
      _session(now, [_log('pushup', weight: 0, reps: 25, sets: 3)]),
    ]);
    final pushups = (await engine(now).calculateAllStats())['STR']!;

    SharedPreferences.setMockInitialValues({});
    await _seedSessions([
      _session(now, [_log('bench', weight: 100, reps: 5, sets: 3)]),
    ]);
    final bench = (await engine(now).calculateAllStats())['STR']!;

    expect(bench, greaterThan(pushups));
  });

  test('bodyweight credit uses the per-session snapshot with carry-forward '
      'and deterministic fallback', () async {
    final now = DateTime(2026, 6, 1, 10);
    final log = _log('dip', weight: 0, reps: 8, sets: 3);

    // No snapshot anywhere → deterministic 70 kg fallback.
    await _seedSessions([_session(now, [log])]);
    final fallback = (await engine(now).calculateAllStats())['STR']!;
    expect(fallback, greaterThan(StatEngine.baseOutputStatValue));

    // A 100 kg athlete's snapshot raises the credit for the same sets.
    SharedPreferences.setMockInitialValues({});
    await _seedSessions([_session(now, [log], bodyweightKg: 100)]);
    final heavyAthlete = (await engine(now).calculateAllStats())['STR']!;
    expect(heavyAthlete, greaterThan(fallback));

    // A later snapshotless session carries the last-known snapshot forward —
    // history is frozen; profile edits can never rewrite it.
    SharedPreferences.setMockInitialValues({});
    await _seedSessions([
      _session(now, [log], bodyweightKg: 100, id: 'with-snapshot'),
      _session(now.add(const Duration(days: 1)), [log], id: 'without'),
    ]);
    final carried = (await engine(now).calculateAllStats())['STR']!;

    SharedPreferences.setMockInitialValues({});
    await _seedSessions([
      _session(now, [log], bodyweightKg: 100, id: 'with-snapshot'),
      _session(
        now.add(const Duration(days: 1)),
        [log],
        bodyweightKg: 100,
        id: 'without',
      ),
    ]);
    final explicit = (await engine(now).calculateAllStats())['STR']!;
    expect(carried, explicit);
  });

  test('rules migration grandfathers tonnage-era stats — no archetype drops '
      'at update', () async {
    final now = DateTime(2026, 6, 1, 10);
    final prefs = await SharedPreferences.getInstance();

    // A high-volume light-work veteran: big board under tonnage rules, little
    // intensity credit under v3 — exactly who the floor protects.
    await _seedSessions([
      for (var i = 0; i < 10; i++)
        _session(now.subtract(Duration(days: i + 1)), [
          _log('bench', weight: 20, reps: 25, sets: 3),
        ], id: 'light-$i'),
    ]);
    await prefs.setString(
      StatEngine.combatStatsKey,
      jsonEncode({
        'STR': 480,
        'DEF': 300,
        'VIT': 80,
        'AGI': 350,
        'END': 200,
        'LCK': 2,
      }),
    );

    await MigrationService.runStatsRecomputeIfRulesChanged();

    final stored =
        jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
            as Map<String, dynamic>;
    expect(stored['STR'], greaterThanOrEqualTo(480));
    expect(stored['AGI'], greaterThanOrEqualTo(350));
    expect(
      jsonDecode(prefs.getString(StatEngine.grandfatherFloorKey)!),
      {'STR': 480, 'AGI': 350},
    );
    expect(
      prefs.getInt('stats_rules_version_v1'),
      StatEngine.statsRulesVersion,
    );

    // Decay cannot take the board below the grandfathered floor either.
    await prefs.setDouble('combat_decay_factor_v1', 0.5);
    final decayed = await StatEngine(
      nowProvider: () => now,
      catalog: catalog,
    ).calculateAllStats();
    expect(decayed['STR'], greaterThanOrEqualTo(480));
  });

  test('fresh installs get no grandfather floor', () async {
    final prefs = await SharedPreferences.getInstance();
    await MigrationService.runStatsRecomputeIfRulesChanged();
    expect(prefs.getString(StatEngine.grandfatherFloorKey), isNull);
  });

  test('volumeForStat is the exact inverse of the v3 stat curve', () async {
    final now = DateTime(2026, 6, 1, 10);
    final prefs = await SharedPreferences.getInstance();
    await _seedSessions([]);
    await prefs.setString(
      StatEngine.calibrationSeedKey,
      jsonEncode({'STR': StatEngine.volumeForStat(420)}),
    );
    final stats = await engine(now).calculateAllStats();
    expect(stats['STR'], 420);
  });
}

Future<void> _seedSessions(List<WorkoutSession> sessions) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'workout_sessions',
    jsonEncode([for (final s in sessions) s.toJson()]),
  );
}

WorkoutSession _session(
  DateTime date,
  List<ExerciseLog> logs, {
  String id = 'session',
  double? bodyweightKg,
}) {
  return WorkoutSession(
    id: id,
    date: date,
    muscleGroup: 'Chest',
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    exercises: logs,
    estimatedCalories: 100,
    bodyweightKgAtSave: bodyweightKg,
  );
}

ExerciseLog _log(
  String id, {
  required double weight,
  required int reps,
  int sets = 1,
}) {
  return ExerciseLog(
    exerciseId: id,
    exerciseName: id,
    sets: [for (var i = 0; i < sets; i++) SetEntry(weight: weight, reps: reps)],
  );
}
