import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/recovery_insights.dart';
import 'json_safe.dart';
import 'keyed_lock.dart';

/// One resolved rest-day briefing: the insight to show today, whether today is
/// the day the pool wrapped (the sheet shows the honest refresher line only on
/// a wrap day), and the calendar day the pick was resolved FOR ([dayKey]) — the
/// commit files under this day, not a re-read clock, so a peek→commit that
/// straddles midnight can't mislabel the day (and repeat the insight tomorrow).
class RecoveryInsightPick {
  const RecoveryInsightPick({
    required this.insight,
    required this.poolWrapped,
    required this.dayKey,
  });
  final RecoveryInsight insight;
  final bool poolWrapped;
  final String dayKey;
}

/// Rotates BIT's rest-day recovery briefings ([recoveryInsights]).
///
/// One insight per calendar day, stable across reopens; a new day picks
/// deterministically (FNV-1a of the day key, the Quest/Guild rotation pattern)
/// from the not-yet-seen set so every insight is genuinely new until the pool
/// is exhausted, then the cycle restarts with [RecoveryInsightPick.poolWrapped]
/// set for the wrap day. Owns the `recovery_insight_state_v1` key.
class RecoveryInsightService {
  RecoveryInsightService({DateTime Function()? nowProvider})
      : _nowProvider = nowProvider ?? DateTime.now;

  static const stateKey = 'recovery_insight_state_v1';

  final DateTime Function() _nowProvider;

  /// Resolves today's briefing WITHOUT consuming it (Codex F1: a pick must
  /// never burn before the sheet actually renders). Pure read — deterministic
  /// for a given day + stored state, so repeated peeks agree.
  Future<RecoveryInsightPick> peekToday() {
    return prefsWriteLock.synchronized(stateKey, () async {
      final prefs = await SharedPreferences.getInstance();
      return _resolve(_loadState(prefs), _dayKey(_nowProvider()));
    });
  }

  /// Records [pick] as the shown insight for [RecoveryInsightPick.dayKey] —
  /// the day the pick was resolved for, NOT a fresh clock read, so a commit
  /// that lands just past midnight still files under the day the user actually
  /// saw. The opener calls this right after the sheet route is pushed.
  /// Idempotent per day (a double-tap or reopen commits once); a kill between
  /// peek and commit costs nothing — the same candidate resolves again next
  /// open. The read-modify-write runs inside [prefsWriteLock] (per the
  /// deep-feature learnings: a prefs RMW is not atomic, and both recovery
  /// cards can trigger this concurrently).
  Future<void> commitShown(RecoveryInsightPick pick) {
    return prefsWriteLock.synchronized(stateKey, () async {
      final prefs = await SharedPreferences.getInstance();
      final state = _loadState(prefs);
      final dayKey = pick.dayKey;
      final alreadyShown = state.lastShownDayKey == dayKey &&
          state.lastShownId != null &&
          _byId(state.lastShownId!) != null;
      if (alreadyShown) return;

      // A wrap commit starts the fresh cycle; a normal commit extends it.
      final seen = pick.poolWrapped
          ? <String>{}
          : state.seenIds.where((id) => _byId(id) != null).toSet();
      seen.add(pick.insight.id);
      await prefs.setString(
        stateKey,
        jsonEncode({
          'seenIds': seen.toList(),
          'lastShownId': pick.insight.id,
          'lastShownDayKey': dayKey,
          'lastShownWrapped': pick.poolWrapped,
        }),
      );
    });
  }

  /// The shared pick logic: same committed day => the stored insight; else a
  /// deterministic candidate from the unseen set (full pool + wrap flag when
  /// exhausted). Persists nothing.
  RecoveryInsightPick _resolve(_InsightState state, String dayKey) {
    if (state.lastShownDayKey == dayKey && state.lastShownId != null) {
      final shown = _byId(state.lastShownId!);
      if (shown != null) {
        return RecoveryInsightPick(
          insight: shown,
          poolWrapped: state.lastShownWrapped,
          dayKey: dayKey,
        );
      }
      // The stored id left the pool (content edit); fall through to a pick.
    }

    final seen = state.seenIds.where((id) => _byId(id) != null).toSet();
    var unseen = recoveryInsights.where((i) => !seen.contains(i.id)).toList();
    var wrapped = false;
    if (unseen.isEmpty) {
      // Every insight has been shown: restart the cycle honestly.
      unseen = List.of(recoveryInsights);
      wrapped = true;
    }
    return RecoveryInsightPick(
      insight: unseen[_seed(dayKey) % unseen.length],
      poolWrapped: wrapped,
      dayKey: dayKey,
    );
  }

  RecoveryInsight? _byId(String id) {
    for (final i in recoveryInsights) {
      if (i.id == id) return i;
    }
    return null;
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // Stable (portable) FNV-1a of the day key — Dart's String.hashCode is not
  // stable across runs, so the same day must not resolve to different picks.
  static int _seed(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  _InsightState _loadState(SharedPreferences prefs) {
    // json_safe convention: a corrupt/malformed blob degrades to first-run
    // state (the pool just restarts) instead of throwing on the home path.
    final map = safeDecodeMap(prefs.getString(stateKey), debugLabel: stateKey);
    if (map == null) return const _InsightState();
    try {
      return _InsightState(
        seenIds: [
          for (final id in (map['seenIds'] as List? ?? const []))
            id.toString(),
        ],
        lastShownId: map['lastShownId'] as String?,
        lastShownDayKey: map['lastShownDayKey'] as String?,
        lastShownWrapped: map['lastShownWrapped'] as bool? ?? false,
      );
    } catch (_) {
      // Schema-drifted field types: reset rather than crash.
      return const _InsightState();
    }
  }
}

class _InsightState {
  const _InsightState({
    this.seenIds = const [],
    this.lastShownId,
    this.lastShownDayKey,
    this.lastShownWrapped = false,
  });

  final List<String> seenIds;
  final String? lastShownId;
  final String? lastShownDayKey;
  final bool lastShownWrapped;
}
