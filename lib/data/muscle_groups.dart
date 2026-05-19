/// Canonical 7-bucket muscle taxonomy used across the entire app:
/// Start Workout chips, Create Exercise picker, class definitions,
/// muscle-balance chart, calorie MET map, persisted [WorkoutSession.muscleGroup].
///
/// Detailed muscles from `exercises.json` (chest, triceps, lats, abdominals,
/// quadriceps, etc.) map into one of these buckets via [muscleGroupForDetailed].
const List<String> canonicalMuscleGroups = [
  'Chest',
  'Back',
  'Shoulders',
  'Arms',
  'Legs',
  'Core',
  'Full Body',
];

/// Lowercase detailed muscle name → canonical bucket.
const Map<String, String> _detailedToBucket = {
  'chest': 'Chest',
  'triceps': 'Arms',
  'biceps': 'Arms',
  'forearms': 'Arms',
  'shoulders': 'Shoulders',
  'neck': 'Shoulders',
  'lats': 'Back',
  'middle back': 'Back',
  'lower back': 'Back',
  'traps': 'Back',
  'quadriceps': 'Legs',
  'hamstrings': 'Legs',
  'glutes': 'Legs',
  'calves': 'Legs',
  'adductors': 'Legs',
  'abductors': 'Legs',
  'abdominals': 'Core',
};

/// Map a detailed-muscle string from `exercises.json` (case-insensitive) to one
/// of the [canonicalMuscleGroups]. Returns `null` for unknown inputs.
String? muscleGroupForDetailed(String detailed) =>
    _detailedToBucket[detailed.toLowerCase()];

/// Normalize any input (lowercase, Title Case, mixed) to the canonical Title
/// Case bucket. Used at read-time on persisted strings so legacy data like
/// `'chest'` / `'Chest'` / `'CHEST'` all resolve to `'Chest'`. Returns `null`
/// when the input doesn't match any canonical bucket.
String? normalizeMuscleGroup(String raw) {
  final lower = raw.toLowerCase();
  for (final group in canonicalMuscleGroups) {
    if (group.toLowerCase() == lower) return group;
  }
  return null;
}

/// Normalize a target list to canonical Title Case, deduped in the app-wide
/// display order. Unknown values and the UI-only "All" chip are ignored.
List<String> normalizeTargetMuscleGroups(Iterable<String> rawGroups) {
  final selected = {for (final raw in rawGroups) ?normalizeMuscleGroup(raw)};
  return [
    for (final group in canonicalMuscleGroups)
      if (selected.contains(group)) group,
  ];
}

bool hasTargetMuscle(Iterable<String> targetGroups, String muscleGroup) {
  final normalized = normalizeMuscleGroup(muscleGroup);
  if (normalized == null) return false;
  return normalizeTargetMuscleGroups(targetGroups).contains(normalized);
}

String targetMuscleGroupsLabel(
  Iterable<String> targetGroups, {
  String fallback = 'Workout',
}) {
  final groups = normalizeTargetMuscleGroups(targetGroups);
  if (groups.isEmpty) return fallback;
  if (groups.length == canonicalMuscleGroups.length) return 'All Targets';
  if (groups.length <= 2) return groups.join(' + ');
  return '${groups.first} + ${groups.length - 1}';
}
