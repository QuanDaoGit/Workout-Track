# Adventure v3 — stage-select UI, image body sprite, ongoing polish (shipped 2026-06-13)

Presentation-only evolution of the Adventure screen. The v2 service/state machine (charges,
`dispatchExpedition`, `returnsAt`, settle/peek/acknowledge, idempotent ledger) is unchanged. Built
through `/deep-feature`; Codex reviewed the opinion (6 findings) and the plan (4 more) — all folded
in.

## What changed
- **Home card** (`adventure_card.dart`): generic emblem (`emblem_adventure_mode.png`) + "No
  expedition is going on" when idle; the crafted route emblem + a subtle cycling-ellipsis "ONGOING
  EXPEDITION…" when out; "RETURNED · tap to collect" when back. The ellipsis is the only motion and
  freezes under reduced motion (a marquee would be a usability anti-pattern).
- **Adventure page** (`adventure_page.dart`): a console **stage-select** — three full framed route
  **backdrops** replace the list rows. Tap to arm (the tile darkens, comes alive without a sprite,
  and shows its payout + duration; a "?" reveals the VIT→multiplier breakdown). **GO ON ADVENTURE**
  spends the charge; the chosen route brightens with the walking sprite while the other two darken +
  lock. Per-state contract enforced by `_TileRole` (selectable / armed / activeOut / activeReturned /
  locked). Cancel via re-tap or ✕.
- **Body sprite** (`pixel_walker.dart`): the code-drawn body is replaced by the generic 4-frame
  image strip (`assets/adventure/body/frames/walk_0..3.png`, 24×42) with the user's procedural face
  overlaid at the rig head anchor. errorBuilder falls back to the old code body.
- **Diorama** (`route_diorama.dart`): `showWalker` (decoupled from `animate`), `framed` (bezel +
  corner ticks), `darkened` (scrim); 4-frame walk synced to ground scroll.

## Codex findings → resolutions
- Shared `adventureUiStateOf(state, now, currentWeekIso)` view-model ({phase, charges, weeklyCapped,
  canDispatch}) consumed by BOTH card and page — no returned-window divergence, blocked states don't
  collapse to idle.
- **Single animation owner:** exactly one diorama animates (armed or active). The lifecycle hook is
  `didUpdateWidget` (a prop flip won't fire `didChangeDependencies`), so re-arm A→B and armed→out
  stop the old controller atomically. Tested.
- Payout + duration stay visible on the armed route; only the breakdown hides behind "?" (keeps the
  v2 VIT-legibility fix).
- Reduced motion vs semantic time: visuals freeze, but a coarse logic `Timer` still recomputes the
  phase so out→returned advances and COLLECT appears.
- Assets: declared `body/` + `body/frames/`; per-frame + generic-emblem errorBuilder; manifest test
  enumerates them.

## Tests
`adventure_phase_test.dart` (pure predicate), `adventure_page_widget_test.dart` (6 matrix states,
single-animation-owner, GO gating, cancel, reduced motion), `adventure_assets_test.dart` (+body
frames + generic emblem). Service tests unchanged.

## Out of scope
Finds collection shelf, 4th route, area restructure. No service/persistence change.
