import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/loot_registry.dart';
import 'package:workout_track/models/milestone_models.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/milestone_service.dart';
import 'package:workout_track/services/stat_engine.dart';
import 'package:workout_track/services/xp_service.dart';

void main() {
  test(
    'mid-frequency pacing surfaces a non-stat milestone each valley week',
    () {
      final weeks = _simulate(weekdays: const [0, 1, 3, 4], weeks: 8);

      expect(_lootIdsForWeek(weeks, 4), contains('frame_neon'));
      expect(_lootIdsForWeek(weeks, 5), contains('title_grinder'));
      expect(_kindsForWeek(weeks, 6), contains(MilestoneKind.levelUp));
      expect(_lootIdsForWeek(weeks, 7), contains('title_iron_will'));
      expect(_lootIdsForWeek(weeks, 8), contains('theme_forest'));

      for (var week = 4; week <= 8; week++) {
        expect(_nonStatEventsForWeek(weeks, week), isNotEmpty);
      }
    },
  );

  test('low and high frequency pacing degrade gracefully', () {
    final low = _simulate(weekdays: const [0, 2, 4], weeks: 11);
    final high = _simulate(weekdays: const [0, 1, 2, 3, 4, 5], weeks: 8);

    expect(
      _maxDeadValleyGap(low, fromWeek: 4, toWeek: 8),
      lessThanOrEqualTo(1),
    );
    expect(
      _lootIdsThroughWeek(low, 11),
      containsAll(['frame_neon', 'theme_forest']),
    );

    expect(
      _lootIdsThroughWeek(high, 7),
      containsAll(['frame_neon', 'theme_forest']),
    );
    expect(_lootIdsThroughWeek(high, 7), contains('title_iron_will'));
  });

  test('identical histories produce identical milestone events', () {
    final a = _simulate(weekdays: const [0, 1, 3, 4], weeks: 8);
    final b = _simulate(weekdays: const [0, 1, 3, 4], weeks: 8);

    expect(_eventSignature(a), _eventSignature(b));
  });
}

List<_WeekEvents> _simulate({required List<int> weekdays, required int weeks}) {
  final sessions = <WorkoutSession>[];
  final owned = defaultLootIds.toSet();
  final eventsByWeek = <int, List<MilestoneEvent>>{};
  final start = DateTime(2026, 1, 5); // Monday.
  var totalXP = 0;
  final volumeSeed = StatEngine.volumeForStat(120);
  final volumeByStat = <String, double>{
    'STR': volumeSeed,
    'DEF': volumeSeed,
    'AGI': volumeSeed,
  };
  var endurance = 0;

  Map<String, int> currentStats(int lck) => {
    'STR': _statFromVolume(volumeByStat['STR']!),
    'DEF': _statFromVolume(volumeByStat['DEF']!),
    'AGI': _statFromVolume(volumeByStat['AGI']!),
    'END': min(1000, StatEngine.baseOutputStatValue + endurance),
    'VIT': StatEngine.baseOutputStatValue,
    'LCK': lck,
  };

  for (var week = 0; week < weeks; week++) {
    for (final weekday in weekdays) {
      final date = start.add(Duration(days: week * 7 + weekday));
      final lckBefore = XpService.lckForSessions(sessions, now: date);
      final beforeStats = currentStats(lckBefore);
      final before = MilestoneService.snapshotFromSessions(
        sessions: sessions,
        stats: beforeStats,
        totalXP: totalXP,
        lck: lckBefore,
        ownedLootIds: owned,
        primaryMuscleByExerciseId: _primaryByExerciseId,
      );

      final muscle = _muscles[sessions.length % _muscles.length];
      final session = _session(date: date, muscle: muscle);
      sessions.add(session);
      totalXP = XpService.calculateTotalXP(sessions);
      volumeByStat[_statForMuscle(muscle)] =
          volumeByStat[_statForMuscle(muscle)]! +
          session.exercises.first.totalVolume;
      endurance += 72;

      final lckAfter = XpService.lckForSessions(sessions, now: date);
      final after = MilestoneService.snapshotFromSessions(
        sessions: sessions,
        stats: currentStats(lckAfter),
        totalXP: totalXP,
        lck: lckAfter,
        ownedLootIds: owned,
        primaryMuscleByExerciseId: _primaryByExerciseId,
      );
      final events = MilestoneService.milestonesCrossed(before, after);
      for (final event in events) {
        if (event.kind == MilestoneKind.lootUnlock && event.lootId != null) {
          owned.add(event.lootId!);
        }
      }
      eventsByWeek.putIfAbsent(week + 1, () => []).addAll(events);
    }
  }

  return [
    for (final entry in eventsByWeek.entries)
      _WeekEvents(week: entry.key, events: entry.value),
  ];
}

