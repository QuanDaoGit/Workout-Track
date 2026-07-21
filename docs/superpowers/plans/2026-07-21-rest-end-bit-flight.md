# Rest-End BIT Flight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** At rest end (natural or skip), the rest panel's BIT flies to the finished card, seals it (single strobe), and hops to the frontier slot — overlay-only, input never waits.

**Architecture:** One new self-contained overlay widget (`SessionBitFlight`) mounted in a Stack over the hub body; `ActiveWorkoutPage` owns the trigger taxonomy + the single-owner pending-celebration; `RestBreakPanel` gains an origin key + a natural-end callback. No services, no persistence, no engine changes.

**Tech Stack:** Flutter widget layer; `flutter_test` with bounded pumps (never `pumpAndSettle` while the hub is mounted).

**Spec:** `docs/superpowers/specs/2026-07-21-rest-end-bit-flight-design.md`.

## Codex plan review (2026-07-21) — needs-attention, 4 findings, all folded

| # | Finding | Resolution (the committed code is the authority) |
|---|---|---|
| 1 (high) | Pending claimed before targets proven → seal silently lost on the swap race | `_launchFlight` only records a request + origin; the begin-gate runs from the **non-resting list's own build** via post-frame (structurally after layout), claims pending only when `begin()` accepts a valid finished-card target, else releases to the return-consumer (one fallback funnel) |
| 2 (high) | Opening a DIFFERENT exercise leaves a stale pending → late unrelated strobe | `_openExercise` clears pending + the flight request **unconditionally** (any exercise open dismisses the rest context); encoded as a test |
| 3 (med) | settleNow can't cancel scheduled callbacks → stale stamp/resurrection | Generation token (`_flightGen` host-side + `_gen` widget-side) captured by every delayed callback; settleNow/dispose/open bump it; all mutations require token match + mounted |
| 4 (med) | Trigger oracle can't tell seal-beat from fallback | Tests assert trigger == 0 mid-flight (after list return, before b2) then == 1 after b2; StrobeFlash timers drained at test end; isolated `SessionBitFlight` widget test covers target-missing/settleNow; a two-action stress test asserts exactly one celebration owner |

Key API facts (verified): `BitMoodCore(pose, size, freezeBob, reveal, blink, anticipation, idleAmp)` — pose morphs take 900ms (do NOT flip pose mid-flight; use `blink: true` for the stamp), `anticipation` 0..1 coil, `freezeBob` stills the idle; `StrobeFlash(trigger, …)` fires on trigger change, has NO internal RM gate (call sites own it); the rest panel's live-finish branch (the `<3s` overshoot check) is in `_RestBreakPanelState`'s ticker.

---

### Task 1: `SessionBitFlight` overlay widget

**Files:** Create `app/lib/widgets/session_bit_flight.dart`

State machine: `idle → beat0 → beat1 → beat2 → beat3 → idle`, one `AnimationController`
(natural 770ms / skip 690ms), phase boundaries as fractions. Public API:

```dart
enum FlightProfile { natural, skip }

class SessionBitFlight extends StatefulWidget {
  const SessionBitFlight({
    super.key,
    required this.child,
    required this.onStamp,   // fire the single celebration (host bumps strobe)
    required this.onDone,    // landing or settleNow — host restores the in-card BIT
  });
  final Widget child;
  final VoidCallback onStamp;
  final VoidCallback onDone;
  @override
  State<SessionBitFlight> createState() => SessionBitFlightState();
}

class SessionBitFlightState extends State<SessionBitFlight>
    with SingleTickerProviderStateMixin {
  // begin(): origin in GLOBAL coords (measured by the host while the panel is
  // still mounted); target keys resolved lazily post-layout each beat.
  void begin({
    required Rect originGlobal,
    required GlobalKey finishedCardKey,
    required GlobalKey frontierSlotKey,
    required FlightProfile profile,
  }) { ... }
  void settleNow() { ... } // stop, clear, onDone — idempotent
  bool get active => _active;
}
```

Implementation notes (complete in code, summarized here):
- Controller created **eagerly in initState** (assignment form — the reduced-motion dispose
  trap). Host never calls `begin` under RM, but the controller must still be safe.
