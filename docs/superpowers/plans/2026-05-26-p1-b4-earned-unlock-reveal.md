# P1 / B4 (reframed) — Earned-Unlock Reveal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give workouts the satisfying "you got something" moment the original B4 wanted through **earned deterministic milestones.** When a real-training milestone unlocks a loot item on workout save, play a post-session reveal/celebration, add a Loot Feed of recent unlocks, and flag unviewed unlocks on the Profile tab.

**Architecture (why this is small + core-loop-aligned):** The original B4 (random drops, pity timer, fragments, scrap, server roll) is **rejected for this shipped plan** because it dilutes the training-to-character loop and re-introduces the scrap/battle economy `migration_service` is actively purging. The shipped loot system is already fully deterministic: `LootService.evaluateUnlocks({stats, sessions})` walks `lootRegistry`, grants newly-eligible milestone unlocks, and **returns the newly-granted IDs "for caller-side surfacing."** `workout_summary.dart:195` already calls it on save **but discards the return.** So the reveal is: capture that return → surface it. No new economy, no PRNG.

**Tech Stack:** Flutter / Dart. Reuse `LootItem`/`LootRarity {common, uncommon, rare, epic}` (`lib/models/loot_item.dart`), `lootItemById` (`lib/data/loot_registry.dart`), the `ArcadeRouteMotion.reveal` + `StrobeFlash` reveal idioms, and `shared_preferences` for state. Tests via `flutter test`; lint baseline ~8, add zero new.

---

### Task 1: Capture newly-granted unlocks at workout save

**Files:**
- Modify: `lib/pages/Workout session/workout_summary.dart` (the `evaluateUnlocks` call ~195; add state field)
- Test: `test/workout_summary_unlock_capture_test.dart` (new)

- [ ] **Step 1: Confirm the call site + return type**

Read `workout_summary.dart` around line 195. Confirm `LootService().evaluateUnlocks(stats:..., sessions:...)` returns `Future<List<String>>` (newly-granted IDs) and is currently awaited without capture. Confirm `_combatStats` and `allSessions` are in scope there.

- [ ] **Step 2: Write the failing test**

Create `test/workout_summary_unlock_capture_test.dart`. Seed `SharedPreferences` so that completing the session crosses a milestone (e.g. reach the `sessions: 25` threshold for `title_iron_will`, or `lifetimeReps: 500` for `frame_gold`). Drive `WorkoutSummaryPage` to saved state and assert the unlock surfaces (the reveal widget appears / the captured list is non-empty). Use the existing summary-test pump helper.

```dart
expect(find.byType(EarnedUnlockReveal), findsOneWidget);
expect(find.textContaining('Added to Loot Inventory'), findsOneWidget);
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/workout_summary_unlock_capture_test.dart`
Expected: FAIL — `EarnedUnlockReveal` undefined / not shown.

- [ ] **Step 4: Capture the return + store as state**

Add `List<String> _unlockedItemIds = [];` to the summary state. Change the discard to a capture:

```dart
      final allSessions = await WorkoutStorageService().getSessions();
      _unlockedItemIds = await LootService().evaluateUnlocks(
        stats: _combatStats,
        sessions: allSessions,
      );
```

Then record them for the Loot Feed (Task 3) and the unviewed badge:

```dart
      if (_unlockedItemIds.isNotEmpty) {
        await LootFeedService().recordUnlocks(_unlockedItemIds);
      }
```

(`LootFeedService` defined in Task 3.)

- [ ] **Step 5: Render the reveal (widget built in Task 2)** — wire it after `_saved`; see Task 2 Step 4 for the placement. Then run the test → PASS. Commit with Task 2.

---

### Task 2: The `EarnedUnlockReveal` widget (3-stage, skippable)

**Files:**
- Create: `lib/widgets/earned_unlock_reveal.dart`
- Modify: `lib/pages/Workout session/workout_summary.dart` (render it in the results section)
- Test: `test/earned_unlock_reveal_test.dart` (new)

- [ ] **Step 1: Write the failing widget test**

Create `test/earned_unlock_reveal_test.dart`:

```dart
testWidgets('shows item name and toast; skip button advances', (tester) async {
  final item = lootItemById('frame_gold')!;
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: EarnedUnlockReveal(items: [item], reduceMotion: true),
  )));
  expect(find.text(item.name), findsOneWidget);
  expect(find.textContaining('Added to Loot Inventory'), findsOneWidget);
});

testWidgets('multiple unlocks all listed', (tester) async {
  final items = [lootItemById('frame_gold')!, lootItemById('title_iron_will')!];
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: EarnedUnlockReveal(items: items, reduceMotion: true),
  )));
  expect(find.text('frame_gold'), findsNothing); // shows name, not id
  expect(find.text(items[0].name), findsOneWidget);
  expect(find.text(items[1].name), findsOneWidget);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/earned_unlock_reveal_test.dart`
