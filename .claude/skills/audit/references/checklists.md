# Audit checklists — per track

Each subagent gets ONE track's list. The **IGNORE** column is as important as LOOK-FOR — telling the
model what *not* to flag is where false positives die. Anchor every flag to evidence.

## Deterministic lint (model-free — run as grep/asserts, not judgment)

| Check | How | Anchor |
|---|---|---|
| Hard-coded colors | `Grep` `0xFF[0-9A-Fa-f]{6}` / `Color(0x` / `Colors\.` in `lib/pages` & `lib/widgets` — every hit not in `theme/tokens.dart` is a token violation | `file:line` |
| Layout overflow | `captureSurface` records `RenderFlex overflowed` / `FlutterError` during pump | scenario name + error text |
| Tap targets < 48px | measure `GestureDetector`/`InkWell`/icon-button hit area in the rendered tree | `file:line` + size |
| Rounded Material icons | `Grep` `Icons\.[a-z_]+` NOT ending `_sharp` (CLAUDE.md icon rule) | `file:line` |
| Missing semantics on interactive | image-only buttons / custom-painted controls with no `Semantics` label | `file:line` |
| Non-integer pixel-art scale | `Image`/`IronbitAvatar` sized at a non-integer multiple of its native grid | `file:line` |

## Presentation (grounded in a rendered PNG — `Read` it, frame adversarially: "what is WRONG here")

LOOK FOR: misaligned edges/baselines; inconsistent spacing rhythm (not on the 4/8/12/16/24 scale);
weak hierarchy (everything same weight / "everything is a chip"); low contrast text on `kCard`/`kBg`;
clipped or truncated labels; orphaned/awkward wrapping; competing focal points; crammed density;
inconsistent corner radius (should be `kCardRadius` 4); color used to mean two things at once.

IGNORE: the locked pixel-arcade aesthetic itself (CRT scanlines, neon glow, mono timers are intent,
not slop); deliberate body-neutral muting (no red/green deltas); the palette in `tokens.dart`; motion
(a still PNG can't judge it — defer to on-device); anything in `references/exceptions.md`.

## Journey (grounded in a multi-screen capture sequence)

LOOK FOR: dead ends / no way back; lost back-stack; a step that doesn't carry state forward; missing
empty / loading / error states; a destructive or irreversible action with no confirm (and the inverse —
a confirm on a frequent reversible action = cry-wolf); inconsistent affordance for the same action
across screens; an onboarding step that blocks on data it never collected.

IGNORE: cosmetic per-screen issues (those are the Presentation track's job); intended friction (a
two-gate consent is deliberate).

## Correctness (oracle-driven — NEVER "the code says X")

For each computed value (XP, level, e1RM, volume, calories, coverage sets, streak, decay, gem totals):
1. **Known-answer fixture** — compute the expected value from the rule in `docs/` (e.g.
   `docs/stats-mechanics.md`) and assert the service returns it. A doc/code mismatch is a finding
   regardless of which is "right" (it means one is wrong).
2. **Invariants** — bounds (XP ≥ 0, e1RM ≥ top set weight, multiplier ≤ cap), monotonicity (more
   volume ⇒ ≥ XP), conservation (session volume == Σ set volume), idempotency (re-saving the same
   session id doesn't double-count).
3. **Independent recompute** — a few lines that re-derive the value WITHOUT calling the service; diff.

IGNORE: display rounding that matches the documented precision; deliberate non-linearity that the
docs/PRD specify.

## State / integration (code + a replayed session through real APIs)

LOOK FOR: a value that survives a kill it shouldn't (or doesn't survive one it should); resume that
drops logged sets/warm-ups; a migration that isn't idempotent; a reward granted twice; a cache that
disagrees with its source of truth (e.g. a meter total vs the rollup it claims to show); a write with
no `changes` signal where a listener needs it.

IGNORE: ephemeral UI state that's supposed to reset; intentionally non-persisted fields.
