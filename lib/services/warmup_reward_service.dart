import '../models/workout_models.dart';
import 'gem_service.dart';

/// Grants the small gem bonus for logging a warm-up set this session.
///
/// "Warmed up" is now **observable** — `session.warmedUp` is true when an
/// exercise carries a logged warm-up set ([ExerciseLog.warmupSets]) — not a
/// self-reported toggle. Anchored to a **real saved workout** and **capped once
/// per calendar day**: the award is keyed on the session's day (`warmup:<dayKey>`
/// in the gem ledger), so a second warmed-up session the same day — or a retried
/// save — can never double-credit. Mirrors [AdventureService.grantChargeForSession]:
/// same not-partial/not-abandoned + has-a-real-working-set gates, and it never
/// throws into the save path (a warm-up reward can never break a save).
class WarmupRewardService {
  WarmupRewardService({GemService? gemService})
    : _gems = gemService ?? GemService();

  final GemService _gems;

  /// Flat, deliberately small (a summary "cherry", not the headline reason —
  /// keeps the act intrinsically motivated rather than reward-driven).
  static const int gemReward = 10;

  static const String label = 'Warm-up bonus';

  /// Awards [gemReward] gems for [session] when it qualifies, returning the
  /// amount credited (0 if it didn't qualify or was already claimed today).
  Future<int> grantForSession(WorkoutSession session, {DateTime? now}) async {
    try {
      if (session.isPartial || session.isAbandoned) return 0;
      if (!session.warmedUp) return 0;
      // Anchor to real training: a warm-up set earns nothing without at least
      // one real working set logged (same bar as the Adventure charge).
      final hasRealSet = session.exercises.any(
        (log) => log.sets.any((set) => set.reps > 0),
      );
      if (!hasRealSet) return 0;

      return await _gems.awardWarmupGems(
        dayKey: _dayKey(session.date),
        amount: gemReward,
        label: label,
        now: now,
      );
    } catch (_) {
      // A warm-up reward can never break a workout save.
      return 0;
    }
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
