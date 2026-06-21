import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/rest_models.dart';
import 'package:workout_track/models/stat_radar_read.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/migration_service.dart';
import 'package:workout_track/services/rest_service.dart';
import 'package:workout_track/services/stat_engine.dart';
import 'package:workout_track/services/xp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const catalog = {
    'bench': 'chest',
    'triceps': 'triceps',
    'curl': 'biceps',
    'row': 'lats',
    'press': 'shoulders',
    'lateral': 'shoulders',
    'squat': 'quadriceps',
    'rdl': 'hamstrings',
    'calf': 'calves',
    'crunch': 'abdominals',
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('new users start with baseline output stats and zero LCK', () async {
    final now = DateTime(2026, 5, 14, 10);
    await _seedSessions([]);

    final stats = await StatEngine(
      nowProvider: () => now,
      catalog: catalog,
    ).calculateAllStats();

    expect(stats, {
      'STR': 10,
      'DEF': 10,
      'VIT': 10,
      'AGI': 10,
      'END': 10,
      'LCK': 0,
    });
  });

  test('calculates weighted and bodyweight volume with cap', () async {
    final now = DateTime(2026, 5, 14, 10);
    await _seedSessions([
      _session(
        date: now,
        logs: [
          _log('bench', weight: 100, reps: 10, sets: 5),
          _log('triceps', weight: 0, reps: 10, sets: 2),
        ],
      ),
    ]);

    final stats = await StatEngine(
      nowProvider: () => now,
      catalog: catalog,
    ).calculateAllStats();
    // Intensity-credit currency: 5 × e1RM(100,10) for the bench, and the
    // bodyweight triceps sets load 0.65 × 70 kg fallback bodyweight.
    final benchCredit = 5 * StatEngine.intensityCreditForSet(100, 10);
    final bodyweightCredit =
        2 * StatEngine.intensityCreditForSet(0.65 * 70, 10);
    final expected = _statFromVolume(benchCredit + bodyweightCredit);

    expect(stats['STR'], 10 + expected);
    expect(stats['END'], 10 + _statFromEndurance(70));

    await _seedSessions([
      _session(
        date: now,
        logs: [_log('bench', weight: 1000000, reps: 20, sets: 20000)],
      ),
    ]);
    final capped = await StatEngine(
      nowProvider: () => now,
      catalog: catalog,
    ).calculateAllStats();

    expect(capped['STR'], 1000);
  });

  test('calculates END from rep bands and caps at 1000', () async {
    final now = DateTime(2026, 5, 14, 10);
    await _seedSessions([
      _session(
        date: now,
        logs: [
          _log('bench', weight: 50, reps: 5),
          _log('bench', weight: 50, reps: 10),
          _log('bench', weight: 50, reps: 15),
        ],
      ),
    ]);

    final stats = await StatEngine(
      nowProvider: () => now,
      catalog: catalog,
    ).calculateAllStats();

    expect(
      StatEngine.endurancePointsForSet(const SetEntry(weight: 50, reps: 5)),
      2.5,
    );
    expect(stats['END'], 10 + _statFromEndurance(35));

    await _seedSessions([
      _session(date: now, logs: [_log('bench', weight: 50, reps: 3000000)]),
    ]);

    final capped = await StatEngine(
      nowProvider: () => now,
      catalog: catalog,
    ).calculateAllStats();

    expect(capped['END'], 1000);
  });

  test(
    'uses exercise primary muscle instead of workout target fallback',
    () async {
      final now = DateTime(2026, 5, 14, 10);
      await _seedSessions([
        _session(
          date: now,
          muscleGroup: 'Chest',
          logs: [_log('curl', weight: 20, reps: 10, sets: 3)],
        ),
      ]);

      final stats = await StatEngine(
        nowProvider: () => now,
        catalog: catalog,
      ).calculateAllStats();

      expect(stats['STR'], greaterThan(10));
      expect(stats['DEF'], greaterThan(10));
    },
  );

  test('class-at-save focus adds a 20 percent effective stat bonus', () async {
    final now = DateTime(2026, 5, 14, 10);

    await _seedSessions([
      _session(
        date: now,
        classAtSave: 'bruiser',
        logs: [_log('bench', weight: 100, reps: 10, sets: 1)],
      ),
      _session(
        date: now.add(const Duration(minutes: 1)),
        id: 'assassin',
        classAtSave: 'assassin',
        logs: [_log('crunch', weight: 100, reps: 10, sets: 1)],
      ),
      _session(
        date: now.add(const Duration(minutes: 2)),
        id: 'tank',
        classAtSave: 'tank',
        logs: [_log('squat', weight: 100, reps: 10, sets: 1)],
      ),
    ]);

    final stats = await StatEngine(
      nowProvider: () => now,
      catalog: catalog,
    ).calculateAllStats();

    // Class focus now pushes visible radar identity:
    // bruiser -> STR, assassin -> AGI, tank -> END.
    final credit = StatEngine.intensityCreditForSet(100, 10);
    // STR: bruiser bench 1.0 + 0.2 bonus, assassin crunch 0.20, tank squat 0.22.
    expect(stats['STR'], 10 + _statFromVolume(credit * (1.2 + 0.20 + 0.22)));
    // AGI: crunch 1.0 + 0.2 bonus, bench 0.12, squat 0.07.
    expect(stats['AGI'], 10 + _statFromVolume(credit * (1.2 + 0.12 + 0.07)));
    expect(stats['END'], 10 + _statFromEndurance(73));
    // VIT is the recovery meter now (not volume) — covered by its own tests.
  });

  test(
    'class-typical training produces distinct readable radar shapes',
    () async {
      final now = DateTime(2026, 5, 14, 10);
      final cases = {
        'assassin': (
          expectedTop: 'AGI',
          sessions: _classTypicalSessions(
            now: now,
            classAtSave: 'assassin',
            logs: [
              _log('press', weight: 30, reps: 10, sets: 3),
              _log('lateral', weight: 10, reps: 15, sets: 3),
              _log('crunch', weight: 0, reps: 15, sets: 3),
            ],
          ),
        ),
        'bruiser': (
          expectedTop: 'STR',
          sessions: _classTypicalSessions(
            now: now,
            classAtSave: 'bruiser',
            logs: [
              _log('bench', weight: 80, reps: 8, sets: 3),
              _log('row', weight: 70, reps: 10, sets: 3),
              _log('curl', weight: 25, reps: 12, sets: 3),
              _log('triceps', weight: 25, reps: 12, sets: 3),
            ],
          ),
        ),
        'tank': (
          expectedTop: 'END',
          sessions: _classTypicalSessions(
            now: now,
            classAtSave: 'tank',
            logs: [
              _log('squat', weight: 100, reps: 8, sets: 3),
              _log('rdl', weight: 80, reps: 10, sets: 3),
              _log('calf', weight: 60, reps: 15, sets: 3),
            ],
          ),
        ),
      };

      for (final entry in cases.entries) {
        SharedPreferences.setMockInitialValues({});
        await _seedSessions(entry.value.sessions);

        final stats = await StatEngine(
          nowProvider: () => now.add(const Duration(days: 19)),
          catalog: catalog,
        ).calculateAllStats();

        const visible = ['STR', 'AGI', 'END'];
        final top = visible.reduce((a, b) => stats[a]! >= stats[b]! ? a : b);
        final gradeIndexes = [
          for (final stat in visible) _gradeIndex(stats[stat] ?? 0),
        ];

        expect(top, entry.value.expectedTop, reason: entry.key);
        final sortedValues = [for (final stat in visible) stats[stat] ?? 0]
          ..sort((a, b) => b.compareTo(a));
        expect(
          sortedValues.first - sortedValues[1],
          greaterThanOrEqualTo(80),
          reason: '${entry.key} should be guessable in a 5-second radar read',
        );
        expect(
          gradeIndexes.reduce(max) - gradeIndexes.reduce(min),
          lessThanOrEqualTo(2),
          reason: entry.key,
        );
        expect(
          visible.every(
            (stat) => (stats[stat] ?? 0) >= StatEngine.rankThresholdC,
          ),
          isTrue,
          reason: entry.key,
        );
      }
    },
  );

  test(
    'radar-only classifier reads class-typical variants above seventy percent',
    () async {
      final now = DateTime(2026, 5, 14, 10);
      final cases = _radarReadabilityCases();

      var correct = 0;
      final failures = <String>[];
      for (final c in cases) {
        SharedPreferences.setMockInitialValues({});
        await _seedSessions(
          _classTypicalSessions(
            now: now,
            classAtSave: c.classAtSave,
            logs: c.logs,
          ),
        );

        final stats = await StatEngine(
          nowProvider: () => now.add(const Duration(days: 19)),
          catalog: catalog,
        ).calculateAllStats();
        for (final axis in ['STR', 'AGI', 'END']) {
          expect(
            stats[axis],
            c.expectedStats[axis],
            reason: '${c.id} $axis should match the study fixture',
          );
        }
        final visibleGrades = [
          for (final axis in ['STR', 'AGI', 'END'])
            _gradeIndex(stats[axis] ?? 0),
        ];
        expect(
          visibleGrades.reduce(max) - visibleGrades.reduce(min),
          lessThanOrEqualTo(2),
          reason: '${c.expectedClass} variant should not show a dead stat',
        );

        final guess = _classGuessFromRadar(stats);
        if (guess == c.expectedClass) {
          correct += 1;
        } else {
          failures.add('${c.expectedClass}: guessed $guess from $stats');
        }
      }

      final accuracy = correct / cases.length;
      expect(accuracy, greaterThan(0.70), reason: failures.join('\n'));
    },
  );

  test('radar readability study embeds the shared fixture cases', () {
    final fixture = jsonDecode(
      File('tool/radar_readability_cases.json').readAsStringSync(),
    );
    final html = File('tool/radar_readability_study.html').readAsStringSync();
    final match = RegExp(
      r'<script id="study-cases" type="application/json">\s*(.*?)\s*</script>',
      dotAll: true,
    ).firstMatch(html);

    expect(match, isNotNull);
    expect(jsonDecode(match!.group(1)!), fixture);
  });

  test('radar readability study keeps trial exposure radar-only', () {
    final html = File('tool/radar_readability_study.html').readAsStringSync();

    expect(html, contains('const studyMode = "radar_only_v1";'));
    expect(html, contains('id="participant-id"'));
    expect(html, contains('participantId'));
    expect(html, contains('AGI-led profile'));
    expect(html, contains('STR-led profile'));
    expect(html, contains('END-led profile'));
    expect(html, isNot(contains('Pass target:')));
    expect(html, isNot(contains('id="legend"')));
    expect(html, isNot(contains('id="build-read"')));
    expect(html, isNot(contains('BUILD:')));
    expect(html, isNot(contains('STR</b> POWER')));
    expect(html, isNot(contains('AGI</b> CONTROL')));
    expect(html, isNot(contains('END</b> STAMINA')));
  });

  test('ignores partial and abandoned sessions', () async {
    final now = DateTime(2026, 5, 14, 10);
    await _seedSessions([
      _session(
        date: now,
        isPartial: true,
        logs: [_log('bench', weight: 100, reps: 10, sets: 3)],
      ),
      _session(
        date: now,
        isPartial: true,
        isAbandoned: true,
        logs: [_log('squat', weight: 100, reps: 10, sets: 3)],
      ),
    ]);

    final stats = await StatEngine(
      nowProvider: () => now,
      catalog: catalog,
    ).calculateAllStats();

    expect(stats, {
      'STR': 10,
      'DEF': 10,
      'VIT': 10,
      'AGI': 10,
      'END': 10,
      'LCK': 0,
    });
  });

  test('LCK is the weekly consistency streak on the training schedule', () async {
    final now = DateTime(2026, 6, 1, 9); // Monday; default schedule is M/W/F.
    final engine = StatEngine(nowProvider: () => now, catalog: catalog);

    // 0 sessions → no streak → LCK 0.
    SharedPreferences.setMockInitialValues({});
    await _seedSessions([]);
    expect(await engine.calculateLuck(), 0);

    // Three full weeks of M/W/F adherence (no missed scheduled day) → 3 weeks.
    SharedPreferences.setMockInitialValues({});
    await _seedSessions(
      _scheduledSessions(firstDay: DateTime(2026, 5, 11), until: now),
    );
    expect(await engine.calculateLuck(), 3);

    // Skipping the most recent scheduled Friday (05-29) is an unscheduled
    // recovery → the streak resets to 0.
    SharedPreferences.setMockInitialValues({});
    await _seedSessions(
      _scheduledSessions(
        firstDay: DateTime(2026, 5, 11),
        until: DateTime(2026, 5, 29),
      ),
    );
    expect(await engine.calculateLuck(), 0);
  });

  test('LCK diamond/multiplier ladder uses weekly thresholds (1/3/6/10)', () {
    expect(XpService.lckDiamondCount(0), 0);
    expect(XpService.lckXpMultiplier(0), 1.0);
    expect(XpService.lckDiamondCount(1), 1);
    expect(XpService.lckXpMultiplier(1), 1.5);
    expect(XpService.lckDiamondCount(2), 1);
    expect(XpService.lckDiamondCount(3), 2);
    expect(XpService.lckXpMultiplier(3), 2.0);
    expect(XpService.lckDiamondCount(5), 2);
    expect(XpService.lckDiamondCount(6), 3);
    expect(XpService.lckXpMultiplier(6), 2.5);
    expect(XpService.lckDiamondCount(9), 3);
    expect(XpService.lckDiamondCount(10), 4);
    expect(XpService.lckXpMultiplier(10), 3.0);
    expect(XpService.lckDiamondCount(100), 4);
    expect(XpService.lckXpMultiplier(100), 3.0);
  });

  test('inactivity no longer decays earned stats (they are immutable)', () async {
    final prefs = await SharedPreferences.getInstance();
    await _seedSessions([
      _session(date: DateTime(2026, 5, 8), logs: [_log('bench')]),
    ]);
    // The earned board from a real session.
    final full = await StatEngine(
      nowProvider: () => DateTime(2026, 5, 8, 12),
      catalog: catalog,
    ).calculateAllStats();

    // Two weeks later with no training: the boot pass runs, earned stats hold.
    await StatEngine(
      nowProvider: () => DateTime(2026, 5, 22, 9),
      catalog: catalog,
    ).processMissedTrainingDays();

    final stored =
        jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
            as Map<String, dynamic>;
    expect(stored['STR'], full['STR']);
    expect(stored['AGI'], full['AGI']);
    expect(stored['END'], full['END']);
    // No decay factor is ever written.
    expect(prefs.getDouble('combat_decay_factor_v1'), isNull);
  });

  test('processMissedTrainingDays still spends a shield on a missed day', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 5, 14, 9);
    await _seedSessions([
      _session(date: DateTime(2026, 5, 8), logs: [_log('bench')]),
    ]);
    await prefs.setString(
      StatEngine.combatStatsKey,
      jsonEncode({
        'STR': 800,
        'DEF': 500,
        'VIT': 100,
        'AGI': 0,
        'END': 100,
        'LCK': 40,
      }),
    );
    await prefs.setString(
      'combat_stats_last_session_date',
      DateTime(2026, 5, 8).toIso8601String(),
    );
    await prefs.setString(
      RestService.stateKey,
      jsonEncode(
        RestState.defaults(
          currentWeekKey: RestService.weekKey(now),
        ).copyWith(shieldCharges: 1).toJson(),
      ),
    );

    await StatEngine(
      nowProvider: () => now,
      catalog: catalog,
    ).processMissedTrainingDays();

    final stored =
        jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
            as Map<String, dynamic>;
    final restState = RestState.fromJson(
      jsonDecode(prefs.getString(RestService.stateKey)!)
          as Map<String, dynamic>,
    );

    // Earned stats untouched (no decay); the shield was spent to protect the
    // first missed scheduled day — the rest-protection side effect we preserved.
    expect(stored['STR'], 800);
    expect(restState.shieldCharges, 0);
    expect(restState.protectedMissDateKeys, contains('2026-05-11'));
  });

  test('calculateAllStats ignores a stale legacy decay factor', () async {
    final prefs = await SharedPreferences.getInstance();
    await _seedSessions([
      _session(date: DateTime(2026, 5, 8), logs: [_log('bench')]),
    ]);
    final full = await StatEngine(
      nowProvider: () => DateTime(2026, 5, 8, 12),
      catalog: catalog,
    ).calculateAllStats();

    // A leftover decay factor from the old system must have no effect now.
    await prefs.setDouble('combat_decay_factor_v1', 0.5);
    final recomputed = await StatEngine(
      nowProvider: () => DateTime(2026, 5, 8, 12),
      catalog: catalog,
    ).calculateAllStats();

    expect(recomputed['STR'], full['STR']);
    expect(recomputed['AGI'], full['AGI']);
    expect(recomputed['END'], full['END']);
  });

  test('last-session delta is the real change vs the previously-shown board', () async {
    final first = DateTime(2026, 5, 13, 10);
    final second = DateTime(2026, 5, 14, 10);

    // Board state the user last saw, after the first workout.
    await _seedSessions([
      _session(date: first, id: 'first', logs: [_log('bench')]),
    ]);
    final afterFirst = await StatEngine(
      nowProvider: () => first,
      catalog: catalog,
    ).calculateAllStats();

    // Second workout saved → recompute. The delta is measured against the cached
    // board value, not a marginal latest-session recompute.
    await _seedSessions([
      _session(date: first, id: 'first', logs: [_log('bench')]),
      _session(date: second, id: 'second', logs: [_log('bench')]),
    ]);
    final engine = StatEngine(nowProvider: () => second, catalog: catalog);
    final stats = await engine.calculateAllStats();
    final delta = await engine.getLastSessionDelta();
    final prefs = await SharedPreferences.getInstance();

    expect(
      jsonDecode(prefs.getString(StatEngine.combatStatsKey)!),
      containsPair('STR', stats['STR']),
    );
    // Visible capability stats grew from the cached board to the new one. (LCK
    // is the weekly consistency streak — a 2-day span doesn't tick it, so it is
    // covered separately.)
    expect(delta.keys, containsAll(['STR', 'AGI', 'END']));
    expect(delta['STR'], stats['STR']! - afterFirst['STR']!);
    expect(delta['AGI'], stats['AGI']! - afterFirst['AGI']!);
    expect(delta['END'], stats['END']! - afterFirst['END']!);
  });

  test('runDecayRemovalOnce un-decays the board and suppresses the delta', () async {
    final prefs = await SharedPreferences.getInstance();
    final d = DateTime(2026, 5, 10, 10);
    await _seedSessions([
      _session(date: d, id: 'a', logs: [_log('bench')]),
    ]);
    final full = await StatEngine(
      nowProvider: () => d,
      catalog: catalog,
    ).calculateAllStats();

    // Simulate a legacy install: a stored decay factor and a cached board that
    // the old system had decayed below the true recompute.
    final cache = Map<String, dynamic>.from(
      jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
          as Map<String, dynamic>,
    );
    final decayedStr = (full['STR']! * 0.6).floor();
    cache['STR'] = decayedStr;
    await prefs.setString(StatEngine.combatStatsKey, jsonEncode(cache));
    await prefs.setDouble('combat_decay_factor_v1', 0.6);

    await MigrationService.runDecayRemovalOnce(
      statEngine: StatEngine(nowProvider: () => d, catalog: catalog),
    );

    final stored =
        jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
            as Map<String, dynamic>;
    final delta = await StatEngine(catalog: catalog).getLastSessionDelta();

    // Board snapped back up to the true (un-decayed) value, the legacy factor is
    // cleared, and the one-time un-decay gain is NOT shown as a board jump.
    expect(stored['STR'], full['STR']);
    expect(prefs.getDouble('combat_decay_factor_v1'), isNull);
    expect(delta['STR'], isNull);
  });

  test('returns rank letters and colors on the widening ladder', () {
    final engine = StatEngine(catalog: catalog);

    // Ladder: D <100, C 100, B 300, A 600, S 900.
    expect(engine.getRank(99), 'D');
    expect(engine.getRank(100), 'C');
    expect(engine.getRank(299), 'C');
    expect(engine.getRank(300), 'B');
    expect(engine.getRank(600), 'A');
    expect(engine.getRank(899), 'A');
    expect(engine.getRank(900), 'S');
    expect(engine.getRankColor(50), const Color(0xFF6B6B8A)); // D muted
    expect(engine.getRankColor(150), Colors.white); // C
    expect(engine.getRankColor(400), const Color(0xFF00BFFF)); // B cyan
    expect(engine.getRankColor(650), const Color(0xFFFFD700)); // A amber
    expect(engine.getRankColor(950), const Color(0xFF00FF9C)); // S neon
  });

  test('legacy cached zero stats with no sessions read as baseline', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StatEngine.combatStatsKey,
      jsonEncode({'STR': 0, 'DEF': 0, 'VIT': 0, 'AGI': 0, 'LCK': 0}),
    );

    final stats = await StatEngine(catalog: catalog).getStoredStats();

    expect(stats['END'], 10);
    expect(stats['STR'], 10);
    expect(stats['LCK'], 0);
  });
}

