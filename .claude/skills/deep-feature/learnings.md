# Deep-feature learnings — recurring failure modes from Codex reviews

Maintenance: **generalize, never transcribe** (feature-specific findings stay in the plan doc).
Update an existing category over adding a near-duplicate. Cap ~40 content lines below this header;
when full, prune the least-recently-fired category.

### Fire-and-forget write races
**Rule:** An unawaited write that can land after a later read-modify-write on the same prefs key
resurrects/clobbers state — track in-flight writes and drain them on every exit path before the final
write. *Seen: idle checkpoint racing `saveSession` (2026-06).*

### Dual-path divergence
**Rule:** When 2+ paths handle one event or seed one field (foreground vs cold-reopen, manual vs auto,
resume vs repeat vs history), pin a once-only precedence + a "user touched it → never auto-reseed" guard,
and test every path. *Seen: zero-set idle reveal; selection clobbering a resumed loadout (2026-06).*

### Legacy-data cliffs
**Rule:** A new nullable field used in a threshold/comparison must define the null (legacy) case
explicitly — default to "never triggers" — with a legacy-fixture test. *Seen: null `lastActivityAt` would
time out every old session; warm-up `warmup` key → false (2026-06).*

### Settlement/presentation coupling
**Rule:** When a reward resolves on a later surface, settle the data (award, persist, mark unviewed)
independently of the ceremony and auto-settle on the next earn — a blocked/unseen ceremony must never
block or burn the next earn. *Seen: Adventure pending expedition (2026-06).*

### Asset-dependent core surfaces
**Rule:** A surface newly depending on bundled images needs per-image errorBuilder fallbacks + a manifest
test that loads every registry path; Flutter asset dirs are non-recursive — declare each subfolder.
*Seen: Adventure diorama/emblems; v3 body/ subfolders (2026-06).*

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
