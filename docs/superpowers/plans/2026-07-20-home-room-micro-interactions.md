# Home-Room Micro-Interactions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Board tap dollies the room camera into the quest board (CRT reveal over it, settle on pop); pad dispatch tap leans the camera toward the pad under the sheet; BIT press fires a shaped haptic purr; board + pad answer pointer-down with a paint-level press-light.

**Architecture:** A `RoomCamera` (ChangeNotifier: scale + focal alignment) driven by one HomePage `AnimationController`, rendered by a `RoomZoomLens` that scales the room's **rendered raster layer** (`Transform.scale` + `filterQuality` around a `RepaintBoundary`) — identity when scale ≤ 1, so goldens and reduced-motion are byte-identical. The camera is **stateless while covered** (resets under the opaque route; pop plays a settle from a freshly-set pose via `RouteAware`). A new `ArcadeRouteMotion.dolly` holds the incoming page invisible for the first ~42% of a 280ms transition so the dolly reads before the CRT bands reveal. The purr is a `HapticService` method (envelope / double-pulse / selection-tick fallback ladder + in-flight guard). Press-light is painter state, never per-fixture transforms.

**Tech Stack:** Flutter (existing app); `vibration` pkg (already a dependency); no new packages.

**Spec:** `docs/superpowers/specs/2026-07-20-home-room-micro-interactions-design.md`

**Codex plan-review gate:** run the prompt-carried adversarial review of THIS plan before Task 1 (deep-feature Stage 4); fold findings in.

**File map:**
- Create: `app/lib/widgets/room/room_zoom_lens.dart` (RoomCamera + RoomZoomLens)
- Create: `app/test/room_zoom_lens_test.dart`
- Create: `app/test/haptic_purr_test.dart`
- Create: `app/test/arcade_route_dolly_test.dart`
- Modify: `app/lib/services/haptic_service.dart` (add `bitPurr`)
- Modify: `app/lib/widgets/companion/bit_companion.dart` (purr wiring, ~line 171)
- Modify: `app/lib/widgets/room/quest_board.dart` (press-light)
- Modify: `app/lib/widgets/room/room_scene.dart` (anchors extraction, static focal helpers, pad press-light, `onViewQuestsFromBoard`)
- Modify: `app/lib/widgets/arcade_route.dart` (dolly motion)
- Modify: `app/lib/pages/home.dart` (camera + lens + board handler + RouteAware + pad sheet try/finally)
- Modify: `app/lib/pages/root_page.dart` (`_pushFaded` motion param, `onViewQuestsFromBoard` wiring)
- Modify: `app/test/quest_board_test.dart` if it exists, else new `app/test/quest_board_press_test.dart`

All `flutter` commands run from `app/`.

---

### Task 1: `HapticService.bitPurr()`

**Files:**
- Modify: `app/lib/services/haptic_service.dart` (after `boostClimax`, ~line 240)
- Create: `app/test/haptic_purr_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HapticService.enabled = true;
    HapticService.nowProvider = DateTime.now;
  });
  tearDown(() {
    HapticService.enabled = true;
    HapticService.nowProvider = DateTime.now;
  });

  test('bitPurr fires once and drops a re-fire inside the envelope window',
      () async {
    var now = DateTime(2026, 7, 20, 10, 0, 0);
    HapticService.nowProvider = () => now;
    expect(await HapticService.instance.bitPurr(), isTrue);
    // 100ms later — still inside the ~300ms envelope: dropped (the motor must
    // never cancel-restart mid-purr).
    now = now.add(const Duration(milliseconds: 100));
    expect(await HapticService.instance.bitPurr(), isFalse);
    // Past the window: fires again.
    now = now.add(const Duration(milliseconds: 300));
    expect(await HapticService.instance.bitPurr(), isTrue);
  });

  test('bitPurr is a silent no-op when haptics are disabled', () async {
    HapticService.enabled = false;
    expect(await HapticService.instance.bitPurr(), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/haptic_purr_test.dart`
Expected: FAIL — `bitPurr` isn't defined.

- [ ] **Step 3: Implement `bitPurr` in `haptic_service.dart`** (insert after `boostClimax`, before `fire`)

