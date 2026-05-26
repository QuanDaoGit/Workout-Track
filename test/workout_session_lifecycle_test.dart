import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/quest_service.dart';
import 'package:workout_track/services/workout_storage_service.dart';
import 'package:workout_track/services/xp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('workout session JSON keeps lifecycle defaults backward compatible', () {
    final date = DateTime(2026, 5, 14, 9);
    final legacy = _session(date: date).toJson()
      ..remove('startedAt')
      ..remove('pausedAt')
      ..remove('autoDiscardAt')
      ..remove('isPausedForResume')
      ..remove('isAbandoned')
      ..remove('baseXP')
      ..remove('lckMultiplier')
      ..remove('potionMultiplier')
      ..remove('awardedXP')
      ..remove('classAtSave')
      ..remove('statDelta');

    final parsed = WorkoutSession.fromJson(legacy);
    expect(parsed.startedAt, date);
    expect(parsed.pausedAt, isNull);
    expect(parsed.autoDiscardAt, isNull);
    expect(parsed.isPausedForResume, isFalse);
    expect(parsed.isAbandoned, isFalse);
    expect(parsed.baseXP, isNull);
    expect(parsed.awardedXP, isNull);
    expect(parsed.classAtSave, isNull);
    expect(parsed.statDelta, isEmpty);
    expect(parsed.isOngoing, isFalse);

    final pausedAt = date.add(const Duration(minutes: 20));
    final autoDiscardAt = DateTime(2026, 5, 15);
    final abandoned = _session(
      date: date,
      startedAt: date.subtract(const Duration(minutes: 10)),
      pausedAt: pausedAt,
      autoDiscardAt: autoDiscardAt,
      isPartial: true,
      isAbandoned: true,
      isPausedForResume: true,
    );
    final json = abandoned.toJson();
    expect(json['startedAt'], abandoned.startedAt.toIso8601String());
    expect(json['pausedAt'], pausedAt.toIso8601String());
    expect(json['autoDiscardAt'], autoDiscardAt.toIso8601String());
    expect(json['isPausedForResume'], isTrue);
    expect(json['isAbandoned'], isTrue);
  });

  test(
    'XP includes completed and abandoned sessions, but excludes ongoing',
    () {
      final now = DateTime(2026, 5, 14, 9);
      final completed = _session(date: now, setCount: 2, seconds: 1200);
      final ongoing = _session(
        date: now,
        startedAt: now.subtract(const Duration(minutes: 10)),
        isPartial: true,
        setCount: 2,
        seconds: 600,
      );
      final abandoned = _session(
        date: now,
        isPartial: true,
        isAbandoned: true,
        setCount: 10,
        seconds: 3600,
        targetMinutes: 30,
      );

      expect(XpService.calculateSessionXP(completed), 80);
      expect(XpService.calculateSessionXP(abandoned), 30);
      expect(XpService.calculateTotalXP([completed, ongoing, abandoned]), 110);
    },
  );

  test('persisted awarded XP overrides legacy formula for saved workouts', () {
    final now = DateTime(2026, 5, 14, 9);
    final awarded = _session(
      date: now,
      setCount: 2,
      seconds: 1200,
      baseXP: 80,
      lckMultiplier: 2.0,
      potionMultiplier: 1.5,
      awardedXP: 240,
      classAtSave: 'bruiser',
    );

    final parsed = WorkoutSession.fromJson(awarded.toJson());

    expect(parsed.baseXP, 80);
    expect(parsed.lckMultiplier, 2.0);
    expect(parsed.potionMultiplier, 1.5);
    expect(parsed.awardedXP, 240);
    expect(parsed.classAtSave, 'bruiser');
    expect(XpService.calculateBaseSessionXP(parsed), 80);
    expect(XpService.calculateSessionXP(parsed), 240);
  });

  test('session stat delta persists with backward-compatible default', () {
    final now = DateTime(2026, 5, 14, 9);
    final session = _session(date: now, statDelta: {'STR': 3, 'END': 12});

    final parsed = WorkoutSession.fromJson(session.toJson());

    expect(parsed.statDelta, {'STR': 3, 'END': 12});
  });

  test('paused resumable sessions freeze elapsed time and resume clock', () {
    final startedAt = DateTime(2026, 5, 14, 9);
    final now = DateTime(2026, 5, 14, 12);
    final live = _session(
      date: startedAt,
      startedAt: startedAt,
      isPartial: true,
      seconds: 600,
    );
    final paused = _session(
      date: startedAt,
      startedAt: startedAt,
      pausedAt: startedAt.add(const Duration(minutes: 10)),
      autoDiscardAt: DateTime(2026, 5, 15),
      isPartial: true,
      isPausedForResume: true,
      seconds: 600,
    );

    expect(live.elapsedSecondsForDisplay(now), 10800);
    expect(paused.elapsedSecondsForDisplay(now), 600);
    expect(
      paused.resumeStartTime(now),
      now.subtract(const Duration(minutes: 10)),
    );
  });

  test(
    'abandoned sessions do not complete quests or side milestones',
    () async {
      final service = QuestService();
      final now = DateTime(2026, 5, 14, 9);
      final abandoned = _session(
        date: now,
        isPartial: true,
        isAbandoned: true,
        setCount: 10,
        seconds: 3600,
      );

      final summary = await service.getSummary([abandoned], now: now);

      expect(
        summary.weeklyQuests
            .firstWhere((quest) => quest.id == 'weekly_workout_1')
            .completed,
        isFalse,
      );
      expect(
        summary.weeklyQuests
            .firstWhere((quest) => quest.id == 'weekly_sets_10')
            .completed,
        isFalse,
      );
      expect(
        summary.sideQuests
            .firstWhere((quest) => quest.id == 'side_first_workout')
            .completed,
        isFalse,
      );
    },
  );

  test('replacing ongoing sessions keeps only one resumable workout', () async {
    final storage = WorkoutStorageService();
    final now = DateTime(2026, 5, 14, 9);
    final completed = _session(date: now, id: 'completed');
    final oldOngoing = _session(date: now, id: 'old', isPartial: true);
    final newOngoing = _session(
      date: now.add(const Duration(minutes: 1)),
      id: 'new',
      isPartial: true,
    );

    await storage.saveSession(completed);
    await storage.replaceOngoingSession(oldOngoing);
    await storage.replaceOngoingSession(newOngoing);

    final sessions = await storage.getSessions();
    expect(
      sessions.where((session) => !session.isPartial).single.id,
      'completed',
    );
    expect(sessions.where((session) => session.isOngoing).single.id, 'new');
  });

  test('session writes emit storage change signal', () async {
    final storage = WorkoutStorageService();
    final now = DateTime(2026, 5, 14, 9);
    final emitted = expectLater(WorkoutStorageService.changes, emits(isNull));

    await storage.replaceOngoingSession(
      _session(date: now, id: 'active', isPartial: true),
    );

    await emitted;
  });

  test('mission finish marker emits storage change signal', () async {
    final now = DateTime(2026, 5, 14, 9);
    final emitted = expectLater(WorkoutStorageService.changes, emits(isNull));

    await WorkoutStorageService.markMissionFinished(
      now,
      MissionFinishState.endedEarly,
    );

    await emitted;
  });

  test(
    'annotating session stat delta rewrites session without recalculation',
    () async {
      final storage = WorkoutStorageService();
      final now = DateTime(2026, 5, 14, 9);

      await storage.replaceOngoingSession(
        _session(date: now, id: 'active', isPartial: true),
      );
      await storage.annotateSessionStatDelta('active', {'STR': 4, 'END': 9});

      final session = (await storage.getSessions()).single;
      expect(session.statDelta, {'STR': 4, 'END': 9});
      expect(session.isPartial, isTrue);
    },
  );

  test('completed sessions mark today mission as completed', () async {
    final storage = WorkoutStorageService();
    final now = DateTime(2026, 5, 14, 9);

    await storage.saveSession(_session(date: now));

    expect(
      await WorkoutStorageService.missionFinishStateToday(now: now),
      MissionFinishState.completed,
    );
  });

  test('ended early replacement is idempotent and finishes mission', () async {
    final storage = WorkoutStorageService();
    final now = DateTime(2026, 5, 14, 9);
    final ongoing = _session(
      date: now,
      id: 'active',
      isPartial: true,
      seconds: 600,
      targetMinutes: 30,
    );
    final ended = _session(
      date: now,
      id: 'active',
      isPartial: true,
      isAbandoned: true,
      seconds: 600,
      targetMinutes: 30,
      setCount: 0,
    );

    await storage.replaceOngoingSession(ongoing);
    await storage.replaceOngoingWithAbandoned(ended, markMissionFinished: true);
    await storage.replaceOngoingWithAbandoned(ended, markMissionFinished: true);

    final sessions = await storage.getSessions();
    expect(await storage.getOngoingSession(), isNull);
    expect(sessions, hasLength(1));
    expect(sessions.single.isAbandoned, isTrue);
    expect(XpService.calculateTotalXP(sessions), 10);
    expect(
      await WorkoutStorageService.missionFinishStateToday(now: now),
      MissionFinishState.endedEarly,
    );
  });

  test(
    'abandoned cleanup without user end early does not finish mission',
    () async {
      final storage = WorkoutStorageService();
      final now = DateTime(2026, 5, 14, 9);
      final ongoing = _session(date: now, id: 'active', isPartial: true);

      await storage.replaceOngoingSession(ongoing);
      await storage.replaceOngoingWithAbandoned(
        _session(
          date: now,
          id: 'active',
          isPartial: true,
          isAbandoned: true,
          seconds: 600,
          targetMinutes: 30,
          setCount: 0,
        ),
      );

      expect(
        await WorkoutStorageService.missionFinishStateToday(now: now),
        MissionFinishState.none,
      );
    },
  );

  test(
    'expired paused sessions are detected after auto-discard time',
    () async {
      final storage = WorkoutStorageService();
      final now = DateTime(2026, 5, 14, 9);
      final paused = _session(
        date: now,
        id: 'paused',
        isPartial: true,
        isPausedForResume: true,
        pausedAt: now.add(const Duration(minutes: 5)),
        autoDiscardAt: DateTime(2026, 5, 15),
      );

      await storage.replaceOngoingSession(paused);

      expect(
        await storage.getExpiredPausedSession(
          now: DateTime(2026, 5, 14, 23, 59),
        ),
        isNull,
      );
      expect(
        (await storage.getExpiredPausedSession(now: DateTime(2026, 5, 15)))?.id,
        'paused',
      );
    },
  );

  test(
    'auto-ended paused session is abandoned and no longer resumable',
    () async {
      final storage = WorkoutStorageService();
      final now = DateTime(2026, 5, 14, 9);
      final paused = _session(
        date: now,
        id: 'paused',
        isPartial: true,
        isPausedForResume: true,
        seconds: 900,
        targetMinutes: 30,
        pausedAt: now.add(const Duration(minutes: 15)),
        autoDiscardAt: DateTime(2026, 5, 15),
      );

      await storage.replaceOngoingSession(paused);
      await storage.replaceOngoingWithAbandoned(
        _session(
          date: now,
          id: 'ended',
          isPartial: true,
          isAbandoned: true,
          seconds: paused.actualDurationSeconds,
          targetMinutes: paused.targetDurationMinutes,
          setCount: 0,
        ),
      );

      final sessions = await storage.getSessions();
      expect(await storage.getOngoingSession(), isNull);
      expect(sessions.single.isAbandoned, isTrue);
      expect(XpService.calculateTotalXP(sessions), 15);
    },
  );
}

