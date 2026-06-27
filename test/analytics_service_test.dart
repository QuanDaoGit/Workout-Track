import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/services/analytics_consent_service.dart';
import 'package:workout_track/services/analytics_service.dart';

/// Captures everything the facade forwards, so we can assert the consent gate.
class _RecordingSink implements AnalyticsSink {
  final List<(String, Map<String, Object>?)> events = [];
  final List<(String, String?)> userProps = [];
  bool? collectionEnabled;

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    events.add((name, parameters));
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    userProps.add((name, value));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AnalyticsConsentService', () {
    test('analytics defaults ON, crash reporting defaults OFF', () async {
      final c = AnalyticsConsentService();
      expect(await c.analyticsEnabled(), isTrue);
      expect(await c.crashReportingEnabled(), isFalse);
    });

    test('analytics opt-out persists across instances', () async {
      await AnalyticsConsentService().setAnalyticsOptedOut(true);
      expect(await AnalyticsConsentService().analyticsEnabled(), isFalse);
    });

    test('crash opt-in persists across instances', () async {
      await AnalyticsConsentService().setCrashReportingOptedIn(true);
      expect(await AnalyticsConsentService().crashReportingEnabled(), isTrue);
    });
  });

  group('AnalyticsService consent gate', () {
    test('forwards events + params when enabled (default)', () async {
      final sink = _RecordingSink();
      await AnalyticsService.bootstrap(sink: sink);

      await AnalyticsService.instance.logWorkoutSaved(
        exerciseCount: 4,
        setCount: 12,
        durationSeconds: 3000,
      );

      expect(sink.collectionEnabled, isTrue);
      expect(sink.events, hasLength(1));
      expect(sink.events.single.$1, 'workout_saved');
      expect(sink.events.single.$2, {
        'exercise_count': 4,
        'set_count': 12,
        'duration_seconds': 3000,
      });
    });

    test('drops events AND disables collection when opted out', () async {
      await AnalyticsConsentService().setAnalyticsOptedOut(true);
      final sink = _RecordingSink();
      await AnalyticsService.bootstrap(sink: sink);

      await AnalyticsService.instance.logAppOpen();

      expect(sink.collectionEnabled, isFalse);
      expect(sink.events, isEmpty);
    });

    test('toggling opt-out at runtime stops forwarding', () async {
      final sink = _RecordingSink();
      await AnalyticsService.bootstrap(sink: sink);

      await AnalyticsService.instance.logAppOpen();
      expect(sink.events, hasLength(1));

      await AnalyticsService.instance.setAnalyticsOptedOut(true);
      await AnalyticsService.instance.logAppOpen();

      expect(sink.events, hasLength(1)); // no new event after opt-out
      expect(sink.collectionEnabled, isFalse);
    });
  });

  group('first_workout_saved lifetime guard', () {
    test('fires once per install, never again — even after re-bootstrap', () async {
      final sink = _RecordingSink();
      await AnalyticsService.bootstrap(sink: sink);
      await AnalyticsService.instance.logFirstWorkoutSaved();
      await AnalyticsService.instance.logFirstWorkoutSaved();
      // The persisted flag survives a later install session (fresh bootstrap).
      final sink2 = _RecordingSink();
      await AnalyticsService.bootstrap(sink: sink2);
      await AnalyticsService.instance.logFirstWorkoutSaved();
      expect(
        sink.events.where((e) => e.$1 == 'first_workout_saved'),
        hasLength(1),
      );
      expect(sink2.events.where((e) => e.$1 == 'first_workout_saved'), isEmpty);
    });
  });
}