```dart
  /// Minimum spacing between two purrs — slightly over the envelope length so
  /// a rapid re-tap can never cancel-restart the motor mid-envelope (restarts
  /// stutter; see [boostSwell]'s doc). Purely time-based via [nowProvider].
  static const Duration purrWindow = Duration(milliseconds: 300);

  DateTime? _purrStartedAt;

  /// BIT's press **purr** — the tactile twin of his cheer orbit: one soft,
  /// gap-free ~280ms rise-and-fall envelope (peak amplitude well under the
  /// reward tier — a creature response, not an event). Devices without
  /// amplitude control get a designed soft double-pulse ("b-brr"), NEVER a
  /// flat sustained buzz (the no-drone doctrine); devices without a raw
  /// vibrator fall back to the plain selection tick. Fires under reduced
  /// motion (action-tied haptic; haptics carry their own Settings toggle).
  ///
  /// Returns whether a purr was issued — a call inside [purrWindow] of the
  /// previous one is dropped (never restart the motor mid-envelope).
  Future<bool> bitPurr() async {
    if (!enabled) return false;
    final now = nowProvider();
    final started = _purrStartedAt;
    if (started != null && now.difference(started) < purrWindow) return false;
    _purrStartedAt = now;
    try {
      if (!await _ensureVibrator()) {
        await HapticFeedback.selectionClick();
        return true;
      }
      if (await _ensureAmplitudeControl()) {
        // Gap-free segments (pattern[i] paired with intensities[i]): a soft
        // rise to a low peak, decaying out — 280ms total.
        await Vibration.vibrate(
          pattern: const [0, 60, 60, 60, 60, 40],
          intensities: const [0, 50, 105, 80, 45, 20],
        );
      } else {
        // No amplitude control: two tiny pulses 60ms apart — reads as a soft
        // "b-brr", categorically not a drone.
        await Vibration.vibrate(pattern: const [0, 25, 60, 30]);
      }
    } catch (e) {
      debugPrint('HapticService: bitPurr failed: $e');
    }
    return true;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/haptic_purr_test.dart`
