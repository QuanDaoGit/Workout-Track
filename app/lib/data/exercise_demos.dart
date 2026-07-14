import '../models/workout_models.dart';

part 'exercise_demos.g.dart';

/// A short form-demo clip for a single exercise.
///
/// [video] is a normalized muted mp4 played (looping) by the demo cabinet /
/// fullscreen player via `video_player`; [poster] is a static still extracted
/// from the same clip, used for small thumbnails and as the player's pre-init
/// frame.
class ExerciseDemo {
  const ExerciseDemo(this.video, this.poster);

  final String video;
  final String poster;
}

const String _demoDir = 'assets/exercises/demos';

/// Demo asset paths are derived from the exercise's **catalog id**: the source
/// clip, the normalized mp4, and the poster all share the id as their basename
/// (`$_demoDir/<id>.mp4` + `$_demoDir/<id>.webp`), so there is no per-exercise
/// path bookkeeping. [kDemoExerciseIds] — generated into `exercise_demos.g.dart`
/// by `ops/generate_exercise_demos.py` from the files actually on disk — is the
/// single list of which ids have a demo. Every consumer falls back to the
/// catalog photo when [exerciseDemoFor] returns null.

/// The motion demo for [id], or null when the exercise has no demo.
ExerciseDemo? exerciseDemoFor(String id) => kDemoExerciseIds.contains(id)
    ? ExerciseDemo('$_demoDir/$id.mp4', '$_demoDir/$id.webp')
    : null;

/// Whether [id] has a curated motion demo.
bool hasExerciseDemo(String id) => kDemoExerciseIds.contains(id);

/// Thumbnail asset for [e]: the demo's poster still when one exists, otherwise
/// the catalog photo. Static in both cases (no animation at thumbnail size).
String exerciseThumbAsset(Exercise e) =>
    hasExerciseDemo(e.id) ? '$_demoDir/${e.id}.webp' : e.imageAssetPath;

/// All demo asset paths (videos + posters) — used by the drift-guard test.
Iterable<String> allDemoAssetPaths() => kDemoExerciseIds.expand(
  (id) => ['$_demoDir/$id.mp4', '$_demoDir/$id.webp'],
);

/// All exercise ids that have a demo — used by the drift-guard test.
Iterable<String> demoExerciseIds() => kDemoExerciseIds;