- `begin` stores origin (converted to local via `context.findRenderObject()`), sets `_active`,
  runs `controller.forward(from: 0)`. Beat boundaries (natural): b0 end 90/770, b1 end 470/770,
  b2 end 590/770, b3 end 1.0; skip: b0 end 16/690, shifted accordingly.
- Target resolution: `_rectFor(GlobalKey)` → key.currentContext?.findRenderObject() as
  RenderBox? → null-safe local rect; resolved at b1 start (finished card) and b3 start
  (frontier slot); a null/off-viewport target (center outside the overlay's bounds inflated by
  40px) skips that leg: b1 target null → jump to b3 (still `onStamp` — celebration fires,
  harmlessly invisible if scrolled away); b3 target null → fade out over the last 80ms →
  `settleNow`.
- Path b1: quadratic bezier: origin center → finished-card corner point
  `cardRect.topRight + const Offset(-16, 2)`; control = midpoint + `Offset(bow, 0)` where
  `bow = (overlayWidth - midpoint.dx - 28).clamp(0, 24)`. Progress: path param s(t):
  `t < .35 ? easeInCubic` mapped to `[0,.45]` of s, else `easeOutCubic` mapped to `[.45,1]`
  (continuous at the joint). Scale = `lerpDouble(96, 40, s)`.
- Beat 0 render: BIT at origin, `anticipation: t/b0End` ramp (max 1), sink 2px.
- Beat 2: position at the corner point + a 1-frame 2px overshoot (t-based); `blink: true`
  while in beat 2; `widget.onStamp()` fired ONCE via a `_stamped` latch at b2 entry.
- Beat 3: parabola: lerp(corner, slotCenter) + `Offset(0, -8 * sin(pi * u))`, `easeOut` on u;
  scale 40→44.
- Ghosts: ring buffer of (center, size) pushed each frame during b1; render 2 delayed copies
  (40/80ms) wrapped in `Opacity(0.22 / 0.10)`; ghosts + main BIT all
  `ExcludeSemantics(child: BitMoodCore(pose: BitPose.neutral, reveal: 1, freezeBob: true, …))`
  — `freezeBob` keeps the flight frame deterministic. Beat 0 uses `pose: BitPose.rest` (it IS
  the rest BIT until lift-off), b1+ `neutral` — set ONCE at b1 entry; the 900ms morph then
  eases the body language over the whole flight (a feature: the wake-up reads gradual).
- Build: `Stack(children: [widget.child, if (_active) Positioned.fill(child: IgnorePointer(
  child: AnimatedBuilder(...)))])` — `StackFit.passthrough` NOT needed here because the child
  fills; verify layout-transparency with the existing page tests.
- `onDone` called exactly once per flight (latch), from `status == completed` listener or
  `settleNow`.

- [ ] Write the widget; `flutter analyze` clean. Commit: `feat: SessionBitFlight overlay (flight → corner seal → frontier hop)`.

### Task 2: `RestBreakPanel` — origin key + natural-end callback

**Files:** Modify `app/lib/widgets/rest_break_panel.dart`

- [ ] Add params: `this.bitKey, this.onNaturalEnd` (both optional, additive — byte-stable
  default path per the shared-primitive rule). Wrap the BIT:
  `KeyedSubtree(key: widget.bitKey ?? ..., child: BitMoodCore(...))` (plain child when null).
  In the ticker's live-finish branch (inside the `< 3s` check, BEFORE
  `RestTimerService.instance.cancel()`): `widget.onNaturalEnd?.call();`
- [ ] Commit: `feat: rest panel exposes BIT origin + live natural-end callback`.

### Task 3: Red tests — the taxonomy + contracts

**Files:** Create `app/test/active_workout_flight_test.dart`

Harness: the rest-panel test file's fixtures + `pumpBounded`; `ActiveWorkoutPage(restSeconds: 1)`
so a natural expiry is one `pump(2s)` away. Key assertions per spec's test contract (full code
in the file; representative):

