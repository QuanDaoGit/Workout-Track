# Coverage ledger format

The ledger is the run's **single source of truth and checkpoint**. It lives at
`audit-runs/<run-id>/ledger.md`, is rewritten after every unit, and is what a resumed run reads to find
the next `pending` row. Keep it a plain markdown table — human-readable and trivially re-parsed.

## File header

```markdown
# App-Wide Audit — run 2026-06-26
status: in-progress        # in-progress | complete
started: 2026-06-26
units: 12 done / 71 total  # update on every checkpoint
grounded: 9 screens rendered, 3 code-only
```

## The table

| col | meaning |
|---|---|
| `id` | stable unit slug (e.g. `screen.profile`, `system.xp`, `flow.onboarding`, `data.programs`, `sweep.theme`) |
| `type` | screen / flow / system / data / sweep |
| `source` | the file(s) or area it covers |
| `tracks` | which `audit` tracks apply (presentation / journey / correctness / state / lint) |
| `prio` | P0 core-loop · P1 important · P2 long-tail (sets run order) |
| `status` | `pending` → `in-progress` → `done`; or `blocked` (can't render/seed yet — note why) |
| `findings` | count + max severity once done (e.g. `4 · major`) |
| `evidence` | path to the unit's findings file / rendered PNG |

```markdown
| id | type | source | tracks | prio | status | findings | evidence |
|----|------|--------|--------|------|--------|----------|----------|
| flow.onboarding | flow | pages/onboarding/* | journey | P0 | pending | — | — |
| screen.home | screen | pages/home.dart | presentation,lint | P0 | pending | — | — |
| system.xp | system | services/xp_service.dart | correctness,state | P0 | pending | — | — |
| data.loot | data | data/loot_registry.dart | correctness | P1 | pending | — | — |
| sweep.theme | sweep | app-wide | lint | P1 | pending | — | — |
```

## Rules

- **Single writer.** Only the orchestrator writes `ledger.md`. Workers write their own
  `units/<unit>.md` + a `MANIFEST` line (see `worker-contract.md`) and nothing else. This is what makes
  parallel fan-out safe — concurrent workers can't race on the checkpoint.
- **Reconcile per batch, atomically.** After a parallel batch returns, the orchestrator re-reads the
  ledger, parses each worker's `MANIFEST`, **validates the claimed `done` against the existence of its
  `units/<unit>.md`** (a `done` with no file → treat as `blocked`), updates the rows + header counts,
  and writes via **temp-file-then-rename**. One batch = one atomic ledger write. Never patch from a
  stale snapshot — re-read first. A crash mid-batch loses at most that batch, which re-runs cleanly.
- **Resume, don't restart:** on entry, if a ledger with `pending` rows exists, continue from the first
  `pending`/`in-progress`. Re-running a `done` unit is wasted work; only redo if the source file changed
  since (note the reason).
- **Completeness check:** before the first audit, assert every `lib/pages/**` and `lib/services/**` file
  appears in some row (glob vs ledger diff), AND run the step-1 drift checks for flows/sweeps. A missing
  source file = incomplete ledger = fix first; a drift-surfaced item with no row → the `unmapped`
  section.
- **`blocked` is a visible gap,** never a silent skip — it shows in the master report's coverage stat
  and forces `verdict: incomplete` if it's a P0/P1.
