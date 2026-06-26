# Haptics overhaul — research foundation & implementation contract (2026-06-23)

> Feeds the app-wide haptic expansion the user requested: "Finch/Duolingo don't just put haptics on
> buttons — they put it on app *motion* (press BIT, gems flying, demo start/stop, BIT boot/cheer,
> changing items in the bag…). Apply haptics across every interactive + animated surface, screen by
> screen. We are simplifying audio, so the haptic layer makes up for it."
>
> **Reuse:** the semantic `HapticService` + `HapticSettingsService` + Settings toggle + the 6-process
> surface pass (P1–P6) already shipped (see `research/insights.md`, 2026-06-21 haptics entry). The
> taxonomy (`selection/tap/success/reward/warning`), the no-VIBRATE-permission built-in layer, the
> own-toggle / not-reduced-motion-gated / respects-system-setting stance, and the Duolingo/Finch
> "borrow craft not guilt" cut are **already `[validated]` and implemented** — not re-litigated here.
> This doc covers what was *new and unsettled*: **continuous/animation-coupled haptics** and the
> **"more is always better" thesis**.

---

## 1. The core tension, and how it resolves

The user's stance — *"haptic motion can never be too much"* — runs into a wall of consistent,
authoritative, partly-peer-reviewed evidence that says the opposite about **intensity and duration**:

- **Android official haptic principles** (`developer.android.com/.../haptics-principles`): *"Less is
  more."* *"Given the choice of buzzy haptics or no haptics for touch feedback, choose no haptics."*
  Too much vibration becomes *"annoying, numbing, and distracting, causing users to disable all
  haptics."* Scale intensity with importance: frequent/low-priority → **subtle**; important → strong.
  Prefer **discrete** primitives (10–20 ms) sequenced; **avoid continuous buzzing** and legacy
  long one-shots (they "ring 20–50 ms after input ends" and feel buzzy).
- **Journal of Consumer Research, peer-reviewed primary** ("Haptic Rewards", 2025,
  `doi:10.1093/jcr/ucaf025`): reward response to a vibration is **quadratic in duration, peaking at
  ~400 ms**. Both very brief (25–200 ms) *and* long (800–3,200 ms) reduce perceived reward; a
  3,200 ms vibration **decreased** purchasing vs *no* vibration and was rated "unpleasant/punishing."
  → Haptics genuinely **amplify reward** (this supports the user's instinct to add them to reward
  beats) **but the lever is timing/duration, not raw quantity** — a long strong "continuous" buzz
  *backfires even on a celebration.*
- **UX consensus** (Boréas, Saropa, Android): reserve haptics for moments touch adds clarity;
  low-stakes actions made to feel urgent → users disable or tune out. Always provide an opt-out
  (we have it). Touch/sensory-sensitive users find intense/unexpected vibration overwhelming →
  prefer crisp, predictable, short.

**Resolution (the design thesis for this overhaul):**

> **Be generous with COVERAGE. Be disciplined with INTENSITY and DURATION.**

The user's goal — a rich tactile layer on *every* meaningful interaction and emotional beat,
compensating for deliberately simplified audio — is **fully compatible** with the evidence *provided*
the intensity is mapped to importance and "continuous" moments are **short rhythmic pulse-trains
coupled to the animation, never a sustained drone.** Coverage breadth ≠ intensity. The evidence
forbids *buzzy/long/undifferentiated*; it does **not** forbid *broad-but-subtle-and-consistent*. The
Haptics toggle + system-setting respect are exactly the escape hatch the sources demand.

`[validated]` Android principles authoritative; JCR peer-reviewed primary; multiple corroborating UX
sources. Confidence high. **This refines (does not overturn) the prior `[validated]` "sparing,
consistent, peak-timed" bar**: "sparing" is reinterpreted as *sparing of intensity/duration*, not
sparing of coverage — the user's explicit product call, defensible because our intensity ladder keeps
the broad layer at the subtlest `selectionClick` rung.

