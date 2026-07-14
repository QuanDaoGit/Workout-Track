import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/workout_draft_controller.dart';

/// The shell-owned pre-start draft controller: lifecycle, the synchronous
/// validity gate Train arms from, and the commit guard.
void main() {
  test('idle by default', () {
    final c = WorkoutDraftController();
    expect(c.active, isFalse);
    expect(c.isValid, isFalse);
    expect(c.canStart, isFalse);
    c.dispose();
  });

  test('begin activates invalid; setValid arms canStart', () {
    final c = WorkoutDraftController();
    c.begin(const WorkoutDraftSeed.manual());
    expect(c.active, isTrue);
    expect(c.canStart, isFalse); // no exercise yet
    c.setValid(true);
    expect(c.canStart, isTrue);
    c.dispose();
  });

  test('clear returns to idle', () {
    final c = WorkoutDraftController();
    c.begin(const WorkoutDraftSeed.manual());
    c.setValid(true);
    c.clear();
    expect(c.active, isFalse);
    expect(c.canStart, isFalse);
    c.dispose();
  });

  test('requestCommit runs the committer only when canStart', () {
    final c = WorkoutDraftController();
    var commits = 0;
    c.registerCommitter(() => commits++);
    c.begin(const WorkoutDraftSeed.manual());
    c.requestCommit(); // invalid → must not commit
    expect(commits, 0);
    c.setValid(true);
    c.requestCommit();
    expect(commits, 1);
    c.dispose();
  });

  test('notifies only on real state changes', () {
    final c = WorkoutDraftController();
    var n = 0;
    c.addListener(() => n++);
    c.begin(const WorkoutDraftSeed.manual()); // +1
    c.setValid(true); // +1
    c.setValid(true); // no-op
    c.clear(); // +1
    c.clear(); // no-op (already idle)
    expect(n, 3);
    c.dispose();
  });

  test('repeat seed carries exercise ids + groups', () {
    final seed = WorkoutDraftSeed.repeat(['a', 'b'], muscleGroups: ['Chest']);
    expect(seed.initialSelectedExerciseIds, ['a', 'b']);
    expect(seed.initialMuscleGroups, ['Chest']);
    expect(seed.isProgramWorkout, isFalse);
  });
}
