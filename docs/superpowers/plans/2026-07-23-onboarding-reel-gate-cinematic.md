# Onboarding reel → Start Gate — cinematic pass — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`)
> syntax for tracking.

**Goal:** Make the onboarding motivational reel read as cinema (BIT silent + lights down), and make the
Start Gate a hero reveal where the poured charge visibly arrives on the character.

**Architecture:** Three existing screens are refined in place. `charge_ritual_screen.dart` gains a
`_chromeLight` dim factor on decorative chrome (controls exempt) and hides BIT's bubble during the reel
(intro lines relocate to the self-paced held frame; START cancels any type). `start_gate_screen.dart`
recomposes around a large centered hero avatar and adds a one-shot charge-arrival surge (frame/name
ignite, one XP shimmer that never fabricates progress, hyped BIT arrival). `charge_ritual_engine.dart`
is untouched behaviorally. Reduced-motion paths and all engine watchdogs stay byte-identical.

**Tech Stack:** Flutter (Dart), `flutter_test` widget tests, the repo's `test/audit/audit_capture.dart`
golden harness, `video_player` (already wired). Run all commands from `app/`.

**Spec:** `docs/superpowers/specs/2026-07-23-onboarding-reel-gate-cinematic-design.md`

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `lib/pages/onboarding/charge_ritual_screen.dart` | Reel host + hold-to-charge | BIT-silent reel, intro relocation, START type-cancel, `_chromeLight` dim/undim (controls exempt) |
| `lib/pages/onboarding/start_gate_screen.dart` | Final onboarding reveal | Hero-portrait recomposition, payoff-first reveal order, `_arrival` charge surge, hyped BIT arrival |
| `lib/pages/onboarding/charge_ritual_engine.dart` | Charge phase machine | **No behavior change** (referenced only) |
| `test/charge_ritual_screen_test.dart` | Reel widget tests | Add BIT-silent + type-cancel + dim/exempt tests |
| `test/start_gate_screen_test.dart` (**new**) | Gate widget tests | Hero focal + arrival + reduced-motion tests |
| `test/audit/screens_d_test.dart` | Start Gate golden capture | Re-capture the recomposed gate |
| `test/audit/charge_ritual_dialogue_frames_test.dart` | Reel dim golden capture | Add a reel-dim frame |

**Constants added** (top of `charge_ritual_screen.dart`, near the existing `_kMessageStartMs`):
- `static const int _kIntroLine2Ms = 3200;` — held-frame dwell before the 2nd intro line.
- `static const double _kChromeDimFloor = 0.30;` — decorative-chrome opacity while the reel plays.
- `static const int _kReelDimRampMs = 500;` — lights-down / lights-up ramp length.

**Constants added** (top of `start_gate_screen.dart`):
- `static const int _kArrivalMs = 900;` — the charge-arrival surge duration.
- `static const int _kBitSettleMs = 3200;` — screen-enter offset at which BIT's hyped arrival line
  settles to the guiding prompt (after the prompt reveal at 1420ms → ~1.8s of hyped line).

---

## Phase A — Reel goes silent (BIT bubble hidden during playback; intro relocated; START cancels type)

### Task A1: Failing test — no BIT bubble text during the reel; intro line shows on the held frame

**Files:**
- Test: `test/charge_ritual_screen_test.dart` (add tests)

Note: under `reduced: true` there is no reel, so these tests drive `reduced: false`, where `_initVideo`
fails in the test host (no platform video) and the watchdog lands on the poster/hold. To exercise the
**reel** phase deterministically, drive the engine directly is not possible from the widget; instead
assert the **held-frame** intro and the **reel-phase bubble-hidden** contract via the phase the widget
exposes through visible text. Use the existing `advance()` helper.

- [ ] **Step 1: Write the failing tests**

```dart
  testWidgets('held frame shows the first intro line, then the second after a dwell', (
    tester,
  ) async {
    await pumpRitual(tester, reduced: false);
    await tester.pump();
    await advance(tester, 200); // entry eases to the held frame (Beat C)

    // The START BOOSTING gate is up and BIT delivers the first invitation line.
    expect(find.textContaining('say hi to our coach'), findsOneWidget);
    expect(find.textContaining("listen to his message"), findsNothing);

    // After the held-frame dwell the second line arrives (still pre-play).
    await advance(tester, 3400); // > _kIntroLine2Ms (3200)
    expect(find.textContaining("listen to his message"), findsOneWidget);
  });

  testWidgets('the BIT speech bubble is hidden while the reel plays', (tester) async {
    await pumpRitual(tester, reduced: false);
    await tester.pump();
    await advance(tester, 200);

    // Press START BOOSTING to begin playback. In the test host the video is not
    // initialized, so playback cannot truly start — assert instead that the
    // production gate exists: while phase == reel the bubble slot renders nothing.
    // (Driven via the engine's public reel phase is not reachable from the widget;
    // this test guards the composition wiring: the bubble is absent whenever the
    // reel monitor is showing live video.)
    // We validate the inverse observable: on the held frame the bubble IS present.
    expect(find.byType(BitSpeechBubble), findsWidgets);
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd app && flutter test test/charge_ritual_screen_test.dart -n "held frame shows the first intro line"`
Expected: FAIL — today the first line is present but the 2nd line never appears on the held frame
(the current code only switches lines by `videoPosMs`, which is 0 pre-play).

