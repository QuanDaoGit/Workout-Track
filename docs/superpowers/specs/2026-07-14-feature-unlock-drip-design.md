# Earned Feature Unlocks ("the app assembles itself") — Design

**Date:** 2026-07-14 · **Status:** approved by user (brainstorming dialogue) · **Research:** `research/insights.md` → "Progressive feature unlocking (workout-count feature drip)" (Codex evidence-review *needs-attention* → 4 findings folded in)

## Goal

Make Ironbit feel more game-like than a normal app by pacing the meta surfaces as **earned unlocks**: a new user starts with the tool core + one full identity loop, and the meta features (Shop, Guild, Inventory, Adventure) come online through a short, front-loaded, count/event-based ladder — each reveal marked by one standardized unlock ceremony. This converts today's day-1 hollow empty states (guild with no sessions, shop with no gems, inventory with no loot) into anticipated, earned reveals.

## Decisions locked during brainstorming

1. **Shape: meta-drip** (option A). The tool core is never gated.
2. **Conditions: mixed** — natural events where they exist (first gems → Shop, first loot → Inventory), workout counts elsewhere (Guild, Adventure).
3. **Locked tap: floating notice only** (the existing pinned-lifts floating-notice pattern), invitation-framed copy.
4. **Ceremony fires on the shell**, not inside the workout summary (Phase-8 precedent #9: save context is the wrong celebration moment; also protects the BIT summary ceremony from stacking).
5. **User directive:** the ceremony is its **own separate dedicated workflow**, with each component thoughtfully and comprehensively crafted — front-end craft is a first-class requirement, not a byproduct of the gating plumbing. Implementation is therefore split into two workstreams (below).

## The ladder (v1)

**Never gated:** Home, TRAIN + entire session flow, Logs/history, XP/stats/level, BIT + home room, **Quests** (activation hook; source of first gems/loot), Labs/Profile (settings/units/avatar always reachable). Strength surfaces stay open (naturally data-gated).

| Order | Feature | Unlock condition | Typically lands |
|---|---|---|---|
| 1 | **Shop** (push from Home) | first gems earned (gem ledger non-empty) | workout 1 (first quest claim) |
| 2 | **Guild** (tab) | 3 completed workouts | ~week 1 |
| 3 | **Inventory / Items** (tab) | first loot earned (owned non-default loot) | ~workout 4 (first frame) |
| 4 | **Adventure** (home-room expedition pad) | 5 completed workouts | ~week 2 |

- "Completed workouts" uses the same completed-sessions bar as frames/guild level (non-abandoned, real working set).
- Thresholds are **constants, not architecture** — tunable if instrumentation later disagrees.
- Adventure gets the diegetic treatment: the room's expedition pad renders **dormant/unpowered** until unlocked.

## Locked presentation

- Gated **tabs** (Items, Guild) stay visible in the bottom bar, dimmed with a small lock glyph. Gated **pushes** (Shop entry on Home) render dimmed/locked in place.
- Tap → floating notice, **invitation-framed, never debt-framed** ("Complete 3 workouts to found your guild", not "3 to go"). No deadlines; nothing ever re-locks; BIT/belonging is never gated.

## The unlock ceremony (dedicated workstream — craft bar applies)

One standard `FeatureUnlockCeremony` used by every gate. Fired from a **pending queue on the shell** (RootPage), following the `ModalRoute.isCurrent` pattern of the idle-session reveal; multiple unlocks queue one at a time.

Beat sketch (to be fully designed in its own `/deep-feature` pass with `ironbit-design`):
brief takeover → pixel/scanline reveal of the feature icon + "NEW SYSTEM ONLINE — GUILD" → BIT cheer line → **GO** (quick-nav to the new surface) / LATER. Reward haptic; reduced motion gets a static card. Every component (reveal animation, typography beat, BIT integration, SFX/haptic track, quick-nav exit) is individually crafted and test/golden-covered — this is a flagship front-end surface, not a stock dialog.

## Architecture

- **New `FeatureGateService`** (`lib/services/feature_gate_service.dart`): small registry of gates (id, condition, copy, icon). Conditions evaluated from existing sources only — `WorkoutStorageService` (completed count), `GemService` ledger, `LootService` (owned non-default loot). No new data collection.
- **Latched unlocks:** once a condition is met, the unlock persists forever (`feature_unlocks_v1`, per-gate `unlockedAt`); deleting history can never re-lock a feature. Ceremony-shown is tracked separately from unlocked.
- Evaluated on shell load + on the existing `WorkoutStorageService.changes` stream.
- `RootPage` nav buttons read gate state; pending-ceremony check on load/resume.

## Migration / grandfathering

Free by construction: existing users' conditions all evaluate as met on first launch after the update — the one-time migration latches every gate **and marks it pre-celebrated**, so existing installs see zero locks and zero ceremony spam. New users start fresh.

## Risks carried from research (Codex findings)

- **F1 (high):** games/companion-app precedent (Finch, Habitica, Duolingo, Pokémon GO) is hypothesis-grade for a *tracker* — a locked tab may read as missing capability. Mitigation: prototype/sanity check that the locked state reads as "earnable", not "broken", before full commitment.
- **F2 (high):** ~75% week-1 churn → gated features must not be activation drivers (they aren't: XP/quests/BIT stay day-1) and the ladder must be front-loaded (it is: resolves in ~2 weeks of real use). Per-gate funnel targets once instrumented (see-locked → unlock → revisit).
- **F3:** visible-locked, thresholds, and ceremony are experiment parameters, not proven design — keep them constants/tunable.
- **F4:** anti-guilt copy audit on every locked/countdown string; count-based no-deadline gates only; preview/reveal escape hatch is a fallback if the prototype check fails.

## Workstreams

1. **WS1 — gating plumbing:** `FeatureGateService`, latching + migration, locked nav/entry rendering, floating notices, room dormant-pad state. Mostly service + shell work.
2. **WS2 — the unlock ceremony (dedicated):** the full `FeatureUnlockCeremony` component family, designed and built to the app's flagship-ceremony bar (session-ceremony-grade craft), via its own `/deep-feature` + `ironbit-design` pass.

## Testing

- Service: latching, condition eval, no-re-lock, migration seeding (existing user → all latched + pre-celebrated, no ceremonies).
- Widget: dimmed/locked nav + notice; ceremony queue (one at a time, `isCurrent` gating); reduced-motion static path.
- Goldens: locked-tab state; ceremony key frames.
- Copy audit: every locked string reviewed against anti-guilt doctrine.
