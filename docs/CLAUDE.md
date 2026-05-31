# docs/ — Agent operating brief

You are working in the **product & spec hub**. This folder defines *what and why*, not *how*.

## Purpose
Hold the durable product intent: requirements (PRD), rationale (PRODUCT), feature specs/plans,
and decision records. A future agent should be able to read here and understand the product
without reading code.

## What lives here
- `PRD.md` — requirements, scope, shipped vs out-of-scope. Update when scope changes or a feature ships.
- `PRODUCT.md` — the soul rule and the *mechanics* rationale (stat math, class bonuses, overload). Update when mechanics change.
- `superpowers/plans/` — dated feature specs (frozen once shipped; do not rewrite history).
- `decisions/` — ADRs.

## How to work here well
1. **Reconcile before writing.** Before editing PRD/PRODUCT, verify claims against the code
   (`lib/services/`, `lib/theme/tokens.dart`). These docs went stale once already — keep them honest.
2. **Don't duplicate the root CLAUDE.md.** Architecture, tokens, and file layout are *its* job.
   Link to it; don't restate it.
3. **Respect the soul rule.** "Real workout data is the only input to character growth." Any spec
   that adds RNG, manual-confirm quests, or non-training inputs contradicts PRODUCT.md — flag it.
4. **Keep PRD current-state accurate.** It is the "read first" doc per the root working rules.
   The 6th stat (END), classes, guild, onboarding, loot, programs, body metrics are all *shipped*.

## Do NOT
- Invent features. Scope changes go through the user first (root working rule).
- Hard-code palette hex into docs — reference `lib/theme/tokens.dart`.
- Rewrite a shipped plan in `superpowers/plans/` — write a new dated plan instead.
