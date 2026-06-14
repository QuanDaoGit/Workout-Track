# App IA restructure — 4-places + center-Train model (decision record + Phase 1, 2026-06-13)

**Status:** model decided; **Phase 1 "the base" shipped** (the nav shell + re-homing). Per-area
"scene" redesigns are deferred to later phases. No mechanics/persistence change.

## Why
The flat 5-tab shell (`Home · Workout · Quests · Guild · Profile`) treated every surface as a peer
and gave the product no sense of *place*. We reorganized into **four browseable destinations plus one
center action**, so the navigation itself reinforces the soul-doctrine hooks — a place you *return*
to, a place you *equip/own*, a place you *belong*, a place you *tinker with who you are*, and the
*verb* (train) elevated at the center.

## The model
Bottom nav, 5 slots: **Home · Inventory · ⟨TRAIN⟩ · Guild · Labs**.

| Slot | Kind | Hook | Holds |
|---|---|---|---|
| **Home** | destination | ritual return + anticipation | hub + Quests (push) + Adventure (push) + workout **history/calendar** (push) |
| **Inventory** | destination | collection / cosmetics | loot inventory + Shop; **loot badge lives here** |
| **TRAIN** | center action | competence (real training) | confirm → `StartWorkoutPage`; resume if a session is live |
| **Guild** | destination | belonging / social | the guild simulation (unchanged) |
| **Labs** | destination | identity attachment | identity, stats, settings + Programs/Exercise **library** (push) |

Train is **not a page** — it is the primary verb. Tapping it on a cold start opens a "Start training?"
confirm then the existing start flow; tapping it while a session is live **resumes** (no confirm). The
old persistent active-workout dock is gone — the **center button pulses** while a session is live and
is the resume affordance.

## Phase 1 "the base" — what shipped (structural only)
Built via `/deep-feature`; Codex reviewed the design → REVISE (6 findings, all folded in).
- **Shell rewrite** ([root_page.dart](../../../lib/pages/root_page.dart)): custom bottom bar (4 corner
  `_NavItem`s + elevated `_TrainNavButton`); `enum AppDestination { home, inventory, guild, labs }` +
  `goTo()` (semantic, not index-based — Codex #3); the dock removed; pulse on live (frozen under
  reduced motion); loot badge relocated to Inventory (Codex #7); pushed surfaces refresh + re-arm the
  idle/expired reveal on pop via `_pushFaded` (Codex #4, #5); Train state machine re-reads the ongoing
  session at tap time (Codex #2). Built-in `Icons.*_sharp` / already-declared pixel icons only — no
  new mandatory assets (Codex #6).
- **Inventory promoted** to a destination (reuses [inventory_page.dart](../../../lib/pages/inventory_page.dart)).
- **Workout tab dropped**; its two halves exposed as focused pushed pages `WorkoutLogsPage` (→ Home,
  via the streak/history affordance) and `WorkoutLibraryPage` (→ Labs "Training Library")
  ([workout_page.dart](../../../lib/pages/workout_page.dart)).
- **Quests tab dropped**; reached by push from Home.
- A front "Start training?" confirm on the nav tap (later removed in Phase 2 — see below).

## Deferred to per-area phases (NOT in the base)
Character-in-room **scene Home** (equipped cosmetics, furniture); native integration of history into
Home and the library into Labs (the base only makes them *reachable* by push); distinct per-area world
backdrops; pixel-art nav icons; trimming Labs' now-redundant COSMETICS entry (kept this phase to avoid
orphaning helpers — the new Inventory tab already covers it).

## Open tradeoff (accepted)
Per the user, **pulse replaces the dock**. Codex rated dock-removal high-risk: on full-screen pushed
pages the pulse is not visible, so the idle/expired safety net is the sole backstop against a stranded
session there. Accepted with that backstop; a thin "session live · resume" AppBar chip on pushed pages
is the cheap hedge if it proves a problem in use.

## Phase 2 — Train-as-commit (in-shell selection), shipped
The start flow is unified on the Train button. Exercise selection is now an **in-shell surface**
(nav stays visible) rather than a pushed full-screen route, and the in-progress pick **persists as a
draft across tab navigation** (in-memory; survives tab-nav, not app kill).
- New shell-owned [WorkoutDraftController](../../../lib/services/workout_draft_controller.dart) +
  `WorkoutDraftSeed`; `RootPage.openWorkoutDraft(seed)` is the **single entry** (center Train tap +
  onboarding finale route through it).
- [StartWorkoutPage](../../../lib/pages/Workout%20session/start_workout.dart) gains an `embedded`
  mode (no own Scaffold/selection bar; reports validity to the controller; registers its existing
  confirm+launch as the committer).
- **Train gains two more states** (idle → **armedLocked** (draft, 0 lifts) → **armedReady** (valid
  draft, breathing glow lure) → live). Precedence: a live/paused/expired session always wins and
  clears the draft. Tapping armed Train on the selection surface commits via the existing
  **"START THIS WORKOUT?"** confirm — so the flow now has **one** confirm at the irreversible launch
  (the Phase-1 front "Start training?" dialog was removed). A non-motion "READY · TAP TRAIN TO START"
  / "PICK AT LEAST ONE EXERCISE" hint + Semantics labels keep it accessible (Codex #5).
- Codex design review → REVISE (5 findings, all folded in: draft lifecycle, session precedence,
  single entry API, synchronous validity at commit, a11y affordance).
- **Remaining full-screen entries (documented exception):** the Home mission/program-day start and
  "repeat workout" still push the standalone (non-embedded) `StartWorkoutPage`. They don't touch the
  shell draft (no desync) and preserve Home's pre/post XP-gain capture; migrating them to in-shell is
  a follow-up.

## Out of scope
No mechanics/persistence changes. Adventure / Quests / Shop / Guild internals untouched — only entry
points and the shell topology moved.
