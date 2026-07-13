import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bodyweight_loads.dart';
import '../data/class_definitions.dart';
import '../data/muscle_groups.dart';
import '../models/character_class.dart';
import '../models/rest_models.dart';
import '../theme/tokens.dart';
import '../models/workout_models.dart';
import 'exercise_catalog_service.dart';
import 'json_safe.dart';
import 'rest_service.dart';

class StatEngine {
  StatEngine({DateTime Function()? nowProvider, Map<String, String>? catalog})
    : _nowProvider = nowProvider ?? DateTime.now,
      _catalogOverride = catalog;

  static const combatStatsKey = 'combat_stats';
  static const calibrationSeedKey = 'calibration_seed_volumes_v1';
  static const _sessionsKey = 'workout_sessions';
  static const _peaksKey = 'combat_stat_peaks';
  static const _lastDeltaKey = 'combat_stat_last_delta';
  static const _lastSessionDateKey = 'combat_stats_last_session_date';

  /// Bumped whenever the stat computation rules change (`_statsForSessions`
  /// weights or the seed). `MigrationService` recomputes a
  /// user's cached stats on boot when their stored version differs, so a re-tune
  /// lands quietly at app-update instead of as a surprise jump mid-workout.
  ///
  /// v3: STR/AGI currency switched from raw tonnage (`reps × load`) to
  /// intensity-weighted e1RM-equivalent credit (see [intensityCreditForSet]);
  /// bodyweight sets use a per-movement %BW × per-session bodyweight snapshot
  /// instead of a flat 40 kg; legs feed STR at 0.22 (was 0.10). Existing users
  /// are protected by the grandfather floor (see [grandfatherFloorKey]).
  static const statsRulesVersion = 3;

  /// One-time per-stat floor captured at the v3 rules migration: the visible
  /// STR/AGI values a user had already earned under the tonnage rules. The
  /// recompute under the new currency is clamped to never display less, so the
  /// rules change cannot read as lost progress.
  static const grandfatherFloorKey = 'combat_stat_floor_v1';

  static const outputStats = ['STR', 'VIT', 'AGI', 'END'];
  static const stats = ['STR', 'VIT', 'AGI', 'END', 'LCK'];
  static const volumeStats = outputStats;
  // VIT is no longer volume-derived — it's the recovery meter, out of the
  // kg-volume set.
  static const _kgVolumeStats = ['STR', 'AGI'];
  static const baseOutputStatValue = 10;
  static const _enduranceScale = 150.0;

  /// Log-curve scale for the STR/AGI volume stats, in intensity-credit units
  /// (see [intensityCreditForSet]). Retuned from 500 when the currency moved
  /// off raw tonnage, so a representative session keeps roughly the same early
  /// pacing. Public for pacing simulations and tests.
  static const double volumeCurveScale = 120.0;

  /// Epley reps cap for strength credit. Above ~12 reps the e1RM estimate
  /// stops being meaningful (and uncapped reps would let high-rep fluff farm
  /// STR — the exact exploit the intensity currency exists to close), so a
  /// 25-rep set banks the same credit as a 12-rep set at that load. Unlike
  /// calibration's `bestOneRmForLog` (which *skips* high-rep sets when
  /// estimating a max), growth credit caps instead of skipping so every
  /// logged set still moves the number.
  static const int maxCreditReps = 12;

  /// Deterministic last-resort bodyweight when neither the session snapshot
  /// nor any earlier session carries one.
  static const double fallbackBodyweightKg = 70.0;

  /// Trailing window for the VIT recovery-balance meter.
  static const _vitalityWindowDays = 14;

  final DateTime Function() _nowProvider;
  final Map<String, String>? _catalogOverride;

