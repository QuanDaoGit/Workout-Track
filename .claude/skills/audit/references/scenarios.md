# Render scenario authoring

A "scenario" makes one page render to a truthful PNG. The danger (Codex F1): a hand-seeded page can
look polished while the *real* route shows an empty-state bug, a missing dependency, or stale data.
These rules keep the artifact honest.

## Rules

1. **Seed through real service write APIs, not raw prefs.**
   - ✅ `await LootService().grantItem('frame_bronze');` · `await WorkoutStorageService().saveSession(s);`
   - ❌ `SharedPreferences.setMockInitialValues({'loot_inventory': '[...]'})` — a hand-rolled JSON
     blob silently rots when the model's `toJson` changes; the real API can't.
   - The ONE allowed raw-prefs use is the documented fixture pattern (e.g. seeding a `WorkoutSession`
     list the same way `quests_page_golden_test.dart` does) — and only because it round-trips through
     `session.toJson()`, so it still tracks the schema.
2. **Construct the page as the app does.** Pass the same params `RootPage`/the pusher passes
   (`nowProvider`, `onProfileChanged`, etc.). If the app injects a clock, inject a *pinned* one.
3. **Assert smoke text/actions.** Pass `smokeText:` to `captureSurface` — a string that MUST appear if
   the page rendered its real content (a header, a known label). A missing-dependency or empty-state
   bug then fails the capture loudly instead of yielding a clean-but-wrong PNG.
4. **Label confidence.** `confidence: high` only if the capture was reached by driving real navigation
   from `RootPage`. A directly-constructed page is `confidence: medium` — note it so the auditor
   weights it. A page that needed a fake/stub to render at all is `low` — fix the scenario first.
5. **Pin the clock + sizes.** Use a fixed `DateTime` for any date-seeded surface (quests, streaks,
   coverage windows) or the PNG changes day-to-day. Capture at ≥1 real Android size (390×844 default;
   add a small/large size for layout-sensitive pages).

## Skeleton

```dart
testWidgets('audit/<page> — <scenario>', (tester) async {
  // 1. seed via REAL service APIs (round-trips the schema)
  SharedPreferences.setMockInitialValues({});
  await LootService().grant('frame_bronze');

  // 2. capture (loads fonts, forces reduced motion, asserts smoke, records overflow)
  await captureSurface(
    tester,
    name: 'inventory_owned',
    smokeText: 'No Title',                  // a LOADED-state string, or capture FAILS
    builder: (context) => const InventoryPage(),  // constructed as the app does
  );
},
    // REQUIRED: skip on a normal `flutter test` — captures are on-demand tools
    // that write a gitignored PNG and only run under --update-goldens.
    skip: !autoUpdateGoldenFiles);
```

> `smokeText` must appear ONLY in the page's **loaded** state (a section header, a known row) — not an
> AppBar title that also shows during the loading spinner, or it can't catch a load that never finished.

Run with **`flutter test --update-goldens test/audit/<file>`** → writes
`test/audit/_shots/<name>.png` (the `--update-goldens` flag is required — the capture uses
`matchesGoldenFile`, which only *writes* under that flag; without it a first run fails by design). The
auditor then `Read`s that PNG for the presentation/journey pass.

### Harness gotchas (handled inside `captureSurface` — don't re-learn them)

- **No `pumpAndSettle`.** The app has ambient perpetual animations (CRT flicker/drift, loading
  spinners) that never settle and hang it. The harness flushes async `initState` loads with **plain
  bounded pumps** instead.
- **Real disk I/O (fonts) and image precache must run inside `tester.runAsync`** — inside the
  `testWidgets` FakeAsync zone, real I/O futures never complete. The harness does this; a scenario
  doesn't touch it. (This is why fonts loaded mid-test hang but `setUpAll` font loading doesn't.)
- **`runAsync` deadlocks while a Ticker is live** (e.g. a loading spinner). The harness only calls
  `runAsync` before the first widget exists (fonts) and after the load has settled (precache).