---

## 2. Continuous / animation-coupled haptics — the technique

**Built-in `HapticFeedback` cannot do true continuous/amplitude haptics** — `vibrate()` is a single
short long-press-like buzz; only the `vibration` package (VIBRATE permission, bypasses the system
touch-feedback setting) or `haptic_kit`'s `.continuous()` do real sustained/amplitude output. The
prior `[validated]` decision is to **stay on the built-in layer** (no permission, respects the user's
system choice). Therefore **"continuous" = a pulse-train of discrete one-shots** — which is also
exactly what Android recommends ("sequence discrete primitives," not a drone) and what Finch actually
does (its "continuous" breathing guidance is a slow *rhythm* of gentle pulses, not a motor drone).

**The implementation pattern (load-bearing, confirmed):** do **not** run a `Timer.periodic` next to an
`AnimationController` — *"they drift, and the user feels the drift."* Instead:

> Drive the pulse-train off the **animation's own ticker**: in `AnimationController.addListener`, keep a
> threshold cursor and fire one pulse each time the value crosses the next `i/N` boundary, using a
> **`while` loop** (not `if`) so a stuttered frame still fires every threshold it skipped. One
> controller is the single source of truth for visual + haptic, so they stay in sync and the haptic
> **stops automatically when the animation stops/disposes** — no leaked timer (which the app's own
> learning flags as a flutter_test "pending timer" failure).

`[validated, technical]` Confirmed across the Flutter/haptics community pattern + Android's
"co-design with visuals, avoid desync" principle. Confidence high.

**Battery is a non-issue.** A haptic pulse is ~5–15 mJ; disabling haptics saves <1–2%/day. Short
pulse-trains are free; the constraint is *annoyance/fatigue*, not power — another reason bursts stay
short.

---

## 3. The haptic grammar v2 (the implementation contract)

Maps every surface class to one **existing** intent. The intensity ladder *is* the discipline that
makes broad coverage safe.

| Intent (existing) | Feel | Surface class (generous coverage) |
|---|---|---|
| `selection` (selectionClick, subtlest) | tick | **the workhorse** — nav/tab switches, chips, **rows that navigate**, card taps, list selects, picker ticks, toggles, favorite, equip/select-in-bag, send-nod, info/show-detail/help taps, muscle-group pick |
| `tap` (lightImpact) | light bump | ordinary button presses — `PixelButton` default, `TrainNavButton`, neutral `FilledButton` CTAs, demo play/pause |
| `success` (mediumImpact) | confirm | a state landed — set logged, save & exit, finish exercise/workout, sheet commit, weight confirm, exercise added to draft |
| `reward` (mediumImpact; ~400 ms burst is the seam) | celebratory | claim, level-up, PR, loot unlock, milestone, BIT cheer peak |
| `warning` (heavyImpact) | heavy | destructive/irreversible *commit* only — delete set/exercise, discard, reset, class-switch AGREE |

**Continuous / animated beats (short pulse-trains, coupled to the controller, ≤ ~1 s):**

| Moment | Pattern | Rule |
|---|---|---|
| **Gem flight** (quest claim, summary) | one **subtle `selection`** pulse **per gem landing** in the wallet, off the flight controller's per-gem arrival; a final `reward` when the count settles | rising count = rising cadence (pleasant), each tick subtle; **caps at the ≤5/sec ceiling** (coalesce if many gems). *This is a user-directed override of the prior "once-per-claim not per-gem" rule — reconciled by keeping each per-gem tick at the subtlest rung.* |
| **BIT boot / power-up** (onboarding cold→solution) | slow gentle `selection` ticks synced to the coil/inhale breathing beats — "continuous weak" | Finch breathing model: calm, slow, low-intensity; stop on settle |
| **BIT cheer** (solution reveal peak) | a **short** strong burst (~400–600 ms) of `success`/`reward`-level pulses at the cheer apex, then stop — "strong continuous" | JCR: a celebration buzz peaks ~400 ms; **never a multi-second drone** (backfires). Upgrades today's single `reward()` |
| **Stat/XP count-up** (summary) | optional subtle `selection` ticks at milestone thresholds off the count animation | low priority; subtle; cap cadence |

