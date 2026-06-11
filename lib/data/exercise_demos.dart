import '../models/workout_models.dart';

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

/// Curated motion demos, keyed by exercise id (the FULL BODY A / Day-1 lifts).
/// Only a handful of exercises have a demo; every consumer falls back to the
/// catalog photo when [exerciseDemoFor] returns null.
const Map<String, ExerciseDemo> _demos = {
  'Barbell_Bench_Press_-_Medium_Grip': ExerciseDemo(
    '$_demoDir/barbell_bench_press.mp4',
    '$_demoDir/barbell_bench_press_poster.webp',
  ),
  'Wide-Grip_Lat_Pulldown': ExerciseDemo(
    '$_demoDir/wide_grip_lat_pulldown.mp4',
    '$_demoDir/wide_grip_lat_pulldown_poster.webp',
  ),
  'Barbell_Squat': ExerciseDemo(
    '$_demoDir/barbell_squat.mp4',
    '$_demoDir/barbell_squat_poster.webp',
  ),
  'Dumbbell_Bicep_Curl': ExerciseDemo(
    '$_demoDir/dumbbell_bicep_curl.mp4',
    '$_demoDir/dumbbell_bicep_curl_poster.webp',
  ),
  'Triceps_Pushdown': ExerciseDemo(
    '$_demoDir/triceps_pushdown.mp4',
    '$_demoDir/triceps_pushdown_poster.webp',
  ),
};

/// The motion demo for [id], or null when the exercise has no demo.
ExerciseDemo? exerciseDemoFor(String id) => _demos[id];

/// Whether [id] has a curated motion demo.
bool hasExerciseDemo(String id) => _demos.containsKey(id);

/// Thumbnail asset for [e]: the demo's poster still when one exists, otherwise
/// the catalog photo. Static in both cases (no animation at thumbnail size).
String exerciseThumbAsset(Exercise e) =>
    _demos[e.id]?.poster ?? e.imageAssetPath;

/// All demo asset paths (videos + posters) — used by the drift-guard test.
Iterable<String> allDemoAssetPaths() =>
    _demos.values.expand((d) => [d.video, d.poster]);

/// All exercise ids that have a demo — used by the drift-guard test.
Iterable<String> demoExerciseIds() => _demos.keys;