Future<void> _seedSessions(List<WorkoutSession> sessions) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'workout_sessions',
    jsonEncode(sessions.map((session) => session.toJson()).toList()),
  );
}

WorkoutSession _session({
  required DateTime date,
  required List<ExerciseLog> logs,
  String id = 'session',
  String muscleGroup = 'Chest',
  bool isPartial = false,
  bool isAbandoned = false,
  String? classAtSave,
}) {
  return WorkoutSession(
    id: id,
    date: date,
    muscleGroup: muscleGroup,
    targetDurationMinutes: 30,
    actualDurationSeconds: 1800,
    exercises: logs,
    estimatedCalories: 100,
    isPartial: isPartial,
    isAbandoned: isAbandoned,
    classAtSave: classAtSave,
  );
}

ExerciseLog _log(String id, {double weight = 50, int reps = 5, int sets = 1}) {
  return ExerciseLog(
    exerciseId: id,
    exerciseName: id,
    sets: [for (var i = 0; i < sets; i++) SetEntry(weight: weight, reps: reps)],
  );
}

List<WorkoutSession> _classTypicalSessions({
  required DateTime now,
  required String classAtSave,
  required List<ExerciseLog> logs,
}) {
  return [
    for (var i = 0; i < 20; i++)
      _session(
        date: now.add(Duration(days: i)),
        id: '$classAtSave-$i',
        classAtSave: classAtSave,
        logs: logs,
      ),
  ];
}

