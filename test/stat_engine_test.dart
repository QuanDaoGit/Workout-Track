import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/rest_models.dart';
import 'package:workout_track/models/workout_models.dart';
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
    'squat': 'quadriceps',
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
    final expected = _statFromVolume(5800);

    expect(stats['STR'], 10 + expected);
    expect(stats['END'], 80);

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
    expect(stats['END'], 45);

    await _seedSessions([
      _session(
        date: now,
        logs: [_log('bench', weight: 50, reps: 20, sets: 100)],
      ),
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

      expect(stats['STR'], 10);
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

    expect(stats['STR'], 10 + _statFromVolume(1200));
    expect(stats['AGI'], 10 + _statFromVolume(1200));
    expect(stats['VIT'], 10 + _statFromVolume(1200));
    expect(stats['END'], 40);
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

  test('LCK reflects current training streak capped at 100', () async {
    final now = DateTime(2026, 5, 14, 10);
    final engine = StatEngine(nowProvider: () => now, catalog: catalog);

    // 0 sessions → no streak → LCK 0.
    SharedPreferences.setMockInitialValues({});
    await _seedSessions([]);
    expect(await engine.calculateLuck(), 0);

    // Session today only → streak 1.
    SharedPreferences.setMockInitialValues({});
    await _seedSessions([
      _session(date: now, logs: [_log('bench')]),
    ]);
    expect(await engine.calculateLuck(), 1);

    // Three consecutive days ending today → streak 3.
    SharedPreferences.setMockInitialValues({});
    await _seedSessions([
      _session(
        date: now.subtract(const Duration(days: 2)),
        id: 'd-2',
        logs: [_log('bench')],
      ),
      _session(
        date: now.subtract(const Duration(days: 1)),
        id: 'd-1',
        logs: [_log('bench')],
      ),
      _session(date: now, id: 'd0', logs: [_log('bench')]),
    ]);
    expect(await engine.calculateLuck(), 3);

    // Gap on yesterday breaks the streak — only today counts.
    SharedPreferences.setMockInitialValues({});
    await _seedSessions([
      _session(
        date: now.subtract(const Duration(days: 2)),
        id: 'd-2',
        logs: [_log('bench')],
      ),
      _session(date: now, id: 'd0', logs: [_log('bench')]),
    ]);
    expect(await engine.calculateLuck(), 1);

    // Longer streaks should map directly to LCK until the 100 cap.
    SharedPreferences.setMockInitialValues({});
    await _seedSessions(_streakSessions(now: now, days: 50));
    expect(await engine.calculateLuck(), 50);

    SharedPreferences.setMockInitialValues({});
    await _seedSessions(_streakSessions(now: now, days: 100));
    expect(await engine.calculateLuck(), 100);

    SharedPreferences.setMockInitialValues({});
    await _seedSessions(_streakSessions(now: now, days: 200));
    expect(await engine.calculateLuck(), 100);
  });

  test('LCK XP multiplier thresholds use 25-point diamond tiers', () {
    expect(XpService.lckDiamondCount(0), 0);
    expect(XpService.lckXpMultiplier(0), 1.0);
    expect(XpService.lckDiamondCount(24), 0);
    expect(XpService.lckXpMultiplier(24), 1.0);
    expect(XpService.lckDiamondCount(25), 1);
    expect(XpService.lckXpMultiplier(25), 1.5);
    expect(XpService.lckDiamondCount(49), 1);
    expect(XpService.lckXpMultiplier(49), 1.5);
    expect(XpService.lckDiamondCount(50), 2);
    expect(XpService.lckXpMultiplier(50), 2.0);
    expect(XpService.lckDiamondCount(74), 2);
    expect(XpService.lckXpMultiplier(74), 2.0);
    expect(XpService.lckDiamondCount(75), 3);
    expect(XpService.lckXpMultiplier(75), 2.5);
    expect(XpService.lckDiamondCount(99), 3);
    expect(XpService.lckXpMultiplier(99), 2.5);
    expect(XpService.lckDiamondCount(100), 4);
    expect(XpService.lckXpMultiplier(100), 3.0);
  });

  test('planned rest days do not advance decay', () async {
    final prefs = await SharedPreferences.getInstance();
    await _seedSessions([
      _session(date: DateTime(2026, 5, 11), logs: [_log('bench')]),
    ]);
    await prefs.setString(
      StatEngine.combatStatsKey,
      jsonEncode({
        'STR': 800,
        'DEF': 500,
        'VIT': 100,
        'AGI': 0,
        'END': 30,
        'LCK': 40,
      }),
    );
    await prefs.setString(
      'combat_stat_peaks',
      jsonEncode({
        'STR': 1000,
        'DEF': 1000,
        'VIT': 100,
        'AGI': 0,
        'END': 30,
        'LCK': 40,
      }),
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
        'combat_stat_peaks',
        jsonEncode({
          'STR': 1000,
          'DEF': 1000,
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
      expect(decayed['END'], 90);
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
      'combat_stat_peaks',
      jsonEncode({
        'STR': 1000,
        'DEF': 1000,
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
      jsonEncode({
        'STR': 800,
        'DEF': 0,
        'VIT': 0,
        'AGI': 0,
        'END': 50,
        'LCK': 0,
      }),
    );
    await prefs.setString(
      'combat_stat_peaks',
      jsonEncode({
        'STR': 1000,
        'DEF': 0,
        'VIT': 0,
        'AGI': 0,
        'END': 50,
        'LCK': 0,
      }),
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

  test('stores character stats and touched last-session delta', () async {
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
    // Two consecutive-day sessions: STR grew with the new volume, LCK grew
    // with the streak (1 → 2). Both deltas should be present.
    expect(delta.keys, containsAll(['STR', 'END', 'LCK']));
    expect(
      delta['STR'],
      stats['STR']! - (StatEngine.baseOutputStatValue + _statFromVolume(250)),
    );
    expect(delta['END'], 3);
    expect(delta['LCK'], 1);
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

List<WorkoutSession> _streakSessions({
  required DateTime now,
  required int days,
}) {
  return [
    for (var i = days - 1; i >= 0; i--)
      _session(
        date: DateTime(now.year, now.month, now.day - i, now.hour),
        id: 'streak-$i',
        logs: [_log('bench')],
      ),
  ];
}

int _statFromVolume(double volume) {
  return min(1000, (100 * log(volume / 500 + 1)).floor());
}
