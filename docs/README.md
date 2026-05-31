# docs/ — Product & Spec hub

The single home for **what we're building and why**. Implementation truth (tokens, services,
file layout) lives in the root [CLAUDE.md](../CLAUDE.md); this folder holds product intent.

## Contents

| File / folder | What it is |
|---|---|
| [PRD.md](PRD.md) | Product requirements — scope, intent, shipped features, out-of-scope. The "read this first" doc. |
| [PRODUCT.md](PRODUCT.md) | Product/design rationale — the soul rule, muscle taxonomy, stat/XP math, class bonuses, overload logic. |
| [superpowers/plans/](superpowers/plans/) | Reconciled feature specs & implementation plans (dated, archival once shipped). |
| `decisions/` | Architecture & product decision records (ADRs). Empty until the first decision is logged. |

## Conventions
- Dated specs: `superpowers/plans/YYYY-MM-DD-<topic>.md`.
- Decisions: `decisions/NNNN-<slug>.md` (sequential), short and immutable once accepted.
- When a feature ships, update [PRD.md](PRD.md)'s "Shipped Features" rather than letting it drift.

See [CLAUDE.md](CLAUDE.md) in this folder for the agent brief on maintaining these docs.
