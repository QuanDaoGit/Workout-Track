import '../data/muscle_groups.dart';
import '../data/muscle_splits.dart';
import '../models/workout_models.dart';

/// One exercise's contribution to a muscle over the week — the logged name (so a
/// since-deleted exercise still reads), its id (for navigation), and the
/// fractional working **sets** it credited.
class MuscleContributor {
  const MuscleContributor({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
  });

  final String exerciseId;
  final String exerciseName;
  final double sets;
}

/// Pure analyzer: weekly **working-set** credit per canonical muscle bucket,
/// using the fractional method (direct/primary set = 1.0, indirect/secondary
/// set = 0.5) — the weighting that best explains hypertrophy in the volume
/// dose-response literature.
///
/// Display / coverage-analysis only — this feeds **no** XP/stat/overload path,
/// and nothing renders it yet. Stateless and catalog-driven (no
/// SharedPreferences), mirroring [WorkoutMetricService] so it's trivially
/// unit-testable with fixtures.
class MuscleCoverageService {
  const MuscleCoverageService._();

  /// Map of canonical bucket (`Chest`/`Back`/`Shoulders`/`Arms`/`Legs`/`Core`)
  /// → fractional working-set count over [window] ending at [now]. Buckets with
  /// no credit are absent.
  ///
  /// Per exercise: every working set credits **1.0** to the primary muscle's
  /// bucket and **0.5** to each *distinct* secondary bucket. Because detailed
  /// muscles collapse into 7 buckets, the secondary buckets are de-duped and the
  /// primary bucket always wins — a synergist that lands in the primary's own
  /// bucket (squat: glutes/hams alongside quads → all `Legs`) does **not** stack
  /// an extra 0.5 onto the direct credit.
  ///
  /// Notes: warm-up sets are excluded by construction ([ExerciseLog.sets] holds
  /// working sets only); partial/ongoing sessions are skipped; exercises absent
  /// from [exercisesById] (e.g. a deleted custom) are skipped, not guessed.
  /// `Full Body` never appears — no detailed muscle maps to it.
  static Map<String, double> weeklySetsByBucket({
    required List<WorkoutSession> sessions,
    required Map<String, Exercise> exercisesById,
    DateTime? now,
    Duration window = const Duration(days: 7),
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(window);
    final result = <String, double>{};

    for (final session in sessions) {
      if (session.isPartial) continue;
      if (!session.date.isAfter(cutoff)) continue;

      for (final log in session.exercises) {
        final setCount = log.sets.length;
        if (setCount == 0) continue;

        final exercise = exercisesById[log.exerciseId];
        if (exercise == null) continue;

        final primaryBucket = exercise.primaryMuscle == null
            ? null
            : _bucketFor(exercise.primaryMuscle!);
        if (primaryBucket != null) {
          result[primaryBucket] = (result[primaryBucket] ?? 0.0) + setCount;
        }

        final secondaryBuckets = <String>{};
        for (final muscle in exercise.secondaryMuscles) {
          final bucket = _bucketFor(muscle);
          if (bucket != null && bucket != primaryBucket) {
            secondaryBuckets.add(bucket);
          }
        }
        for (final bucket in secondaryBuckets) {
          result[bucket] = (result[bucket] ?? 0.0) + 0.5 * setCount;
        }
      }
    }

    return result;
  }

  /// Map of **detailed muscle** → fractional working-set count over [window]
  /// ending at [now] — the finer-grained sibling of [weeklySetsByBucket] that the
  /// detailed body map consumes. Keys are the raw free-exercise-db muscle tokens
  /// (`chest`/`biceps`/`triceps`/`lats`/`quadriceps`/…) **except** the two tokens
  /// that lack head granularity, which are split via the curated overrides
  /// ([splitDetailedMuscle]): `shoulders` → `front_delt`/`rear_delt`, `abdominals`
  /// → `rectus_abdominis`/`obliques`. An un-curated `shoulders`/`abdominals` stays
  /// the **generic token** (coarse — never guessed).
  ///
  /// Crediting per working set: 1.0 to the primary muscle, 0.5 to each secondary,
  /// primary wins on overlap. When a token splits into several sub-regions, the
  /// **dominant** (first-listed) region takes the full role weight and each extra
  /// region takes half — so a Russian twist is a full set for obliques + a half
  /// set for rectus, not a full set for both. Warm-ups excluded
  /// ([ExerciseLog.sets] is working sets only), partial sessions skipped, unknown
  /// exercises skipped. Display / coverage only — feeds no XP/stat/overload path.
  static Map<String, double> weeklySetsByMuscle({
    required List<WorkoutSession> sessions,
    required Map<String, Exercise> exercisesById,
    DateTime? now,
    Duration window = const Duration(days: 7),
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(window);
    final result = <String, double>{};

    for (final session in sessions) {
      if (session.isPartial) continue;
      if (!session.date.isAfter(cutoff)) continue;

      for (final log in session.exercises) {
        final setCount = log.sets.length;
        if (setCount == 0) continue;

        final exercise = exercisesById[log.exerciseId];
        if (exercise == null) continue;

        creditPerSet(exercise).forEach((key, weight) {
          result[key] = (result[key] ?? 0.0) + weight * setCount;
        });
      }
    }

    return result;
  }

  /// The per-**working-set** credit an exercise contributes to each detailed
  /// muscle key — the single source of truth both [weeklySetsByMuscle] and
  /// [weeklyContributors] use, so the meter total and the drill list can never
  /// disagree (Codex F2). Max weight wins (primary 1.0 over secondary 0.5 on any
  /// overlap); a split token gives its **dominant** sub-region the full role
  /// weight and each extra sub-region half.
  static Map<String, double> creditPerSet(Exercise exercise) {
    final credit = <String, double>{};
    void apply(String token, double roleBase) {
      final subs = splitDetailedMuscle(exercise.id, token);
      for (var i = 0; i < subs.length; i++) {
        final weight = roleBase * (i == 0 ? 1.0 : 0.5);
        final key = subs[i];
        final current = credit[key];
        if (current == null || weight > current) credit[key] = weight;
      }
    }

    final primary = exercise.primaryMuscle;
    if (primary != null) apply(primary, 1.0);
    for (final muscle in exercise.secondaryMuscles) {
      apply(muscle, 0.5);
    }
    return credit;
  }

  /// Per detailed-muscle key, the exercises that fed it over [window] and the
  /// working **sets each credited** (summed across that exercise's logs).
  /// Same crediting + same skips (warm-ups, partial, unknown-exercise) as
  /// [weeklySetsByMuscle], so per key the contributors' sets sum to that key's
  /// total. Display name comes from the **logged** [ExerciseLog.exerciseName] (so
  /// a since-deleted exercise still reads correctly); the id drives navigation.
  static Map<String, List<MuscleContributor>> weeklyContributors({
    required List<WorkoutSession> sessions,
    required Map<String, Exercise> exercisesById,
    DateTime? now,
    Duration window = const Duration(days: 7),
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(window);
    // key -> exerciseId -> accumulating contributor
    final byKey = <String, Map<String, MuscleContributor>>{};

    for (final session in sessions) {
      if (session.isPartial) continue;
      if (!session.date.isAfter(cutoff)) continue;

      for (final log in session.exercises) {
        final setCount = log.sets.length;
        if (setCount == 0) continue;
        final exercise = exercisesById[log.exerciseId];
        if (exercise == null) continue; // can't attribute → skip (meter skips too)

        creditPerSet(exercise).forEach((key, weight) {
          final perExercise = byKey.putIfAbsent(key, () => {});
          final existing = perExercise[log.exerciseId];
          perExercise[log.exerciseId] = MuscleContributor(
            exerciseId: log.exerciseId,
            exerciseName: log.exerciseName,
            sets: (existing?.sets ?? 0) + weight * setCount,
          );
        });
      }
    }

    return {
      for (final entry in byKey.entries)
        entry.key: entry.value.values.toList()
          ..sort((a, b) => b.sets.compareTo(a.sets)),
    };
  }

  /// Resolve a detailed muscle (`'triceps'`, `'lats'`) — or a legacy bucket-named
  /// string — to its canonical bucket. Mirrors the resolution the Logs muscle
  /// balance already uses, with a normalize fallback for custom/legacy data.
  static String? _bucketFor(String muscle) =>
      muscleGroupForDetailed(muscle) ?? normalizeMuscleGroup(muscle);

  /// [weeklyContributors] normalized to a **weekly average** over [window], so a
  /// multi-week window can be compared against the *weekly* MEV/MAV bands the
  /// body map paints (a multi-week *total* vs a weekly band would be nonsense).
  ///
  /// The divisor is the number of 7-day weeks in the window, but **capped to the
  /// user's real history** — `min(window, now − firstSessionEver)`, floored at one
  /// week. This is the load-bearing guard: it never divides known training by
  /// *empty pre-history weeks* (a new user whose whole history is one week, on the
  /// 12-week preset, must not read RESTED). An established user divides by the full
  /// window (4 or 12); rest/deload weeks *inside* the window still count — that
  /// honest chronic-coverage read is the whole point.
  ///
  /// Dividing every contributor's sets uniformly preserves the meter↔drill
  /// `sum == total` invariant ([MuscleBreakdown]). A ≤1-week window (or sparser
  /// history) returns the raw counts unchanged. [effectiveWeeks] is the real span
  /// used (≥1), for honest "avg/wk · last N wk" copy.
  static AveragedCoverage averagedContributors({
    required List<WorkoutSession> sessions,
    required Map<String, Exercise> exercisesById,
    DateTime? now,
    Duration window = const Duration(days: 7),
  }) {
    final clock = now ?? DateTime.now();
    final raw = weeklyContributors(
      sessions: sessions,
      exercisesById: exercisesById,
      now: clock,
      window: window,
    );

    DateTime? firstSession;
    for (final session in sessions) {
      if (session.isPartial) continue;
      if (firstSession == null || session.date.isBefore(firstSession)) {
        firstSession = session.date;
      }
    }

    final windowDays = window.inDays;
    final spanDays = firstSession == null
        ? windowDays
        : clock.difference(firstSession).inDays;
    final effectiveDays = spanDays.clamp(1, windowDays);
    final weeks = (effectiveDays / 7.0) < 1.0 ? 1.0 : effectiveDays / 7.0;

    if (weeks <= 1.0) {
      return AveragedCoverage(contributors: raw, effectiveWeeks: 1.0);
    }

    final averaged = {
      for (final entry in raw.entries)
        entry.key: [
          for (final c in entry.value)
            MuscleContributor(
              exerciseId: c.exerciseId,
              exerciseName: c.exerciseName,
              sets: c.sets / weeks,
            ),
        ],
    };
    return AveragedCoverage(contributors: averaged, effectiveWeeks: weeks);
  }
}

/// The body map's window read: per-detailed-muscle contributors already
/// normalized to a weekly average, plus the real span the divisor used.
class AveragedCoverage {
  const AveragedCoverage({
    required this.contributors,
    required this.effectiveWeeks,
  });

  final Map<String, List<MuscleContributor>> contributors;

  /// The span actually averaged over (≥1) — equals the nominal window weeks for
  /// an established user, less when history is shorter. Drives honest copy.
  final double effectiveWeeks;
}
