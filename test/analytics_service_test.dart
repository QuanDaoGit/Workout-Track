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

  group('newly wired taxonomy events forward name + params', () {
    late _RecordingSink sink;
    setUp(() async {
      sink = _RecordingSink();
      await AnalyticsService.bootstrap(sink: sink);
    });

    test('workout_started carries muscle_groups, exercise_count, source', () async {
      await AnalyticsService.instance.logWorkoutStarted(
        muscleGroups: ['Chest', 'Back'],
        exerciseCount: 5,
        source: AnalyticsValue.sourceProgram,
      );
      expect(sink.events.single.$1, 'workout_started');
      expect(sink.events.single.$2, {
        'muscle_groups': 'Chest,Back',
        'exercise_count': 5,
        'source': 'program',
      });
    });

    test('consent_changed carries scope + value', () async {
      await AnalyticsService.instance.logConsentChanged(
        AnalyticsValue.consentCrash,
        true,
      );
      expect(sink.events.single.$1, 'consent_changed');
      expect(sink.events.single.$2, {'scope': 'crash', 'value': true});
    });

    test('enum-param events forward their single param', () async {
      await AnalyticsService.instance.logRestAction(AnalyticsValue.restSkip);
      await AnalyticsService.instance.logWorkoutDiscarded(
        AnalyticsValue.discardUser,
      );
      await AnalyticsService.instance.logCharacterView(
        AnalyticsValue.surfaceProfile,
      );
      await AnalyticsService.instance.logCosmeticEquipped(
        AnalyticsValue.cosmeticFrame,
      );
      await AnalyticsService.instance.logOnboardingStep(
        AnalyticsValue.stepStartGate,
      );
      expect(sink.events.map((e) => e.$1).toList(), [
        'rest_action',
        'workout_discarded',
        'character_view',
        'cosmetic_equipped',
        'onboarding_step',
      ]);
      expect(sink.events[0].$2, {'kind': 'skip'});
      expect(sink.events[1].$2, {'reason': 'user_discard'});
      expect(sink.events[2].$2, {'surface': 'profile'});
      expect(sink.events[3].$2, {'kind': 'frame'});
      expect(sink.events[4].$2, {'step': 'start_gate'});
    });

    test('paramless lifecycle + engagement events forward by name', () async {
      await AnalyticsService.instance.logIncompleteWorkoutFound();
      await AnalyticsService.instance.logWorkoutRecovered();
      await AnalyticsService.instance.logLootUnlockViewed();
      expect(sink.events.map((e) => e.$1).toList(), [
        'incomplete_workout_found',
        'workout_recovered',
        'loot_unlock_viewed',
      ]);
    });

    test('setUserProperties forwards class + reduced_motion', () async {
      await AnalyticsService.instance.setUserProperties(
        characterClass: 'tank',
        reducedMotion: true,
      );
      expect(sink.userProps, contains(('class', 'tank')));
      expect(sink.userProps, contains(('reduced_motion', 'true')));
    });

    test('opted out: none of the new events forward', () async {
      await AnalyticsService.instance.setAnalyticsOptedOut(true);
      await AnalyticsService.instance.logRestAction(AnalyticsValue.restStart);
      await AnalyticsService.instance.logLootUnlockViewed();
      await AnalyticsService.instance.logConsentChanged(
        AnalyticsValue.consentAnalytics,
        false,
      );
      expect(sink.events, isEmpty);
    });
  });
}