Expected: PASS (platform calls fail open in the test env — the guard logic is what's under test).

- [ ] **Step 5: Commit**

```bash
git add app/lib/services/haptic_service.dart app/test/haptic_purr_test.dart
git commit -m "feat(haptics): BIT purr - shaped ~280ms envelope with drone-safe fallbacks and in-flight guard"
```

---

### Task 2: Wire the purr into `BitCompanion`

**Files:**
- Modify: `app/lib/widgets/companion/bit_companion.dart:167-172` (`_onTap`)

- [ ] **Step 1: Replace the selection tick with the purr**

In `_onTap`, change:

```dart
    // BIT's press signature — a spoken "bi-di-bip?" (a character response, not
    // a UI click), beside a light poke haptic. A resting BIT stays silent.
    HapticService.instance.fireCoalesced(HapticIntent.selection);
    SfxService.instance.playUi(UiSound.bitChirp);
```

to:

```dart
    // BIT's press signature — a spoken "bi-di-bip?" beside a shaped haptic
    // PURR (the orbit's tactile twin — a creature response, not a UI click).
    // The purr carries its own in-flight guard, so tap-mashing never restarts
    // the motor mid-envelope. A resting BIT stays silent (guarded above).
    unawaited(HapticService.instance.bitPurr());
    SfxService.instance.playUi(UiSound.bitChirp);
```

`dart:async` is already imported (Timer); `unawaited` comes from it.

- [ ] **Step 2: Analyze + run the companion/room tests**

Run: `flutter analyze` then `flutter test test/ --plain-name BIT` (and `flutter test test/tap_haptic_coverage_test.dart`)
Expected: analyze 0 issues; no test pins the old coalesced call (if one does, update it to expect the purr path).

- [ ] **Step 3: Commit**

```bash
git add app/lib/widgets/companion/bit_companion.dart
git commit -m "feat(companion): BIT press fires the purr instead of a generic selection tick"
```

---

### Task 3: QuestBoard press-light

**Files:**
- Modify: `app/lib/widgets/room/quest_board.dart`
- Create: `app/test/quest_board_press_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/room/quest_board.dart';

void main() {
  Widget host({VoidCallback? onTap}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuestBoard(
              width: 65,
              height: 72,
              total: 5,
              filled: 3,
              ready: 0,
              onTap: onTap ?? () {},
            ),
          ),
        ),
      );

  QuestBoardPainter painterOf(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is QuestBoardPainter));
    return paint.painter! as QuestBoardPainter;
  }

  testWidgets('pointer-down lights the board; release relaxes it after a beat',
      (tester) async {
    await tester.pumpWidget(host());
    expect(painterOf(tester).press, isFalse);

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(QuestBoard)));
    await tester.pump();
    expect(painterOf(tester).press, isTrue,
        reason: 'the screen answers the finger immediately');

    await gesture.up();
    await tester.pump();
    // Held lit for a short legibility beat even on an instant tap...
    expect(painterOf(tester).press, isTrue);
    // ...then relaxes.
    await tester.pump(const Duration(milliseconds: 120));
    expect(painterOf(tester).press, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/quest_board_press_test.dart`
Expected: FAIL — `press` isn't defined on the painter.

- [ ] **Step 3: Implement**

(a) `QuestBoardPainter`: add the field + constructor param:

```dart
  QuestBoardPainter({
    required this.total,
    required this.filled,
    required this.ready,
    required this.glow,
    this.powered = true,
    this.lockGlow = 0.30,
    this.press = false,
  });
```
```dart
  /// True while a finger is down (plus a short linger) — the screen answers
  /// with one brightness step. Paint-state feedback only: the fixture never
  /// transforms (the room is one rigid depth plane).
  final bool press;
```

(b) In `paint`, add the wash. For the **powered** branch, immediately before `bolts();` at the end (after the claim edge-glow block):

```dart
    if (press) {
      // Press-light: the screen answers the finger — one washed brightness
      // step over the recessed screen (a CRT taking the touch), no geometry.
      rc(sx + 1, sy + 1, sw - 2, sh - 2, _qbCyHi.withValues(alpha: 0.10));
    }
```

For the **unpowered** branch, before its `bolts();`:

```dart
      if (press) {
        // Even sealed, the crate acknowledges the touch — the padlock blinks
        // one step brighter.
        cham(27, 33, 13, 10, bitGlow.withValues(alpha: (a + 0.25).clamp(0.0, 1.0)), 1);
      }
```

(c) `shouldRepaint`: add `|| old.press != press`.

(d) `_QuestBoardState`: press state + linger timer. Add imports `dart:async`. Add fields:

```dart
  bool _pressed = false;
  Timer? _pressLinger;
```

Add methods:

```dart
  void _setPressed(bool down) {
    _pressLinger?.cancel();
    if (down) {
      if (!_pressed) setState(() => _pressed = true);
      return;
    }
    // Hold the lit step ~90ms past release so an instant tap still reads.
    _pressLinger = Timer(const Duration(milliseconds: 90), () {
      if (mounted && _pressed) setState(() => _pressed = false);
    });
  }
```

In `dispose`: `_pressLinger?.cancel();` before `_ticker.dispose();`.

(e) Wire the painter + gestures in `build`: pass `press: _pressed` to `QuestBoardPainter`, and extend the tappable `GestureDetector`:

```dart
            child: GestureDetector(
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              onTap: () {
                HapticService.instance.selection(); // glance at the board
                widget.onTap!();
              },
              behavior: HitTestBehavior.opaque,
              child: ExcludeSemantics(child: content),
            ),
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/quest_board_press_test.dart` (and any existing quest_board tests)
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/widgets/room/quest_board.dart app/test/quest_board_press_test.dart
git commit -m "feat(room): quest board press-light - the screen answers pointer-down with a paint-level step"
```

---

### Task 4: Pad press-light in `room_scene.dart`

**Files:**
- Modify: `app/lib/widgets/room/room_scene.dart` (pad emitter block ~line 888-930; state fields near `_bitResting`; dispose ~line 440)

- [ ] **Step 1: Add state + setter** (near the other private state fields of the room scene State class)

```dart
  // Pad press-light: lit while a finger is down on the pad (+ a ~90ms linger
  // so an instant tap still reads). Paint-state only — the pad never moves.
  bool _padPressed = false;
  Timer? _padPressLinger;

  void _setPadPressed(bool down) {
    _padPressLinger?.cancel();
    if (down) {
      if (!_padPressed) setState(() => _padPressed = true);
      return;
    }
    _padPressLinger = Timer(const Duration(milliseconds: 90), () {
      if (mounted && _padPressed) setState(() => _padPressed = false);
    });
  }
```

(`dart:async` import: the file already uses timers — verify; add if missing.)
In `dispose()` add `_padPressLinger?.cancel();`.

- [ ] **Step 2: Wire gestures + overlay on the pad emitter**

The pad `GestureDetector` (~line 901) gains down/up/cancel, only when the pad is tappable:

```dart
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (adv != null || widget.onDormantPadTap != null)
                          ? (_) => _setPadPressed(true)
                          : null,
                      onTapUp: (_) => _setPadPressed(false),
                      onTapCancel: () => _setPadPressed(false),
                      onTap: adv != null
                          ? _onPadTap
                          : (widget.onDormantPadTap == null
                                ? null
                                : _onDormantPadTap),
```

And the pad sprite gets the light step — wrap the existing `Image.asset` (the `child:` of the pad's `AnimatedBuilder`) in a `Stack`:

```dart
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/room/bit_pad.png',
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.none,
                              isAntiAlias: false,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stack) =>
                                  BitPad(width: padW, height: padH),
                            ),
                            if (_padPressed)
                              const IgnorePointer(
                                child: ColoredBox(
                                  // One brightness step over the pad face —
                                  // the dock acknowledges the touch.
                                  color: Color(0x14E8E8FF),
                                ),
                              ),
                          ],
                        ),
```

**Token discipline:** `Color(0x14E8E8FF)` is a literal — express it as `kText.withValues(alpha: 0.08)` instead (drop the `const` on that subtree):

```dart
                            if (_padPressed)
                              IgnorePointer(
                                child: ColoredBox(
                                  color: kText.withValues(alpha: 0.08),
                                ),
                              ),
