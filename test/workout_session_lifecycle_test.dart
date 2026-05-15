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
      ..remove('isAbandoned');

    final parsed = WorkoutSession.fromJson(legacy);
    expect(parsed.startedAt, date);
    expect(parsed.isAbandoned, isFalse);
    expect(parsed.isOngoing, isFalse);

    final abandoned = _session(
      date: date,
      startedAt: date.subtract(const Duration(minutes: 10)),
      isPartial: true,
      isAbandoned: true,
    );
    final json = abandoned.toJson();
    expect(json['startedAt'], abandoned.startedAt.toIso8601String());
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
}

WorkoutSession _session({
  required DateTime date,
  DateTime? startedAt,
  String id = 'session',
  bool isPartial = false,
  bool isAbandoned = false,
  int setCount = 3,
  int seconds = 1800,
  int targetMinutes = 30,
}) {
  return WorkoutSession(
    id: id,
    date: date,
    startedAt: startedAt,
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
    selectedExerciseIds: const ['bench'],
  );
}