**Cross-cutting rules (all from the evidence + prior `[validated]`):**
1. **Consistency:** same trigger class → same intent everywhere (learnability).
2. **Peak-timing / sync:** fire on the frame the visual lands; drive trains off the controller (no
   free Timer) → no felt/seen drift, no "broken" desync feel.
3. **Rate ceiling ≤ ~5 pulses/sec**; coalesce bursts.
4. **Reduced-motion edge (new, important):** haptics still fire (own toggle), **but** a pulse-train
   coupled to an animation that is *frozen* under reduced motion has **no ticker to ride** → collapse
   the train to a **single representative pulse** (e.g. BIT cheer reduced-motion = one `reward()`;
   gem flight reduced-motion = one `reward()` as the count snaps). Never a dead control, never a
   free-running train against a still frame.
5. **Fail-open & guarded:** every call through `HapticService` (already try/caught, mute-aware).
6. **Battery:** ignore; keep trains short for *feel*, not power.

---

## 4. Infrastructure implied (feeds the build)

1. **Keep `HapticService` one-shot.** Do **not** give it a service-owned `Timer` loop (drift +
   flutter_test pending-timer leak). Add **one reusable widget-side helper** for animation-coupled
   trains — an `AnimationController`-driven threshold pulser (the `while`-loop cursor pattern), so the
   train lives and dies with the animation. Reduced-motion → single pulse.
2. **Opt-in haptics on the shared tap wrappers.** Add a `HapticIntent haptic` param (default
   `none` = no behavior change) to `PhosphorTap` / `HoldDepress` / `ArcadeTap`; `ArcadeChip` passes
   `selection` by default (a chip is always a selection — subtle, on-evidence). Batches opt their
   specific surfaces in. This is how the gaps (cards, chips, rows) get covered without a surprise
   global buzz.
3. **`TrainNavButton`** (bare `GestureDetector`, the hero CTA) → fire `tap` on press.
4. **`FilledButton`** can't carry a param (Material) → per batch, add a `HapticService` call at the
   top of the specific `onPressed`. Localized, safe.