  /// Returns all 5 stats as a map.
  Future<Map<String, int>> calculateAllStats({bool suppressDelta = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await _loadCompletedSessions(prefs);
    final catalog = await _loadCatalog();
    final seed = _decodeSeed(prefs.getString(calibrationSeedKey));

    // The value the board is currently showing (baseline if never computed),
    // captured before we overwrite it.
    final oldCached = _decodeStats(prefs.getString(combatStatsKey));

    final computed = _statsForSessions(sessions, catalog, seed);
    // Inactivity no longer decays earned stats — they are immutable (a body-
    // neutral, gain-framed model; loss-framing punished absence and overstated
    // real detraining). See MigrationService.runDecayRemovalOnce.
    // Grandfather floor (v3 rules migration): never display less than the user
    // had already earned under the old rules — not from the recompute and not
    // from decay. Applied after decay so the floor wins.
    _applyGrandfatherFloor(
      computed,
      _decodePartialStats(prefs.getString(grandfatherFloorKey)),
    );
    // LCK = weekly consistency streak (needs rest-schedule state). Computed
    // before the delta so a streak that ticks up still surfaces in the finish
    // summary's luck gain.
    computed['LCK'] = await _computeLck(sessions);
    final latestSession = sessions.isEmpty ? null : sessions.last;
    // Per-session delta = computed − previously-cached, so the finish summary
    // reflects the *real* change the board will show (including decay-recovery
    // and re-score "catch-up" jumps a marginal latest-session delta misses). A
    // missing cache reads as baseline, so a first workout still shows its gain;
    // with no sessions the delta is empty (baseline vs baseline).
    final delta = _deltaVsCached(
      computed: computed,
      cached: oldCached,
      active: latestSession != null,
    );

    // VIT is the recovery meter — recomputed fresh from rest/training balance,
    // not from this session's volume. Inject it into the persisted snapshot.
    computed['VIT'] = await _computeVitality(sessions);

    final peaks = _mergePeaks(
      _decodeStats(prefs.getString(_peaksKey)),
      computed,
    );
    await prefs.setString(combatStatsKey, jsonEncode(computed));
    await prefs.setString(_peaksKey, jsonEncode(peaks));
    await prefs.setString(
      _lastDeltaKey,
      jsonEncode(suppressDelta ? const <String, int>{} : delta),
    );
    if (latestSession != null) {
      final day = _dateOnly(latestSession.date);
      await prefs.setString(_lastSessionDateKey, day.toIso8601String());
    }

    return computed;
  }

  // Widening D/C/B/A/S grade ladder (no F). Small early gaps, large late gaps,
  // so new lifters promote fast and veterans grind for S. All grades reachable
  // under the 1000 stat cap (S at 900 leaves headroom). Tunable.
  static const rankThresholdC = 100;
  static const rankThresholdB = 300;
  static const rankThresholdA = 600;
  static const rankThresholdS = 900;

  /// Returns rank letter for a given stat value.
  String getRank(int statValue) {
    if (statValue >= rankThresholdS) return 'S';
    if (statValue >= rankThresholdA) return 'A';
    if (statValue >= rankThresholdB) return 'B';
    if (statValue >= rankThresholdC) return 'C';
    return 'D';
  }

  /// Returns rank color for a given stat value.
  Color getRankColor(int statValue) {
    if (statValue >= rankThresholdS) return kRankS;
    if (statValue >= rankThresholdA) return kRankA;
    if (statValue >= rankThresholdB) return kRankB;
    if (statValue >= rankThresholdC) return kRankC;
    return kRankD;
  }

  /// Returns the current LCK value (weekly consistency streak).
  Future<int> calculateLuck() async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await _loadCompletedSessions(prefs);
    return _computeLck(sessions);
  }

