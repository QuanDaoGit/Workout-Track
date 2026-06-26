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

  /// Upper bound on rest duration the ±15s controls can extend to — keeps
  /// repeated +15 taps from growing the timer unbounded.
  static const int maxRestSeconds = 600;

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

  /// Shift the active rest by [deltaSeconds] (the ±15s controls). A no-op when
  /// no rest is active. If the new remaining drops to zero or below, this is a
  /// skip ([cancel]). The [endsAt] timestamp stays the source of truth, and
  /// [RestSnapshot.totalSeconds] (the progress denominator) is only ever grown
  /// to cover the new remaining — never shrunk — so the fraction stays in
  /// `[0,1]` for every reader; extension is capped at [maxRestSeconds].
  void adjust(int deltaSeconds) {
    final snap = current.value;
    if (snap == null || !snap.isActive) return;
    final newRemaining = snap.remaining.inSeconds + deltaSeconds;
    if (newRemaining <= 0) {
      cancel();
      return;
    }
    final clamped = newRemaining > maxRestSeconds
        ? maxRestSeconds
        : newRemaining;
    current.value = RestSnapshot(
      endsAt: DateTime.now().add(Duration(seconds: clamped)),
      totalSeconds: snap.totalSeconds > clamped ? snap.totalSeconds : clamped,
    );
  }

  /// Clear the active rest (user tapped Skip, or rest finished naturally).
  void cancel() {
    current.value = null;
  }
}