```

- [ ] **Step 3: Analyze + room tests**

Run: `flutter analyze` and `flutter test test/room_scene_golden_test.dart test/tap_haptic_coverage_test.dart`
Expected: analyze 0; goldens unchanged at rest (press state is transient); coverage test green (same GestureDetector, still marked/baseline).

- [ ] **Step 4: Commit**

```bash
git add app/lib/widgets/room/room_scene.dart
git commit -m "feat(room): pad press-light - one brightness step on pointer-down, paint only"
```

---

### Task 5: Room anchors + focal helpers + board-path callback

**Files:**
- Modify: `app/lib/widgets/room/room_scene.dart` (layout block ~line 673-700; widget params ~line 146)

- [ ] **Step 1: Extract the layout anchors into a static, reusable solver**

Add to `HomeRoomScene` (the public widget class):

```dart
  /// The room's load-bearing layout anchors, solved from the box size — the
  /// SAME math the scene's build uses (single source of truth; the build
  /// consumes this so the two can never drift). Public so the page-level
  /// camera can aim at fixtures without duplicating layout constants.
  static ({
    double kx,
    double cx,
    double padCenterY,
    double padTopY,
    double bitCenterY,
  }) anchorsFor(double width, double height) {
    final h = height < minHeight ? minHeight : height;
    final kx = (width / 340.0).clamp(0.85, 1.15);
    final cx = width * 0.5;
    final padH = 52 * kx;
    final padBitGap = 102 * kx;
    final maxPadCenterY = h - 92 * kx;
    final padCenterY =
        (h * 0.5 + padBitGap).clamp(padBitGap, maxPadCenterY);
    final padTopY = padCenterY - padH / 2;
    final emitterY = padTopY + 4 * kx;
    final bitCenterY = emitterY - 80 * kx;
    return (
      kx: kx,
      cx: cx,
      padCenterY: padCenterY,
      padTopY: padTopY,
      bitCenterY: bitCenterY,
    );
  }

  /// Focal alignment of the quest board's center (the camera's dolly target),
  /// in [Alignment] space for the given room box. Derived from the board's
  /// placement: left 40kx, top bitCenterY−16kx, 65×72kx.
  static Alignment boardFocal(Size size) {
    final a = anchorsFor(size.width, size.height);
    final cxPx = (40 + 65 / 2) * a.kx;
    final cyPx = a.bitCenterY - 16 * a.kx + (72 / 2) * a.kx;
    return Alignment(
      (cxPx / size.width) * 2 - 1,
      (cyPx / size.height) * 2 - 1,
    );
  }

  /// Focal alignment of the pad's center (the focus-push target).
  static Alignment padFocal(Size size) {
    final a = anchorsFor(size.width, size.height);
    return Alignment(0, (a.padCenterY / size.height) * 2 - 1);
  }
```

- [ ] **Step 2: Make build() consume the solver** — replace the inline lines in the `LayoutBuilder` (`final kx = …` through `final bitCenterY = …`, keeping `padW`, `bitSize`, `horizonY` etc.):

```dart
        final w = c.maxWidth;
        final anchors = HomeRoomScene.anchorsFor(w, h);
        final kx = anchors.kx;
        final cx = anchors.cx;
        final padW = 150 * kx, padH = 52 * kx;
        final bitSize = 92 * kx;
        final padCenterY = anchors.padCenterY;
        final horizonY = padCenterY;
        final horizonFrac = horizonY / h;
        final padTopY = anchors.padTopY;
        final padBottomY = padCenterY + padH / 2;
        final emitterY = padTopY + 4 * kx;
        final bitCenterY = anchors.bitCenterY;
```

(The `padBitGap`/`maxPadCenterY` locals move into the solver; delete the old comment block or keep it above the solver.)

- [ ] **Step 3: Add the board-path callback param** to `HomeRoomScene`:

```dart
    this.onViewQuestsFromBoard,
```
```dart
  /// Optional dedicated handler for the WALL BOARD's tap (the camera-dolly
  /// path). Falls back to [onViewQuests] when null, so standalone/golden
  /// hosts are unaffected. BIT's claimable bubble line always uses
  /// [onViewQuests] — the camera moves only for the fixture itself.
  final VoidCallback? onViewQuestsFromBoard;
```

In the QuestBoard `onTap` closure (~line 833), route the final call through it:

```dart
                    onTap: widget.onViewQuests == null
                        ? null
                        : () {
                            HapticService.instance.fireCoalesced(
                              HapticIntent.selection,
                            );
                            if (widget.questBoardPowered) {
                              SfxService.instance.playUi(UiSound.boardTap);
                            }
                            (widget.onViewQuestsFromBoard ??
                                    widget.onViewQuests!)
                                .call();
                          },
```

- [ ] **Step 4: Test the anchors** — append to `app/test/quest_board_press_test.dart` (same feature area) or a small new group in it:

```dart
  test('focal helpers track the room layout math', () {
    const size = Size(340, 400);
    final a = HomeRoomScene.anchorsFor(size.width, size.height);
    expect(a.kx, 1.0);
    // padCenterY = clamp(200 + 102, 102, 400-92) = 302 → clamped to 308? No:
    // maxPadCenterY = 308, so 302 stands.
    expect(a.padCenterY, 302);
    expect(a.padTopY, 276);
    expect(a.bitCenterY, 200);
    final board = HomeRoomScene.boardFocal(size);
    // board center x = 72.5 → alignment (72.5/340)*2-1 ≈ -0.5735
    expect(board.x, closeTo(-0.5735, 0.001));
    // board center y = 200-16+36 = 220 → (220/400)*2-1 = 0.1
    expect(board.y, closeTo(0.1, 0.001));
    final pad = HomeRoomScene.padFocal(size);
    expect(pad.x, 0);
    expect(pad.y, closeTo(0.51, 0.001));
  });
