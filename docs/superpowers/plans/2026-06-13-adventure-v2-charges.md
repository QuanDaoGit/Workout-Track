# Adventure v2 — charges, manual stage-select, VIT-timed expeditions (shipped 2026-06-13)

Supersedes the dispatch model in `2026-06-12-adventure-design.md` (that doc stays frozen as the v1
record). Built through the full `/deep-feature` pipeline.

## Why
v1 auto-dispatched one expedition/day on workout save and revealed on the next Home sitting — the
reward was *dispensed*, the user passive, and VIT (the recovery meter) had no outward use. v2 gives
the loop agency, game-feel, and a purpose for VIT.

## The model
1. **Charges (instant payoff).** Each completed workout (non-partial/non-abandoned, ≥1 set reps>0)
   grants **1 charge**, max **1/day** (max-anchored `lastChargeDay`), banked up to **3**. Surfaced on
   the workout summary as the immediate workout reward. `grantChargeForSession` replaces
   `dispatchForSession` in the save path.
2. **Manual stage-select dispatch.** The user spends a charge via `dispatchExpedition(routeId)`: tap a
   route to arm it (preview rank→pay, VIT→duration + multiplier, est total) → the other two dim and
   lock (choice-closure commitment device) → DISPATCH. One expedition out at a time; ≤5 dispatch/ISO
   week (the weekly gem-budget bound).
3. **VIT-scaled 4–8h haul.** Captured & frozen at dispatch: `durationMinutes = 240 + (VIT/100)·240`
   (4–8h); `multiplier = 1.0 + (VIT/100)·0.4` (1.0–1.4×). `payout = base(rank) × multiplier × ±30%`,
   rolled once seeded by a collision-resistant id.
4. **Timed, Finch-gentle reveal.** Revealable when `maxSeen ≥ returnsAt`, where `maxSeen =
   max(now, storedMaxSeen)` (monotonic rollback guard). No expiry/withering; a returned expedition
   waits indefinitely for a calm collection (on the Adventure page or auto-revealed on next Home
   open). The settle/peek/acknowledge split, single-flight queue, and idempotent ledger are unchanged.

## Deep-feature record (audit → research → opinion → Codex ×2)
- **Research:** appointment mechanics drive retention but are the most-criticized dark pattern (the
  line is *meta-systems that extend playtime beyond what players would choose*); Finch validates the
  gentle, never-punished shape; choice-closure (Gu/Botti/Faro 2013) backs the lock-and-confirm ritual;
  offline clock-forward is essentially undefendable (server time only) so it's a documented boundary.
- **Codex opinion review → RECONSIDER.** Two intent calls the user accepted eyes-open: the real
  4–8h gated wait (an appointment mechanic — accepted because gems are cosmetic-only, never punished)
  and VIT-scaling gems (accepted because higher VIT = longer wait *and* more pay, so there's no
  under-recover incentive; the nudge "keep recovery high" is on-doctrine; VIT/multiplier/duration are
  shown at the arm step for legibility). Three engineering fixes folded in: keep the 5/ISO-week cap
  (throughput would otherwise nearly double); +1 CHARGE is the instant summary payoff (reward no
  longer detaches from the sweat); coarse countdown + max-seen guard (clock-skip only skips waiting,
  never the charge cost).
- **Codex plan review → 3 findings:** queue-poisoning (verified non-issue — `_serial` already
  swallows a failed op into the queue tail); manual-dispatch id collision (fixed —
  `exp_${now.microsecondsSinceEpoch}_${Random().nextInt(0x7fffffff)}`, never `1<<32`); ISO-week vs
  rolling-7-day (documented as calendar ISO-week, = v1 semantics, real bound is 1 charge/day).

## Invariants
Weekly gem budget = 5 × base × [1.0–1.4×]/ISO-week. Charge cap = 3. Clock-forward = accepted offline
boundary (cost is the charge = a real workout). Reconstructed-value rule: payout, duration,
multiplier, returnsAt all frozen at dispatch.

## Out of scope (tracked separately)
Finds collection shelf; 4th mixed-stat route; Home/Training-Ground/Adventure area restructure.
