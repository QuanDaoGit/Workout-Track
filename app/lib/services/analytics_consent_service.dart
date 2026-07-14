import 'package:shared_preferences/shared_preferences.dart';

/// Consent for off-device telemetry (ADR 0001 —
/// docs/decisions/0001-usage-instrumentation.md).
///
/// Two independent scopes, each its own SharedPreferences key:
/// - **Analytics (Firebase)** — ON by default; the user can OPT OUT.
/// - **Crash reporting (Sentry)** — OFF by default; the user must OPT IN.
///
/// Mirrors the app's keyed-pref service pattern (e.g. `WorkoutDefaultsService`).
/// Regardless of these flags, no PII / bodyweight / name / exercise content ever
/// leaves the device — these gate only the anonymous event stream.
class AnalyticsConsentService {
  static const _analyticsOptOutKey = 'analytics_opt_out_v1';
  static const _crashOptInKey = 'crash_reporting_opt_in_v1';
  static const _firstWorkoutLoggedKey = 'analytics_first_workout_logged_v1';

  /// Analytics is collected unless the user has opted out. Default: `true`.
  Future<bool> analyticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_analyticsOptOutKey) ?? false);
  }

  Future<void> setAnalyticsOptedOut(bool optedOut) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_analyticsOptOutKey, optedOut);
  }

  /// Crash reporting is off until the user opts in. Default: `false`.
  Future<bool> crashReportingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_crashOptInKey) ?? false;
  }

  Future<void> setCrashReportingOptedIn(bool optedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_crashOptInKey, optedIn);
  }

  /// Lifetime guard so `first_workout_saved` is emitted at most once per install
  /// (ADR 0001) — never re-derived from mutable workout history, which a delete
  /// or reset could send back to "one completed session".
  Future<bool> hasLoggedFirstWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstWorkoutLoggedKey) ?? false;
  }

  Future<void> markFirstWorkoutLogged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstWorkoutLoggedKey, true);
  }
}