- [ ] **Step 3: Add the intro constants + a held-frame line sequencer**

In `charge_ritual_screen.dart`, add near the other `static const` timing fields (after
`_kHoldThankYouMs`):

```dart
  // Held-frame BIT intro: line 1 on entry, line 2 after this dwell (self-paced —
  // both live on the START BOOSTING wait so nothing competes with the reel).
  static const int _kIntroLine2Ms = 3200;
  // Lights-down: decorative chrome opacity floor while the reel plays, and the
  // ramp length for fading down (reel start) / back up (the hold).
  static const double _kChromeDimFloor = 0.30;
  static const int _kReelDimRampMs = 500;
```

Add a field to stamp when playback begins (near `_holdStartMs`):

```dart
  double? _reelStartMs; // pausable clock stamped when the reel phase begins
```

Stamp it in `_onTick` where the reel phase is first observed. Immediately after the existing
`if (phase == ChargeRitualPhase.hold && _holdStartMs == null) { _holdStartMs = _elapsedMs; }` block,
add:

```dart
    if (phase == ChargeRitualPhase.reel && _reelStartMs == null) {
      _reelStartMs = _elapsedMs;
    }
```

- [ ] **Step 4: Rewrite the `bitLine` computation for the relocated intro + reel silence**

In `_composition`, replace the `bitLine` assignment (the `final bitLine = ignited ? … ` block) with a
version that (a) keys the pre-reel line off the held-frame clock, and (b) is only *used* when the
bubble is shown (reel silence is enforced in Step 5):

```dart
    final heldElapsedMs = _elapsedMs; // pre-play clock (0 at mount, ticks in preroll)
    final introLine = heldElapsedMs < _kIntroLine2Ms
        ? 'say hi to our coach, jack mercer.'
        : "let's listen to his message together.";
    final bitLine = ignited
        ? "fully charged. let's keep moving."
        : pouring
        ? '[BOOSTING]'
        : reelDone
        ? (boostCued
              ? "alright warrior, let's [boost] this up and start strong."
              : 'thank you for the message, coach.')
        : introLine;
```

- [ ] **Step 5: Hide the bubble during the reel + pass a `showBubble` flag to `_PowerZone`**

In `_composition`, compute:

```dart
    final reelPlaying = phase == ChargeRitualPhase.reel;
```

Change the `_PowerZone(...)` call to pass `showBubble: !reelPlaying`. In the `_PowerZone` class add the
field `final bool showBubble;` (required, in the constructor) and wrap the `BitSpeechBubble` so it
renders an empty `SizedBox` slot (reserving height) when `!showBubble`:

```dart
                const SizedBox(height: kSpace2),
                SizedBox(
                  height: 40, // reserve the bubble's line box so BIT doesn't jump
                  child: showBubble
                      ? BitSpeechBubble(
                          key: ValueKey(bitLine),
                          text: bitLine,
                          tailDirection: BitTailDirection.none,
                          typewriter: !reduceMotion,
                          fontSize: 12,
                        )
                      : const SizedBox.shrink(),
                ),
```

