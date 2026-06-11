import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/services/body_metrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('logWeight - unrestricted logging + validation', () {
    test('logs entry and retrieves it', () async {
      final service = BodyMetricsService(
        nowProvider: () => DateTime(2026, 5, 16),
      );
      final entry = await service.logWeight(74.2, currentGoal: BodyGoal.cut);

      expect(entry.weightKg, 74.2);
      expect(entry.goalAtTime, BodyGoal.cut);

      final entries = await service.getEntries();
      expect(entries.length, 1);
      expect(entries.first.weightKg, 74.2);
    });

    test('allows multiple logs in the same week (no cadence gate)', () async {
      final now = DateTime(2026, 5, 16);
      await BodyMetricsService(nowProvider: () => now).logWeight(75.0);

      final next = BodyMetricsService(
        nowProvider: () => now.add(const Duration(days: 2)),
      );
      await next.logWeight(74.6); // would have thrown under the old 7-day gate

      expect(await next.getEntries(), hasLength(2));
    });

    test('rejects an implausible weight at the data layer', () async {
      final service = BodyMetricsService(
        nowProvider: () => DateTime(2026, 5, 16),
      );
      expect(() => service.logWeight(750.0), throwsA(isA<ArgumentError>()));
      expect(() => service.logWeight(5.0), throwsA(isA<ArgumentError>()));
      expect(await service.getEntries(), isEmpty);
    });
  });

  group('reward cadence (rolling 7-day reward anchor)', () {
    test('reward is available before any has been granted', () async {
      final service = BodyMetricsService(
        nowProvider: () => DateTime(2026, 5, 16),
      );
      expect(await service.canEarnReward(), true);
      expect(await service.daysUntilNextReward(), 0);
    });

    test('blocks a second reward within 7 days of the last', () async {
      final now = DateTime(2026, 5, 16);
      await BodyMetricsService(nowProvider: () => now).markRewardGranted();

      final later = BodyMetricsService(
        nowProvider: () => now.add(const Duration(days: 4)),
      );
      expect(await later.canEarnReward(), false);
      expect(await later.daysUntilNextReward(), 3);
    });

    test('allows a reward again after 7 days', () async {
      final now = DateTime(2026, 5, 16);
      await BodyMetricsService(nowProvider: () => now).markRewardGranted();

      final later = BodyMetricsService(
        nowProvider: () => now.add(const Duration(days: 7)),
      );
      expect(await later.canEarnReward(), true);
      expect(await later.daysUntilNextReward(), 0);
    });

    test('clock rollback cannot reopen the reward window', () async {
      final now = DateTime(2026, 5, 16);
      await BodyMetricsService(nowProvider: () => now).markRewardGranted();

      final backdated = BodyMetricsService(
        nowProvider: () => now.subtract(const Duration(days: 10)),
      );
      expect(await backdated.canEarnReward(), false);
    });

    test('reward cadence is calendar-day based (no time-of-day drift)', () async {
      await BodyMetricsService(
        nowProvider: () => DateTime(2026, 5, 16, 20, 0),
      ).markRewardGranted();

      final morningSeven = BodyMetricsService(
        nowProvider: () => DateTime(2026, 5, 23, 6, 0),
      );
      expect(await morningSeven.canEarnReward(), true);
      expect(await morningSeven.daysUntilNextReward(), 0);

      final morningSix = BodyMetricsService(
        nowProvider: () => DateTime(2026, 5, 22, 6, 0),
      );
      expect(await morningSix.canEarnReward(), false);
      expect(await morningSix.daysUntilNextReward(), 1);
    });
  });

  group('reward-anchor migration seeding', () {
    test('seeds from a recent log so no free reward on upgrade', () async {
      // Logged 2 days before the upgrade.
      await BodyMetricsService(
        nowProvider: () => DateTime(2026, 5, 14),
      ).logWeight(75.0);

      final today = BodyMetricsService(
        nowProvider: () => DateTime(2026, 5, 16),
      );
      await today.seedRewardAnchorFromLastLog();

      expect(await today.canEarnReward(), false);
      expect(await today.daysUntilNextReward(), 5);
    });

    test('seeds from an old log so a due reward stays available', () async {
      await BodyMetricsService(
        nowProvider: () => DateTime(2026, 5, 8),
      ).logWeight(75.0);

      final today = BodyMetricsService(
        nowProvider: () => DateTime(2026, 5, 16),
      );
      await today.seedRewardAnchorFromLastLog();

      expect(await today.canEarnReward(), true);
    });

    test('never-logged user: seeding is a no-op, first log rewards', () async {
      final service = BodyMetricsService(
        nowProvider: () => DateTime(2026, 5, 16),
      );
      await service.seedRewardAnchorFromLastLog();
      expect(await service.canEarnReward(), true);
    });

    test('seeding is idempotent — a second seed never moves the anchor', () async {
      await BodyMetricsService(
        nowProvider: () => DateTime(2026, 5, 14),
      ).logWeight(75.0);

      final svc = BodyMetricsService(nowProvider: () => DateTime(2026, 5, 16));
      await svc.seedRewardAnchorFromLastLog(); // anchor = 2 days ago

      // A newer log updates the last-log token...
      await svc.logWeight(74.0);
      // ...but re-seeding must not overwrite the existing anchor.
      await svc.seedRewardAnchorFromLastLog();

      expect(await svc.daysUntilNextReward(), 5); // still based on the old log
    });
  });

  group('anti-farm: reward anchor survives delete', () {
    test('granting then deleting the entry keeps the reward window closed', () async {
      final now = DateTime(2026, 5, 16);
      final service = BodyMetricsService(nowProvider: () => now);
      final entry = await service.logWeight(75.0);
      await service.markRewardGranted();

      final later = BodyMetricsService(
        nowProvider: () => now.add(const Duration(days: 3)),
      );
      await later.deleteEntry(entry.loggedAt);

      expect(await later.getEntries(), isEmpty);
      expect(await later.canEarnReward(), false);
      expect(await later.daysUntilNextReward(), 4);
    });
  });

  group('deleteEntry', () {
    test('removes entry by timestamp', () async {
      final now = DateTime(2026, 5, 2);
      final service = BodyMetricsService(nowProvider: () => now);
      await service.logWeight(75.0);

      final service2 = BodyMetricsService(
        nowProvider: () => now.add(const Duration(days: 7)),
      );
      await service2.logWeight(74.5);

      await service2.deleteEntry(now);
      final entries = await service2.getEntries();
      expect(entries.length, 1);
      expect(entries.first.weightKg, 74.5);
    });
  });

  group('updateEntry', () {
    test('corrects a weight in place without adding an entry', () async {
      final now = DateTime(2026, 5, 16);
      final service = BodyMetricsService(nowProvider: () => now);
      final entry = await service.logWeight(75.0);

      await service.updateEntry(entry.loggedAt, 76.5);

      final entries = await service.getEntries();
      expect(entries.length, 1, reason: 'edit must not create a new entry');
      expect(entries.first.weightKg, 76.5);
      expect(entries.first.loggedAt, entry.loggedAt);
    });

    test('does not touch the reward anchor (editing is not a new log)', () async {
      final now = DateTime(2026, 5, 16);
      final service = BodyMetricsService(nowProvider: () => now);
      final entry = await service.logWeight(75.0);
      await service.markRewardGranted();

      await service.updateEntry(entry.loggedAt, 76.0);
      expect(await service.canEarnReward(), false);
    });

    test('is a no-op for an implausible correction', () async {
      final now = DateTime(2026, 5, 16);
      final service = BodyMetricsService(nowProvider: () => now);
      final entry = await service.logWeight(75.0);

      await service.updateEntry(entry.loggedAt, 999.0);
      final entries = await service.getEntries();
      expect(entries.first.weightKg, 75.0);
    });

    test('is a no-op when no entry matches the timestamp', () async {
      final now = DateTime(2026, 5, 16);
      final service = BodyMetricsService(nowProvider: () => now);
      await service.logWeight(75.0);

      await service.updateEntry(DateTime(2020, 1, 1), 80.0);
      final entries = await service.getEntries();
      expect(entries.length, 1);
      expect(entries.first.weightKg, 75.0);
    });
  });
}
