# Expedition dispatch returns home + camera scroll-focus — design

**Date:** 2026-07-22 · **Status:** implemented (user pre-approved; Codex adversarial review run —
needs-attention, 3 findings, all folded in, see the resolution section) · **Surfaces:**
`adventure_page.dart`, `home.dart`, `root_page.dart`, `adventure_service.dart` (one signal),
`room_scene.dart` (read-only geometry reuse)

## The user's three ideas, evaluated

1. **"Expedition card should navigate to the map."** Already shipped: `AdventureCard.onTap →
   _openAdventure → AdventurePage` (and the section's `MAP >` link does the same). **No change.**
2. **"Starting an expedition returns to Home so the fly-up always plays."** Accepted, with
   mechanics hardened. Today the room's 2000ms launch send-off (`_playLaunch`, fired on a fresh
   `idle→out` flip in `didUpdateWidget`) is the *designed* dispatch payoff — but a map dispatch
   strands it: the user stays on the map (weak feedback: tile dims + walker), and the launch fires
   only on the eventual manual return. Worse, the map is usually entered from the EXPEDITION
   section **below the fold**, so on return the room is scrolled off-screen — the launch can play
   entirely unseen, and if the room sliver was unmounted (beyond cache extent) the flip is a cold
   mount and **no launch ever plays**. The fix makes the room launch the single dispatch payoff on
   every path.
3. **"Scroll the pad/board to vertical center before zooming."** Accepted as intent, adjusted in
   sequencing. Research (insights.md 2026-07-20, IJHCS click-response fluency — load-bearing in the
   shipped dolly): motion must START on tap; a serial scroll-then-zoom adds dead latency. So the
   scroll runs **concurrently** with the existing camera move, same duration and curve — one
   composite camera gesture ("track + push"), total time-to-page unchanged. The user's underlying
   observation is real and sharp: the pad sits low enough that the dispatch sheet **covers it**,
   so the current 1.05 focus-push is mostly invisible. Centering is what makes the push readable.

## Change B — dispatch always returns home, launch always seen

### B1. Map auto-return
`AdventurePage._dispatch`: on success (`expedition != null`), keep `_busy` latched and
`Navigator.of(context).popUntil((r) => r.isFirst)` instead of staying on the page. `popUntil`
(not a single `pop`) collapses every stacking, including the nested case
report → CHANGE ORDERS (`pushReplacement`) → new map over a stale map. On failure: current
notice + stay (unchanged). No artificial delay — the pop starts on tap-response (fluency), and the
room launch is the payoff.

### B2. Shell lands on the Home tab
A dispatch can originate with the shell on a non-Home tab (only via the unlock-ceremony
`GO → _pushAdventure` path). One-shot signal: `AdventureService.dispatchTick` — a
`static final ValueNotifier<int>` bumped inside `dispatchExpedition` on success (service is the
single dispatch authority; both entry points inherit it). `RootPage` listens: on bump →
`goTo(AppDestination.home)`. The bump happens while the map still covers the shell, so the tab
switch is a silent snap under cover (existing doctrine). Pad-sheet dispatches bump too —
`goTo(home)` is a no-op there.