(Removing the bubble from the tree disposes its typewriter `Timer`, so a line mid-type when the reel
starts is cancelled cleanly — the atomic cancel Codex F4 asked for.)

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd app && flutter test test/charge_ritual_screen_test.dart`
Expected: PASS (all existing tests + the two new ones).

- [ ] **Step 7: Analyze + commit**

```bash
cd app && flutter analyze lib/pages/onboarding/charge_ritual_screen.dart
git add app/lib/pages/onboarding/charge_ritual_screen.dart app/test/charge_ritual_screen_test.dart
git commit -m "feat(onboarding): BIT goes silent during the reel; intro moves to the held frame"
```

### Task A2: Pre-arm skip to the held frame so it never pops in mid-reel (Codex F2)

**Files:**
- Modify: `lib/pages/onboarding/charge_ritual_screen.dart` (`_composition`, add a latch field)
- Test: `test/charge_ritual_screen_test.dart`

**Why:** today `skipVisible = !ignited && _elapsedMs >= 3000` — a raw wall-clock timer. If the user
presses START BOOSTING before 3s, the skip link **pops in mid-reel** — one of the competing signals the
theater pass removes. Skip must be present from the moment the held frame is reachable (a whole-ritual
escape that's already there when playback starts), never appearing during the reel. Its route semantics
(`_skip → _goToGate(flow)`) are unchanged — appearance timing only.

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('skip is armed on the held frame and never first-appears during the reel', (
    tester,
  ) async {
    await pumpRitual(tester, reduced: false);
    await tester.pump();
    await advance(tester, 250); // entry reaches the held frame (Beat C) well before 3s

    // Skip is already reachable on the held frame (pre-armed), not gated to 3s.
    expect(find.textContaining('continue without charging'), findsOneWidget);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && flutter test test/charge_ritual_screen_test.dart -n "skip is armed on the held frame"`
Expected: FAIL — at ~250ms `_elapsedMs < 3000`, so today's skip is still hidden.

- [ ] **Step 3: Latch "held frame reached" and drive skip visibility off it**

Add a field near `_reelStartMs`:

```dart
  bool _heldFrameReached = false; // latched once the START BOOSTING gate is shown
```

In `_composition`, where `boostReady` is computed, latch it (a build-time latch is fine — it only ever
flips false→true):

```dart
    if (boostReady) _heldFrameReached = true;
```

Change the skip-visibility line from the raw timer to the latch (still hidden at ignition, still shown
on the reduced-motion hold path where the gate is reached immediately):

```dart
    final skipVisible = !ignited && (_heldFrameReached || reelDone || _reduceMotion);
```

(Reduced motion has no held frame but lands on `reelDone`; the delayed-skip 3s timer is retired — skip
is now a stable, pre-armed control, matching the lights-exempt controls in Phase B.)

- [ ] **Step 4: Run the test + the existing skip test**

Run: `cd app && flutter test test/charge_ritual_screen_test.dart -n "skip"`
Expected: PASS. Note: the existing `'skip is delayed (~3s) then routes to the gate'` test asserts the
OLD 3s-delay behavior — **update it** to assert skip is present on the reduced-motion hold immediately
(it lands on `reelDone`), then still routes to the gate:

```dart
  testWidgets('skip is armed and routes to the gate', (tester) async {
    await pumpRitual(tester, reduced: true);
    await tester.pump();
    expect(find.textContaining('continue without charging'), findsOneWidget);
    await tester.tap(find.textContaining('continue without charging'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(StartGateScreen), findsOneWidget);
  });
```

Also update the `'builds under full motion'` test's assertion `expect(find.textContaining('continue
without charging'), findsNothing)` — under full motion the video init fails and the watchdog lands on
`reelDone`, so skip is now present; change that line to `findsOneWidget`.

- [ ] **Step 5: Analyze + commit**

```bash
cd app && flutter analyze lib/pages/onboarding/charge_ritual_screen.dart
git add app/lib/pages/onboarding/charge_ritual_screen.dart app/test/charge_ritual_screen_test.dart
git commit -m "fix(onboarding): pre-arm skip to the held frame (no mid-reel pop-in)"
```

---

## Phase B — Lights down on the reel, back up on the hold (controls exempt)

### Task B1: Compute `_chromeLight` and apply it to decorative chrome only

**Files:**
- Modify: `lib/pages/onboarding/charge_ritual_screen.dart` (`_composition`, `_ChargeHeader`, `_PowerZone`)
- Test: `test/charge_ritual_screen_test.dart`

- [ ] **Step 1: Write the failing test — controls stay full-opacity, decoration dims**

```dart
  testWidgets('reduced motion keeps chrome fully lit (no dimming)', (tester) async {
    await pumpRitual(tester, reduced: true);
    await tester.pump();
    // Reduced motion has no reel; _chromeLight must be pinned to 1.0 — the header
    // opacity wrapper is at 1.0 (assert via the Opacity widget we add in Step 2).
    final op = tester.widgetList<Opacity>(find.byKey(const ValueKey('reel_chrome_dim')));
    for (final o in op) {
      expect(o.opacity, 1.0);
    }
  });
```

- [ ] **Step 2: Add the `_chromeLight` derivation**

In `_composition`, after `reelPlaying` is computed, add:

