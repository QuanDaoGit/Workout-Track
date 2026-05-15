import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/rest_models.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/rest_service.dart';
import 'package:workout_track/services/stat_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const catalog = {
    'bench': 'chest',
    'triceps': 'triceps',
    'curl': 'biceps',
    'row': 'lats',
    'squat': 'quadriceps',
    'crunch': 'abdominals',
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
    final expected = _statFromVolume(5800);

    expect(stats['STR'], expected);

    await _seedSessions([
      _session(
        date: now,
        logs: [_log('bench', weight: 1000000, reps: 20, sets: 1)],
      ),
    ]);
    final capped = await StatEngine(
      nowProvider: () => now,
      catalog: catalog,
    ).calculateAllStats();

    expect(capped['STR'], 1000);
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

      expect(stats['STR'], 0);
      expect(stats['DEF'], greaterThan(0));
    },
  );

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

    expect(stats, {'STR': 0, 'DEF': 0, 'VIT': 0, 'AGI': 0, 'LCK': 0});
  });

  test('calculates LCK from weekly touched combat groups', () async {
    final now = DateTime(2026, 5, 14, 10);
    final engine = StatEngine(nowProvider: () => now, catalog: catalog);
    final logsByCount = [
      <ExerciseLog>[],
      [_log('bench')],
      [_log('bench'), _log('row')],
      [_log('bench'), _log('row'), _log('squat')],
      [_log('bench'), _log('row'), _log('squat'), _log('crunch')],
    ];
    final expected = [0, 5, 10, 25, 40];

    for (var i = 0; i < logsByCount.length; i++) {
      SharedPreferences.setMockInitialValues({});
      await _seedSessions([_session(date: now, logs: logsByCount[i])]);
      expect(await engine.calculateLuck(), expected[i]);
    }
  });

  test('planned rest days do not advance decay', () async {
    final prefs = await SharedPreferences.getInstance();
    await _seedSessions([
      _session(date: DateTime(2026, 5, 11), logs: [_log('bench')]),
    ]);
    await prefs.setString(
      StatEngine.combatStatsKey,
      jsonEncode({'STR': 800, 'DEF': 500, 'VIT': 100, 'AGI': 0, 'LCK': 40}),
    );
    await prefs.setString(
      'combat_stat_peaks',
      jsonEncode({'STR': 1000, 'DEF': 1000, 'VIT': 100, 'AGI': 0, 'LCK': 40}),
    );
    await prefs.setString(
      'combat_stats_last_session_date',
      DateTime(2026, 5, 11).toIso8601String(),
    );

    await StatEngine(
      nowProvider: () => DateTime(2026, 5, 15, 9),
      catalog: catalog,
    ).applyDecayIfNeeded();

    final decayed =
        jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
            as Map<String, dynamic>;

    expect(decayed['STR'], 800);
    expect(decayed['DEF'], 500);
  });

  test(
    'applies decay after two missed non-rest days and respects floor',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await _seedSessions([
        _session(date: DateTime(2026, 5, 8), logs: [_log('bench')]),
      ]);
      await prefs.setString(
        StatEngine.combatStatsKey,
        jsonEncode({'STR': 800, 'DEF': 500, 'VIT': 100, 'AGI': 0, 'LCK': 40}),
      );
      await prefs.setString(
        'combat_stat_peaks',
        jsonEncode({'STR': 1000, 'DEF': 1000, 'VIT': 100, 'AGI': 0, 'LCK': 40}),
      );
      await prefs.setString(
        'combat_stats_last_session_date',
        DateTime(2026, 5, 8).toIso8601String(),
      );

      await StatEngine(
        nowProvider: () => DateTime(2026, 5, 14, 9),
        catalog: catalog,
      ).applyDecayIfNeeded();

      final decayed =
          jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
              as Map<String, dynamic>;

      expect(decayed['STR'], 720);
      expect(decayed['DEF'], 500);
      expect(decayed['VIT'], 90);
      expect(decayed['LCK'], 0);
    },
  );

  test('recovery shield protects one missed non-rest day from decay', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 5, 14, 9);
    await _seedSessions([
      _session(date: DateTime(2026, 5, 8), logs: [_log('bench')]),
    ]);
    await prefs.setString(
      StatEngine.combatStatsKey,
      jsonEncode({'STR': 800, 'DEF': 500, 'VIT': 100, 'AGI': 0, 'LCK': 40}),
    );
    await prefs.setString(
      'combat_stat_peaks',
      jsonEncode({'STR': 1000, 'DEF': 1000, 'VIT': 100, 'AGI': 0, 'LCK': 40}),
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
    ).applyDecayIfNeeded();

    final stored =
        jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
            as Map<String, dynamic>;
    final restState = RestState.fromJson(
      jsonDecode(prefs.getString(RestService.stateKey)!)
          as Map<String, dynamic>,
    );

    expect(stored['STR'], 800);
    expect(restState.shieldCharges, 0);
    expect(restState.protectedMissDateKeys, contains('2026-05-11'));
  });

  test('ongoing and abandoned sessions do not prevent decay', () async {
    final prefs = await SharedPreferences.getInstance();
    await _seedSessions([
      _session(date: DateTime(2026, 5, 8), logs: [_log('bench')]),
      _session(
        date: DateTime(2026, 5, 11),
        logs: [_log('bench')],
        isPartial: true,
      ),
      _session(
        date: DateTime(2026, 5, 13),
        logs: [_log('bench')],
        isPartial: true,
        isAbandoned: true,
      ),
    ]);
    await prefs.setString(
      StatEngine.combatStatsKey,
      jsonEncode({'STR': 800, 'DEF': 0, 'VIT': 0, 'AGI': 0, 'LCK': 0}),
    );
    await prefs.setString(
      'combat_stat_peaks',
      jsonEncode({'STR': 1000, 'DEF': 0, 'VIT': 0, 'AGI': 0, 'LCK': 0}),
    );
    await prefs.setString(
      'combat_stats_last_session_date',
      DateTime(2026, 5, 8).toIso8601String(),
    );

    await StatEngine(
      nowProvider: () => DateTime(2026, 5, 14, 9),
      catalog: catalog,
    ).applyDecayIfNeeded();

    final stored =
        jsonDecode(prefs.getString(StatEngine.combatStatsKey)!)
            as Map<String, dynamic>;

    expect(stored['STR'], 720);
  });

  test('stores combat stats and touched last-session delta', () async {
    final first = DateTime(2026, 5, 13, 10);
    final second = DateTime(2026, 5, 14, 10);
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
    expect(delta.keys, ['STR']);
    expect(delta['STR'], stats['STR']! - _statFromVolume(250));
  });

  test('returns rank letters and colors', () {
    final engine = StatEngine(catalog: catalog);

    expect(engine.getRank(199), 'D');
    expect(engine.getRank(200), 'C');
    expect(engine.getRank(400), 'B');
    expect(engine.getRank(600), 'A');
    expect(engine.getRank(800), 'S');
    expect(engine.getRankColor(100), const Color(0xFF6B6B8A));
    expect(engine.getRankColor(450), const Color(0xFF00BFFF));
    expect(engine.getRankColor(650), const Color(0xFFFFD700));
    expect(engine.getRankColor(900), const Color(0xFF00FF9C));
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
  );
}

ExerciseLog _log(String id, {double weight = 50, int reps = 5, int sets = 1}) {
  return ExerciseLog(
    exerciseId: id,
    exerciseName: id,
    sets: [for (var i = 0; i < sets; i++) SetEntry(weight: weight, reps: reps)],
  );
}

int _statFromVolume(double volume) {
  return min(1000, (100 * log(volume / 500 + 1)).floor());
}