Expected: FAIL — `EarnedUnlockReveal` undefined.

- [ ] **Step 3: Build the widget**

Create `lib/widgets/earned_unlock_reveal.dart`. Tier-colored by `LootRarity`; honors `reduceMotion` (instant, no animation) — consistent with the app's other reveal surfaces:

```dart
import 'package:flutter/material.dart';
import '../models/loot_item.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'strobe_flash.dart';

Color rarityColor(LootRarity r) => switch (r) {
  LootRarity.common => kText,
  LootRarity.uncommon => kNeon,
  LootRarity.rare => kCyan,
  LootRarity.epic => kAmber,
};

/// Post-session celebration for items unlocked by hitting a real training
/// milestone. Earned through a deterministic rule. One card per unlocked item.
class EarnedUnlockReveal extends StatelessWidget {
  const EarnedUnlockReveal({
    super.key,
    required this.items,
    this.reduceMotion = false,
  });

  final List<LootItem> items;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Unlocked ${items.map((i) => i.name).join(", ")}. '
          'Added to Loot Inventory.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('UNLOCKED',
              style: TextStyle(fontFamily: 'PressStart2P', fontSize: 11, color: kNeon)),
          const SizedBox(height: kSpace3),
          for (final item in items) ...[
            StrobeFlash(
              trigger: item.id,
              color: rarityColor(item.rarity),
              opacity: 0.25,
              toggles: reduceMotion ? 0 : 2,
              toggleMs: 80,
              borderRadius: BorderRadius.circular(kCardRadius),
              child: Container(
                padding: const EdgeInsets.all(kCardPadding),
                decoration: BoxDecoration(
                  color: kCard,
                  border: Border.all(color: rarityColor(item.rarity), width: 1.5),
                  borderRadius: BorderRadius.circular(kCardRadius),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style: AppFonts.shareTechMono(
                                  color: rarityColor(item.rarity),
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(item.description,
                              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: kSpace2),
          ],
          Text('Added to Loot Inventory',
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Render it in the summary**

In `workout_summary.dart` results section, after `_saved` and when unlocks exist:

```dart
if (_saved && _unlockedItemIds.isNotEmpty) ...[
  const SizedBox(height: kSpace4),
  EarnedUnlockReveal(
    items: _unlockedItemIds
        .map(lootItemById)
        .whereType<LootItem>()
        .toList(),
    reduceMotion: MediaQuery.of(context).disableAnimations,
  ),
],
```

(Import `lootItemById` from `../../data/loot_registry.dart` and `EarnedUnlockReveal`.)

- [ ] **Step 5: Run both new tests + commit**

Run: `flutter test test/earned_unlock_reveal_test.dart test/workout_summary_unlock_capture_test.dart` (PASS).
Run: `flutter analyze` (zero new).
```bash
git add lib/widgets/earned_unlock_reveal.dart "lib/pages/Workout session/workout_summary.dart" test/earned_unlock_reveal_test.dart test/workout_summary_unlock_capture_test.dart
git commit -m "feat(loot): earned-unlock reveal on workout save

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Loot Feed + unviewed badge

**Files:**
- Create: `lib/services/loot_feed_service.dart`
- Modify: `lib/pages/inventory_page.dart` (Loot Feed strip) and the Profile tab icon (unviewed dot)
- Test: `test/loot_feed_service_test.dart` (new)

- [ ] **Step 1: Write the failing service test**

Create `test/loot_feed_service_test.dart` (`SharedPreferences.setMockInitialValues({})` in setUp):

```dart
test('records unlocks, exposes recent, tracks unviewed, clears on view', () async {
  final svc = LootFeedService();
  expect(await svc.hasUnviewed(), isFalse);
  await svc.recordUnlocks(['frame_gold', 'title_iron_will']);
  expect(await svc.hasUnviewed(), isTrue);
  final recent = await svc.recentEntries();
  expect(recent.length, 2);
  expect(recent.first.itemId, 'title_iron_will'); // newest first
  await svc.markAllViewed();
  expect(await svc.hasUnviewed(), isFalse);
});

test('recent is capped at 5 newest', () async {
  final svc = LootFeedService();
  for (final id in ['a','b','c','d','e','f']) { await svc.recordUnlocks([id]); }
  expect((await svc.recentEntries()).length, 5);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/loot_feed_service_test.dart`
Expected: FAIL — `LootFeedService` undefined.

- [ ] **Step 3: Build the service**

