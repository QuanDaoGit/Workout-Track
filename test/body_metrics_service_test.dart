import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/body_metrics_models.dart';
import 'package:workout_track/services/body_metrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('canLogWeight - 7-day cadence enforcement', () {
    test('allows first-ever log', () async {
      final service = BodyMetricsService(
        nowProvider: () => DateTime(2026, 5, 16),
      );
      expect(await service.canLogWeight(), true);
    });

    test('blocks log within 7 days of last entry', () async {
      final now = DateTime(2026, 5, 16);
      final service = BodyMetricsService(nowProvider: () => now);
      await service.logWeight(75.0);

      // 3 days later
      final laterService = BodyMetricsService(
        nowProvider: () => now.add(const Duration(days: 3)),
      );
      expect(await laterService.canLogWeight(), false);
    });

    test('allows log after 7 days', () async {
      final now = DateTime(2026, 5, 16);
      final service = BodyMetricsService(nowProvider: () => now);
      await service.logWeight(75.0);

      // 7 days later
      final laterService = BodyMetricsService(
        nowProvider: () => now.add(const Duration(days: 7)),
      );
      expect(await laterService.canLogWeight(), true);
    });

    test('clock manipulation guard - prevents backdating', () async {
      final now = DateTime(2026, 5, 16);
      final service = BodyMetricsService(nowProvider: () => now);
      await service.logWeight(75.0);

      // User sets clock back 10 days
      final backdatedService = BodyMetricsService(
        nowProvider: () => now.subtract(const Duration(days: 10)),
      );
      expect(await backdatedService.canLogWeight(), false);
    });
  });

  group('daysUntilNextLog', () {
    test('returns 0 when no entries exist', () async {
      final service = BodyMetricsService(
        nowProvider: () => DateTime(2026, 5, 16),
      );
      expect(await service.daysUntilNextLog(), 0);
    });

    test('returns remaining days correctly', () async {
      final now = DateTime(2026, 5, 16);
      final service = BodyMetricsService(nowProvider: () => now);
      await service.logWeight(75.0);

      final laterService = BodyMetricsService(
        nowProvider: () => now.add(const Duration(days: 4)),
      );
      expect(await laterService.daysUntilNextLog(), 3);
    });

    test('returns 0 when 7 days have passed', () async {
      final now = DateTime(2026, 5, 16);
      final service = BodyMetricsService(nowProvider: () => now);
      await service.logWeight(75.0);

      final laterService = BodyMetricsService(
        nowProvider: () => now.add(const Duration(days: 8)),
      );
      expect(await laterService.daysUntilNextLog(), 0);
    });
  });

  group('logWeight', () {
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

    test('throws when cadence not met', () async {
      final now = DateTime(2026, 5, 16);
      final service = BodyMetricsService(nowProvider: () => now);
      await service.logWeight(75.0);

      final laterService = BodyMetricsService(
        nowProvider: () => now.add(const Duration(days: 3)),
      );
      expect(
        () => laterService.logWeight(74.0),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('isDirectionAligned', () {
    test('CUT: aligned when current < previous by >= 0.3 kg', () {
      final previous = WeightEntry(
        weightKg: 75.0,
        loggedAt: DateTime(2026, 5, 9),
      );
      final current = WeightEntry(
        weightKg: 74.5,
        loggedAt: DateTime(2026, 5, 16),
      );
      expect(
        BodyMetricsService.isDirectionAligned(current, previous, BodyGoal.cut),
        true,
      );
    });

    test('CUT: not aligned when delta < 0.3', () {
      final previous = WeightEntry(
        weightKg: 75.0,
        loggedAt: DateTime(2026, 5, 9),
      );
      final current = WeightEntry(
        weightKg: 74.8,
        loggedAt: DateTime(2026, 5, 16),
      );
      expect(
        BodyMetricsService.isDirectionAligned(current, previous, BodyGoal.cut),
        false,
      );
    });

    test('BULK: aligned when current > previous by >= 0.3 kg', () {
      final previous = WeightEntry(
        weightKg: 75.0,
        loggedAt: DateTime(2026, 5, 9),
      );
      final current = WeightEntry(
        weightKg: 75.5,
        loggedAt: DateTime(2026, 5, 16),
      );
      expect(
        BodyMetricsService.isDirectionAligned(current, previous, BodyGoal.bulk),
        true,
      );
    });

    test('BULK: not aligned when weight drops', () {
      final previous = WeightEntry(
        weightKg: 75.0,
        loggedAt: DateTime(2026, 5, 9),
      );
      final current = WeightEntry(
        weightKg: 74.5,
        loggedAt: DateTime(2026, 5, 16),
      );
      expect(
        BodyMetricsService.isDirectionAligned(current, previous, BodyGoal.bulk),
        false,
      );
    });

    test('RECOMP: aligned when abs(delta) <= 0.5 kg', () {
      final previous = WeightEntry(
        weightKg: 75.0,
        loggedAt: DateTime(2026, 5, 9),
      );
      final current = WeightEntry(
        weightKg: 75.3,
        loggedAt: DateTime(2026, 5, 16),
      );
      expect(
        BodyMetricsService.isDirectionAligned(
          current,
          previous,
          BodyGoal.recomp,
        ),
        true,
      );
    });

    test('RECOMP: not aligned when abs(delta) > 0.5 kg', () {
      final previous = WeightEntry(
        weightKg: 75.0,
        loggedAt: DateTime(2026, 5, 9),
      );
      final current = WeightEntry(
        weightKg: 75.8,
        loggedAt: DateTime(2026, 5, 16),
      );
      expect(
        BodyMetricsService.isDirectionAligned(
          current,
          previous,
          BodyGoal.recomp,
        ),
        false,
      );
    });

    test('returns false for first-ever log (no previous entry)', () {
      final current = WeightEntry(
        weightKg: 75.0,
        loggedAt: DateTime(2026, 5, 16),
      );
      expect(
        BodyMetricsService.isDirectionAligned(current, null, BodyGoal.cut),
        false,
      );
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
}