```

(Import `room_scene.dart`. If the arithmetic comment above disagrees with the run, trust the run — the point is the helpers equal the build math, pinned by exact numbers once observed.)

- [ ] **Step 5: Run + commit**

Run: `flutter test test/quest_board_press_test.dart test/room_scene_golden_test.dart` → PASS (goldens unchanged — same math, relocated).

```bash
git add app/lib/widgets/room/room_scene.dart app/test/quest_board_press_test.dart
git commit -m "refactor(room): extract layout anchors + focal helpers; dedicated board-tap callback"
```

---

### Task 6: `RoomCamera` + `RoomZoomLens`

**Files:**
- Create: `app/lib/widgets/room/room_zoom_lens.dart`
- Create: `app/test/room_zoom_lens_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/room/room_zoom_lens.dart';

void main() {
  testWidgets('identity camera adds no transform layer over the child',
      (tester) async {
    final camera = RoomCamera();
    await tester.pumpWidget(RoomZoomLens(
      camera: camera,
      child: const SizedBox(width: 10, height: 10),
    ));
    expect(
      find.descendant(
          of: find.byType(RoomZoomLens), matching: find.byType(Transform)),
      findsNothing,
      reason: 'scale 1 must paint the child untouched (goldens/reduced-motion)',
    );
  });

  testWidgets('an engaged camera scales around its focal point, clipped',
      (tester) async {
    final camera = RoomCamera();
    await tester.pumpWidget(RoomZoomLens(
      camera: camera,
      child: const SizedBox(width: 10, height: 10),
    ));
    camera.set(1.12, const Alignment(-0.5, 0.1));
    await tester.pump();
    final transform = tester.widget<Transform>(find.descendant(
        of: find.byType(RoomZoomLens), matching: find.byType(Transform)));
    expect(transform.alignment, const Alignment(-0.5, 0.1));
    expect(
      find.descendant(
          of: find.byType(RoomZoomLens), matching: find.byType(ClipRect)),
      findsOneWidget,
      reason: 'the zoomed layer must not bleed outside the room box',
    );
    // Disengage → identity again.
    camera.reset();
    await tester.pump();
    expect(
      find.descendant(
          of: find.byType(RoomZoomLens), matching: find.byType(Transform)),
      findsNothing,
    );
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/room_zoom_lens_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement `room_zoom_lens.dart`**

```dart
import 'package:flutter/material.dart';

/// The home room's camera: a scale + focal alignment the page animates.
/// Identity is `scale == 1` — the lens then paints its child untouched, so
/// goldens, standalone hosts, and reduced motion are byte-identical.
class RoomCamera extends ChangeNotifier {
  double _scale = 1.0;
  Alignment _focal = Alignment.center;

  double get scale => _scale;
  Alignment get focal => _focal;

  void set(double scale, Alignment focal) {
    if (scale == _scale && focal == _focal) return;
    _scale = scale;
    _focal = focal;
    notifyListeners();
  }

  void reset() => set(1.0, _focal);
}

/// Scales the room's **rendered raster layer** around [RoomCamera.focal] — a
/// photographic camera move (the compositor samples the already-painted
/// layer), never a geometry re-render of crisp sprites at fractional scale
/// (the pixel-shimmer doctrine). The [RepaintBoundary] is what makes the
/// child a layer; [FilterQuality.low] gives the deliberate soft "camera"
/// sampling in motion. At `scale <= 1` the child renders with no transform
/// at all.
class RoomZoomLens extends StatelessWidget {
  const RoomZoomLens({super.key, required this.camera, required this.child});

  final RoomCamera camera;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inner = RepaintBoundary(child: child);
    return ListenableBuilder(
      listenable: camera,
      child: inner,
      builder: (context, c) {
        if (camera.scale <= 1.0) return c!;
        return ClipRect(
          child: Transform.scale(
            scale: camera.scale,
            alignment: camera.focal,
            filterQuality: FilterQuality.low,
            child: c,
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run tests** → PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/widgets/room/room_zoom_lens.dart app/test/room_zoom_lens_test.dart
git commit -m "feat(room): RoomCamera + RoomZoomLens - raster-layer camera zoom, identity at rest"
```

---

### Task 7: `ArcadeRouteMotion.dolly`

**Files:**
- Modify: `app/lib/widgets/arcade_route.dart`
- Create: `app/test/arcade_route_dolly_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/arcade_route.dart';

void main() {
  testWidgets('dolly holds the incoming page back for the travel beat',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      home: const Scaffold(body: Text('HOME')),
    ));
    navKey.currentState!.push(arcadeRoute(
      (_) => const Scaffold(body: Text('QUESTS')),
      motion: ArcadeRouteMotion.dolly,
    ));
    // 80ms in (t≈0.29 < the 0.42 reveal gate): the incoming page must be
    // fully transparent — the room's dolly owns the frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final fade = tester.widget<FadeTransition>(find
        .ancestor(of: find.text('QUESTS'), matching: find.byType(FadeTransition))
        .first);
    expect(fade.opacity.value, 0.0,
        reason: 'travel beat: nothing may cover the dollying room yet');
    // At the end the page is fully in.
    await tester.pump(const Duration(milliseconds: 220));
    final fadeEnd = tester.widget<FadeTransition>(find
        .ancestor(of: find.text('QUESTS'), matching: find.byType(FadeTransition))
        .first);
    expect(fadeEnd.opacity.value, 1.0);
  });

  testWidgets('dolly under reduced motion is the plain fade', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      home: const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Text('HOME')),
      ),
    ));
    navKey.currentState!.push(arcadeRoute(
      (_) => const Scaffold(body: Text('QUESTS')),
      motion: ArcadeRouteMotion.dolly,
    ));
    await tester.pumpAndSettle();
    expect(find.text('QUESTS'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/arcade_route_dolly_test.dart`
Expected: FAIL — `ArcadeRouteMotion.dolly` doesn't exist.

- [ ] **Step 3: Implement.** In `arcade_route.dart`:

(a) enum: `enum ArcadeRouteMotion { panel, flow, reveal, fade, powerOn, dolly }`

(b) spec (add to `_specFor`):

```dart
    // The quest-board camera dolly's receive: the incoming page holds back
    // through the travel beat (the Home room visibly dollies alone under a
    // fully transparent route), then the CRT-signal bands sweep it in over
    // the zoomed room. Reverse is the pop settle window — the page clears
    // out early so the room's pull-back owns the tail.
    ArcadeRouteMotion.dolly => const _CrtRouteSpec(
      forward: Duration(milliseconds: 280),
      reverse: Duration(milliseconds: 190),
      accent: kCyan,
      bandCount: 18,
      tearCount: 3,
      sweepStrength: 0.26,
      edgeStrength: 0.20,
      revealGate: 0.42,
    ),
```

(c) `_CrtRouteSpec` gains `final double revealGate;` (constructor param, default `0`).

(d) route builder: in `arcadeRoute`'s `transitionsBuilder`, before the CRT branch:

```dart
      if (motion == ArcadeRouteMotion.dolly) {
        return _dollyReveal(animation, child, spec);
      }
```

(e) the composition:

```dart
/// The dolly receive: opacity 0 through the travel beat (`revealGate`), then
/// the standard CRT-signal composition runs on the remapped remainder.
Widget _dollyReveal(
  Animation<double> animation,
  Widget child,
  _CrtRouteSpec spec,
) {
  final gated = CurvedAnimation(
    parent: animation,
    curve: Interval(spec.revealGate, 1.0),
  );
  return FadeTransition(
    opacity: Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: animation,
        // A hard gate, then a fast ramp: invisible until the gate, fully
        // present shortly after (the bands carry the texture of the reveal).
        curve: Interval(spec.revealGate, spec.revealGate + 0.18),
      ),
    ),
    child: _crtSignalTransition(gated, child, spec),
  );
}
```

- [ ] **Step 4: Run tests** → PASS (adjust the 80ms/opacity assertion only if the Interval math genuinely differs — the contract is: opacity exactly 0 before the gate, 1 at the end).

- [ ] **Step 5: Commit**

```bash
git add app/lib/widgets/arcade_route.dart app/test/arcade_route_dolly_test.dart
git commit -m "feat(routes): ArcadeRouteMotion.dolly - travel-beat hold-back then CRT reveal"
```

---

### Task 8: RootPage wiring

**Files:**
- Modify: `app/lib/pages/root_page.dart` (`_pushFaded` ~line 691; `_pushQuests` ~line 667; HomePage construction ~line 746)

- [ ] **Step 1: Motion-parameterize the shared push**

```dart
  Future<void> _pushFaded(
    WidgetBuilder builder, {
    ArcadeRouteMotion motion = ArcadeRouteMotion.fade,
  }) async {
    await Navigator.of(
      context,
    ).push(arcadeRoute(builder, motion: motion));
    if (!mounted) return;
    _reloadQuestAwarePages();
    _showExpiredPausedSummaryIfNeeded();
    _showIdleRevealIfNeeded();
    // A pushed page can earn a gate (a quest claim mints the first gems) —
    // re-evaluate on every return so the unlock lands now, not next workout.
    unawaited(_evaluateGates());
  }
```

- [ ] **Step 2: Board-path quest push + HomePage wiring**

```dart
  void _pushQuests({ArcadeRouteMotion motion = ArcadeRouteMotion.fade}) {
    if (!FeatureGateService.isUnlockedSync(FeatureGate.quests)) {
      showFeatureLockedNotice(context, FeatureGate.quests);
      return;
    }
    _pushFaded(
      (_) => QuestsPage(onQuestChanged: _reloadQuestAwarePages),
      motion: motion,
    );
  }
```

HomePage construction gains:

```dart
      onViewQuestsFromBoard: () =>
          _pushQuests(motion: ArcadeRouteMotion.dolly),
```

(Existing `onViewQuests: _pushQuests` still compiles — it becomes a closure `() => _pushQuests()` if the tear-off no longer matches `VoidCallback`; with the default param a tear-off is still assignable in Dart? It is NOT — change the call site to `onViewQuests: () => _pushQuests(),`.) Also update the feature-gate switch's `_pushQuests();` call (line ~249) — unchanged semantics with the default.

- [ ] **Step 3: Analyze + commit**

Run: `flutter analyze` → 0 issues.

```bash
git add app/lib/pages/root_page.dart
git commit -m "feat(shell): board-path quest push rides the dolly route motion"
```

---

### Task 9: HomePage — camera driver, lens, board gate, pop settle, pad push

**Files:**
- Modify: `app/lib/pages/home.dart` (imports; State fields ~line 240; initState/dispose ~line 250/353; `_onPadDispatch` ~line 740-776; room hosting ~line 2290; new handlers)
- Modify: `app/lib/pages/home.dart` — `HomePage` widget params (~line 146): add `this.onViewQuestsFromBoard,` + `final VoidCallback? onViewQuestsFromBoard;`

- [ ] **Step 1: Imports + fields**

Imports: `../widgets/room/room_zoom_lens.dart`; `../widgets/arcade_route.dart` is NOT needed here; ensure `../main.dart` (or wherever `appRouteObserver` lives — grep `appRouteObserver` and import its file) is imported.

State class: add `with RouteAware` to the existing mixin list (it already has TickerProviderStateMixin via `_HomePageState extends State<HomePage> with ...` — verify and extend).

```dart
  // ── Room camera (board dolly / pad focus-push) ────────────────────────────
  // Doctrine: stateless while covered — the camera engages only inside the
  // two transition windows and any non-standard path finds it at identity.
  final RoomCamera _roomCamera = RoomCamera();
  late final AnimationController _cameraCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 190),
  )..addListener(_driveCamera);
  double _cameraTarget = 1.0;
  Alignment _cameraFocal = Alignment.center;
  bool _pendingBoardReturn = false;
  bool _padFocusActive = false;
  Timer? _coverReset;
  final GlobalKey _roomKey = GlobalKey();

  void _driveCamera() {
    final t = Curves.easeOutCubic.transform(_cameraCtrl.value);
    _roomCamera.set(1.0 + (_cameraTarget - 1.0) * t, _cameraFocal);
  }

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  Size? get _roomBoxSize {
    final box = _roomKey.currentContext?.findRenderObject() as RenderBox?;
    return (box?.hasSize ?? false) ? box!.size : null;
  }
```

- [ ] **Step 2: RouteAware plumbing**

In `didChangeDependencies` (add the subscription; keep idempotent):

```dart
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
```

In `dispose`: `appRouteObserver.unsubscribe(this); _coverReset?.cancel(); _cameraCtrl.dispose(); _roomCamera.dispose();`

RouteAware overrides:

```dart
  @override
  void didPushNext() {
    // A route now covers the shell. Once it is fully opaque the camera resets
    // silently — no transform is ever HELD as route state (any non-standard
    // return finds the room at identity).
    _coverReset?.cancel();
    _coverReset = Timer(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      _cameraCtrl.stop();
      _cameraCtrl.value = 0;
    });
  }

  @override
  void didPopNext() {
    _coverReset?.cancel();
    if (!_pendingBoardReturn) return;
    _pendingBoardReturn = false;
    if (_reduceMotion) return;
    final size = _roomBoxSize;
    if (size == null) return;
    // Set the settle pose while the popping route still covers us, then ease
    // home as its 190ms reverse fade plays — the pull-back half of the dolly.
    _cameraTarget = 1.06;
    _cameraFocal = HomeRoomScene.boardFocal(size);
    _cameraCtrl.value = 1.0;
    _cameraCtrl.reverse();
  }
```

- [ ] **Step 3: The board handler** (near `_onPadDispatch`):

```dart
  /// The wall board's tap: authorization FIRST (a locked board shows the
  /// notice with zero camera), then the dolly + the push start in the same
  /// tick — the route's travel-beat hold-back guarantees the zoom reads.
  void _onBoardTap() {
    final fromBoard = widget.onViewQuestsFromBoard;
    if (!_questsUnlocked || fromBoard == null) {
      widget.onViewQuests?.call();
      return;
    }
    if (!_reduceMotion && !_padFocusActive) {
      final size = _roomBoxSize;
      if (size != null) {
        _pendingBoardReturn = true;
        _cameraTarget = 1.12;
        _cameraFocal = HomeRoomScene.boardFocal(size);
        _cameraCtrl.duration = const Duration(milliseconds: 280);
        _cameraCtrl.forward(from: 0);
      }
    }
    fromBoard();
  }
```

- [ ] **Step 4: Pad focus-push.** In `_onPadDispatch`, replace the tail (the `showExpeditionDispatchSheet(...)` call) with an engage/await/finally:

```dart
    final defaultRoute =
        state.standingOrderRouteId ??
        (_characterClass != null
            ? defaultRouteForClass(_characterClass!).id
            : adventureRoutes.first.id);
    if (_padFocusActive) return;
    _padFocusActive = true;
    final size = _roomBoxSize;
    final engage = !_reduceMotion && size != null;
    if (engage) {
      _cameraTarget = 1.05;
      _cameraFocal = HomeRoomScene.padFocal(size!);
      _cameraCtrl.duration = const Duration(milliseconds: 180);
      _cameraCtrl.forward(from: 0);
    }
    try {
      await showExpeditionDispatchSheet(
        context,
        charges: ui.charges,
        vit: _vitality,
        stats: _combatStats,
        selectedRouteId: defaultRoute,
        onSend: _dispatchExpedition,
      );
    } finally {
      _padFocusActive = false;
      if (engage && mounted) {
        _cameraCtrl.reverse(); // every dismissal path lands here
      }
    }
```

`_onPadDispatch` becomes `Future<void> _onPadDispatch() async` (verify the current signature — it's a sync `void` today; the room's callback accepts a `VoidCallback`, an async function still satisfies it). **Check `showExpeditionDispatchSheet`'s return type** (`widgets/room/expedition_dispatch_sheet.dart`) — if it doesn't return the sheet's `Future`, change it to `return showModalBottomSheet(...)` so the await is real.

- [ ] **Step 5: Mount the lens + key + callbacks** in build (~line 2290):

```dart
            SliverToBoxAdapter(
              child: RoomZoomLens(
                camera: _roomCamera,
                child: HomeRoomScene(
                  key: _roomKey,
                  height: roomHeight,
                  ...(existing params unchanged)...
                  onViewQuests: widget.onViewQuests,
                  onViewQuestsFromBoard: _onBoardTap,
                  ...(rest unchanged)...
                ),
              ),
            ),
```

- [ ] **Step 6: Contract test** — extend `app/test/recovery_insight_sheet_test.dart`-style seeding in a new `app/test/home_room_camera_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/pages/home.dart';
import 'package:workout_track/widgets/room/quest_board.dart';

void main() {
  testWidgets('locked board tap: notice path, zero camera', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var plainCalls = 0;
    var boardCalls = 0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        onViewQuests: () => plainCalls++,
        onViewQuestsFromBoard: () => boardCalls++,
      ),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byType(QuestBoard), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 60));
    expect(plainCalls, 1, reason: 'locked → the notice path (plain callback)');
    expect(boardCalls, 0);
    expect(
      find.descendant(
          of: find.byType(HomePage), matching: find.byType(Transform).first),
      findsNothing,
      reason: 'a locked tap must never engage the camera',
    );
  });
}
```

(A fresh prefs store = no unlocks = board locked. If `Transform`s exist elsewhere in Home's tree, tighten the finder to a descendant of `RoomZoomLens` instead — the lens-scoped absence is the real contract; mirror the lens test's finder.)

- [ ] **Step 7: Run** `flutter analyze` + the new test + `flutter test test/home_page_test.dart` (if exists) → green.

- [ ] **Step 8: Commit**

```bash
git add app/lib/pages/home.dart app/test/home_room_camera_test.dart
git commit -m "feat(home): room camera - board dolly + pop settle + pad focus-push, stateless while covered"
```

---

### Task 10: Verification pass

- [ ] **Step 1:** `flutter analyze` → 0 issues.
- [ ] **Step 2:** Full `flutter test` → only the 7 pre-existing env-sensitive failures (baseline: finish_reveal, home_level_strip golden, profile_hero_card golden, room_scene large-text golden + 3 more; compare against the stashed A/B baseline list).
- [ ] **Step 3:** Playwright frame captures on the web build (`flutter run -d web-server --web-port 8087 --dart-define=SEED_DEMO=intermediate`): screenshot sequence through a board tap (expect the room visibly enlarging toward the board before the quest page appears; on back, the settle), a pad tap (lean + sheet), and BIT taps. Save to `design/screenshots/room-micro-interactions/`.
- [ ] **Step 4:** ironbit-design finish-time audit greps over changed files (`Color(0x`, `.withOpacity(`, `Colors.`, `Icons.` non-sharp, raw `GestureDetector` without wrapper/marker) — resolve every hit; `flutter test test/tap_haptic_coverage_test.dart` green.
- [ ] **Step 5:** Docs: add the feature to `docs/PRD.md` (Home/room section) + the CLAUDE.md Companion/room row (one sentence each: camera grammar + purr). Update `.claude/skills/ironbit-design/learnings.md` ONLY if a generalizable lesson emerged (state "No new design learning" otherwise).
- [ ] **Step 6:** Commit docs; state the on-device shimmer check as a named verification gap for user sign-off (no Android device in this env).