WorkoutSession _session({
  required DateTime date,
  DateTime? startedAt,
  String id = 'session',
  bool isPartial = false,
  bool isAbandoned = false,
  bool isPausedForResume = false,
  DateTime? pausedAt,
  DateTime? autoDiscardAt,
  int setCount = 3,
  int seconds = 1800,
  int targetMinutes = 30,
  int? baseXP,
  double? lckMultiplier,
  double? potionMultiplier,
  int? awardedXP,
  String? classAtSave,
  Map<String, int> statDelta = const {},
}) {
  return WorkoutSession(
    id: id,
    date: date,
    startedAt: startedAt,
    pausedAt: pausedAt,
    autoDiscardAt: autoDiscardAt,
    muscleGroup: 'Chest',
    targetDurationMinutes: targetMinutes,
    actualDurationSeconds: seconds,
    exercises: [
      ExerciseLog(
        exerciseId: 'bench',
        exerciseName: 'Bench Press',
        sets: [
          for (int i = 0; i < setCount; i++)
            const SetEntry(weight: 50, reps: 5),
        ],
      ),
    ],
    estimatedCalories: 100,
    isPartial: isPartial,
    isAbandoned: isAbandoned,
    isPausedForResume: isPausedForResume,
    selectedExerciseIds: const ['bench'],
    baseXP: baseXP,
    lckMultiplier: lckMultiplier,
    potionMultiplier: potionMultiplier,
    awardedXP: awardedXP,
    classAtSave: classAtSave,
    statDelta: statDelta,
  );
}
