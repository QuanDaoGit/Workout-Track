import 'package:firebase_analytics/firebase_analytics.dart';

import 'analytics_consent_service.dart';

/// Where analytics events go. The app depends on this interface, **not** on
/// Firebase directly — so the SDK stays contained to [FirebaseAnalyticsSink] and
/// tests can inject a recording / no-op sink. (ADR 0001.)
abstract class AnalyticsSink {
  Future<void> logEvent(String name, {Map<String, Object>? parameters});
  Future<void> setCollectionEnabled(bool enabled);
  Future<void> setUserProperty(String name, String? value);
}

/// The default sink before [AnalyticsService.bootstrap], and the sink used by
/// tests / builds without Firebase configured.
class NoopAnalyticsSink implements AnalyticsSink {
  const NoopAnalyticsSink();
  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {}
  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
  @override
  Future<void> setUserProperty(String name, String? value) async {}
}

/// The real Firebase-backed sink — the only place in the app that touches the
/// Firebase Analytics SDK.
class FirebaseAnalyticsSink implements AnalyticsSink {
  FirebaseAnalyticsSink(this._fa);
  final FirebaseAnalytics _fa;

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) =>
      _fa.logEvent(name: name, parameters: parameters);

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      _fa.setAnalyticsCollectionEnabled(enabled);

  @override
  Future<void> setUserProperty(String name, String? value) =>
      _fa.setUserProperty(name: name, value: value);
}

/// Single chokepoint for product analytics (ADR 0001; taxonomy in
/// `statistics/metrics-glossary.md`). Typed events only, with anonymous params —
/// **never** bodyweight, name, or exercise content. Telemetry must never crash
/// the app, so every send is guarded and a no-op until [bootstrap].
class AnalyticsService {
  AnalyticsService(this._sink, this._consent);

  /// Mutable so [bootstrap] can install the Firebase sink and tests can inject a
  /// recording sink. Starts as a no-op, so calls before bootstrap are safe.
  static AnalyticsService instance =
      AnalyticsService(const NoopAnalyticsSink(), AnalyticsConsentService());

  final AnalyticsSink _sink;
  final AnalyticsConsentService _consent;
  bool _enabled = true;

  /// Install the production sink and apply the stored consent state. Called once
  /// from `main()` after `Firebase.initializeApp`.
  static Future<void> bootstrap({required AnalyticsSink sink}) async {
    instance = AnalyticsService(sink, AnalyticsConsentService());
    await instance._applyConsent();
  }

  Future<void> _applyConsent() async {
    _enabled = await _consent.analyticsEnabled();
    await _sink.setCollectionEnabled(_enabled);
  }

  /// Settings opt-out toggle — also disables collection at the SDK level.
  Future<void> setAnalyticsOptedOut(bool optedOut) async {
    await _consent.setAnalyticsOptedOut(optedOut);
    _enabled = !optedOut;
    await _sink.setCollectionEnabled(_enabled);
  }

  // ---- Event taxonomy (statistics/metrics-glossary.md) ----------------------

  Future<void> logAppOpen() => _log('app_open');

  Future<void> logOnboardingStep(String step) =>
      _log('onboarding_step', {'step': step});

  Future<void> logOnboardingComplete() => _log('onboarding_complete');

  Future<void> logWorkoutStarted({
    required List<String> muscleGroups,
    required int exerciseCount,
    required String source,
  }) =>
      _log('workout_started', {
        'muscle_groups': muscleGroups.join(','),
        'exercise_count': exerciseCount,
        'source': source,
      });

  /// Lifetime-once: the activation event must fire at most once per install, so a
  /// delete-then-resave (or history reset) can't re-emit it (ADR 0001, Codex F1).
  Future<void> logFirstWorkoutSaved() async {
    if (!_enabled) return;
    if (await _consent.hasLoggedFirstWorkout()) return;
    await _consent.markFirstWorkoutLogged();
    await _log('first_workout_saved');
  }