const _muscles = ['Chest', 'Back', 'Shoulders', 'Legs'];
const _primaryByExerciseId = {
  'sim-chest': 'chest',
  'sim-back': 'lats',
  'sim-shoulders': 'shoulders',
  'sim-legs': 'quadriceps',
};

WorkoutSession _session({required DateTime date, required String muscle}) {
  final id = 'sim-${muscle.toLowerCase()}';
  return WorkoutSession(
    id: '${date.toIso8601String()}-$muscle',
    date: date,
    muscleGroup: muscle,
    targetMuscleGroups: [muscle],
    targetDurationMinutes: 45,
    actualDurationSeconds: 45 * 60,
    estimatedCalories: 0,
    exercises: [
      ExerciseLog(
        exerciseId: id,
        exerciseName: muscle,
        sets: const [
          SetEntry(weight: 40, reps: 8),
          SetEntry(weight: 40, reps: 8),
          SetEntry(weight: 40, reps: 8),
          SetEntry(weight: 40, reps: 8),
          SetEntry(weight: 40, reps: 8),
          SetEntry(weight: 40, reps: 8),
          SetEntry(weight: 40, reps: 8),
          SetEntry(weight: 40, reps: 8),
          SetEntry(weight: 40, reps: 8),
        ],
      ),
    ],
  );
}

String _statForMuscle(String muscle) => switch (muscle) {
  'Back' => 'DEF',
  'Shoulders' => 'AGI',
  _ => 'STR',
};

int _statFromVolume(double volume) => min(
  1000,
  StatEngine.baseOutputStatValue + (100 * log(volume / 500 + 1)).floor(),
);

List<MilestoneEvent> _eventsForWeek(List<_WeekEvents> weeks, int week) => weeks
    .where((entry) => entry.week == week)
    .expand((entry) => entry.events)
    .toList();

List<MilestoneEvent> _nonStatEventsForWeek(List<_WeekEvents> weeks, int week) =>
    _eventsForWeek(
      weeks,
      week,
    ).where((event) => event.kind != MilestoneKind.rankPromotion).toList();

List<String> _lootIdsForWeek(List<_WeekEvents> weeks, int week) =>
    _eventsForWeek(
      weeks,
      week,
    ).map((event) => event.lootId).whereType<String>().toList();

Set<String> _lootIdsThroughWeek(List<_WeekEvents> weeks, int week) => {
  for (final entry in weeks)
    if (entry.week <= week)
      for (final event in entry.events)
        if (event.lootId != null) event.lootId!,
};

List<MilestoneKind> _kindsForWeek(List<_WeekEvents> weeks, int week) =>
    _eventsForWeek(weeks, week).map((event) => event.kind).toList();

int _maxDeadValleyGap(
  List<_WeekEvents> weeks, {
  required int fromWeek,
  required int toWeek,
}) {
  var maxGap = 0;
  var current = 0;
  for (var week = fromWeek; week <= toWeek; week++) {
    if (_nonStatEventsForWeek(weeks, week).isEmpty) {
      current++;
      maxGap = max(maxGap, current);
    } else {
      current = 0;
    }
  }
  return maxGap;
}

List<String> _eventSignature(List<_WeekEvents> weeks) => [
  for (final entry in weeks)
    for (final event in entry.events)
      '${entry.week}:${event.kind.name}:${event.stat ?? ''}:${event.lootId ?? ''}:${event.valueAfter}',
];

class _WeekEvents {
  const _WeekEvents({required this.week, required this.events});

  final int week;
  final List<MilestoneEvent> events;
}