```dart
Finder overlayBit() => find.byKey(const ValueKey('flight_bit'));
int strobeTrigger(WidgetTester t, String name) =>
    (t.widget<StrobeFlash>(find.ancestor(of: find.text(name),
        matching: find.byType(StrobeFlash)).first).trigger ?? 0) as int;

testWidgets('natural expiry flies and stamps once', (tester) async {
  await pumpHub(tester, restSeconds: 1);
  await finishExercise(tester, 'alpha');           // rest takeover up
  await tester.pump(const Duration(seconds: 2));   // ticker: live finish → flight
  await tester.pump(const Duration(milliseconds: 50));
  expect(overlayBit(), findsOneWidget);            // flight running
  expect(find.byKey(const ValueKey('frontier_bit')), findsNothing); // suppressed
  await tester.pump(const Duration(milliseconds: 600)); // past stamp
  expect(strobeTrigger(tester, 'alpha'), 1);
  await tester.pump(const Duration(milliseconds: 400)); // landed
  expect(overlayBit(), findsNothing);
  expect(find.byKey(const ValueKey('frontier_bit')), findsOneWidget);
  expect(strobeTrigger(tester, 'alpha'), 1);       // exactly once
});
```

- [ ] Tests: natural (above) · skip (tap SKIP REST → panel gone same frame + overlay present)
  · stale (force `RestTimerService.instance.current.value` to `endsAt: now−5s` then pump → no
  overlay, strobe bumps once on return) · reduced motion (skip path under
  `disableAnimations: true` → no overlay, trigger stays 0, warmth present) · mid-flight tap
  (start flight, tap 'bravo' → `ExerciseSessionPage` pushed, overlay settles; pop back → no
  extra strobe) · final exercise (finish last → immediate single bump, no overlay; RM variant
  0). Run: expect FAIL (no wiring). Commit red.

### Task 4: Wire `ActiveWorkoutPage`

**Files:** Modify `app/lib/pages/Workout session/active_workout.dart`

- [ ] New state:

```dart
  String? _pendingCelebrationId; // finished-but-uncelebrated (also the stamp target)
  bool _flightActive = false;    // overlay owns BIT; in-card frontier BIT suppressed
  bool _returnConsumeScheduled = false;
  final GlobalKey _restBitKey = GlobalKey();
  final GlobalKey _frontierSlotKey = GlobalKey();
  final GlobalKey<SessionBitFlightState> _flightKey = GlobalKey();
  bool get _reduceMotion {
    final mq = MediaQuery.of(context);
    return mq.disableAnimations || mq.accessibleNavigation;
  }
```

- [ ] `_openExercise`: entry — `if (_pendingCelebrationId == exercise.id) _pendingCelebrationId = null;`
  and `_flightKey.currentState?.settleNow();`. Finish branch — replace the
  `_flashTriggers[exercise.id]++` line:

```dart
        if (_allDone) {
          // Final exercise: rest is suppressed, the list is visible now — the
          // celebration fires immediately (RM: the static warmth is the signal).
          if (!_reduceMotion) {
            _flashTriggers[exercise.id] = (_flashTriggers[exercise.id] ?? 0) + 1;
          }
        } else {
          _pendingCelebrationId = exercise.id;
        }
```

- [ ] Trigger + consume methods:

