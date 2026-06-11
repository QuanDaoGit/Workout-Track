import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/shadow_models.dart';
import '../models/stat_radar_read.dart';
import 'guild_service.dart';
import 'loot_service.dart';
import 'stat_engine.dart';
import 'workout_storage_service.dart';

/// "The Shadow" — the nemesis built from the user's own steady training.
///
/// Model (acute:chronic workload ratio, uncoupled): the Shadow IS your prior
/// month. Per axis, `r = acute rate / chronic rate` where acute = mean linear
/// credit per day over the last [acuteWindowDays] and chronic = mean per day
/// over the [chronicWindowDays] before that. Calendar-day rate windows (not
/// session counts) keep the time semantics honest for sparse and dense
/// trainers alike and span any common split cycle.
///
/// The Shadow is a live mirror — recomputed from history on every evaluation.
/// Persistent state is limited to the per-axis chronic high-water (anti
/// under-training floor), the week-over-week mean ratio (gap-closing signal),
/// and the one-time defeat marker. The Shadow never mutates real stats, XP,
/// or any other system's keys; its only writes are `shadow_state_v1` and the
/// idempotent loot grant on the first genuine defeat.
class ShadowService {
  ShadowService({DateTime Function()? nowProvider, StatEngine? statEngine})
    : _nowProvider = nowProvider ?? DateTime.now,
      _statEngine = statEngine ?? StatEngine();

  static const stateKey = 'shadow_state_v1';

  /// "You" — recent training pace window (days). 10 covers a full cycle of
  /// any common split (PPL, upper/lower, 5-day) so axis ratios don't whipsaw
  /// with rotation phase.
  static const acuteWindowDays = 10;

  /// "The Shadow" — the steady-baseline window (days), ending where the acute
  /// window starts. Uncoupled from acute so the Shadow is genuinely your past.
  static const chronicWindowDays = 28;

  /// Below this many completed sessions the surface stays a teaser
  /// ("Something is forming.").
  static const minTotalSessions = 6;

  /// The chronic window needs at least this many sessions to be a baseline.
  static const minChronicSessions = 3;

  /// Sessions at which the Shadow stops being provisional: genuine defeat can
  /// award the permanent title (~4 weeks of normal training).
  static const matureSessions = 12;

  /// r >= this → axis held/ahead. Slightly under 1.0 to absorb window
  /// quantization noise (a perfectly steady every-3-days lifter floats
  /// between ~0.93 and ~1.24 purely from where sessions land in the windows).
  static const aheadThreshold = 0.95;

  /// r >= this (and < ahead) → neck-and-neck. Below = Shadow leads. Matches
  /// the ACWR literature's healthy floor (~0.8).
  static const closeThreshold = 0.8;

  /// Faded floor: mean(chronic / decayed high-water) below this means the
  /// baseline was rested away — defeat shows as rebuilding, never rewards.
  static const fadedFraction = 0.9;

  /// Weekly decay on the high-water anchor, forgiving the distant past while
  /// still blocking the "rest, then beat a weak Shadow" exploit window.
  static const highWaterWeeklyDecay = 0.98;

  /// Gap-closing fires when this week's mean ratio improves on last week's by
  /// at least this much (while still behind).
  static const gapClosingDelta = 0.05;

  /// Per-axis minimum chronic rate (credit/day) for an axis to be scored —
  /// keeps spill-only or token signals from producing absurd ratios. Tunable.
  static const minChronicRate = {'STR': 2.0, 'AGI': 1.0, 'END': 1.0};

  /// Loot granted once, on the first genuine defeat.
  static const titleLootId = 'title_shadowbane';
  static const frameLootId = 'frame_spectral';

  static const _axes = StatRadarRead.visibleStats;

  final DateTime Function() _nowProvider;
  final StatEngine _statEngine;