  Future<void> logWorkoutSaved({
    required int exerciseCount,
    required int setCount,
    required int durationSeconds,
  }) =>
      _log('workout_saved', {
        'exercise_count': exerciseCount,
        'set_count': setCount,
        'duration_seconds': durationSeconds,
      });

  Future<void> logWorkoutSaveFailed(String reason) =>
      _log('workout_save_failed', {'reason': reason});

  Future<void> logWorkoutDiscarded(String reason) =>
      _log('workout_discarded', {'reason': reason});

  Future<void> logIncompleteWorkoutFound() => _log('incomplete_workout_found');

  Future<void> logWorkoutRecovered() => _log('workout_recovered');

  Future<void> logRestAction(String kind) => _log('rest_action', {'kind': kind});

  Future<void> logCharacterView(String surface) =>
      _log('character_view', {'surface': surface});

  Future<void> logCosmeticEquipped(String kind) =>
      _log('cosmetic_equipped', {'kind': kind});

  Future<void> logLootUnlockViewed() => _log('loot_unlock_viewed');

  /// Anonymous segmentation only (no identifiers).
  Future<void> setUserProperties({
    String? characterClass,
    bool? reducedMotion,
  }) async {
    if (!_enabled) return;
    try {
      if (characterClass != null) {
        await _sink.setUserProperty('class', characterClass);
      }
      if (reducedMotion != null) {
        await _sink.setUserProperty('reduced_motion', reducedMotion.toString());
      }
    } catch (_) {
      // Telemetry must never crash the app.
    }
  }

  /// Consent telemetry — fires when the user flips the analytics opt-out or the
  /// crash-reporting opt-in toggle. `scope` ∈ {analytics, crash}; `value` is the
  /// new enabled-state. Emitted BEFORE opt-out disables collection so the last
  /// event a departing user sends is their own opt-out (ADR 0001).
  Future<void> logConsentChanged(String scope, bool value) =>
      _log('consent_changed', {'scope': scope, 'value': value});

  Future<void> _log(String name, [Map<String, Object>? parameters]) async {
    if (!_enabled) return;
    try {
      await _sink.logEvent(name, parameters: parameters);
    } catch (_) {
      // Telemetry must never crash the app.
    }
  }
}

/// Centralized param-value vocabulary for the event taxonomy
/// (`statistics/metrics-glossary.md`). Callers reference these instead of bare
/// string literals so an enum value means one thing everywhere.
abstract final class AnalyticsValue {
  // onboarding_step.step (visual step order)
  static const stepColdOpen = 'cold_open';
  static const stepProblem = 'problem';
  static const stepSolution = 'solution';
  static const stepCalibrationQuizA = 'calibration_quiz_a';
  static const stepClassReveal = 'class_reveal';
  static const stepCalibrationQuizB = 'calibration_quiz_b';
  static const stepProgramSelection = 'program_selection';
  static const stepNameScreen = 'name_screen';
  static const stepStartGate = 'start_gate';

  // workout_started.source
  static const sourceProgram = 'program';
  static const sourceFree = 'free';

  // workout_save_failed.reason
  static const saveFailLockTimeout = 'lock_timeout';
  static const saveFailWriteFailed = 'write_failed';

  // workout_discarded.reason
  static const discardIdleZeroSets = 'idle_zero_sets';
  static const discardUser = 'user_discard';

  // rest_action.kind
  static const restStart = 'start';
  static const restFinish = 'finish';
  static const restSkip = 'skip';
  static const restAdjust = 'adjust';

  // character_view.surface
  static const surfaceInventory = 'inventory';
  static const surfaceProfile = 'profile';

  // cosmetic_equipped.kind
  static const cosmeticTitle = 'title';
  static const cosmeticFrame = 'frame';

  // consent_changed.scope
  static const consentAnalytics = 'analytics';
  static const consentCrash = 'crash';
}