/// Seeds a completed session on every scheduled [weekdays] day in
/// `[firstDay, until)` (until exclusive). Used to build perfectly-adherent
/// histories for the weekly consistency streak (LCK).
List<WorkoutSession> _scheduledSessions({
  required DateTime firstDay,
  required DateTime until,
  Set<int> weekdays = const {1, 3, 5}, // default schedule: Mon / Wed / Fri
}) {
  final out = <WorkoutSession>[];
  var day = DateTime(firstDay.year, firstDay.month, firstDay.day);
  final end = DateTime(until.year, until.month, until.day);
  var i = 0;
  while (day.isBefore(end)) {
    if (weekdays.contains(day.weekday)) {
      out.add(
        _session(
          date: day.add(const Duration(hours: 10)),
          id: 'sched-$i',
          logs: [_log('bench')],
        ),
      );
      i++;
    }
    day = day.add(const Duration(days: 1));
  }
  return out;
}

int _statFromVolume(double volume) {
  return min(
    1000,
    (100 * log(volume / StatEngine.volumeCurveScale + 1)).floor(),
  );
}

int _statFromEndurance(double endurancePoints) {
  return min(1000, (100 * log(endurancePoints / 150 + 1)).floor());
}

List<_RadarReadabilityCase> _radarReadabilityCases() {
  final raw =
      jsonDecode(File('tool/radar_readability_cases.json').readAsStringSync())
          as List<dynamic>;
  return [
    for (final item in raw.cast<Map<String, dynamic>>())
      _RadarReadabilityCase(
        id: item['id'] as String,
        classAtSave: item['classAtSave'] as String,
        expectedClass: item['expectedClass'] as String,
        expectedStats: (item['stats'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, value as int),
        ),
        logs: [
          for (final log
              in (item['logs'] as List<dynamic>).cast<Map<String, dynamic>>())
            _log(
              log['exerciseId'] as String,
              weight: (log['weight'] as num).toDouble(),
              reps: log['reps'] as int,
              sets: log['sets'] as int,
            ),
        ],
      ),
  ];
}

class _RadarReadabilityCase {
  const _RadarReadabilityCase({
    required this.id,
    required this.classAtSave,
    required this.expectedClass,
    required this.expectedStats,
    required this.logs,
  });

  final String id;
  final String classAtSave;
  final String expectedClass;
  final Map<String, int> expectedStats;
  final List<ExerciseLog> logs;
}

String? _classGuessFromRadar(Map<String, int> stats) {
  final axes = StatRadarRead.axisToClass.keys.toList()
    ..sort((a, b) => (stats[b] ?? 0).compareTo(stats[a] ?? 0));
  final lead = (stats[axes.first] ?? 0) - (stats[axes[1]] ?? 0);
  if (lead < StatRadarRead.dominantLeadThreshold) return null;
  return StatRadarRead.classForAxis(axes.first);
}

int _gradeIndex(int value) {
  if (value >= StatEngine.rankThresholdS) return 4;
  if (value >= StatEngine.rankThresholdA) return 3;
  if (value >= StatEngine.rankThresholdB) return 2;
  if (value >= StatEngine.rankThresholdC) return 1;
  return 0;
}
