import 'package:flutter/foundation.dart';

/// Snapshot of an active rest. Both per-set rest (fired inside
/// `exercise_session`) and between-exercise rest (fired on Finish Exercise,
/// surfaced on `active_workout`) flow through the same snapshot.
class RestSnapshot {
  const RestSnapshot({required this.endsAt, required this.totalSeconds});

  final DateTime endsAt;
  final int totalSeconds;

  Duration get remaining {
    final delta = endsAt.difference(DateTime.now());
    return delta.isNegative ? Duration.zero : delta;
  }

  bool get isActive => remaining > Duration.zero;
}

/// Singleton state observed by both `exercise_session` and `active_workout`.
/// Source of truth is the [endsAt] timestamp, so a navigation pop never
/// resets the timer.
class RestTimerService {
  RestTimerService._();
  static final RestTimerService instance = RestTimerService._();

  final ValueNotifier<RestSnapshot?> current = ValueNotifier<RestSnapshot?>(
    null,
  );

  /// Start a fresh rest for [seconds]. Replaces any active timer.
  void start(int seconds) {
    if (seconds <= 0) {
      current.value = null;
      return;
    }
    current.value = RestSnapshot(
      endsAt: DateTime.now().add(Duration(seconds: seconds)),
      totalSeconds: seconds,
    );
  }

  /// Clear the active rest (user tapped Skip, or rest finished naturally).
  void cancel() {
    current.value = null;
  }
}