  /// Returns stat delta from most recent session.
  Future<Map<String, int>> getLastSessionDelta() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodePartialStats(prefs.getString(_lastDeltaKey));
  }

  Future<Map<String, int>> getStoredStats() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(combatStatsKey);
    if (stored == null) return calculateAllStats();
    final sessions = await _loadCompletedSessions(prefs);
    if (sessions.isEmpty) {
      // No completed workouts yet: recompute so legacy cached zeros become the
      // real baseline after seed cleanup, while future workout-derived seed
      // data still flows through the same calculation path.
      return calculateAllStats();
    }
    // VIT (recovery balance) and LCK (weekly consistency streak) are both live,
    // date-sensitive meters — refresh them on read so they reflect today's
    // rest/training state even between workout saves (e.g. a week boundary
    // crossed while the app was open).
    final decoded = _decodeStats(stored);
    decoded['VIT'] = await _computeVitality(sessions);
    decoded['LCK'] = await _computeLck(sessions);
    return decoded;
  }

  static double endurancePointsForSet(SetEntry set) {
    if (set.reps <= 0) return 0;
    final multiplier = set.reps <= 7
        ? 0.5
        : set.reps <= 14
        ? 1.0
        : 1.5;
    return set.reps * multiplier;
  }

  /// Boot pass: applies streak SHIELDS for unprotected missed scheduled-training
  /// days since the last session, and refreshes the live LCK streak in the cache.
  /// Inactivity no longer decays earned stats (they are immutable) — this exists
  /// purely for the shield/streak-protection side effect (it is the only caller
  /// of [RestService.applyShieldsForMissedTrainingDays]) plus the LCK refresh.
  Future<void> processMissedTrainingDays() async {
    final prefs = await SharedPreferences.getInstance();

    // No cached stats yet → a full recompute establishes them.
    if (prefs.getString(combatStatsKey) == null) {
      await calculateAllStats();
      return;
    }

    final sessions = await _loadCompletedSessions(prefs);
    final latestSession = sessions.isEmpty ? null : sessions.last;
    final lastSessionRaw = prefs.getString(_lastSessionDateKey);
    if (latestSession == null && lastSessionRaw == null) {
      await _refreshLuckInCache(prefs); // no history → nothing to protect
      return;
    }

    final today = _dateOnly(_nowProvider());
    final lastSessionDate = _dateOnly(
      latestSession?.date ?? DateTime.parse(lastSessionRaw!),
    );
    // Apply shields for missed scheduled days (streak protection). Idempotent:
    // already-protected days are excluded and shields only ever decrement.
    await RestService(
      nowProvider: _nowProvider,
    ).applyShieldsForMissedTrainingDays(
      sessions: sessions,
      since: lastSessionDate,
      now: today,
    );
    await _refreshLuckInCache(prefs);
  }

  void _applyGrandfatherFloor(Map<String, int> stats, Map<String, int> floor) {
    for (final entry in floor.entries) {
      final current = stats[entry.key];
      if (current != null && current < entry.value) {
        stats[entry.key] = entry.value;
      }
    }
  }

  Future<void> _refreshLuckInCache(SharedPreferences prefs) async {
    final current = _decodeStats(prefs.getString(combatStatsKey));
    current['LCK'] = await calculateLuck();
    await prefs.setString(combatStatsKey, jsonEncode(current));
  }

  Future<List<WorkoutSession>> _loadCompletedSessions(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_sessionsKey);
    if (raw == null) return [];
    return safeMapList(raw, WorkoutSession.fromJson, debugLabel: _sessionsKey)
        .where((session) => !session.isPartial && !session.isAbandoned)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Public catalog loader (exerciseId -> primary muscle). Reused by
  /// calibration so its exercise->stat mapping matches the engine exactly.
  Future<Map<String, String>> loadCatalog() => _loadCatalog();

  Future<Map<String, String>> _loadCatalog() async {
    if (_catalogOverride != null) return _catalogOverride;
    // Built-in exercises: use raw JSON to get primaryMuscles field
    final raw = await rootBundle.loadString('assets/exercises.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    final result = <String, String>{
      for (final item in decoded)
        (item as Map<String, dynamic>)['id'] as String: _firstPrimaryMuscle(
          item['primaryMuscles'] as List<dynamic>?,
        ),
    };
    // Custom exercises: use stored primaryMuscle field
    final custom = await ExerciseCatalogService().getCustomExercises();
    for (final e in custom) {
      result[e.id] = e.primaryMuscle ?? '';
    }
    return result;
  }

  String _firstPrimaryMuscle(List<dynamic>? muscles) {
    if (muscles == null || muscles.isEmpty) return '';
    return muscles.first as String? ?? '';
  }

  Map<String, int> _statsForSessions(
    List<WorkoutSession> sessions,
    Map<String, String> catalog, [
    Map<String, double> seed = const {},
  ]) {
    final volumes = {for (final stat in _kgVolumeStats) stat: 0.0};
    var endurance = 0.0;
    // Bodyweight is resolved per session from its save-time snapshot; sessions
    // without one (pre-snapshot history) carry the last-known snapshot forward,
    // bottoming out at the deterministic fallback. Profile edits never rewrite
    // history: only the frozen snapshots are read.
    double? lastKnownBodyweight;
    for (final session in sessions) {
      final bodyweight =
          session.bodyweightKgAtSave ??
          lastKnownBodyweight ??
          fallbackBodyweightKg;
      if (session.bodyweightKgAtSave != null) {
        lastKnownBodyweight = session.bodyweightKgAtSave;
      }
      for (final log in session.exercises) {
        final volume = intensityCreditForLog(log, bodyweightKg: bodyweight);
        final endurancePoints = _endurancePointsForLog(log);
        final primary = _primaryForLog(log, session, catalog);
        final weights = _visibleWeightsForPrimaryMuscle(primary);
        volumes['STR'] = (volumes['STR'] ?? 0) + volume * weights.strVolume;
        volumes['AGI'] = (volumes['AGI'] ?? 0) + volume * weights.agiVolume;
        endurance += endurancePoints * weights.endurancePoints;

        final classBonusStat = _classBonusStatForLog(session, primary);
        if (classBonusStat != null) {
          volumes[classBonusStat] =
              (volumes[classBonusStat] ?? 0) + (volume * 0.2);
        }
        endurance += _classBonusEnduranceForLog(
          session,
          primary,
          endurancePoints,
        );
      }
    }

    // Calibration seed volume (from the onboarding calibration workout) is
    // expressed in the same kg-volume currency, so it composes with training
    // and survives every recompute. Constant across before/after, so it does
    // not leak into per-session deltas.
    for (final stat in _kgVolumeStats) {
      final s = seed[stat];
      if (s != null && s > 0) {
        volumes[stat] = (volumes[stat] ?? 0) + s;
      }
    }

    return {
      for (final stat in _kgVolumeStats)
        stat: _withOutputBaseline(_statFromVolume(volumes[stat] ?? 0)),
      'END': _withOutputBaseline(_statFromEndurance(endurance)),
      // LCK is the weekly consistency streak — injected async in
      // calculateAllStats (it needs rest-schedule state), not here.
    };
  }

  /// Per-session delta = `computed − previously-cached`, over the visible
  /// capability stats (LCK only when it rises, matching prior behavior). This is
  /// the change the board's absolute value actually makes, so the finish summary
  /// and the Home "last session" tag reflect decay-recovery / re-score jumps
  /// instead of only a session's marginal contribution. Empty when [active] is
  /// false (no sessions), so a no-session boot recompute emits nothing.
  Map<String, int> _deltaVsCached({
    required Map<String, int> computed,
    required Map<String, int> cached,
    required bool active,
  }) {
    if (!active) return {};
    final delta = <String, int>{};
    for (final stat in const ['STR', 'AGI', 'END']) {
      final value = (computed[stat] ?? 0) - (cached[stat] ?? 0);
      if (value != 0) delta[stat] = value;
    }
    final luckDelta = (computed['LCK'] ?? 0) - (cached['LCK'] ?? 0);
    if (luckDelta > 0) delta['LCK'] = luckDelta;
    return delta;
  }

  /// LCK = the weekly consistency streak (consecutive 7-day blocks held without
  /// an unscheduled recovery). Delegates to the rest schedule, which owns the
  /// streak rule. The consistent lifter is the lucky one.
  Future<int> _computeLck(List<WorkoutSession> sessions) {
    final restService = RestService(nowProvider: _nowProvider);
    return restService.currentConsistencyWeeks(
      sessions: sessions,
      now: _nowProvider(),
    );
  }

  Future<int> _computeVitality(List<WorkoutSession> sessions) async {
    final restService = RestService(nowProvider: _nowProvider);
    final state = await restService.loadState(now: _nowProvider());
    return vitalityFromState(state, sessions, restService);
  }

  /// VIT = a rolling recovery-balance meter over the last [_vitalityWindowDays]
  /// days (0–100, floor [baseOutputStatValue]). Rewards completing scheduled
  /// training AND resting on rest days; mildly dings training on rest days
  /// (overtraining); scales down by how much of the scheduled training you
  /// actually did, so inactivity collapses it toward the floor. Public for
  /// tests.
  int vitalityFromState(
    RestState state,
    List<WorkoutSession> sessions,
    RestService restService,
  ) {
    final now = _dateOnly(_nowProvider());
    var sumCredit = 0.0;
    var considered = 0;
    var scheduledTraining = 0;
    var completedScheduled = 0;
    for (var i = 0; i < _vitalityWindowDays; i++) {
      final day = now.subtract(Duration(days: i));
      final info = restService.dayInfoForState(
        day: day,
        sessions: sessions,
        state: state,
        now: now,
      );
      if (info.isScheduledTrainingDay) scheduledTraining++;
      switch (info.kind) {
        case RestDayKind.workoutComplete:
          if (info.isScheduledTrainingDay) {
            completedScheduled++;
            sumCredit += 1.0;
          } else {
            sumCredit += 0.7; // trained on a rest day — mild overtraining
          }
          considered++;
        case RestDayKind.plannedRest:
          sumCredit += 1.0; // productive recovery
          considered++;
        case RestDayKind.protectedMiss:
          sumCredit += 0.5; // shielded — neutral
          considered++;
        case RestDayKind.unplannedMiss:
          considered++; // detraining — zero credit
        case RestDayKind.trainingDay:
        case RestDayKind.abandonedOnly:
          break; // today, no verdict yet
      }
    }
    if (considered == 0) return baseOutputStatValue;
    final raw = 100.0 * sumCredit / considered;
    final activityFactor = scheduledTraining == 0
        ? 1.0
        : min(1.0, completedScheduled / scheduledTraining);
    return (raw * activityFactor)
        .round()
        .clamp(baseOutputStatValue, 100)
        .toInt();
  }

  String _primaryForLog(
    ExerciseLog log,
    WorkoutSession session,
    Map<String, String> catalog,
  ) {
    final primary = catalog[log.exerciseId];
    return primary ?? _fallbackPrimary(session);
  }

  String? _classBonusStatForLog(WorkoutSession session, String primaryMuscle) {
    final cls = _classFromStoredName(session.classAtSave);
    if (cls == null) return null;
    final bucket = muscleGroupForDetailed(primaryMuscle);
    if (bucket == null || !musclesForClass(cls).contains(bucket)) return null;
    return switch (cls) {
      CharacterClass.bruiser => 'STR',
      CharacterClass.assassin => 'AGI',
      // Tank's visible radar identity is durability/work-capacity, so its
      // focus bonus is applied in END currency below.
      CharacterClass.tank => null,
    };
  }

  double _classBonusEnduranceForLog(
    WorkoutSession session,
    String primaryMuscle,
    double endurancePoints,
  ) {
    final cls = _classFromStoredName(session.classAtSave);
    if (cls == null || endurancePoints <= 0) return 0;
    final bucket = muscleGroupForDetailed(primaryMuscle);
    if (bucket == null || !musclesForClass(cls).contains(bucket)) return 0;
    return switch (cls) {
      CharacterClass.tank => endurancePoints * 0.2,
      CharacterClass.assassin || CharacterClass.bruiser => 0,
    };
  }

  CharacterClass? _classFromStoredName(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final cls in CharacterClass.values) {
      if (cls.name == raw) return cls;
    }
    return null;
  }

  String _fallbackPrimary(WorkoutSession session) {
    return switch (session.muscleGroup.toLowerCase()) {
      'chest' => 'chest',
      'back' => 'lats',
      'shoulders' => 'shoulders',
      'arms' => 'biceps',
      'legs' => 'quadriceps',
      'core' => 'abdominals',
      _ => '',
    };
  }

  _StatWeights _visibleWeightsForPrimaryMuscle(String muscle) {
    return switch (muscle.toLowerCase()) {
      // Pressing and arms are the clearest STR signal. They still give light
      // AGI support and normal rep-based END so the radar does not go dead.
      'chest' || 'triceps' || 'forearms' => const _StatWeights(
        strVolume: 1.0,
        agiVolume: 0.12,
        endurancePoints: 1.0,
      ),
      // Pulling (back/biceps) visibly supports STR with light AGI support and
      // normal rep-based END.
      'lats' ||
      'middle back' ||
      'lower back' ||
      'biceps' ||
      'traps' ||
      'neck' => const _StatWeights(
        strVolume: 0.8,
        agiVolume: 0.12,
        endurancePoints: 1.0,
      ),
      // Legs should read as durability/work-capacity for Tank. Heavy lower-body
      // work moves STR honestly under the intensity currency (squats are a real
      // strength signal), but END stays the dominant visible axis — pushing
      // this above ~0.22 flips the Tank radar identity to STR.
      'quadriceps' ||
      'hamstrings' ||
      'glutes' ||
      'calves' ||
      'adductors' ||
      'abductors' => const _StatWeights(
        strVolume: 0.22,
        agiVolume: 0.07,
        endurancePoints: 5.0,
      ),
      // Shoulders/core are the AGI signal: control, bracing, precision.
      'shoulders' || 'abdominals' => const _StatWeights(
        strVolume: 0.20,
        agiVolume: 1.0,
        endurancePoints: 1.1,
      ),
      _ => const _StatWeights(),
    };
  }

  /// Legacy kg-volume mapping used by the calibration seed. Visible radar
  /// shaping uses [_visibleWeightsForPrimaryMuscle].
  ///
  /// Back/biceps intentionally fall through to null: they used to seed the
  /// retired DEF stat, i.e. they were never seeded into a *visible* stat. Their
  /// STR contribution comes from actual logged training (see the pulling branch
  /// of [_visibleWeightsForPrimaryMuscle]), not the calibration seed. Mapping
  /// them to 'STR' would newly credit back calibration into visible STR — a
  /// deliberate product change, not part of the DEF removal.
  static String? statForPrimaryMuscle(String muscle) {
    return switch (muscle.toLowerCase()) {
      // Legs still have a legacy STR volume bucket here for compatibility.
      // The visible Tank silhouette is END-led through weighted reps above.
      // VIT is no longer fed by any muscle — it's the recovery meter.
      'chest' ||
      'triceps' ||
      'forearms' ||
      'quadriceps' ||
      'hamstrings' ||
      'glutes' ||
      'calves' ||
      'adductors' ||
      'abductors' => 'STR',
      'shoulders' || 'abdominals' => 'AGI',
      _ => null,
    };
  }

  /// Per-set strength credit: the Epley e1RM-equivalent of the set,
  /// `load × (1 + min(reps, 12) / 30)`. This is the engine's STR/AGI currency
  /// (v3): summed across sets it is intensity-weighted work — a heavy 3×5
  /// banks far more than a light 3×25 of equal tonnage, and no single set can
  /// dominate because credit accumulates instead of taking a best-of. Public
  /// so calibration and pacing simulations stay in the same currency.
  static double intensityCreditForSet(double loadKg, int reps) {
    if (loadKg <= 0 || reps <= 0) return 0;
    return loadKg * (1 + min(reps, maxCreditReps) / 30);
  }

  /// Sum of [intensityCreditForSet] across a log's sets. Bodyweight sets
  /// (weight == 0) load as `%BW × bodyweightKg` via [bodyweightLoadFraction].
  static double intensityCreditForLog(
    ExerciseLog log, {
    required double bodyweightKg,
  }) {
    final bodyweightLoad =
        bodyweightLoadFraction(log.exerciseName) * bodyweightKg;
    return log.sets.fold<double>(0, (sum, set) {
      final load = set.weight > 0 ? set.weight : bodyweightLoad;
      return sum + intensityCreditForSet(load, set.reps);
    });
  }

  double _endurancePointsForLog(ExerciseLog log) {
    return log.sets.fold<double>(
      0,
      (sum, set) => sum + endurancePointsForSet(set),
    );
  }

  int _statFromVolume(double volume) {
    return min(1000, (100 * log(volume / volumeCurveScale + 1)).floor());
  }

  int _statFromEndurance(double endurancePoints) {
    return min(
      1000,
      (100 * log(endurancePoints / _enduranceScale + 1)).floor(),
    );
  }

  /// Inverse of [_statFromVolume]: the kg volume that yields [targetStat]
  /// (above the baseline of 10). Used to size calibration seeds in the same
  /// currency the engine consumes. Clamped to non-negative.
  static double volumeForStat(int targetStat) {
    final above = targetStat - baseOutputStatValue;
    if (above <= 0) return 0;
    // +0.5 lands mid-band so the engine's floor() yields exactly [targetStat]
    // rather than one below it.
    return volumeCurveScale * (exp((above + 0.5) / 100) - 1);
  }

  Map<String, double> _decodeSeed(String? raw) {
    final decoded = safeDecodeMap(raw, debugLabel: 'stat_seed');
    if (decoded == null) return const {};
    return {
      for (final entry in decoded.entries)
        if (_kgVolumeStats.contains(entry.key) && entry.value is num)
          entry.key: (entry.value as num).toDouble(),
    };
  }

  int _withOutputBaseline(int value) {
    return min(1000, baseOutputStatValue + value);
  }

  Map<String, int> _mergePeaks(
    Map<String, int> storedPeaks,
    Map<String, int> current,
  ) {
    return {
      for (final stat in stats)
        stat: max(storedPeaks[stat] ?? 0, current[stat] ?? 0),
    };
  }

  Map<String, int> _decodeStats(String? raw) {
    final decoded = safeDecodeMap(raw, debugLabel: 'combat_stats');
    if (decoded == null) return _emptyStats();
    return {
      for (final stat in stats) stat: (decoded[stat] as num?)?.toInt() ?? 0,
    };
  }

  Map<String, int> _decodePartialStats(String? raw) {
    final decoded = safeDecodeMap(raw, debugLabel: 'partial_stats');
    if (decoded == null) return {};
    return {
      for (final entry in decoded.entries)
        if (stats.contains(entry.key) && entry.value is num)
          entry.key: (entry.value as num).toInt(),
    };
  }

  Map<String, int> _emptyStats() => {
    for (final stat in outputStats) stat: baseOutputStatValue,
    'LCK': 0,
  };

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _StatWeights {
  const _StatWeights({
    this.strVolume = 0,
    this.agiVolume = 0,
    this.endurancePoints = 0,
  });

  final double strVolume;
  final double agiVolume;
  final double endurancePoints;
}
