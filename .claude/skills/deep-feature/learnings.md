# Deep-feature learnings — recurring failure modes from Codex reviews

Maintenance: **generalize, never transcribe** (feature-specific findings stay in the plan doc).
Update an existing category over adding a near-duplicate. Cap ~40 content lines below this header;
when full, prune the least-recently-fired category.

### Non-atomic prefs read-modify-write (races + corrupt-blob crashes)
**Rule:** A SharedPreferences `load JSON → mutate → write` is **not atomic**: two concurrent writers to
the same key (an unawaited fire-and-forget write landing after a later RMW, *or* two awaited RMWs whose
reads interleave) silently drop one update. Drain in-flight writes on every exit path **and** serialise
each RMW critical section behind a **per-key async lock** (a keyed future-chain mutex shared
process-wide via a top-level/static instance, so the app's many ad-hoc `Service()` constructions
contend on the same lock); lock **only** the read+mutate+write, never the surrounding sub-service
orchestration (those services mutate the same key → self-deadlock), and never nest a second lock on the
same key. Separately, a loader that `jsonDecode`s **unguarded** throws on a corrupt/schema-drifted blob —
and on the **boot/home path** (e.g. `getSessions()` in a page's `_loadData`) that crashes app-open;
decode through a corruption-tolerant helper that returns a **typed fallback** ([] / null / defaults) and
**skips an individual bad record** (salvageable subset), proven with a corrupt/missing/drifted-blob test.
*Seen: idle checkpoint racing `saveSession`; concurrent gem `award*`/session saves serialised via a
shared `KeyedLock` keyed on the prefs key; `getSessions`/gem-ledger/stat/rest/quest/loot loaders hardened
via `json_safe` (2026-06).*

### Dual-path divergence
**Rule:** When 2+ paths handle one event or seed one field (foreground vs cold-reopen, manual vs auto,
resume vs repeat vs history), pin a once-only precedence + a "user touched it → never auto-reseed" guard,
and test every path. A **delayed UI commit** (a hold/debounce "land" timer) must be a **cancellable owned
`Timer`**, never a bare `await Future.delayed` — cancel it on Back + dispose and **step-guard its callback**
(`_step` unchanged), or the awaited delay races back-nav and reacts/advances for a question no longer up.
A derived default that **REDUCES** the experience (hides features / strips scaffolding) must persist
**only once the choice is visibly shown/confirmable** — never at an earlier silent commit — and its
unset/killed state must **fail toward the FULLER** experience, never the reduced one (a reduction the
user never saw is a hidden-state hazard; make the store the single source of truth so shown==stored;
Codex 2026-07-14).
**Two persisted models of one concept** (a calendar-weekday schedule vs a sequence cursor) must reconcile
behind **one pure resolver consumed by both** — never let each consumer recompute the shared truth
(precedence drifts apart), and never let a live re-projection re-classify a *past* period that drives
economy (shields/streak/XP): read the **frozen per-period snapshot** so a schedule edit can't retroactively
penalize. Retire the dead field by **freezing + migrating it once** (gated bool); landing the migration
before its consumer leaves a stale reader. **Removing a derived *debuff/factor*** (decay) must
**suppress the one-time recompute delta**, else the un-debuff reads as a fake earned "board jump" in any
computed-vs-cached diff. **Re-curving a value DERIVED from a stored source** (level←totalXP) is a
*silent* migration — nothing stored changes, yet every threshold reading (level, rank) + every
display/test/golden pinning it shifts: prove **monotonicity at each legacy boundary** (new ≥ old, so no
consumer demotes) and repoint every pinned reading. **One shared singleton driven by 2+ phases** (a
between-set vs between-exercise rest, both on `RestTimerService`) means a takeover/derived view gated
**only on the singleton's *active* state** fires in the wrong phase — scope it with a per-phase flag set
where *that* phase's source starts, and **"suppress" the view by cancelling the SOURCE, not hiding it**
(a hidden-but-live source leaks into a later surface — an orphan rest into the summary/next workout); test
the sibling-phase path explicitly (it is the regression). **A milestone gated on an elapsed-time DWELL**
(show line B after 2.2 s on a phase) that a **reversible sub-phase can re-enter before the dwell** (hold⇄pour:
an early pour then release drains back to the same phase with `elapsed < dwell`) **regresses** to line A on
re-entry — a monotonic clock alone can't hold it. **Latch** the milestone the first time it's reached via
**ANY** path (the dwell OR the earlier user action that implies it), never un-latch; the composed test is
`_latched || elapsed >= dwell`. Prove it red-green with the early-action-then-reverse path (it's the regression). *Seen: zero-set idle reveal; a 280 ms select-hold
reacted on the wrong question after a Back; the weekday-anchored schedule unified
RestService×ProgramService via one `ScheduleResolver` + frozen `scheduleByWeekKey`; decay removed
(factor frozen + un-decay delta suppressed) + XP re-curved to √ with a no-loss-boundary proof; a
between-exercise rest takeover scoped via `_restAfterFinish` + suppress-on-last cancelling the shared
`RestTimerService` so a between-set rest never bleeds into the overview (2026-06).*

### Legacy-data cliffs
**Rule:** A new nullable field used in a threshold/comparison must define the null (legacy) case
explicitly — default to "never triggers" — with a legacy-fixture test. **And a migration that
grandfathers existing users into a new GATING system must grant unconditionally, never by replaying
the new conditions over old data** — the evidence shape the condition needs (a ledger entry, a
normalized record) may simply not exist for a legit legacy user, silently locking them out of a
surface they already had; test the sparse-legacy-data rows explicitly. *Seen: null `lastActivityAt`
would time out every old session; warm-up `warmup` key → false (2026-06); feature-unlock seeding by
condition-replay would have hidden the Shop from a 10-workout user with an empty gem ledger — Codex
flipped it to latch-all-for-legacy (2026-07).*

### Settlement/presentation coupling
**Rule:** When a reward resolves on a later surface, settle the data (award, persist, mark unviewed)
independently of the ceremony and auto-settle on the next earn — a blocked/unseen ceremony must never
block or burn the next earn. **The "there is something to collect" signal must be re-derived from
*persisted* state every load (an unviewed-history predicate), never a volatile in-memory held value** —
the held value is only a routing cache. A volatile authority silently loses the affordance across
kill/reopen, a deferred reveal, or the service auto-settling between opens; if collecting is gated and
you also block the next action until collected, that block must key off the same persisted predicate
and fail **open** (re-derive on the next load, never a permanent strand). *Seen: Adventure pending
expedition; the homecoming-coffer collect gated on a held report → re-based on a persisted
`hasUncollectedHaul` (2026-06).*

### Platform-plugin calls must fail open (test env has no native impl)
**Rule:** A newly added platform plugin (notifications, share, camera…) has **no registered platform
implementation in the unit-test env**, so the first touch of `resolvePlatformSpecificImplementation` /
any MethodChannel throws (`LateInitializationError` on the platform `instance`, or
`MissingPluginException`) — and a fire-and-forget call in a widget's `initState` surfaces it as an
unhandled async error that fails *every* test mounting that page. Wrap **every** plugin access in
try/catch that degrades to a no-op/false (fail-open): this both keeps the subsystem from ever crashing
boot / a workout (best-effort delivery) **and** keeps the calling page's widget tests green without
per-test channel mocks. **But try/catch cannot fail-open a plugin whose CONSTRUCTOR kicks off an
unawaited, MEMOIZED init future** (audioplayers' global scope): the MissingPluginException escapes the
awaited chain into the test zone ("failed after it had already completed"), and once the memoized
future holds an error, awaiting it from any *other* zone (a runZonedGuarded wrapper — which therefore
CANNOT fix this) blocks forever at Dart's error-zone boundary → 30s timeouts. Remedy: **skip the
platform layer entirely under `flutter test`** — detect via `Platform.environment['FLUTTER_TEST']`
(the `bool.fromEnvironment` form is NOT defined by the tool) — and make a pre-platform
recorder seam (`onPlayForTest`) the observable contract tests assert against. Prove a new subsystem's *logic* with a tiny injected interface (a fake
recording calls) so the coordinator/decision code is tested with zero plugin involvement. *Seen: Tier-A
rest-timer local notifications — `NotificationService` guarded, `RestNotificationCoordinator` tested via
a `RestAlertScheduler` fake (2026-06); the SFX micro channel's `AudioPool.create` leaked audioplayers'
memoized global-init error into every suite tapping a `PixelButton` until the FLUTTER_TEST gate +
recorder seam (2026-07).*

### Asset-dependent core surfaces
**Rule:** A surface newly depending on bundled images needs per-image errorBuilder fallbacks + a manifest
test that loads every registry path; Flutter asset dirs are non-recursive — declare each subfolder. When
the asset's **geometry** matters (an overlay's transparent aperture, a sprite's safe-area) and you can't
screenshot, **decode every frame in a test** (`instantiateImageCodec` → `toByteData(rawRgba)`): assert
dimensions + that the content clear-region is fully transparent — **all** frames, never one sample (an
artist's hand-authored set can drift per-frame; an animation's mid-frames differ). Pixel overlays scale at
**integer factors only** — author the master at one display size (e.g. 260) and standardize surfaces to its
integer divisors (130 = ÷2), never `BoxFit.fill` at an arbitrary size. *Seen: Adventure diorama/emblems;
v3 body/ subfolders; avatar-frame 260×260 set — decoded all 25 PNGs' central aperture as the no-screenshot
proof, surfaces pinned to 130/260 (2026-06).*

### Farmable reward surfaces
**Rule:** Every new reward needs an anti-farm bound; ask the cheapest action that repeats it.
Idempotency-by-entity-id is NOT a rate cap — for once-per-period rewards key the ledger id on the
*period* so the dedup is the cap. Reward an **observable artifact** (a logged set), not a bare
self-report toggle. A variant many aggregators read goes in its **own field**, never a flag
filtered at every consumer (a missed reader silently inflates). **A period reward whose completion is
measured over a metric WINDOW (active-days *this week*) and keyed by the PERIOD must derive both the
window and the key from ONE captured `now` + ONE period basis** (the same Monday-of-week — not a
Thursday-ISO key over a Monday window), or they drift at a Sun/Mon/DST/timezone edge → a second arm or
mis-read state; **derive "already claimed" from the ledger** (the durable truth) so the banked reward
stays final when the metric later changes (a deleted session), and **prefer auto-bank on completion
over a manual claim** (a completed-but-unclaimed period strands the reward, and an expiring payout reads
as guilt-pressure). *Seen: stat intensity; body-metrics anchor; warm-up `warmup:<day>` re-anchored to
`ExerciseLog.warmupSets`; guild Weekly Cache `guildcache:v1:<mondayKey>` — one `now` for window+key,
ledger-derived banked, auto-bank not claim (Codex F2/F5/F6, 2026-06).*

### Decoupled id sources
**Rule:** When an id's uniqueness rode on a correlate you're removing (session id, per-day timestamp, boot
id), it collides once decoupled and a ledger keyed on it swallows the dup — re-base on
`microsecondsSinceEpoch + Random().nextInt(0x7fffffff)`; test the same-fixed-clock case. *Seen: Adventure v2 dispatch (2026-06).*

### Advisory/derived numbers
**Rule:** A number shown to the user must (a) be validated against its anchor and suppressed when the
relationship inverts (a warm-up ≥ the work set isn't one), and (b) be quantized to a real settable value
in the display unit — never a raw % or kg round-trip; don't assume one context's constant (bar weight,
plate size) fits all. (c) A target **derived from the same recent history the user is trying to beat** is
self-referential: anchor it with a robust central tendency over a **multi-session window + fixed offsets**
(not one moving point) so it can't oscillate/ratchet; **gate any *judgment*** (deload / "you're short") on
**confidence** — enough clean, low-variance sessions — and **suppress it for sparse or high-variance
history** (no baseline ⇒ don't judge; respect a deliberate low-rep or undulating style); prove no drift
across cycles with a **multi-cycle simulation test**, not just per-session fixtures. Keep the old fixed
default as the sparse fallback, never the universal target. (d) A user's explicit **preference** (a goal
pick) layered on a learned/adaptive signal is the same — it **seeds the cold start** (where history is
empty), it must **not hard-override** the learned signal once that has data: an override re-creates the
exact failure the signal fixed (a clamp manufactures success → runaway load; a sticky once-set global
pick can't represent a goal change and isn't editable; suggestions ignore what the user actually does).
Make the preference the smarter sparse-fallback; let history win at confidence. (e) An **aggregate over
a selectable window compared to a fixed-period landmark** (sets/wk vs weekly MEV/MAV across a 4/12-wk
view) must **normalize to the landmark's period** — a per-period *average*, never the window *total* (a
multi-week total vs a weekly band is nonsense) — and the averaging **divisor must cap to real history**
(`min(window, now−firstEver)`, ≥1 period) so known activity is never divided by *empty pre-history* (a
new user's hard week → falsely "RESTED"); **label the real span** ("avg/wk · last N wk") so the average
isn't misread as raw recent work, and keep **one pure calc boundary** (a service helper, not the display
widget) so the divide can't drift from the meter. *Seen: warm-up suggestion; history-anchored rep target
#5 (top-set-rep median, aim=M+1/floor=M−2, deload gated on ≥2 consistent sessions, simulation-proven);
onboarding training-goal seeds the sparse rep target (5/8/15), Codex flipped a clamp→seed because the
clamp ran load away; body-map averaging-window divisor capped to firstSessionEver, Codex F1 (2026-06).*

### Entity-keyed side-state lifecycle
**Rule:** Ephemeral state in a sibling store keyed by an entity id leaks/mis-applies unless cleared
wherever the entity row is removed/finalized in the storage layer — every terminal path, never at UI
buttons. Bonus: make a heavily-mutated field a read-only projection so stray writers fail `analyze`.
**When the entity is a DERIVED set, not a stored row you delete** (a strength trend computed from
sessions), there's no removal hook to clear the side-state — so **reconcile/self-heal on load**: prune
the side-state to the live set. This is load-bearing when the side-state is **capped** (max-N
pins/favorites): a stale entry silently **consumes a slot with no UI to clear it** (the unpin/remove
affordance renders only for *live* entries), so the cap **deadlocks** — prune before the capacity
check, and test the ghost-entry case. *Seen: program-swap store; `_selectedExerciseIds` getter
(selection v2); pinned lifts `pruneTo` the live trends on load so a ghost pin can't deadlock the 3-pin
cap, Codex F1 (2026-06).*

### Deferred completion signals gate input
**Rule:** When a control becomes actionable the moment an animation/typewriter "completes", flip its
actionable flag in the **same frame** completion lands — notify **synchronously** from the timer/event
callback, not via an `addPostFrameCallback` that opens a one-frame window where the affordance looks
ready but a tap is mis-read (read as "skip", not "continue"). Defer **only** from true build-phase
callers (`didChangeDependencies`/`didUpdateWidget`, where a synchronous owner `setState` is illegal).
Likewise a value **latched** from an `InheritedWidget` (MediaQuery reduce-motion) on first build must be
**reconciled in `didChangeDependencies`** on later changes (don't early-return past the check) or a
mid-interaction toggle is silently ignored. But any **side-effect** fired inside that reconciliation
(a haptic/sound/analytics beat) must be **one-shot-guarded by a dedicated flag** — `didChangeDependencies`
re-runs on *any* inherited change (MediaQuery/theme/locale), so a guard that leans on a sibling
`_complete`/early-return will **replay** the beat without a new user action. And an **animation-coupled**
side-effect rides the `AnimationController`'s **own listener** (threshold cursor, forward-only, flush the
final on `completed`) — never a parallel `Timer` (it drifts against the frames *and* leaks as a
flutter_test pending timer). *Seen: BIT typewriter tap-to-continue dropped the first tap at the completion
frame; reduced-motion toggled mid-type kept on typing; the solution-page reduced-motion reward replayed on
a MediaQuery change until guarded by `_bloomFired`; BIT-boot/cheer & gem-flight haptics ride their
controllers via `HapticPulseTrack` (2026-06).*

### Navigation restructure: positional + always-present assumptions
**Rule:** Remapping nav slots, converting tabs→pushed routes, or removing a persistent shell surface
breaks hidden contracts: positional index callers misroute (migrate to a semantic destination API first),
reload-on-tab-switch stops (re-run reloads on pop), and modal gating assuming the shell route is current
gets starved (re-arm pending reveals on pop). Back any removed always-visible affordance with a safety
net. A **new pre-start/draft state** beside an existing entity must be gated by the authoritative
machine (a live session wins and clears the draft), funnel all launchers through **one entry API**
(pushed vs embedded must not diverge), and expose validity as the single synchronous commit gate.
A **high-intent / first-run launcher must not inherit an *ambient* schedule gate**: a
calendar/weekday "today" resolver degrades to rest/empty off-anchor, so reusing it behind an explicit
START/first-session action drops the user to a generic fallback exactly when intent peaks — resolve
such actions via the **weekday-agnostic next-up**, scope the override to the first occurrence (a
`completedSessions == 0` guard, leaving established-user recovery doctrine untouched), funnel every
first-run entry through that one resolver — **including secondary/empty-state surfaces (a
last-workout / stat card) that are easy-to-miss launchers** — exempt **every** ambient gate on that
path (a confirm *dialog* like "train anyway?", not only the day-resolver), and confirm the override
can't double-credit the bypassed state (a logged artifact must *naturally* exclude the day from its
passive reward).
*Seen: 4-places+center-Train shell (index→AppDestination, reloads/reveals re-fired on pop); in-shell
selection draft gated by the session machine via one openWorkoutDraft entry; onboarding/first-Train
opened a blank picker on a seeded rest day → first session routed to activeWorkoutDay; a follow-up
caught the Home empty last-workout card + the planned-recovery confirm still un-funnelled →
_startFirstWorkout routes to the pre-filled Day-1 + showsRestDayTrainPrompt exempts isNewUser (2026-06).*

### Hand-authored data layers need a source-validated integrity test
**Rule:** When you hand-author a supplemental map keyed by another dataset's ids (a per-exercise
override, a curated allow-list, a coefficient table), the authoring **drifts silently** — a typo'd
id, an id that no longer exists, or an attribute asserted on an entity that doesn't actually have it
all compile fine and just go dead. Add a **test that validates every authored entry against the
canonical source** (read the real asset/registry, assert each key exists *and* the thing you're
augmenting is genuinely present on it), so drift fails CI instead of silently dropping coverage.
Pair it with a **fail-safe default for the un-authored long tail** (return the coarse/original value,
never a guess) so partial authoring degrades honestly rather than fabricating precision. Prove the
guard with a typo'd-entry mutation. **Corollary — two consumers of one derivation must share the
*computation*, not just agree:** when a value is shown two ways (a per-muscle TOTAL on a bar + a
BREAKDOWN list of what fed it), compute both from **one** shared per-unit credit so they can't diverge,
and guard with a `sum(breakdown) == total` test. But that equality test only proves *agreement* — a bug
in the shared helper makes both consistently wrong; keep **explicit expected-output fixtures** as the
primary check (the equality test is secondary). *Seen: the curated `shoulders`/`abdominals` split
overrides — an integrity test decoded `assets/exercises.json` and asserted all 60 ids exist + the split
token is really on each; a `Crunchez_typo` mutation was caught; un-curated tokens stay coarse-generic;
the body-map drill's `weeklyContributors` + `muscleBreakdown` share `creditPerSet` with the meter total,
guarded by fixtures + a per-key sum==total test (Codex F1/F2, 2026-06). **Corollary — when the
hand-authored layer is *redundant* with a self-describing source, delete it, don't just guard it:** if
every artifact already carries the canonical id as its filename (source + output files named by catalog
id), derive all paths from the id, **auto-discover** the sources, and **generate** the membership
manifest from what's on disk — one source of truth, not two parallel hand-maps in two languages that
must agree. Keep the integrity guard (every discovered source resolves to a real id *and* is registered)
so a dropped/misnamed file fails CI; prove it with a non-id source-file mutation. *Seen: the dual Python
`CLIPS` + Dart `_demos` demo maps — both re-encoding info already in the source filenames — collapsed to
id-derived paths + a generated `kDemoExerciseIds` over auto-discovered sources; source-coverage test
proven with a `__ghost_probe__.mp4` mutation (2026-06). **Corollary — enforce a cross-cutting CODE
convention the same way, not just hand-authored data:** a per-call-site opt-in ("pass a haptic intent
on every tap") is silently forgotten on a new surface (the Crest Forge shipped haptic-less). Ban the
bypass with a CI test — a **comment/string + depth-aware source scan** for the raw widget
(`GestureDetector(onTap:)`/`InkWell` outside the wrapper allowlist), a **shrink-only baseline** of
existing violations (never a central grandfather list that rots), and an explicit inline marker
(`// haptic-ok: <reason>`) so legit raw-gesture exceptions stay *visible*. Codex hardened a naive grep →
the depth/comment-aware scan + classify-not-grandfather (`tap_haptic_coverage_test`, 2026-06).*

### Analytics/telemetry event integrity
**Rule:** A funnel event emitted from a persistence chokepoint needs an explicit idempotency contract.
A **once-per-lifetime** event (activation / first-X) gates on a **persisted flag**, never a count over
**mutable** history — a delete/reset returns the count to its trigger value and re-fires it, corrupting
the exact cohort the event defines. A **per-entity** event **dedupes by id** (capture "row already
stored" *before* the write) so a retry / recovery / double-tap re-save can't double-count a conversion.
**Synthetic paths** (seed / demo / import / fixtures) must not emit — route them around the chokepoint,
or run them **before** the analytics sink is installed (a no-op-until-bootstrap facade only guards
*pre*-bootstrap). Duration/quantity params come from the **app's own truth**, never a platform proxy
(foreground engagement time mis-counts a backgrounded workout). *Seen: Phase-2 funnel wiring —
first_workout_saved made lifetime-once via a persisted flag (Codex F1), workout_saved deduped on
`alreadyCompleted` (F2), SEED_DEMO seed moved before bootstrap (F3), duration from
actualDurationSeconds not engagement_time_msec (2026-06).*

### Destructive bulk-data / codemod tooling
**Rule:** A script that edits a large shared data file or removes an entity across many wiring points
must: (1) **dry-run by default**, printing a unified diff — `--apply` writes; (2) **prove
format-preservation before writing** — round-trip the *unmodified* file and byte-compare (a generic
`json.dump`/serializer can silently reformat every entry and bury the one-line change); refuse on drift;
(3) be **transactional** — run *all* validation first (no writes), stage deletions into a backup dir +
hold text originals in memory, and **roll back on any exception** (git can't recover deleted
untracked/generated files in a dirty tree); (4) **refuse ambiguous destruction** rather than guess — a
*referenced* entity (a program lift) must be **replaced** (`--replace-with`, validated: target exists +
not already in the same slot), never silently dropped to a short list; (5) **warn, don't auto-edit,
bespoke data** (hand-tuned seed weights); (6) **reconcile the build MANIFEST, not just the data** —
assets/files declared *individually* in a build manifest (Flutter's per-folder `pubspec.yaml` asset
entries, because asset dirs are non-recursive) must lose their declaration when deleted, or the **build**
breaks even though tests + data look clean; guard with a declared-==-on-disk test. Use **quoted-exact
token** edits so `'X'` never matches inside `'X_2'`. Pair it with one **umbrella integrity test** asserting every cross-registry reference resolves
to the live source (+ per-entity structural invariants), proven red-green — the net that makes an
incomplete removal fail loudly in one place. *Seen: `ops/remove_exercise.py` (byte-stable JSON gate,
staged-deletion rollback, refuse-program-lift-without-replace, warn-on-seeder) + `catalog_integrity_test.dart`
(curated/programs/splits/manifest resolve + per-day uniqueness); Codex F1–F4; proven with dangling-id +
dup-suggested-id, and ghost-pubspec-declaration mutations. A `--from-file` batch prune of 741 non-curated
exercises surfaced the per-folder `pubspec.yaml` asset-declaration touchpoint the first audit missed —
the build broke on deleted-but-still-declared dirs while data tests stayed green, fixed + guarded after
(2026-06).*

### Widget-test lifecycle & prefs cross-test isolation
**Rule:** A new pref-gated feature trips three test-harness traps, none of them feature bugs. (a) A
`late`/lazy `AnimationController`/ticker field that a widget's `dispose()` is the **first** to touch
lazy-creates it *during* dispose → "Looking up a deactivated widget's ancestor is unsafe" (TickerMode
lookup on a dead element); **create tickers eagerly in `initState`**, never in a `late` field a
dispose-before-first-build can trigger (a real production crash too — any such widget torn down before it
ever animated). (b) `SharedPreferences.setMockInitialValues` updates the mock store but **not the cached
`getInstance()` singleton**, so a bool one test writes (or a *late* read after other getInstance calls)
reads **stale across tests** — passes in isolation, fails in-suite; fix by `clear()`-ing the instance in
`setUp` and **seeding through the prefs instance** (`setString`/the service `setEnabled`), not
setMockInitialValues. (c) Two `pumpWidget`s in one widget test **collide** when the page keeps
tickers/timers alive — **one pump per test**; and drive an async-pref-gated assertion through a path the
page *awaits* (an init seed, e.g. `initialMuscleGroups`) rather than a fire-and-forget tap, so the read
fully settles before the assertion (a lingering async fires during teardown). (d) A **transient overlay's lifetime dictates its test idiom**: a dart:async-`Timer`-held transient
leaks as a "pending timer" at teardown, so prefer ONE AnimationController spanning in→hold→out — but
that ticker lifecycle means `pumpAndSettle` runs the transient to completion and **the assertion must
happen mid-lifecycle with bounded pumps** (and the first pump after a `forward(from:)` is the ticker's
zero-frame — budget the segment's duration *after* it); never short-circuit the subtree at opacity 0,
or bare-`pump()` assertions across the suite find nothing. (e) A test that mounts a HEAVY page whose
init runs many real-async service reads through a **process-wide keyed lock** (`prefsWriteLock`) gets
**one scenario per FILE**: the first test's teardown can kill a future *inside* a lock's critical
section, stranding the static chain so every later same-process test that loads the page hangs on its
loading gate (passes alone, deadlocks in-suite — nothing to do with prefs values); and wait for such a
page via a **bounded poll-pump for a real widget** (`for … if (find.byType(X).isEmpty) runAsync(50ms)+pump`),
never one fixed delay. *Seen: Simple Mode —
`_SelectionCheckbox` controller moved to `initState`; prefs leak cleared + instance-seeded; curated-skip
driven via the awaited entry seed; two-state tests split to single-pump (2026-06); the arcade notice —
two shop tests asserted after `pumpAndSettle` and found nothing, the bare-pump contract broke on an
opacity-0 `SizedBox.shrink`, and a dismiss test missed the ticker zero-frame (2026-07); the room-camera
HomePage tests deadlocked in-suite via a stranded KeyedLock until split one-per-file + poll-pumped
(2026-07).*