5. **Settings rows / nav rows** → `selection` on tap (the user's explicit gap: "rows have no haptic").

---

## 5. Open assumptions / what to verify on-device (the honest gaps)

- `[assumption]` Built-in `selectionClick`/`lightImpact`/`mediumImpact`/`heavyImpact` feel
  *distinct and strong enough* on the user's target hardware. The built-in layer is OEM-inconsistent
  (`heavyImpact` no-ops on some Samsung per flutter#73987). **Only on-device testing settles this**;
  if the broad `selection` layer feels absent, the fix is on-device, not in code. *(Carried from the
  prior entry — still the single biggest unknown.)*
- `[assumption]` Per-gem flight ticks feel "continuous and delightful" rather than "stuttery." The
  cadence cap + subtlety should land it, but it's a feel call → on-device sign-off.
- `[assumption]` The user's maximal-coverage preference won't trip the "users disable all haptics"
  failure mode *because* intensity is disciplined. Defensible from evidence, but it's a product bet;
  the toggle is the safety net.
- `[validated]` Battery, permission, reduced-motion handling, and the drift-free coupling technique
  are settled — not on-device-dependent.

---

## 6. Codex adversarial review of the evidence + design (2026-06-23) — verdict *needs-attention* → resolved

Prompt-only review (sandbox can't read repo). All 5 findings adopted; they sharpened the design.

| # | Finding (sev) | Resolution (folded in) |
|---|---|---|
| F1 | No hard budget / silent-surface policy — broad `selectionClick` could turn scrolling/browsing into constant noise → the very "disable all haptics" failure (high) | **Adopted.** Added the **silent-surface matrix** (§7) + a **global coalesce** in `HapticService` (drop any pulse <30 ms after the previous). Shared wrappers default **silent** (`none`); only *meaningful, committing* taps opt in — never passive scroll, informational cards, disabled/gated taps, re-tap of the current tab, or dense browsing. |
| F2 | Per-gem pulse train will read as stutter, not reward, and damages the highest-value beat (high) | **Adopted.** **Do not pulse per gem.** Aggregate to **≤3 subtle `selection` ticks keyed to animation beats + one final `reward`** at wallet-settle, regardless of gem count. Hard cap in the pulser. |
| F3 | Reduced-motion "collapse to one pulse" can still fire an *unexplained* pulse on a frozen/removed animation (med) | **Adopted.** Reduced-motion fires a pulse **only when tied to an explicit user action or a visible state transition**; **suppress** ambient/celebratory train-replacements when the animation is *removed* (e.g. BIT idle boot → silent under reduced motion; gem flight stays, keyed to the CLAIM tap; BIT cheer stays, keyed to the reveal). |
| F4 | Pulser lifecycle under-specified (reverse/repeat/hot-reload dup listeners/retarget/dispose-mid-call/skipped final threshold) (med) | **Adopted.** Pulser ships as a **disposable helper: one listener per controller, forward-only (ignore reverse/repeat), mounted/disposed guards, fires the final threshold on `completed` even if a frame skipped it, idempotent attach.** Lifecycle tests: forward / reverse / repeat / skipped-frame / rebuild / dispose-before-complete. |
| F5 | 9 batches before wrapper semantics are locked multiplies regression risk (med) | **Adopted (already the sequencing).** Land **infra + wrapper opt-in first** (defaults proven by tests), then batches are **pure explicit opt-in lists** — a wrong wrapper default can't silently buzz unrelated screens because the default is `none`. |

## 7. Silent-surface matrix (never fire haptic)

- Passive **scrolling** / fling / momentum.
- Purely **informational** cards/rows that don't navigate or commit anything.
- **Disabled / gated / no-op** taps (e.g. a gated set row warns visually; the warning itself may
  carry at most a single `selection`, never an impact).
- **Re-tapping the current** bottom-nav destination (no state change).
- **Press-only visual affordances** (hold-depress feedback that isn't a committing tap).
- **Dense list exploration** (favoriting/expanding many rows fast) beyond the ≤5/sec ceiling — coalesced.
- Anything firing **<30 ms** after a previous pulse (global coalesce in the service).

## 8. Codex review of the implementation (2026-06-23) — verdict *needs-attention* → resolved

A second prompt-only Codex pass over the finished implementation. One HIGH + verification notes, all
resolved:
- **(HIGH) Reduced-motion reward in `didChangeDependencies` could replay** on a MediaQuery/theme change
  (the `!_complete` guard leaned on the outer early-return). → re-guarded with the dedicated one-shot
  `_bloomFired` flag (solution_page).
- **Direct `selection()` spam surfaces** (demo play/pause, ±15s, favorite) bypassed the 30 ms coalesce. →
  routed through `fireCoalesced`.
- **Boot ambient train slightly chatty** (4 pulses/2.25 s). → softened to 2 ticks + the wake ack.
- Confirmed defensible (kept as-is): the gem-flight `reward` stays at the SFX-synced claim-impact t0 with
  ≤2 stream ticks (don't move the payoff unless audio/visual move too); the inventory tap→confirm→equip
  three-beat is distinct interactions, not a double-fire; HUD pills are committing nav (not informational)
  so they keep their tick.
- **Residual coverage gap (noted, not fixed):** some raw `FilledButton`/`TextButton` *dialog* actions
  (e.g. a generic ENABLE/confirm) stay silent — the *destructive* confirms (delete/discard/reset/AGREE)
  are already covered; app-bar backs & sheet scrims are intentionally silent.
