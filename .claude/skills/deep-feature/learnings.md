# Deep-feature learnings — recurring failure modes from Codex reviews

Maintenance rules: **generalize, never transcribe** — an entry is a reusable category, not a
feature-specific finding (those stay in the feature's plan doc). Update an existing category
instead of adding a near-duplicate. Cap ~40 content lines below this header; when full, prune
the category that has fired least recently.

### Fire-and-forget write races
**Rule:** Any unawaited write that can land after a later read-modify-write on the same
SharedPreferences key resurrects or clobbers state. Track in-flight writes and drain/await them
on every exit path before the final write.
*Seen: idle checkpoint racing `saveSession` (2026-06, idle auto-save diff review).*

### Dual-path divergence
**Rule:** When two+ code paths handle the same event OR seed the same state field (foreground vs
cold-reopen; manual vs auto; resume vs repeat vs history-default), pin edge cases to one written
rule and give shared state an explicit, once-only precedence plus a "user touched it → never
auto-reseed" guard. Test every path.
*Seen: zero-set idle prompted on foreground but silent on reopen; exercise-selection default
loadout could clobber a resumed/repeat selection without precedence (2026-06).*

### Legacy-data cliffs
**Rule:** A new nullable field used in a threshold or comparison must define the null (legacy)
behavior explicitly — default to "never triggers", and add a legacy-fixture test.
*Seen: null `lastActivityAt` would have instantly timed out every pre-existing session (2026-06).*

### Reconstructed-value inflation
**Rule:** Credit/reward values must be captured at the moment of the event and stored, never
re-derived later from timestamp arithmetic — resumes and backgrounding inflate the derived value.
*Seen: idle credited duration originally computed as `lastActivityAt - startedAt` (2026-06).*

### Settlement/presentation coupling
**Rule:** When a reward resolves on a *later* surface (pending-reveal patterns), settle the data
(award, persist, mark unviewed) independently of showing the ceremony — and make the next earn
event auto-settle first. A blocked/unseen ceremony must never block or burn the next earn.
*Seen: Adventure pending expedition would have silently cost a dispatch day (2026-06).*

### Asset-dependent core surfaces
**Rule:** A core surface that newly depends on bundled images needs per-image errorBuilder
fallbacks AND a manifest test that `rootBundle.load`s every registry path — pubspec misses and
renames fail in CI, not on device.
*Seen: Adventure diorama/emblems on Home (2026-06).*

### Farmable reward surfaces
**Rule:** Any new reward path needs an explicit anti-farm bound consistent with existing bars
(the 1-set Finish bar, rolling reward anchors, decaying high-water floors). Ask "what is the
cheapest action that triggers this reward repeatedly?"
*Seen: stat-engine intensity rework; body-metrics weekly reward anchor (2026).*

### Decoupled id sources
**Rule:** When an id's uniqueness silently rode on a correlate you're removing (session id,
per-day timestamp, boot id), it collides once decoupled — and a ledger keyed on it swallows the
duplicate. Re-base on an independent source (`microsecondsSinceEpoch` + `Random().nextInt(0x7fffffff)`,
never `1<<32`); test the worst case (same fixed clock). *Seen: Adventure v2 manual dispatch (2026-06).*