Create `lib/services/loot_feed_service.dart` (versioned JSON in `shared_preferences`, newest-first, capped at 5; `unviewed` flag):

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LootFeedEntry {
  const LootFeedEntry({required this.itemId, required this.at});
  final String itemId;
  final DateTime at;
  Map<String, dynamic> toJson() => {'id': itemId, 'at': at.toIso8601String()};
  static LootFeedEntry fromJson(Map<String, dynamic> j) => LootFeedEntry(
        itemId: j['id'] as String,
        at: DateTime.tryParse(j['at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class LootFeedService {
  static const _feedKey = 'loot_feed_v1';
  static const _unviewedKey = 'loot_feed_unviewed_v1';
  static const _maxEntries = 5;

  Future<void> recordUnlocks(List<String> itemIds, {DateTime? now}) async {
    if (itemIds.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final entries = await _read(prefs);
    final ts = now ?? DateTime.now();
    for (final id in itemIds) {
      entries.insert(0, LootFeedEntry(itemId: id, at: ts));
    }
    final capped = entries.take(_maxEntries).toList();
    await prefs.setString(
      _feedKey, jsonEncode([for (final e in capped) e.toJson()]));
    await prefs.setBool(_unviewedKey, true);
  }

  Future<List<LootFeedEntry>> recentEntries() async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs);
  }

  Future<bool> hasUnviewed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_unviewedKey) ?? false;
  }

  Future<void> markAllViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_unviewedKey, false);
  }

  Future<List<LootFeedEntry>> _read(SharedPreferences prefs) async {
    final raw = prefs.getString(_feedKey);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return [for (final m in list) LootFeedEntry.fromJson(m)];
  }
}
```

- [ ] **Step 4: Run the service test → PASS**

Run: `flutter test test/loot_feed_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Loot Feed strip in inventory + unviewed dot on Profile tab**

- In `lib/pages/inventory_page.dart`: add a top "LOOT FEED" strip listing `recentEntries()` (item name + relative time via the app's existing date helper), and call `LootFeedService().markAllViewed()` when the inventory page opens (clears the badge). Locked frames already show ownership; no fragment UI (fragments rejected).
- Profile tab icon: where the bottom-nav builds the Profile destination, show a small neon dot when `LootFeedService().hasUnviewed()` is true (mirror any existing badge pattern; load the flag in the nav host's state and refresh on the existing reload signal).

- [ ] **Step 6: Full suite + analyze + commit**

Run: `flutter test` (no regressions) and `flutter analyze` (zero new).
```bash
git add lib/services/loot_feed_service.dart lib/pages/inventory_page.dart test/loot_feed_service_test.dart <profile-tab-host-file>
git commit -m "feat(loot): recent-unlocks feed + unviewed badge

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4 (optional): add a few new earned milestones

**Files:** `lib/data/loot_registry.dart`
- [ ] Add 2–3 new `LootItem`s with `LootUnlockRule`s at reachable early thresholds (e.g. a frame at `sessions: 10`, a title at `lifetimeVolume: 2500`) so reveals fire sooner for new users. All gated by real training (`UnlockKind.*`), never chance. Add assets only if needed (titles need none). Update any owned/registry count assertions in tests. Commit.

---

## Out of scope (rejected per reconciled spec)
Random drop roll, base probability table, LCK rarity shift, pity timer, 2-hour cooldown, fragments + auto-assemble, scrap, server-side / signed PRNG, "legendary" tier (the enum's top tier is `epic`). These were intentionally left out of this deterministic milestone pass because they would shift attention away from the clean training-to-character loop and the removed scrap/battle economy.

## Self-Review
- **Spec coverage:** capture unlocks (T1) ✓; 3-stage-style reveal, skippable/instant under reduce-motion, tier-colored (T2) ✓; Loot Feed + unviewed badge (T3) ✓; optional new milestones (T4) ✓; probabilistic mechanics excluded + documented ✓.
- **Placeholder scan:** `<profile-tab-host-file>` in T3 Step 6 is a locate-target (the bottom-nav host, likely `root_page.dart`); T3 Step 5 is locate-then-edit because the exact badge insertion depends on the nav structure. The service (T3 Step 3) and reveal widget (T2 Step 3) are complete code.
- **Type consistency:** `EarnedUnlockReveal({items: List<LootItem>, reduceMotion: bool})` matches tests + the summary render. `LootFeedService.recordUnlocks(List<String>)` / `recentEntries()→List<LootFeedEntry>` / `hasUnviewed()` / `markAllViewed()` match tests and the T1 capture call. `LootRarity` switch covers all four real values (common/uncommon/rare/epic) — exhaustive, no "legendary".
- **StrobeFlash API:** `trigger`/`color`/`opacity`/`toggles`/`toggleMs`/`borderRadius` match the shipped widget; `toggles: 0` under reduce-motion = no flash.
