# Rest-Day Recovery Insights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The blue button on both Home recovery mission cards opens a bottom sheet where BIT delivers one rotating recovery insight per rest day.

**Architecture:** A const content pool (`data/recovery_insights.dart`, the `bit_room_copy.dart` pattern) + a small service owning one SharedPreferences key (`recovery_insight_state_v1`) that picks deterministically per day key (FNV-1a, the Quest rotation pattern) from the unseen set + a bottom-sheet widget reusing `BitMoodCore` and `BitSpeechBubble`. `home.dart` wires both recovery cards to it.

**Tech Stack:** Flutter/Dart, SharedPreferences JSON persistence, flutter_test.

**Spec:** `docs/superpowers/specs/2026-07-18-rest-day-recovery-insights-design.md`

**Run all commands from `app/`** (the Flutter project root).

---

### Task 1: Content pool + invariant test

**Files:**
- Create: `app/lib/data/recovery_insights.dart`
- Test: `app/test/recovery_insights_content_test.dart`

- [ ] **Step 1: Write the failing content-invariant test**

```dart
// app/test/recovery_insights_content_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/recovery_insights.dart';

void main() {
  test('pool is big enough for months of rest days', () {
    expect(recoveryInsights.length, greaterThanOrEqualTo(30));
  });

  test('ids are unique and stable-looking', () {
    final ids = recoveryInsights.map((i) => i.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(RegExp(r'^[a-z0-9_]+$').hasMatch(id), isTrue,
          reason: 'id "$id" must be snake_case');
    }
  });

  test('every insight has a valid category and non-empty text', () {
    for (final i in recoveryInsights) {
      expect(kRecoveryInsightCategories.contains(i.category), isTrue,
          reason: '"${i.id}" has unknown category "${i.category}"');
      expect(i.text.trim(), isNotEmpty);
      expect(i.text.length, lessThanOrEqualTo(220),
          reason: '"${i.id}" is too long for a glance surface');
    }
  });

  test('guardrails: no streak/guilt/body framing anywhere in the pool', () {
    // The spec bans copy that frames rest as risk, debt, or body outcome.
    const banned = [
      'streak',
      'calorie',
      'weight',
      'burn',
      "don't skip",
      'lose momentum',
      'fall behind',
    ];
    for (final i in recoveryInsights) {
      final t = i.text.toLowerCase();
      for (final word in banned) {
        expect(t.contains(word), isFalse,
            reason: '"${i.id}" contains banned word "$word"');
      }
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/recovery_insights_content_test.dart`
Expected: FAIL (compile error, `package:workout_track/data/recovery_insights.dart` does not exist).

- [ ] **Step 3: Write the data file with the full pool**

