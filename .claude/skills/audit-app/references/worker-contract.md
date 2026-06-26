# Worker dispatch contract

A subagent starts **cold** — it has none of the campaign's context. "Follow the audit skill" as a bare
pointer produces shallow, code-reading findings dressed up as real ones. Every dispatch MUST inline
this contract so the worker either produces grounded evidence or refuses. Fill the `<…>` fields per
unit from the ledger + `taxonomy.md`.

## Dispatch template (paste into the Agent prompt)

```
You are auditing ONE unit for an app-wide audit campaign. Do NOT inventory the app or audit anything
beyond this unit.

UNIT:        <id, e.g. screen.profile>
TYPE:        <screen | flow | system | data | sweep>
SOURCE:      <file path(s)>
TRACKS:      <presentation | journey | correctness | state | lint — only these>

METHOD: Read .claude/skills/audit/SKILL.md and its references/ (checklists.md, scenarios.md,
exceptions.md) and apply them to THIS unit only.

REQUIRED EVIDENCE (a finding without one of these is INVALID — drop it):
- presentation/journey → a rendered PNG. Write a scenario via test/audit/audit_capture.dart
  (seed with real service APIs; smokeText = a loaded-state string), run
  `flutter test --update-goldens test/audit/<file>`, then Read test/audit/_shots/<name>.png.
- correctness → an independent ORACLE (a known-answer from docs/<doc>.md, an invariant, or a separate
  recompute that does NOT call the service). Cite the oracle mismatch, never "the code says X".
  Oracle hints for this unit: <e.g. Epley e1RM ≥ top-set weight; gems idempotent-by-id>.
- state → a replayed session through real service APIs (save → kill/reload → assert).
- lint → grep results / captured overflow errors with file:line.

OUTPUT — write a findings file at audit-runs/<run-id>/units/<id>.md containing:
- a findings list, each: severity (blocker|major|minor|nit) · confidence · track · evidence
  (png path#region | file:line | oracle-mismatch) · claim · fix. Apply references/exceptions.md
  (downgrade, never delete).
- a final MANIFEST line (exact format):
  MANIFEST status=<done|blocked> findings=<N> maxSeverity=<blocker|major|minor|nit|none> evidence=<path>

REFUSAL: if you cannot produce the required evidence for a track (no render possible, no oracle
derivable), set status=blocked, state why in one line, and do NOT emit guessed findings. A blocked
unit is honest; a fabricated one corrupts the campaign.

Do NOT write or modify audit-runs/<run-id>/ledger.md — the orchestrator owns it.
```

## Why each clause exists

- **"ONE unit, do not inventory"** — stops a worker from re-expanding into a whole-app campaign
  (`audit`'s app-wide step is removed, but a worker could still over-reach without this).
- **"REQUIRED EVIDENCE / drop it"** — the anti-rubber-stamp clause; code-reading masquerading as a
  finding is the exact failure the campaign exists to prevent.
- **"MANIFEST line"** — the machine-checkable handshake the orchestrator parses to update the ledger;
  no manifest ⇒ treat as `blocked`.
- **"REFUSAL"** — a `blocked` is a visible coverage gap; a fabricated finding is invisible rot.
- **"Do NOT modify ledger.md"** — single-writer discipline; prevents the parallel-write races that
  would corrupt the only checkpoint.
