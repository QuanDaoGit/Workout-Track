class StatRadarRead {
  const StatRadarRead._();

  static const visibleStats = ['STR', 'AGI', 'END'];
  static const dominantLeadThreshold = 40;
  static const balancedMeaning = 'BALANCED';
  static const axisToClass = {
    'STR': 'bruiser',
    'AGI': 'assassin',
    'END': 'tank',
  };
  static const classToAxis = {
    'assassin': 'AGI',
    'bruiser': 'STR',
    'tank': 'END',
  };
  static const readableClassNames = ['assassin', 'bruiser', 'tank'];

  static const _axisMeaning = {
    'STR': 'POWER',
    'AGI': 'CONTROL',
    'END': 'STAMINA',
  };

  static String meaningForAxis(String axis) =>
      _axisMeaning[axis] ?? balancedMeaning;

  static String? classForAxis(String axis) => axisToClass[axis];

  static String? axisForClass(String className) => classToAxis[className];

  static String buildRead(Map<String, int> stats) {
    final axis = dominantAxis(stats);
    return axis == null ? balancedMeaning : meaningForAxis(axis);
  }

  static String? dominantAxis(Map<String, int> stats) {
    final values = [
      for (final stat in visibleStats)
        (stat: stat, value: (stats[stat] ?? 0).clamp(0, 1000)),
    ]..sort((a, b) => b.value.compareTo(a.value));
    if (values.first.value - values[1].value < dominantLeadThreshold) {
      return null;
    }
    return values.first.stat;
  }

  // Rank-band edges. Each of the five ranks (D/C/B/A/S) occupies an equal 1/5
  // slice. Interior values mirror StatEngine.rankThreshold{C,B,A,S}
  // (100/300/600/900); cap 1000. Drift-guarded in test/stat_radar_test.dart.
  static const _rankEdges = <int>[0, 100, 300, 600, 900, 1000];

  /// Maps a stat value (0..1000) to a fraction (0..1) on the rank-band scale:
  /// each rank gets an equal slice, so early ranks read clearly and a value
  /// lands on a boundary at each promotion (100/300/600/900). Continuous within
  /// a band, clamped to [0, 1]. Shared by the stat radar (corner distance) and
  /// the stat bars (cell fill) so the two views never diverge.
  static double rankBandFraction(int value) {
    final v = value.clamp(0, _rankEdges.last);
    final slices = _rankEdges.length - 1; // 5
    for (var i = 0; i < slices; i++) {
      final lo = _rankEdges[i];
      final hi = _rankEdges[i + 1];
      if (v <= hi) {
        final within = hi == lo ? 0.0 : (v - lo) / (hi - lo);
        return (i + within) / slices;
      }
    }
    return 1.0;
  }
}
