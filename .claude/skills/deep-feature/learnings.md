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
**Two persisted models of one concept** (a calendar-weekday schedule vs a sequence cursor) must reconcile
behind **one pure resolver consumed by both** — never let each consumer recompute the shared truth
(precedence drifts apart), and never let a live re-projection re-classify a *past* period that drives
economy (shields/streak/XP): read the **frozen per-period snapshot** so a schedule edit can't retroactively
penalize. Retire the dead field by **freezing + migrating it once** (gated bool); landing the migration
before its consumer leaves a stale reader. *Seen: zero-set idle reveal; selection clobbering a resumed
loadout; a 280 ms select-hold reacted on the wrong question after a Back; the weekday-anchored schedule
unified RestService×ProgramService via one `ScheduleResolver` + frozen `scheduleByWeekKey` + a
workoutIndex migration (2026-06).*

### Legacy-data cliffs
**Rule:** A new nullable field used in a threshold/comparison must define the null (legacy) case
explicitly — default to "never triggers" — with a legacy-fixture test. *Seen: null `lastActivityAt` would
time out every old session; warm-up `warmup` key → false (2026-06).*

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
filtered at every consumer (a missed reader silently inflates). *Seen: stat intensity; body-metrics
anchor; warm-up `warmup:<day>` then re-anchored to `ExerciseLog.warmupSets` (2026).*

### Decoupled id sources
**Rule:** When an id's uniqueness rode on a correlate you're removing (session id, per-day timestamp, boot
id), it collides once decoupled and a ledger keyed on it swallows the dup — re-base on
`microsecondsSinceEpoch + Random().nextInt(0x7fffffff)`; test the same-fixed-clock case. *Seen: Adventure v2 dispatch (2026-06).*

### Advisory/derived numbers
**Rule:** A number shown to the user must (a) be validated against its anchor and suppressed when the
relationship inverts (a warm-up ≥ the work set isn't one), and (b) be quantized to a real settable value
in the display unit — never a raw % or kg round-trip; don't assume one context's constant (bar weight,
plate size) fits all. *Seen: warm-up suggestion (2026-06).*

### Entity-keyed side-state lifecycle
**Rule:** Ephemeral state in a sibling store keyed by an entity id leaks/mis-applies unless cleared
wherever the entity row is removed/finalized in the storage layer — every terminal path, never at UI
buttons. Bonus: make a heavily-mutated field a read-only projection so stray writers fail `analyze`.
*Seen: program-swap store; `_selectedExerciseIds` getter (selection v2, 2026-06).*

### Deferred completion signals gate input
**Rule:** When a control becomes actionable the moment an animation/typewriter "completes", flip its
actionable flag in the **same frame** completion lands — notify **synchronously** from the timer/event
callback, not via an `addPostFrameCallback` that opens a one-frame window where the affordance looks
ready but a tap is mis-read (read as "skip", not "continue"). Defer **only** from true build-phase
callers (`didChangeDependencies`/`didUpdateWidget`, where a synchronous owner `setState` is illegal).
Likewise a value **latched** from an `InheritedWidget` (MediaQuery reduce-motion) on first build must be
**reconciled in `didChangeDependencies`** on later changes (don't early-return past the check) or a
mid-interaction toggle is silently ignored. *Seen: BIT typewriter tap-to-continue dropped the first tap
at the completion frame; reduced-motion toggled mid-type kept on typing (2026-06).*

### Navigation restructure: positional + always-present assumptions
**Rule:** Remapping nav slots, converting tabs→pushed routes, or removing a persistent shell surface
breaks hidden contracts: positional index callers misroute (migrate to a semantic destination API first),
reload-on-tab-switch stops (re-run reloads on pop), and modal gating assuming the shell route is current
gets starved (re-arm pending reveals on pop). Back any removed always-visible affordance with a safety
net. A **new pre-start/draft state** beside an existing entity must be gated by the authoritative
machine (a live session wins and clears the draft), funnel all launchers through **one entry API**
(pushed vs embedded must not diverge), and expose validity as the single synchronous commit gate.
*Seen: 4-places+center-Train shell (index→AppDestination, reloads/reveals re-fired on pop); in-shell
selection draft gated by the session machine via one openWorkoutDraft entry (2026-06).*