```dart
// app/lib/data/recovery_insights.dart

/// BIT's rest-day recovery briefings. One insight surfaces per rest day on the
/// Home recovery mission cards (RECOVERY BRIEFING button), rotated by
/// [RecoveryInsightService] so a user sees each once before the pool wraps.
///
/// Content rules (enforced in part by recovery_insights_content_test.dart):
/// accurate mainstream recovery science, body-neutral (no weight/calorie
/// framing), BIT's voice (short, warm, a little wry), never a training nudge
/// and never guilt. 1-3 sentences.
class RecoveryInsight {
  const RecoveryInsight({
    required this.id,
    required this.category,
    required this.text,
  });

  /// Stable snake_case identity; the seen-set persists these.
  final String id;

  /// One of [kRecoveryInsightCategories]; shown as the sheet's small tag.
  final String category;

  /// The BIT-voiced insight line(s).
  final String text;
}

/// The allowed category tags (the sheet renders these uppercased).
const kRecoveryInsightCategories = ['sleep', 'fuel', 'adaptation', 'mobility', 'mind'];

const List<RecoveryInsight> recoveryInsights = [
  // -- adaptation: what rest actually does ---------------------------------
  RecoveryInsight(
    id: 'rebuild_crew',
    category: 'adaptation',
    text:
        'Training breaks you down. Rest is when the rebuild happens. Today the construction crew is on site.',
  ),
  RecoveryInsight(
    id: 'doms_is_adaptation',
    category: 'adaptation',
    text:
        "Sore two days after a session? That's DOMS. It's adaptation working, not damage.",
  ),
  RecoveryInsight(
    id: 'supercompensation',
    category: 'adaptation',
    text:
        'Muscle grows back slightly stronger than before. Scientists call it supercompensation. I call it leveling up.',
  ),
  RecoveryInsight(
    id: 'nervous_system_rest',
    category: 'adaptation',
    text:
        'Rest repairs more than muscle. Your nervous system recovers too, and it controls how hard you can push.',
  ),
  RecoveryInsight(
    id: 'tendons_slower',
    category: 'adaptation',
    text:
        'Tendons adapt slower than muscles. Rest days give the connectors time to catch up with the engine.',
  ),
  RecoveryInsight(
    id: 'immune_boost',
    category: 'adaptation',
    text:
        'Hard training briefly dips your immune defenses. Recovery days are when they climb back stronger.',
  ),
  RecoveryInsight(
    id: 'deload_science',
    category: 'adaptation',
    text:
        'Even elite lifters schedule easy weeks. Backing off on purpose is a strategy, not a setback.',
  ),
  RecoveryInsight(
    id: 'growth_between',
    category: 'adaptation',
    text:
        'The gym sends the signal. The growth happens between sessions. Today is the between.',
  ),
  // -- sleep ----------------------------------------------------------------
  RecoveryInsight(
    id: 'sleep_growth_window',
    category: 'sleep',
    text:
        "Most muscle repair runs during deep sleep. Tonight's sleep is part of the program.",
  ),
  RecoveryInsight(
    id: 'growth_hormone_sleep',
    category: 'sleep',
    text:
        'Your body releases most of its growth hormone in the first hours of deep sleep. Free gains, no equipment.',
  ),
  RecoveryInsight(
    id: 'sleep_strength_link',
    category: 'sleep',
    text:
        'Short sleep measurably drops next-day strength and focus. A full night is quiet training.',
  ),
  RecoveryInsight(
    id: 'consistent_schedule',
    category: 'sleep',
    text:
        'A steady sleep schedule beats occasional long nights. Your recovery systems love a routine.',
  ),
  RecoveryInsight(
    id: 'screens_before_bed',
    category: 'sleep',
    text:
        'Bright screens late push your sleep clock back. Dimming things an hour before bed helps the repair shift start on time.',
  ),
  RecoveryInsight(
    id: 'naps_count',
    category: 'sleep',
    text:
        'A 20-minute nap genuinely helps recovery. Short and early beats long and late.',
  ),
  RecoveryInsight(
    id: 'sleep_debt',
    category: 'sleep',
    text:
        "One rough night won't undo your work. Sleep pressure builds and your body catches up. Just don't make it a habit.",
  ),
  // -- fuel -----------------------------------------------------------------
  RecoveryInsight(
    id: 'protein_rest_days',
    category: 'fuel',
    text: 'Protein still matters on rest days. The rebuild needs materials.',
  ),
  RecoveryInsight(
    id: 'protein_spread',
    category: 'fuel',
    text:
        'Spreading protein across the day works better than one giant serving. The crew likes steady deliveries.',
  ),
  RecoveryInsight(
    id: 'hydration_repair',
    category: 'fuel',
    text:
        'Muscle tissue is mostly water. Staying hydrated today literally supplies the repair work.',
  ),
  RecoveryInsight(
    id: 'carbs_refill',
    category: 'fuel',
    text:
        'Carbs on rest days refill the fuel tanks your last session emptied. Glycogen restocks over about a day.',
  ),
  RecoveryInsight(
    id: 'no_perfect_meal',
    category: 'fuel',
    text:
        "There's no magic recovery meal. Regular food, enough protein, enough water. Boring works.",
  ),
  RecoveryInsight(
    id: 'creatine_everyday',
    category: 'fuel',
    text:
        'If you take creatine, rest days count too. It works by staying topped up, not by timing.',
  ),
  RecoveryInsight(
    id: 'alcohol_repair',
    category: 'fuel',
    text:
        'Alcohol slows muscle repair and shallows your sleep. A light hand tonight keeps the rebuild on schedule.',
  ),
  // -- mobility & light movement -------------------------------------------
  RecoveryInsight(
    id: 'walk_bloodflow',
    category: 'mobility',
    text:
        'A short walk today speeds recovery. Blood flow carries the repair supplies.',
  ),
  RecoveryInsight(
    id: 'active_vs_couch',
    category: 'mobility',
    text:
        'Gentle movement on rest days often beats full couch mode. Easy is the key word.',
  ),
  RecoveryInsight(
    id: 'stretching_when',
    category: 'mobility',
    text:
        'Rest days are a great slot for relaxed stretching. No clock, no targets, just range.',
  ),
  RecoveryInsight(
    id: 'stiffness_morning',
    category: 'mobility',
    text:
        'Morning stiffness after training is normal. Joints wake up with movement, like old machines warming up.',
  ),
  RecoveryInsight(
    id: 'posture_breaks',
    category: 'mobility',
    text:
        'Sitting all day makes recovery feel worse than it is. Standing up every hour keeps things flowing.',
  ),
  RecoveryInsight(
    id: 'easy_cardio_ok',
    category: 'mobility',
    text:
        'An easy bike ride or swim can aid recovery, as long as it stays conversational. If you can chat, you can recover.',
  ),
  RecoveryInsight(
    id: 'foam_rolling',
    category: 'mobility',
    text:
        'Foam rolling may ease soreness for a while. The science is mixed on why, but if it feels good, it counts.',
  ),
  // -- mind -----------------------------------------------------------------
  RecoveryInsight(
    id: 'rest_is_training',
    category: 'mind',
    text:
        "Recovery isn't the absence of training. It's the half of training you can't see.",
  ),
  RecoveryInsight(
    id: 'stress_budget',
    category: 'mind',
    text:
        'Your body has one stress budget. Life stress and training stress draw from the same account. Rest days pay it back.',
  ),
  RecoveryInsight(
    id: 'boredom_normal',
    category: 'mind',
    text:
        "Feeling restless on a rest day is a good sign. It means the habit took. The rest still counts.",
  ),
  RecoveryInsight(
    id: 'long_game',
    category: 'mind',
    text:
        'Nobody is built in a week. Everyone is built in months. Rest days are how months happen.',
  ),
  RecoveryInsight(
    id: 'sleep_mood_link',
    category: 'mind',
    text:
        'Recovery lifts mood as much as muscle. A rested brain enjoys the next session more.',
  ),
  RecoveryInsight(
    id: 'breathing_switch',
    category: 'mind',
    text:
        'A few slow breaths flip your nervous system into repair mode. Longer out than in is the trick.',
  ),
  RecoveryInsight(
    id: 'trust_the_plan',
    category: 'mind',
    text:
        'The plan already includes today. Resting on schedule IS following the program.',
  ),
];
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/recovery_insights_content_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Run analyze and commit**

Run: `flutter analyze`
Expected: No issues found.

```bash
git add lib/data/recovery_insights.dart test/recovery_insights_content_test.dart
git commit -m "feat: recovery-insight content pool + invariant tests"
```

---

### Task 2: RecoveryInsightService (rotation + persistence)

**Files:**
- Create: `app/lib/services/recovery_insight_service.dart`
- Test: `app/test/recovery_insight_service_test.dart`

**Behavior contract (from the spec):**
- Same day, reopened: same insight.
- New day: deterministic pick (FNV-1a of the day key) from the *unseen* set; recorded as seen.
- Unseen set empty at pick time: clear the seen set, pick from the full pool, and flag the pick `poolWrapped: true` for that whole day (the sheet shows the honest wrap line once per wrap day).
- Corrupt stored JSON: reset to empty state, never crash.

- [ ] **Step 1: Write the failing service tests**

```dart
// app/test/recovery_insight_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/recovery_insights.dart';
import 'package:workout_track/services/recovery_insight_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  RecoveryInsightService serviceAt(DateTime now) =>
      RecoveryInsightService(nowProvider: () => now);

  test('same day returns the same insight on reopen', () async {
    final day = DateTime(2026, 7, 18, 9);
    final first = await serviceAt(day).insightForToday();
    final second =
        await serviceAt(DateTime(2026, 7, 18, 21)).insightForToday();
    expect(second.insight.id, first.insight.id);
    expect(first.poolWrapped, isFalse);
  });

  test('pick is deterministic for a fixed day key', () async {
    final day = DateTime(2026, 7, 18);
    final a = await serviceAt(day).insightForToday();
    SharedPreferences.setMockInitialValues({});
    final b = await serviceAt(day).insightForToday();
    expect(b.insight.id, a.insight.id);
  });

  test('a new day advances to an unseen insight', () async {
    final first = await serviceAt(DateTime(2026, 7, 18)).insightForToday();
    final second = await serviceAt(DateTime(2026, 7, 20)).insightForToday();
    expect(second.insight.id, isNot(first.insight.id));
  });

  test('never repeats until the pool is exhausted, then wraps with flag',
      () async {
    final seen = <String>{};
    var day = DateTime(2026, 1, 1);
    for (var i = 0; i < recoveryInsights.length; i++) {
      final pick = await serviceAt(day).insightForToday();
      expect(pick.poolWrapped, isFalse,
          reason: 'day $i wrapped before exhaustion');
      expect(seen.add(pick.insight.id), isTrue,
          reason: 'repeated ${pick.insight.id} before exhaustion');
      day = day.add(const Duration(days: 1));
    }
    // Pool exhausted: the next day wraps, flags it, and starts a fresh cycle.
    final wrapped = await serviceAt(day).insightForToday();
    expect(wrapped.poolWrapped, isTrue);
    // Reopening the wrap day keeps the flag (the sheet line stays honest).
    final reopened = await serviceAt(day).insightForToday();
    expect(reopened.poolWrapped, isTrue);
    // The day after the wrap is a normal fresh-cycle day again.
    final after =
        await serviceAt(day.add(const Duration(days: 1))).insightForToday();
    expect(after.poolWrapped, isFalse);
    expect(after.insight.id, isNot(wrapped.insight.id));
  });

  test('corrupt stored state resets cleanly instead of crashing', () async {
    SharedPreferences.setMockInitialValues(
        {RecoveryInsightService.stateKey: 'not json {{{'});
    final pick = await serviceAt(DateTime(2026, 7, 18)).insightForToday();
    expect(recoveryInsights.map((i) => i.id), contains(pick.insight.id));
  });

  test('a stored lastShownId no longer in the pool falls through to a fresh pick',
      () async {
    SharedPreferences.setMockInitialValues({
      RecoveryInsightService.stateKey:
          '{"seenIds":["ghost_id"],"lastShownId":"ghost_id","lastShownDayKey":"2026-07-18","lastShownWrapped":false}',
    });
    final pick = await serviceAt(DateTime(2026, 7, 18)).insightForToday();
    expect(recoveryInsights.map((i) => i.id), contains(pick.insight.id));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/recovery_insight_service_test.dart`
Expected: FAIL (compile error, service does not exist).

- [ ] **Step 3: Write the service**

```dart
// app/lib/services/recovery_insight_service.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/recovery_insights.dart';

/// One resolved rest-day briefing: the insight to show today, plus whether
/// today is the day the pool wrapped (the sheet shows the honest refresher
/// line only on a wrap day).
class RecoveryInsightPick {
  const RecoveryInsightPick({required this.insight, required this.poolWrapped});
  final RecoveryInsight insight;
  final bool poolWrapped;
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

  Future<RecoveryInsightPick> insightForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final state = _loadState(prefs);
    final dayKey = _dayKey(_nowProvider());

    // Same day, reopened: return the already-shown insight unchanged.
    if (state.lastShownDayKey == dayKey && state.lastShownId != null) {
      final shown = _byId(state.lastShownId!);
      if (shown != null) {
        return RecoveryInsightPick(
          insight: shown,
          poolWrapped: state.lastShownWrapped,
        );
      }
      // The stored id left the pool (content edit); fall through to a pick.
    }

    var seen = state.seenIds.where((id) => _byId(id) != null).toSet();
    var unseen =
        recoveryInsights.where((i) => !seen.contains(i.id)).toList();
    var wrapped = false;
    if (unseen.isEmpty) {
      // Every insight has been shown: restart the cycle honestly.
      seen = <String>{};
      unseen = List.of(recoveryInsights);
      wrapped = true;
    }

    final pick = unseen[_seed(dayKey) % unseen.length];
    seen.add(pick.id);
    await prefs.setString(
      stateKey,
      jsonEncode({
        'seenIds': seen.toList(),
        'lastShownId': pick.id,
        'lastShownDayKey': dayKey,
        'lastShownWrapped': wrapped,
      }),
    );
    return RecoveryInsightPick(insight: pick, poolWrapped: wrapped);
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
    final raw = prefs.getString(stateKey);
    if (raw == null) return const _InsightState();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _InsightState(
        seenIds: [
          for (final id in (map['seenIds'] as List? ?? const [])) id as String,
        ],
        lastShownId: map['lastShownId'] as String?,
        lastShownDayKey: map['lastShownDayKey'] as String?,
        lastShownWrapped: map['lastShownWrapped'] as bool? ?? false,
      );
    } catch (_) {
      // Corrupt blob: reset rather than crash; the pool just restarts.
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/recovery_insight_service_test.dart`
Expected: PASS (6 tests).

Note: the "new day advances" test cannot flake — the second pick draws from
the unseen set, which excludes the first pick by construction.

- [ ] **Step 5: Run analyze and commit**

Run: `flutter analyze`
Expected: No issues found.

```bash
git add lib/services/recovery_insight_service.dart test/recovery_insight_service_test.dart
git commit -m "feat: RecoveryInsightService — per-rest-day deterministic rotation"
```

---

### Task 3: RecoveryInsightSheet widget

**Files:**
- Create: `app/lib/widgets/recovery_insight_sheet.dart`
- Test: `app/test/recovery_insight_sheet_test.dart`

- [ ] **Step 1: Write the failing widget test**

```dart
// app/test/recovery_insight_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/recovery_insights.dart';
import 'package:workout_track/services/recovery_insight_service.dart';
import 'package:workout_track/widgets/recovery_insight_sheet.dart';

void main() {
  const insight = RecoveryInsight(
    id: 'test_insight',
    category: 'sleep',
    text: 'Most muscle repair runs during deep sleep.',
  );

  Widget host(RecoveryInsightPick pick) => MaterialApp(
        home: Scaffold(
          body: RecoveryInsightSheetContent(pick: pick),
        ),
      );

  testWidgets('renders the insight text, category tag, and close button',
      (tester) async {
    await tester.pumpWidget(host(
        const RecoveryInsightPick(insight: insight, poolWrapped: false)));
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(
        find.textContaining('deep sleep', findRichText: true), findsOneWidget);
    expect(find.text('SLEEP'), findsOneWidget);
    expect(find.text('CLOSE'), findsOneWidget);
    expect(find.text(kRecoveryInsightWrapLine), findsNothing);
  });

  testWidgets('shows the honest wrap line only on a wrap day', (tester) async {
    await tester.pumpWidget(host(
        const RecoveryInsightPick(insight: insight, poolWrapped: true)));
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(find.text(kRecoveryInsightWrapLine), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/recovery_insight_sheet_test.dart`
Expected: FAIL (compile error, sheet does not exist).

- [ ] **Step 3: Write the sheet widget**

```dart
// app/lib/widgets/recovery_insight_sheet.dart
import 'package:flutter/material.dart';

import '../services/recovery_insight_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'companion/bit_mood_core.dart';
import 'companion/bit_speech_bubble.dart';
import 'pixel_button.dart';

/// Shown once per wrap day, when the whole pool has been heard and the
/// rotation honestly restarts (spec: the "new each rest day" promise never
/// silently degrades into repeats).
const kRecoveryInsightWrapLine =
    "You've heard the full briefing. Refreshers from here.";

/// Opens BIT's rest-day recovery briefing over [context]'s navigator.
/// The caller resolves the pick first (async) so the sheet itself is pure UI.
Future<void> showRecoveryInsightSheet(
  BuildContext context,
  RecoveryInsightPick pick,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: kCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
    ),
    builder: (context) => RecoveryInsightSheetContent(pick: pick),
  );
}

/// The sheet body: faced BIT delivering today's insight in the calm recovery
/// register (cyan accent, no reward mechanics, one dismiss action).
class RecoveryInsightSheetContent extends StatelessWidget {
  const RecoveryInsightSheetContent({super.key, required this.pick});

  final RecoveryInsightPick pick;

  @override
  Widget build(BuildContext context) {
    final insight = pick.insight;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'RECOVERY BRIEFING',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 11,
                    color: kRecoveryAccent,
                  ),
                ),
              ),
              Text(
                insight.category.toUpperCase(),
                style: AppFonts.shareTechMono(
                  color: kMutedText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BitMoodCore(size: 72),
              const SizedBox(width: kSpace2),
              Expanded(
                child: BitSpeechBubble(
                  text: insight.text,
                  semanticsLabel: insight.text,
                ),
              ),
            ],
          ),
          if (pick.poolWrapped) ...[
            const SizedBox(height: kSpace3),
            Text(
              kRecoveryInsightWrapLine,
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
            ),
          ],
          const SizedBox(height: kSpace4),
          PixelButton(
            label: 'CLOSE',
            secondary: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/recovery_insight_sheet_test.dart`
Expected: PASS (2 tests).

If `pumpAndSettle` times out (BIT's idle float animates forever), switch both
tests to pump fixed frames instead:
`await tester.pump(); await tester.pump(const Duration(seconds: 3));`
The typewriter completes within ~3s for these text lengths; reduced-motion
snap is exercised app-wide by existing patterns and needs no extra test here.

- [ ] **Step 5: Run analyze and commit**

Run: `flutter analyze`
Expected: No issues found.

```bash
git add lib/widgets/recovery_insight_sheet.dart test/recovery_insight_sheet_test.dart
git commit -m "feat: RecoveryInsightSheet — BIT-voiced rest-day briefing surface"
```

---

### Task 4: Wire both Home recovery cards

**Files:**
- Modify: `app/lib/pages/home.dart` (imports block at top; `_buildProgramRecoveryMissionPanel` around line 1821; `_buildRecoveryMissionPanel` around line 1980)

- [ ] **Step 1: Add the imports**

In the import block at the top of `home.dart` (alphabetical within its group), add:

```dart
import '../services/recovery_insight_service.dart';
import '../widgets/recovery_insight_sheet.dart';
```

- [ ] **Step 2: Add the open method to `_HomePageState`**

Place it next to the other mission-card handlers (e.g. just after `_buildProgramRecoveryMissionPanel`):

```dart
  /// The recovery cards' primary action: resolve today's briefing (async,
  /// per-day stable) then present BIT's sheet. No reward, no streak, no nudge.
  Future<void> _openRecoveryInsight() async {
    final pick = await RecoveryInsightService().insightForToday();
    if (!mounted) return;
    await showRecoveryInsightSheet(context, pick);
  }
```

- [ ] **Step 3: Replace the dead primary on the program recovery card**

In `_buildProgramRecoveryMissionPanel`, replace:

```dart
      primaryLabel: 'KEEP RESTING',
      onPrimary: () {
        showArcadeNotice(context, 'Recovery day in progress.');
      },
```

with:

```dart
      primaryLabel: 'RECOVERY BRIEFING',
      onPrimary: _openRecoveryInsight,
```

(If `showArcadeNotice` has no other caller left in `home.dart`, remove its
import; `flutter analyze` will flag it as unused.)

- [ ] **Step 4: Give the non-program recovery card the same primary**

In `_buildRecoveryMissionPanel`, above the existing `secondaryLabel:` line, add:

```dart
      primaryLabel: 'RECOVERY BRIEFING',
      onPrimary: _openRecoveryInsight,
```

so the tail of the `_missionCard(...)` call reads:

```dart
      primaryLabel: 'RECOVERY BRIEFING',
      onPrimary: _openRecoveryInsight,
      secondaryLabel: 'Train anyway',
      onSecondary: () => _startWorkout(trainAnyway: false),
    );
```

- [ ] **Step 5: Analyze and run the full test suite**

Run: `flutter analyze`
Expected: No issues found (fix any unused-import warning from Step 3).

Run: `flutter test`
Expected: all tests pass, including the three new files.

- [ ] **Step 6: Commit**

```bash
git add lib/pages/home.dart
git commit -m "feat: recovery cards open BIT's rest-day briefing (was dead KEEP RESTING)"
```

---

### Task 5: Visual verification on-device

- [ ] **Step 1: Screenshot the affected UI (project rule: always screenshot)**

Run the app (`flutter run`) with a program whose today is a REST day (or use
the demo seed: `flutter run --dart-define=SEED_DEMO=intermediate`, then set the
device date or pick a program state where today is REST). On Home:
1. The recovery card shows RECOVERY BRIEFING as the blue primary.
2. Tapping opens the sheet: BIT + typewriter insight + category tag + CLOSE.
3. Close, reopen: the same insight (per-day stability).
4. Check theme coherence: cyan accent, PressStart2P header, 4px radii, sharp look.

- [ ] **Step 2: Fix anything off, re-verify, commit any fixes**

```bash
git add -A lib/
git commit -m "fix: recovery briefing polish from on-device review"
```
(Skip the commit if nothing needed fixing.)
