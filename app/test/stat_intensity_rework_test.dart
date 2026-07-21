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

  test('v4 rules migration preserves legacy RANKS via a volume top-up — '
      'no archetype demotes at update and the very next session still moves '
      'the number', () async {
    final now = DateTime(2026, 6, 1, 10);
    final prefs = await SharedPreferences.getInstance();

    // A high-volume light-work veteran: big board under the old rules, little
    // intensity credit under the new — exactly who the conversion protects.
    // STR 480 / AGI 350 were rank B on the legacy ladder (300..600).
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
    final statEngine = StatEngine(nowProvider: () => now, catalog: catalog);
    // Rank preserved: legacy B stays at least B on the new ladder.
    expect(statEngine.getRank((stored['STR'] as num).toInt()), isNot('D'));
    expect(stored['STR'], greaterThanOrEqualTo(StatEngine.rankThresholdB));
    expect(stored['AGI'], greaterThanOrEqualTo(StatEngine.rankThresholdB));
    // Legacy END 200 was rank C.
    expect(stored['END'], greaterThanOrEqualTo(StatEngine.rankThresholdC));
    // The conversion is a volume top-up in the seed channel, NOT an output
    // floor — the old-unit floor blob is gone, so the next session's credit
    // moves the displayed number immediately (no frozen catch-up wall).
    expect(prefs.getString(StatEngine.grandfatherFloorKey), isNull);
    final seed =
        jsonDecode(prefs.getString(StatEngine.calibrationSeedKey)!)
            as Map<String, dynamic>;
    expect((seed['STR'] as num).toDouble(), greaterThan(0));
    expect((seed['AGI'] as num).toDouble(), greaterThan(0));
    expect(
      prefs.getInt('stats_rules_version_v1'),
      StatEngine.statsRulesVersion,
    );
    // The scale jump is suppressed — no fake board-jump delta.
    expect(await statEngine.getLastSessionDelta(), isEmpty);

    // Idempotent: a second boot changes nothing.
    final seedBefore = prefs.getString(StatEngine.calibrationSeedKey);
    await MigrationService.runStatsRecomputeIfRulesChanged();
    expect(prefs.getString(StatEngine.calibrationSeedKey), seedBefore);

    // The next real session moves the number (no output floor to sit under).
    final before = (stored['STR'] as num).toInt();
    await _seedSessions([
      for (var i = 0; i < 10; i++)
        _session(now.subtract(Duration(days: i + 1)), [
          _log('bench', weight: 20, reps: 25, sets: 3),
        ], id: 'light-$i'),
      _session(now, [_log('bench', weight: 100, reps: 8, sets: 5)], id: 'new'),
    ]);
    final after = await statEngine.calculateAllStats();
    expect(after['STR'], greaterThan(before));
  });

  test('v4 migration never promotes a legacy D-rank board', () async {
    final now = DateTime(2026, 6, 1, 10);
    final prefs = await SharedPreferences.getInstance();
    await _seedSessions([
      _session(now.subtract(const Duration(days: 1)), [
        _log('bench', weight: 20, reps: 8, sets: 1),
      ]),
    ]);
    await prefs.setString(
      StatEngine.combatStatsKey,
      jsonEncode({'STR': 60, 'VIT': 40, 'AGI': 30, 'END': 45, 'LCK': 0}),
    );

    await MigrationService.runStatsRecomputeIfRulesChanged();

    // No rank target existed (all legacy D), so no top-up seed was written.
    expect(prefs.getString(StatEngine.calibrationSeedKey), isNull);
  });

  test('fresh installs get no grandfather floor', () async {
    final prefs = await SharedPreferences.getInstance();
    await MigrationService.runStatsRecomputeIfRulesChanged();
    expect(prefs.getString(StatEngine.grandfatherFloorKey), isNull);
    expect(prefs.getString(StatEngine.calibrationSeedKey), isNull);
  });

  test('volumeForStat is the exact inverse of the v4 stat curve', () async {
    final now = DateTime(2026, 6, 1, 10);
    final prefs = await SharedPreferences.getInstance();
    await _seedSessions([]);
    await prefs.setString(
      StatEngine.calibrationSeedKey,
      jsonEncode({'STR': StatEngine.volumeForStat(4200)}),
    );
    final stats = await engine(now).calculateAllStats();
    expect(stats['STR'], 4200);
  });

  test('volumeForStat and enduranceForStat land exactly on every rank '
      'threshold (floor/fp-cbrt verify-nudge)', () {
    for (final target in const [1000, 3000, 6000, 9000, 19999]) {
      final gain = StatEngine.statGainFromVolume(
        StatEngine.volumeForStat(target),
      );
      expect(
        StatEngine.baseOutputStatValue + gain,
        target,
        reason: 'volumeForStat($target)',
      );
      final endGain = StatEngine.enduranceGainFromPoints(
        StatEngine.enduranceForStat(target),
      );
      expect(
        StatEngine.baseOutputStatValue + endGain,
        target,
        reason: 'enduranceForStat($target)',
      );
    }
    // Edges: at/below baseline resolves to zero volume; the cap resolves to a
    // volume the curve maps back to the cap (never statCap + base).
    expect(StatEngine.volumeForStat(StatEngine.baseOutputStatValue), 0);
    expect(StatEngine.volumeForStat(0), 0);
  });

  test('per-session gains stay visible even at S-rank volume (the pacing '
      'contract the old log curve broke)', () {
    // A representative session banks ~820 STR credit (12 working sets @60×8).
    final sessionCredit = 12 * StatEngine.intensityCreditForSet(60, 8) * 0.9;
    final sVolume = StatEngine.volumeForStat(StatEngine.rankThresholdS);
    final before = StatEngine.statGainFromVolume(sVolume);
    final after = StatEngine.statGainFromVolume(sVolume + sessionCredit);
    expect(after - before, greaterThanOrEqualTo(10));
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