```dart
  void _launchFlight(FlightProfile profile) {
    final targetId = _pendingCelebrationId;
    if (_reduceMotion || targetId == null) return; // return-consumer handles it
    final box = _restBitKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    _pendingCelebrationId = null; // claimed by the flight (single owner)
    _flightActive = true;
    final cardKey = _exerciseKeys[targetId]!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _flightKey.currentState?.begin(
        originGlobal: origin,
        finishedCardKey: cardKey,
        frontierSlotKey: _frontierSlotKey,
        profile: profile,
      );
      _stampTargetId = targetId; // field: consumed by _onFlightStamp
    });
  }

  void _onFlightStamp() {
    final id = _stampTargetId;
    if (id == null || _reduceMotion) return;
    setState(() => _flashTriggers[id] = (_flashTriggers[id] ?? 0) + 1);
  }

  void _onFlightDone() {
    _stampTargetId = null;
    if (_flightActive && mounted) setState(() => _flightActive = false);
  }
```

  (`String? _stampTargetId;` joins the fields. Mid-flight settle: `settleNow` → `_onFlightDone`
  only — an interrupted flight's celebration is cancelled, matching the reopen rule.)
- [ ] No-flight return consumer — in the list branch of the rest `ValueListenableBuilder`
  (when NOT resting), before returning the Column:

```dart
                    if (_pendingCelebrationId != null &&
                        !_flightActive &&
                        !_returnConsumeScheduled) {
                      _returnConsumeScheduled = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _returnConsumeScheduled = false;
                        final id = _pendingCelebrationId;
                        if (id == null || _flightActive) return;
                        _pendingCelebrationId = null;
                        if (!_reduceMotion) {
                          setState(() =>
                              _flashTriggers[id] = (_flashTriggers[id] ?? 0) + 1);
                        }
                      });
                    }
```

- [ ] `RestBreakPanel` call site gains `bitKey: _restBitKey`,
  `onNaturalEnd: () => _launchFlight(FlightProfile.natural)`, and the skip closure launches
  BEFORE cancel (origin must be measured while the panel is mounted):

```dart
                      return RestBreakPanel(
                        bitKey: _restBitKey,
                        onNaturalEnd: () =>
                            _launchFlight(FlightProfile.natural),
                        onSkip: () {
                          _launchFlight(FlightProfile.skip);
                          RestTimerService.instance.cancel();
                          _restAfterFinish = false;
                          if (mounted) setState(() {});
                        },
                        nextExerciseName: _nextUndoneExerciseName,
                      );
```

- [ ] Frontier card slot: replace the frontier BIT block so the slot is reserved during the
  flight and the landing ramps the idle in:

```dart
                                        if (exercise.id == frontierId &&
                                            showFrontierBit) ...[
                                          if (_flightActive)
                                            SizedBox(
                                              key: _frontierSlotKey,
                                              width: 44,
                                              height: 44,
                                            )
                                          else
                                            ExcludeSemantics(
                                              child: KeyedSubtree(
                                                key: _frontierSlotKey,
                                                child: TweenAnimationBuilder<double>(
                                                  key: const ValueKey('frontier_bit_ramp'),
                                                  tween: Tween(begin: 0, end: 0.55),
                                                  duration: const Duration(milliseconds: 400),
                                                  builder: (_, amp, _) => BitMoodCore(
                                                    key: const ValueKey('frontier_bit'),
                                                    pose: BitPose.neutral,
                                                    reveal: 1,
                                                    size: 44,
                                                    idleAmp: amp,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          const SizedBox(width: kSpace2),
                                        ],
```

  (One `_frontierSlotKey` in both branches — never two in the tree at once. The ramp wrapper
  runs on every mount; harmless on normal mounts, the no-pop resume on landings.)
- [ ] Wrap the body content: `SessionBitFlight(key: _flightKey, onStamp: _onFlightStamp,
  onDone: _onFlightDone, child: <the existing SafeArea child>)`.
- [ ] settleNow hooks (one-liners at the top of): `_confirmEndEarly`, `_goToSummary`,
  `_savePartialAndQuit`, `_pauseAndQuit`, `_abandonAndShowSummary`, `_onIdleTimeout` (after the
  guards), and `didChangeAppLifecycleState` on `paused`.
- [ ] Run Task-3 tests → green. Also update `active_workout_bit_frontier_test.dart` if the
  ramp wrapper changed any pinned widget lookups (`idleAmp` is now animated — the fresh-session
  test pins `idleAmp == 0.55`; pump ≥400ms before asserting, already true with `pumpBounded`).
  Commit.

### Task 5: Full verification

- [ ] `flutter analyze` 0 · new tests + frontier tests + rest-panel/idle/end-early/durability
  files green (bounded pumps only) · full suite (flaky env baseline excepted, re-run once on
  any surprise) · finish-time greps on the 3 changed lib files · hub goldens still pass (the
  static frames are byte-identical — flight only exists mid-animation).

### Task 6: Docs + reflect

- [ ] PRD shipped entry · CLAUDE.md ActiveWorkoutPage row sentence · insights.md flight entry
  (Duolingo/juice/fatigue + the two Codex rounds) · learnings gates (ironbit-design: corner-seal
  / engine-param constraint if generalizable; else "no new learning") · commit.

## Self-review

Spec coverage: taxonomy rows ↔ Task 3/4 paths all mapped; choreography beats ↔ Task 1; contracts
(readiness/interruption/stale/single-owner/no-double-BIT) ↔ Tasks 1+4 + tests. Types consistent
(`FlightProfile`, `SessionBitFlightState.begin/settleNow/active`, `_stampTargetId`). No
placeholders. The `(_, amp, _)` builder signature must be `(context, amp, child)` in real code.