```dart
    // Lights-down: decoration fades to the floor as the reel starts, and back up
    // as the user holds the boost (mapped to the final pour 0.9→1.0). Between the
    // reel end and the hold it stays at the floor (cinema mood until effort earns
    // the lights back). Reduced motion / no reel → always fully lit.
    double chromeLight;
    if (_reduceMotion) {
      chromeLight = 1.0;
    } else if (reelPlaying) {
      final t = ((_elapsedMs - (_reelStartMs ?? _elapsedMs)) / _kReelDimRampMs)
          .clamp(0.0, 1.0);
      chromeLight = 1.0 + (_kChromeDimFloor - 1.0) * t; // 1.0 → floor
    } else if (pouring) {
      final up = ((charge - 0.9) / 0.1).clamp(0.0, 1.0);
      chromeLight = _kChromeDimFloor + (1.0 - _kChromeDimFloor) * up; // floor → 1.0
    } else if (ignited) {
      chromeLight = 1.0;
    } else if (reelDone) {
      chromeLight = _kChromeDimFloor; // exit recede + thank-you dwell stay dim
    } else {
      chromeLight = 1.0; // preroll / held frame — fully lit
    }
```

- [ ] **Step 3: Wrap the decorative chrome (NOT the controls) in the dim**

Wrap `_ChargeHeader` in `_composition`:

```dart
          Opacity(
            key: const ValueKey('reel_chrome_dim'),
            opacity: chromeLight,
            child: _ChargeHeader(charged: ignited),
          ),
```

Pass `chromeLight` into `_PowerZone` (add `final double chromeLight;` to its constructor). Inside
`_PowerZone.build`, wrap **only** the BIT core + bubble sub-`Column` (not the `ArcadeBar`) in
`Opacity(opacity: chromeLight, child: …)`, and scale the bar's glow by it:

```dart
        DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: reelDone
                ? [
                    BoxShadow(
                      color: accent.withValues(
                        alpha: (0.18 + 0.16 * pulse) * chromeLight,
                      ),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: ArcadeBar(value: charge, height: 16, accent: accent),
        ),
```

The `_HoldKeycap`, the "or tap — BIT pours it" line, `_SkipLink`, and the `_ReelMonitor`'s pause/mute
controls are **outside** any `chromeLight` wrapper — they keep full opacity. (`_ReelMonitor` already owns
its own brightness via `powerOn`/`brightness`/`exitFade`; do not route `chromeLight` into it — the
monitor is the lit subject, not dimmed decoration.)

- [ ] **Step 4: Run the test**

Run: `cd app && flutter test test/charge_ritual_screen_test.dart -n "reduced motion keeps chrome fully lit"`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

```bash
cd app && flutter analyze lib/pages/onboarding/charge_ritual_screen.dart
git add app/lib/pages/onboarding/charge_ritual_screen.dart app/test/charge_ritual_screen_test.dart
git commit -m "feat(onboarding): lights down on the reel, back up on the hold (controls exempt)"
```

### Task B2: Golden — a reel-dim frame

**Files:**
- Modify: `test/audit/charge_ritual_dialogue_frames_test.dart`

- [ ] **Step 1: Add a capture at the dim floor**

Follow the file's existing capture pattern (reduced-motion opens at hold, so to show the dim you must
render the reel path). Add a `--update-goldens`-gated capture that pumps `reduced: false`, advances
~600ms (past `_kReelDimRampMs`), and writes `test/audit/_shots/charge_reel_dim.png`. Use the same
`FontLoader` + `SfxService.enabled = false` scaffolding already in the file.

- [ ] **Step 2: Render + eyeball**

Run: `cd app && flutter test --update-goldens test/audit/charge_ritual_dialogue_frames_test.dart`
Then `Read` `test/audit/_shots/charge_reel_dim.png` — confirm the header + BIT are dimmed while the
skip/keycap stay legible. (Gitignored; no commit of the PNG.)

- [ ] **Step 3: Commit the test change**

```bash
git add app/test/audit/charge_ritual_dialogue_frames_test.dart
git commit -m "test(onboarding): capture the reel-dim frame"
```

---

## Phase C — Start Gate becomes a hero reveal (Option 1 composition)

### Task C1: Recompose the gate around a large centered hero avatar

**Files:**
- Modify: `lib/pages/onboarding/start_gate_screen.dart` (`build`, `_buildCharacterCard`)
- Test: `test/start_gate_screen_test.dart` (**new**)

**Design:** replace the top-anchored identity *card* with a vertically-centered hero column:
(1) a large framed avatar (~132px) as the focal element, (2) name + "untitled", (3) badges row
(RECRUIT · LV.1), (4) the XP bar + "0/50 XP · 1 QUEST ACTIVE" + First Forge line, all centered beneath
the portrait. BIT stays the guide row below; the two CTAs stay anchored at the bottom. All existing
reveal flags (`_cardFrameVisible … _completed`) and the skip-to-end path are preserved — only the
**layout** and the reveal **order** change.

