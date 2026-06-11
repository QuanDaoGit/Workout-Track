---
name: deep-feature
description: Research-first pipeline for features and non-trivial fixes — route to helper skills, audit the code, research (domain accuracy + user/gamer psychology), compile an opinion, have Codex adversarially review the opinion and the plan, then implement behind the verification bar. Use when the user asks to add a feature, fix, improve, rework, or redesign any non-trivial part of the app.
---

# Deep Feature Pipeline

Run the stages **in order**. This is the process that produced the workout-logs redesign and the
stat-engine intensity rework — keep its shape.

## Carve-out (check first, risk-based)

A change may skip stages 0 and 2–4 **only if** it is non-behavioral text or formatting with no
impact on state, navigation, persistence, scoring/XP/stats, accessibility, or design tokens
(typos, comment edits, doc wording). **State in one line why the change qualifies** before
skipping; then implement and run `flutter analyze` + `flutter test`. A one-liner that touches
validation, rewards, persistence, or theme tokens is NOT trivial. When unsure, it isn't.

## Stage tracking (enforcement)

At start, create one TodoWrite/Task item per stage. A stage is complete only when its named
artifact exists in the conversation. Hard gates:

- No plan before the Stage-4 CHALLENGE findings are resolved.
- No implementation before an approved plan.
- No completion claim before analyze/test/review outputs are shown.

## Stage 0 — Skill routing

Classify the task, check the **session's available-skills list**, and invoke the matching
helpers. Reference by capability; the named skill is the current best fit — if it is missing
from the session list, skip it with a note, never block on it.

| Task signal | Capability → current best skill |
|---|---|
| Vague/new feature, unclear requirements | Brainstorming → `superpowers:brainstorming` (fires before everything else) |
| UI / visual / screen work | Design critique → `design:design-critique`; UI/UX reference → `ui-ux-pro-max` (Flutter stack); Accessibility → `design:accessibility-review`; In-app copy → `design:ux-copy` |
| Bug fix / unexpected behavior | Root-cause discipline → `superpowers:systematic-debugging` |
| Implementation phase | TDD → `superpowers:test-driven-development`; Done-claims → `superpowers:verification-before-completion` |
| Stuck / second implementation opinion | `codex:rescue` |

Known-incompatible with this app/environment (do not route to these; reasons checked 2026-06):
`uxaudit` (needs a browser-drivable running app; Flutter web preview cannot render/screenshot
here), `mobile-observability` (pre-launch, no telemetry backend), `brand-voice` / `marketing:*`
(they serve the `marketing/` folder, not app code), `figma:*` (no Figma sources in this repo),
`huggingface:*` (no ML).

*Artifact: one line per selected skill, or "none apply" + reason.*

## Stage 1 — Audit

Read the relevant code before forming any view: `docs/PRD.md` for scope, the owning service(s)
in `lib/services/`, the models/data involved, and the tests pinning current behavior. Name
concrete problems with `file:line` evidence. Separate **defects** from **deliberate design
intent** (e.g. Tank=END radar identity is intent) — intent questions go to the user, not into a
"fix". *Artifact: numbered problem list.*

## Stage 2 — Research (evidence standard)

Default: **3+ web investigations per identified problem area** for product mechanics and UX.
Priorities, in order:

1. **Domain accuracy** — exercise-science literature for anything touching mechanics
   (volume-vs-intensity, e1RM validity, strength standards, detraining). Physiological claims
   require primary or authoritative sources, not blog consensus.
2. **User + gamer psychology** — SDT/competence, loss aversion + forgiveness (Duolingo streak
   research), sunk-cost/identity investment, "players will optimize the fun out of a game".
3. **Leading apps** — Strong/Hevy for tracking mechanics, Duolingo-class for habit mechanics —
   only where real market precedent exists.

Purely internal engineering defects (cache bugs, refactors, test gaps) may skip external
research with a one-line justification. Cite sources as markdown links. Remember: accuracy and
the hook usually point the same way — a farmable stat undermines the competence signal that
makes the number satisfying. *Artifact: findings grouped per problem, with links.*

## Stage 3 — Opinion

Synthesize a recommendation with explicit tensions/tradeoffs (accuracy vs hook is this app's
recurring axis). Separate engineering calls (yours) from intent calls (the user's). State what
you would change, what you would keep, and why. *Artifact: the opinion section.*

## Stage 4 — Codex adversarial review (opinion, then plan)

Review the **opinion** before planning, and the **plan** before implementation, in the
foreground via the codex plugin (`/codex:adversarial-review` flow). Stable rules:

- Carry the full design context (current behavior + proposal) **in the prompt** — never assume
  the reviewer can read the repo.
- End the prompt with a numbered **CHALLENGE** list naming the weakest assumptions: migration
  cliffs, exploit surfaces, hook regressions, missing-data fallbacks.
- Treat findings as design input, not a gate to argue past — revise the design before planning.
  (The stat rework reversed its core mechanism — bounded e1RM tiers → cumulative intensity
  currency — because of this step.)
- Consult `.claude/codex-local.md` **if present** for machine-specific invocation constraints
  (sandbox limitations, scoping flags, plugin path).

*Artifact: verdict + a finding→resolution table. Gate: no plan until findings are resolved.*

## Stage 5 — Plan → implement → verify

1. Enter plan mode; write the Codex-hardened plan (context, changes, files, reuse list,
   verification); get approval.
2. Implement to the CLAUDE.md bar: `flutter analyze` zero issues, `flutter test` all pass, new
   fixture tests per user archetype (beginner / veteran / calisthenics / missing-data) where
   mechanics changed, tokens-only colors, sharp icons.
3. The Codex stop-time review gate fires automatically at turn end; after committing, also run
   `/codex:review --wait` for a diff-grounded review (see `.claude/codex-local.md` for why the
   automatic gate may be weaker than it looks on this machine).
4. Update the affected docs (`docs/stats-mechanics.md`, `docs/PRD.md`) in the same change —
   reconcile against code before writing, per `docs/CLAUDE.md`.

*Artifacts: approved plan; analyze/test output; review verdict.*