  /// Evaluates the Shadow against current history. Idempotent: same history +
  /// same clock → same result and same persisted state. Defensive: malformed
  /// stored state decodes to an empty one; nothing here can throw into the
  /// caller's UI path short of storage itself failing.
  Future<ShadowEvaluation> evaluate() async {
    final prefs = await SharedPreferences.getInstance();
    final state = _decodeState(prefs.getString(stateKey));
    final sessions =
        (await WorkoutStorageService().getSessions())
            .where((s) => !s.isPartial && !s.isAbandoned)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    if (sessions.length < minTotalSessions) {
      return ShadowEvaluation(
        status: ShadowStatus.locked,
        completedSessions: sessions.length,
        titleEarned: state.firstDefeatAtIso != null,
      );
    }

    // Clock-untrusted: a backwards clock can't shift sessions into the future
    // of the evaluation window (body-metrics max(stored, now) pattern).
    final wallNow = _dateOnly(_nowProvider());
    final latestSession = _dateOnly(sessions.last.date);
    final now = wallNow.isAfter(latestSession) ? wallNow : latestSession;

    final loads = await _statEngine.sessionAxisLoads(sessions);
    final acuteStart = now.subtract(const Duration(days: acuteWindowDays - 1));
    final chronicStart = acuteStart.subtract(
      const Duration(days: chronicWindowDays),
    );
    final acute = <SessionAxisLoad>[];
    final chronic = <SessionAxisLoad>[];
    for (final load in loads) {
      final day = _dateOnly(load.date);
      if (!day.isBefore(acuteStart) && !day.isAfter(now)) {
        acute.add(load);
      } else if (!day.isBefore(chronicStart) && day.isBefore(acuteStart)) {
        chronic.add(load);
      }
    }

    if (chronic.length < minChronicSessions) {
      return ShadowEvaluation(
        status: ShadowStatus.forming,
        completedSessions: sessions.length,
        titleEarned: state.firstDefeatAtIso != null,
      );
    }

    final week = GuildService.weekIso(now);
    final acuteRate = _ratePerDay(acute, acuteWindowDays);
    final chronicRate = _ratePerDay(chronic, chronicWindowDays);

    // High-water update (monotonic up, decaying anchor) + faded check.
    final highWater = Map<String, double>.from(state.highWater);
    final highWaterSetAt = Map<String, String>.from(state.highWaterSetAtIso);
    final fadedParts = <double>[];
    for (final axis in _axes) {
      final rate = chronicRate[axis] ?? 0;
      final stored = highWater[axis];
      final setAt = DateTime.tryParse(highWaterSetAt[axis] ?? '');
      final effective = (stored == null || setAt == null)
          ? null
          : stored *
                pow(
                  highWaterWeeklyDecay,
                  max(0, now.difference(setAt).inDays) / 7.0,
                );
      if (effective == null || rate > effective) {
        if (rate >= (minChronicRate[axis] ?? 0)) {
          highWater[axis] = rate;
          highWaterSetAt[axis] = now.toIso8601String();
        }
      } else if (rate >= (minChronicRate[axis] ?? 0) && effective > 0) {
        fadedParts.add(rate / effective);
      }
    }
    final faded =
        fadedParts.isNotEmpty &&
        fadedParts.reduce((a, b) => a + b) / fadedParts.length < fadedFraction;

    // Per-axis reads.
    final axes = <ShadowAxisRead>[];
    final ratios = <double>[];
    var anyBehind = false;
    var allAhead = true;
    var anySufficient = false;
    for (final axis in _axes) {
      final cRate = chronicRate[axis] ?? 0;
      if (cRate < (minChronicRate[axis] ?? 0)) {
        axes.add(ShadowAxisRead(axis: axis, state: ShadowAxisState.forming));
        continue;
      }
      anySufficient = true;
      final aRate = acuteRate[axis] ?? 0;
      final ratio = aRate / cRate;
      ratios.add(ratio);
      final ShadowAxisState axisState;
      String? reason;
      if (ratio >= aheadThreshold) {
        axisState = ShadowAxisState.ahead;
      } else if (ratio >= closeThreshold) {
        axisState = ShadowAxisState.close;
        allAhead = false;
      } else {
        axisState = ShadowAxisState.behind;
        allAhead = false;
        anyBehind = true;
        final meaning = StatRadarRead.meaningForAxis(axis);
        reason = aRate <= 0
            ? 'NO $meaning WORK IN YOUR LAST $acuteWindowDays DAYS'
            : '$meaning PACE BELOW YOUR MONTH BASELINE';
      }
      axes.add(
        ShadowAxisRead(
          axis: axis,
          state: axisState,
          ratio: ratio,
          reason: reason,
        ),
      );
    }

    if (!anySufficient) {
      return ShadowEvaluation(
        status: ShadowStatus.forming,
        completedSessions: sessions.length,
        titleEarned: state.firstDefeatAtIso != null,
      );
    }

    final meanRatio = ratios.reduce((a, b) => a + b) / ratios.length;

    // Week rollover for the gap-closing comparison (idempotent: re-evals in
    // the same week just refresh the current value).
    double? lastWeekMean = state.lastWeekMeanRatio;
    if (state.lastEvalWeekIso != null && state.lastEvalWeekIso != week) {
      lastWeekMean = state.currentWeekMeanRatio;
    }
    final gapClosing =
        anyBehind &&
        lastWeekMean != null &&
        meanRatio >= lastWeekMean + gapClosingDelta;

    final provisional = sessions.length < matureSessions;
    final defeated = allAhead && !faded;
    final genuineDefeat = defeated && !provisional;

    var firstDefeatAtIso = state.firstDefeatAtIso;
    var titleEarnedNow = false;
    if (genuineDefeat && firstDefeatAtIso == null) {
      firstDefeatAtIso = now.toIso8601String();
      titleEarnedNow = true;
      // Idempotent grants — identity/standing only, never XP or gems.
      await LootService().grantItem(titleLootId);
      await LootService().grantItem(frameLootId);
    }

    await prefs.setString(
      stateKey,
      jsonEncode(
        ShadowState(
          lastEvalWeekIso: week,
          lastWeekMeanRatio: lastWeekMean,
          currentWeekMeanRatio: meanRatio,
          highWater: highWater,
          highWaterSetAtIso: highWaterSetAt,
          firstDefeatAtIso: firstDefeatAtIso,
          lastDefeatWeekIso: genuineDefeat ? week : state.lastDefeatWeekIso,
        ).toJson(),
      ),
    );

    final status = defeated
        ? ShadowStatus.defeated
        : faded
        ? ShadowStatus.faded
        : ShadowStatus.contest;

    return ShadowEvaluation(
      status: status,
      completedSessions: sessions.length,
      axes: axes,
      provisional: provisional,
      gapClosing: gapClosing,
      titleEarnedNow: titleEarnedNow,
      titleEarned: firstDefeatAtIso != null,
      headline: _headline(axes),
    );
  }

  /// Mean credit per day over a window: sum of session credits / window days.
  Map<String, double> _ratePerDay(List<SessionAxisLoad> loads, int days) {
    return {
      for (final axis in _axes)
        axis:
            loads.fold<double>(0, (sum, load) => sum + load.axis(axis)) / days,
    };
  }

  /// Driver line for the weakest behind axis, or null when nothing is behind.
  String? _headline(List<ShadowAxisRead> axes) {
    ShadowAxisRead? weakest;
    for (final read in axes) {
      if (read.state != ShadowAxisState.behind) continue;
      if (weakest == null || (read.ratio ?? 0) < (weakest.ratio ?? 0)) {
        weakest = read;
      }
    }
    if (weakest == null) return null;
    return 'SHADOW LEADS ${weakest.axis} — ${weakest.reason}';
  }

  ShadowState _decodeState(String? raw) {
    if (raw == null) return ShadowState();
    try {
      return ShadowState.fromJson(jsonDecode(raw) as Map<String, dynamic>?);
    } catch (_) {
      // Malformed state falls back to forming; real stats/XP are untouched.
      return ShadowState();
    }
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
