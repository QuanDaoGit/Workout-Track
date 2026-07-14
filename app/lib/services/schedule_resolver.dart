import '../models/program_models.dart';

/// The resolved meaning of a single calendar date under the weekday-anchored
/// schedule: is it a training day, and if so which workout the user does and
/// which workout-index completing it advances from.
///
/// One [ResolvedDay] is produced per date by [ScheduleResolver.resolve] and is
/// the SOLE answer to "what happens today" — both the displayed workout and the
/// shield/recovery stamping read the same object, so Home can never show rest
/// while shields burn for training (Codex review finding #1).
class ResolvedDay {
  const ResolvedDay({
    required this.isTrainingDay,
    this.displayedWorkout,
    this.workoutIndexToComplete,
  });

  /// A planned rest day — a non-training weekday (rest is calendar-derived).
  const ResolvedDay.rest() : this(isTrainingDay: false);

  /// True when this weekday is one the user anchored as a training day.
  final bool isTrainingDay;

  /// The workout to surface on a training day (`null` on rest, or when no
  /// program is active / the program has no workouts).
  final ProgramDay? displayedWorkout;

  /// The index into [Program.workouts] that completing today's workout advances
  /// from. Always points at the displayed workout, so completion advances by
  /// exactly one slot with no fast-forward (Codex review finding #2).
  final int? workoutIndexToComplete;

  bool get isRest => !isTrainingDay;
}

/// Pure projection of a program's workout-only sequence onto chosen training
/// weekdays. No I/O, no clock — every input is passed in, so it is deterministic
/// and shared by both `ProgramService` (which workout is today) and
/// `RestService` (is today a training day for shields/recovery).
///
/// Forgiveness is structural: the projection is positional and recomputed every
/// load, so a missed anchored day rolls the SAME [workoutIndex] to the next
/// training weekday with order intact — the workout is never lost or snapped to
/// the calendar.
///
/// History is never reinterpreted here: callers pass [effectiveWeekdays] already
/// resolved for the target date's week (a frozen `scheduleByWeekKey` snapshot for
/// past weeks, the committed/pending set for the current/future week), so editing
/// the schedule can never retroactively burn a shield (Codex review finding #3).
class ScheduleResolver {
  const ScheduleResolver();

  /// Resolve [date] given the active [program], the user's current progression
  /// [workoutIndex], and the [effectiveWeekdays] (1=Mon..7=Sun) that apply to
  /// [date]'s week.
  ///
  /// With no active program, every chosen weekday is a generic training day
  /// (no workout to surface) — preserving the pre-program weekday-only behavior.
  ResolvedDay resolve({
    required DateTime date,
    required Program? program,
    required int workoutIndex,
    required Set<int> effectiveWeekdays,
  }) {
    final isTrainingDay = effectiveWeekdays.contains(date.weekday);
    if (!isTrainingDay) return const ResolvedDay.rest();

    final workouts = program?.workouts ?? const [];
    if (workouts.isEmpty) {
      return const ResolvedDay(isTrainingDay: true);
    }
    final idx = workouts.isEmpty ? 0 : (workoutIndex % workouts.length);
    final safeIdx = idx < 0 ? idx + workouts.length : idx;
    return ResolvedDay(
      isTrainingDay: true,
      displayedWorkout: workouts[safeIdx],
      workoutIndexToComplete: safeIdx,
    );
  }
}