### B3. Home stages the launch
`HomePage._loadData` gains flip detection: previous `_adventureState` resolved `idle` (or had no
pending) and the fresh state is `out` with a new pending id → a live dispatch just happened.
When detected, **before** committing the new state:
- If `_engagement == padSheet` → skip (B4 owns the pad flow's motion).
- Else if the scroll offset > ~1px → `jumpTo(0)`, then wait one frame (`endOfFrame`) **so a
  room sliver that was unmounted beyond cache extent remounts with the OLD (idle) state**, then
  commit the new state → `didUpdateWidget` sees the genuine flip → launch plays. The jump is
  covered by the popping route's reverse fade (`.then` fires at pop start), so the snap never
  shows — the same silent-snap-under-cover contract the board dolly uses.
Cold opens are untouched: first load has `_adventureState == null` → no flip → no launch
(existing "cold mid-expedition reopen never launches" doctrine preserved).

### B4. Pad-sheet dispatch stages the launch too
With Change C the pad flow scrolls down to center the pad; the launch's exit-pop is near the room's
top, which would be clipped. `_onPadDispatch`'s `finally`: if this sheet actually dispatched
(a `_dispatchedThisSheet` flag set by `_dispatchExpedition`) → animate scroll to **0** (full
stage for the ascent) instead of restoring the pre-engage offset. Camera reverse unchanged.

### Reduced motion
Auto-return + tab switch + scroll placement still happen (they are navigation/state, and the jump
is under cover); the launch animation itself stays motion-gated as today (the room simply shows
the away state).

## Change C — concurrent scroll-focus for pad + board

Helper on `HomePageState`:
`void _focusScroll({required double fixtureRoomY, required double viewportFraction, required Duration duration})`
— resolves the fixture's current global Y via the room's RenderBox, computes
`target = clamp(offset + (fixtureScreenY − viewportTop − viewportFraction·viewportH), 0, maxExtent)`,
and `animateTo(target, duration, Curves.easeOutCubic)`. Skipped when reduce-motion, no clients, or
no room box — the exact pre-feature behavior (WCAG 2.3.3 fallback contract).

- **Board** (`_onBoardTap`) — **SERIAL, user-directed 2026-07-23** (the concurrent scroll+dolly
  shipped first and read as one rushed move on device): when the board needs centering, the
  scroll **tracks first** (starting on tap, so the response is still instant — the fluency
  principle is preserved by the track itself; `kBoardTrackMs` 340ms, ease-in-out so it reads
  deliberate), and only on its completion do the route push + 1.12 dolly fire as the original
  same-tick beat (the travel-beat hold-back runs against the dolly unchanged). No scroll needed
  (the common at-the-top case) → the original same-tick push+dolly, zero added latency. Re-taps
  during the track are ignored (`_boardFocusInFlight`); authorization still resolves before any
  camera (locked → notice, no motion). Return (`didPopNext` settle): scroll is **left where it
  is** — the board push is navigation ("you went to the board, you come back at the board"); the
  settle pose is room-relative so it stays valid.
- **Pad** (`_onPadDispatch`, on engage): record the pre-engage offset; pad center
  (`anchorsFor().padCenterY`) → **0.44** of the viewport (optical center of the strip that stays
  visible above the dispatch sheet; a true 0.5 puts the pad at the sheet's top edge on small
  viewports), duration 180ms matching the focus-push. On dismissal without dispatch: animate back
  to the pre-engage offset alongside the camera reverse (the pad sheet is an overlay, not
  navigation — the camera move fully reverses). With dispatch: B4.
- Clamping means "as centered as the scroll extents allow" — at offset 0 the board simply stays
  where it is; a no-op target produces no visible motion.

## Codex adversarial-review resolutions (verdict: needs-attention → all folded)

- **F1 (high) — the pad launch could start under the sheet on a mis-staged room.** Resolved by
  making the pad dispatch ONE ordered sequence inside the awaited `onSend`
  (`_dispatchExpedition`): dispatch → glide the scroll home (awaited, 180ms; skipped under
  reduced motion where no launch plays) → only then `_loadData` commits the `out` state → the
  mounted, staged room takes the flip and the sheet falls away into the ascent. The dismissal
  `finally` skips its scroll-restore when the sheet dispatched (`_dispatchedFromSheet`), so the
  two owners never fight.
- **F2 (high) — re-entrant `_loadData` could consume or double-stage the only idle→out edge.**
  Resolved by serializing every home load through a `_loadChain` future (failed loads keep the
  chain alive). The flip-edge compare (committed `_adventureState.pending == null` → fresh `out`
  with a pending) is now race-free against the storage-change listener and push-return `.then`.
- **F3 (medium) — `popUntil(isFirst)` over-collapse / `.then`-at-pop-start coupling.** Accepted
  with evidence: `popUntil`-to-root is the app's established return idiom (workout summary,
  active-workout exits), every route above the shell on a dispatch path is expedition-owned, and
  the `.then`-fires-at-pop-start timing is *wanted* (the scroll snap hides under the popping
  route's cover — the same silent-snap contract the board dolly uses). F2's serialization removes
  the callback-ordering dependency Codex flagged.
- Codex's "single dispatch-completion state machine" was judged over-scaled: the three resolutions
  above give one owner per beat with ~30 lines, no new machinery beyond a static `ValueNotifier`.

## Not doing
- No scroll restore on board return (navigation semantics; also the restore window is only
  partially covered by the 190ms reverse fade — a visible snap risk for zero gain).
- No new sounds/haptics — every beat keeps its current single owner (dispatch audio stays with
  the room's send-off whoosh, which this change finally makes audible on the map path).
- No change to `AdventureCard` (idea 1 already true) or to the report/collect flows.

## Testing
- `adventure_page` widget test: successful dispatch pops to root; failed dispatch stays.
- Home flip-detection unit/widget test: scrolled-down Home + fresh `idle→out` reload →
  offset snaps to 0 and the room receives the flip while mounted (launch controller animates);
  cold first load with `out` → no launch.
- `home_room_camera` extensions: board tap animates scroll toward the board target concurrently
  with the dolly; pad engage scrolls toward 0.44 and dismissal restores; reduce-motion skips both.
- Existing camera/board/lens tests must stay green (bounded pumps — the room hosts tickers).