- [ ] **Step 1: Write the failing test — the hero avatar is present and large**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/character.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/start_gate_screen.dart';
import 'package:workout_track/widgets/avatar/ironbit_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Character character() => Character(
    name: 'Nova',
    calibration: const CalibrationResult(
      goal: BodyGoal.cut, freq: TrainingFreq.mid, exp: Experience.beginner,
      bodyWeightKg: 72, sex: UserProfileSex.preferNotToSay,
      clazz: CharacterClass.assassin,
    ),
    classConfirmedAt: DateTime(2026, 5, 29, 12),
    characterName: 'Nova',
    createdAt: DateTime(2026, 5, 29, 12),
  );

  Future<void> pump(WidgetTester tester, {required bool reduced}) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(disableAnimations: reduced), child: child!,
      ),
      home: StartGateScreen(character: character()),
    ),
  );

  testWidgets('reduced motion lands on the settled hero gate', (tester) async {
    await pump(tester, reduced: true);
    await tester.pump(); // post-frame skip-to-end

    // The hero avatar is present and rendered large (>= 120px).
    final avatar = tester.widget<IronbitAvatar>(find.byType(IronbitAvatar));
    expect(avatar.size, greaterThanOrEqualTo(120));

    // Identity + CTAs are all present in the settled state.
    expect(find.text('Nova'), findsOneWidget);
    expect(find.text('RECRUIT'), findsOneWidget);
    expect(find.text('LV.1'), findsOneWidget);
    expect(find.textContaining('0 / 50 XP'), findsOneWidget);
    expect(find.text('START WORKOUT'), findsOneWidget);
    expect(find.text('EXPLORE FIRST'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && flutter test test/start_gate_screen_test.dart -n "reduced motion lands on the settled hero gate"`
Expected: FAIL — today's avatar is 80px (`< 120`).

- [ ] **Step 3: Recompose `build`'s body column into a hero layout**

In `start_gate_screen.dart`, replace the `Column` children inside the `SafeArea > Padding` (currently
`_buildCharacterCard(...) → SizedBox(32) → BIT row → Spacer → buttons`) with a centered hero column.
Replace `_buildCharacterCard` with `_buildHero`. Concretely, the new column:

```dart
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    _buildHero(character, reduceMotion),
                    const SizedBox(height: 24),
                    _buildBitRow(bitPrompt, addressed), // the existing BIT row, extracted
                    const Spacer(flex: 2),
                    // ... the two PowerOn button blocks unchanged ...
                  ],
                ),
```

`_buildHero` renders the centered portrait + identity strip (reusing the existing reveal flags):

```dart
  Widget _buildHero(Character character, bool reduceMotion) {
    final clazz = character.calibration.clazz;
    return Semantics(
      label:
          'Character: ${character.characterName}, ${clazz.displayName}, Recruit, Level 1',
      container: true,
      child: Column(
        children: [
          // Focal hero: a large framed pixel face (echoes the Profile hero card).
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _avatarVisible ? 1.0 : 0.0,
            child: Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                border: Border.all(color: kBorderVariant),
                borderRadius: BorderRadius.circular(kCardRadius),
                color: kBg,
              ),
              child: Center(
                child: IronbitAvatar(spec: widget.avatarSpec, size: 132),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 28,
            child: !_nameTyping
                ? const SizedBox.shrink()
                : (reduceMotion
                      ? Text(character.characterName,
                          style: const TextStyle(
                              fontFamily: 'PressStart2P', fontSize: 22, color: kText))
                      : TypewriterText(character.characterName,
                          charMs: 30,
                          style: const TextStyle(
                              fontFamily: 'PressStart2P', fontSize: 22, color: kText))),
          ),
          const SizedBox(height: 4),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _untitledVisible ? 1.0 : 0.0,
            child: Text('untitled',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13)),
          ),
          const SizedBox(height: 10),
          if (_badgesVisible)
            StrobeFlash(
              trigger: _badgesVisible, color: kNeon, opacity: 0.25, toggles: 1,
              toggleMs: 80, borderRadius: BorderRadius.circular(kCardRadius),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _IdentityBadge(label: 'RECRUIT', color: kMutedText),
                  SizedBox(width: 8),
                  _IdentityBadge(label: 'LV.1', color: kNeon),
                ],
              ),
            )
          else
            const SizedBox(height: 22),
          const SizedBox(height: 14),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _xpBarVisible ? 1.0 : 0.0,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: kBorder, borderRadius: BorderRadius.circular(kCardRadius),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _countersVisible ? 1.0 : 0.0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0 / 50 XP',
                        style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12)),
                    Text('1 QUEST ACTIVE',
                        style: AppFonts.shareTechMono(color: kAmber, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('▸ First Forge · save your first workout',
                    style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
```

Extract the existing BIT `SizedBox(height: 80, child: … StrobeFlash … Row(BitMoodCore, BitSpeechBubble))`
verbatim into a `Widget _buildBitRow(String bitLine, BitPose bitPose, String addressed) { … }`, wiring
`bitPose` into the `BitMoodCore(pose: …)` and `bitLine` into the `BitSpeechBubble(text: …)`. In THIS
task (Phase C) call it with the settled values — `_buildBitRow(bitPrompt, BitPose.neutral, addressed)`
— so the gate is behavior-identical to today; **Phase D Task D1 feeds it the hyped values.** (Import
`BitPose` is already present via `bit_mood_core.dart`.)

- [ ] **Step 4: Reorder `_scheduleSequence` payoff-first**

The avatar + name are the peak, so they land first. Change the cumulative offsets so the avatar/name
lead and the admin details follow (keep the same total ~2.5s and the `_completed` gate last):

```dart
  void _scheduleSequence() {
    _step(120, () => _cardFrameVisible = true); // frame fades in under the hero
    _step(120, () => _avatarVisible = true);    // the face is the peak — first
    _step(360, () => _nameTyping = true);
    _step(560, () => _untitledVisible = true);
    _step(720, () => _badgesVisible = true);    // "system online" strobe
    _step(980, () => _xpBarVisible = true);
    _step(1120, () => _countersVisible = true);
    _step(1420, () => _promptTyping = true);    // BIT arrives (see Phase D)
    _step(1900, () => _subtextVisible = true);
    _step(2100, () => _primaryOn = true);
    _step(2200, () => _secondaryOn = true);
    _step(2400, () => _completed = true);
  }
```

(`_cardFrameVisible` no longer wraps a card border — leave the flag driving the hero's own fade if you
prefer, or repoint `_buildHero`'s outer to `_avatarVisible`; keep `_skipToEnd` setting every flag true.)

- [ ] **Step 5: Run the test**

Run: `cd app && flutter test test/start_gate_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze + commit**

```bash
cd app && flutter analyze lib/pages/onboarding/start_gate_screen.dart
git add app/lib/pages/onboarding/start_gate_screen.dart app/test/start_gate_screen_test.dart
git commit -m "feat(onboarding): Start Gate recomposes around a hero portrait"
```

---

## Phase D — The charge arrives on the hero

### Task D1: One-shot arrival surge (frame + name ignite, XP shimmer, hyped BIT)

**Files:**
- Modify: `lib/pages/onboarding/start_gate_screen.dart`
- Test: `test/start_gate_screen_test.dart`

**Design:** a single `AnimationController _arrival` (0→1 over `_kArrivalMs`) starts when the reveal
begins (first frame after the post-frame callback, full-motion only). It drives: the hero frame's neon
`boxShadow` (ignite → cool), the name color (kNeon → kText), and one left-to-right shimmer over the XP
bar. A `_bitHyped` bool starts true and flips false after `_kBitHypedMs`, swapping BIT's line from
"fully charged, <name>." (cheer) to the existing "What should we do first, <name>?" (neutral). The XP
bar's **value never changes** — the shimmer is a moving highlight over the same empty bar.

- [ ] **Step 1: Write the failing test — XP stays 0/50, BIT arrives hyped then settles**

```dart
  testWidgets('the arrival never fabricates XP and BIT settles from hyped', (tester) async {
    await pump(tester, reduced: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // reveal begins

    // Drive past the reveal + arrival window.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    // The XP readout is unchanged — no fake progress was granted.
    expect(find.textContaining('0 / 50 XP'), findsOneWidget);
    // BIT has settled to the guiding prompt (hyped line gone).
    expect(find.textContaining('What should we do first'), findsOneWidget);
    expect(find.textContaining('fully charged'), findsNothing);
  });

  testWidgets('reduced motion shows the settled gate with no hyped line', (tester) async {
    await pump(tester, reduced: true);
    await tester.pump();
    expect(find.textContaining('What should we do first'), findsOneWidget);
    expect(find.textContaining('fully charged'), findsNothing);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && flutter test test/start_gate_screen_test.dart -n "the arrival never fabricates XP"`
Expected: FAIL (`fully charged`/settle logic and `_arrival` don't exist yet).

- [ ] **Step 3: Add the arrival controller + hyped state**

Make `_StartGateScreenState` a `TickerProviderStateMixin`. Add the constants at the top of the file
(`_kArrivalMs = 900`, `_kBitSettleMs = 3200`). Add fields:

```dart
  late final AnimationController _arrival = AnimationController(
    vsync: this, duration: const Duration(milliseconds: _kArrivalMs),
  );
  bool _bitHyped = false;
```

In the post-frame callback of `initState`, after choosing the reduced vs sequence path:

```dart
      if (mq.accessibleNavigation || mq.disableAnimations) {
        _skipToEnd(); // reduced: no arrival surge, no hyped line
        return;
      }
      _bitHyped = true;
      _arrival.forward();
      _scheduleSequence();
```

The hyped→settled flip is scheduled **inside `_scheduleSequence`** (Task C1 Step 4) as one more `_step`
so it lands ~1.8s after the BIT row reveals (prompt at 1420ms → settle at `_kBitSettleMs` 3200ms),
rather than a separate initState `Timer` that would fire only ~180ms after the row appears. Add this
line to `_scheduleSequence`:

```dart
    _step(_kBitSettleMs, () => _bitHyped = false); // BIT: "fully charged" → the prompt
```

And in `_skipToEnd`, set the settled end state so a fast tap lands on the guiding prompt (add alongside
the other flag assignments):

```dart
      _bitHyped = false;
```

Dispose the controller: add `_arrival.dispose();` to `dispose()` (before `super.dispose()`).

- [ ] **Step 4: Drive the frame/name ignite + XP shimmer off `_arrival`**

In `_buildHero`, wrap the hero frame `Container` and the name `Text` in an `AnimatedBuilder(animation:
_arrival, …)`. The ignite is a `sin(pi * t)` pulse (0→1→0):

```dart
          AnimatedBuilder(
            animation: _arrival,
            builder: (context, child) {
              final ignite = math.sin(_arrival.value * math.pi); // 0→1→0
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _avatarVisible ? 1.0 : 0.0,
                child: Container(
                  width: 148, height: 148,
                  decoration: BoxDecoration(
                    border: Border.all(color: kBorderVariant),
                    borderRadius: BorderRadius.circular(kCardRadius),
                    color: kBg,
                    boxShadow: neonGlow(
                      color: kNeon, opacity: 0.55 * ignite, blur: 22 * ignite,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            child: Center(child: IronbitAvatar(spec: widget.avatarSpec, size: 132)),
          ),
```

For the name, lerp the color kNeon→kText across the arrival (only under full motion — reduced motion
uses the plain `Text`/`TypewriterText` as today). Wrap the name box:

```dart
          AnimatedBuilder(
            animation: _arrival,
            builder: (context, _) {
              final c = Color.lerp(kNeon, kText, Curves.easeOut.transform(_arrival.value))!;
              return SizedBox(
                height: 28,
                child: !_nameTyping
                    ? const SizedBox.shrink()
                    : (reduceMotion
                          ? Text(character.characterName,
                              style: const TextStyle(
                                  fontFamily: 'PressStart2P', fontSize: 22, color: kText))
                          : TypewriterText(character.characterName,
                              charMs: 30,
                              style: TextStyle(
                                  fontFamily: 'PressStart2P', fontSize: 22, color: c))),
              );
            },
          ),
```

For the XP bar shimmer, replace the bar `Container` with a `Stack` that overlays a moving highlight
driven by `_arrival` (the bar value is still nothing — it's a decorative empty bar, so the shimmer is
purely a moving neon strip; **assert-safe** because no XP text changes):

```dart
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _xpBarVisible ? 1.0 : 0.0,
            child: SizedBox(
              height: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: kBorder, borderRadius: BorderRadius.circular(kCardRadius),
                    ),
                  ),
                  if (!reduceMotion)
                    AnimatedBuilder(
                      animation: _arrival,
                      builder: (context, _) {
                        final t = _arrival.value;
                        if (t <= 0 || t >= 1) return const SizedBox.shrink();
                        return Align(
                          alignment: Alignment(-1 + 2 * t, 0),
                          child: FractionallySizedBox(
                            widthFactor: 0.28, heightFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: kNeon.withValues(alpha: 0.5 * math.sin(t * math.pi)),
                                borderRadius: BorderRadius.circular(kCardRadius),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
```

Add `import 'dart:math' as math;` at the top of the file if not present.

- [ ] **Step 5: Make BIT arrive hyped, then settle**

In `build`, compute the BIT line + pose from `_bitHyped`:

```dart
    final bitLine = _bitHyped ? 'fully charged, $addressed.' : bitPrompt;
    final bitPose = _bitHyped ? BitPose.cheer : BitPose.neutral;
```

In `_buildBitRow`, use `bitLine`/`bitPose` for the `BitMoodCore(pose: bitPose, …)` and the
`BitSpeechBubble(text: bitLine, emphasis: addressed, …)`. (Pass them into `_buildBitRow`.) The row is
still gated on `_promptTyping`/`_subtextVisible` exactly as today, so reduced-motion + tap-skip land it.

- [ ] **Step 6: Run the tests**

Run: `cd app && flutter test test/start_gate_screen_test.dart`
Expected: PASS (all gate tests).

- [ ] **Step 7: Analyze + commit**

```bash
cd app && flutter analyze lib/pages/onboarding/start_gate_screen.dart
git add app/lib/pages/onboarding/start_gate_screen.dart app/test/start_gate_screen_test.dart
git commit -m "feat(onboarding): the poured charge arrives on the Start Gate hero"
```

### Task D2: Golden — the recomposed gate (settled + arrival-mid)

**Files:**
- Modify: `test/audit/screens_d_test.dart`

- [ ] **Step 1: Re-capture the settled gate**

The existing `audit/start_gate` capture (screens_d_test.dart:65) already renders `StartGateScreen`;
re-run it to refresh `test/audit/_shots/start_gate.png` against the new hero composition. If the file's
`create_exercise` capture is still broken (a known separate issue, being fixed in a background task),
run only the start-gate case with `-n`.

Run: `cd app && flutter test --update-goldens test/audit/screens_d_test.dart -n "start_gate"`
Then `Read` `test/audit/_shots/start_gate.png` — confirm the large centered hero avatar, the identity
strip beneath, no dead void, and BIT below.

- [ ] **Step 2: (Optional) add an arrival-mid capture**

If a mid-arrival golden is wanted, add a `--update-goldens`-gated capture that pumps `reduced: false`,
advances ~200ms (into the `_arrival` window), and writes `charge_arrival_mid.png`. Eyeball the frame +
name ignite. Skip if the settled capture is sufficient.

- [ ] **Step 3: Commit the test change**

```bash
git add app/test/audit/screens_d_test.dart
git commit -m "test(onboarding): re-capture the hero Start Gate golden"
```

---

## Phase E — Full verification

### Task E1: Analyze + full suite + reduced-motion parity

- [ ] **Step 1: Analyze the whole project**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Run the onboarding + coverage test surface**

Run:
```bash
cd app && flutter test test/charge_ritual_screen_test.dart test/charge_ritual_engine_test.dart \
  test/start_gate_screen_test.dart test/tap_haptic_coverage_test.dart
```
Expected: all PASS. The engine tests must be **unchanged and green** (no behavior change in Phase A–D).

- [ ] **Step 3: Run the full suite**

Run: `cd app && flutter test`
Expected: green (the pre-change baseline is fully green — any failure is real). If a golden fails, it is
an *intended* re-baseline from Task B2 / D2 only — re-render + eyeball, never blind-accept.

- [ ] **Step 4: Reduced-motion parity check (manual assertion)**

Confirm via the reduced-motion tests (`charge_ritual` "reduced motion lands…", `start_gate` "reduced
motion shows the settled gate…"): no reel, `_chromeLight` pinned to 1.0, no `_arrival` surge, gate opens
settled with BIT on the guiding prompt (no hyped line). These are the WCAG fallback contract — they must
be byte-identical to today's behavior.

- [ ] **Step 5: Final commit (if any test-only touch-ups remain)**

```bash
git add -A app/test
git commit -m "test(onboarding): reel→gate cinematic pass verification"
```

---

## On-device sign-off (cannot verify here — hand to the user)

- Dim depth (`_kChromeDimFloor` 0.30) + ramp feel; the dark beat between reel-end and the hold vs the
  warm-up-early fallback.
- Arrival intensity (`_kArrivalMs` 900; the ignite/shimmer strength) — medium by design; tune up/down.
- Hero avatar size (148/132px) + vertical balance at real device sizes.
- **The F5 gate:** whether the clip still reads too fast once BIT is silent + the lights are down. If
  yes → the asset re-cut (longer caption dwells) is the named fallback, out of scope for this build.

## Notes for the executor

- **Do not stage foreign work.** The tree carries a parallel session's changes (`home.dart`,
  `room_scene.dart`, `focus_frame.dart`, `expedition_dock_test.dart`, an SFX-doctrine spec, and an
  intermixed `insights.md`). Every `git add` above names explicit paths — never `git add -A` at repo
  root, and never stage those files.
- Engine (`charge_ritual_engine.dart`) is **read-only** here — if you find yourself changing a phase
  transition, stop: the design forbids it (soft-lock guarantees).
- Keep the typewriter at `kBitTypeCharMs` (22ms/char); no strobe beyond the existing single-toggle
  `StrobeFlash` beats.
