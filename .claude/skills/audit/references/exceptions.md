# Design-system intent ledger (reconciliation exceptions)

Reconciliation (workflow step 4) uses this to **downgrade/tag** findings that are deliberate intent —
**never to delete**. An exception must be **exact + validated**: it names the page/region, the
rationale, an owner/date, and **the constraint that must still hold**. If the current instance violates
that constraint, the exception does NOT apply and the finding stands. Broad entries ("ignore red") are
forbidden — they re-create the blind spot reconciliation exists to avoid.

Format:
```
- id: <slug>
  where: <page / region>
  intent: <one line>
  constraint: <what must still be true for this to remain intentional>
  owner/date: <who / when validated>
```

## Entries

- id: vit-red-heart
  where: Profile/Labs stats — the VIT recovery meter heart icon only
  intent: VIT uses a red HEALTH heart on purpose (health, not danger); it is not a `kDanger` misuse
  constraint: red appears ONLY on the VIT heart glyph; any OTHER red on a non-danger element, or the
    heart drifting to mean "error/danger", is still a finding
  owner/date: project memory `vit-red-heart-intentional` / 2026-06

- id: body-neutral-no-rg-deltas
  where: weight / body-metrics surfaces, stat deltas
  intent: no red/green good-bad coloring on weight arrows or deltas (body-neutral mandate)
  constraint: directional indicators stay muted/mono; a NEW red/green delta anywhere is a finding,
    not "fixed by this exception"
  owner/date: docs Phase-7 decision #5 / 2026-06

- id: pixel-arcade-aesthetic
  where: app-wide visual language
  intent: CRT scanlines, neon glow, `PressStart2P` headings, mono timers, 4px radius, sharp icons are
    the locked aesthetic — not slop to "modernize"
  constraint: applies to the deliberate motifs only; misaligned/clipped/low-contrast instances of them
    are still findings (intent ≠ a pass for poor execution)
  owner/date: CLAUDE.md theme + icon rules / 2026-06

- id: pixel-art-painter-palettes
  where: procedural pixel-art / sprite painters — `widgets/avatar/*`, `widgets/companion/*`,
    `widgets/room/*`, `widgets/adventure/bit_route_walker.dart`, `*_icon.dart` sprite painters
  intent: these paint pixel art (skin/hair/sprite shading, glows, FX gradients) that intrinsically
    needs its own literal color palette — the "tokens only" rule targets UI CHROME (cards, buttons,
    text), not asset painters
  constraint: applies to CustomPainter/pixel-sprite files only; a regular page/chrome widget hardcoding
    a hex that matches a token (kBg/kCard/kNeon/etc.) is STILL a finding — don't let this exempt lazy
    chrome. When unsure if a file is "art" or "chrome", it's chrome.
  owner/date: app-wide-audit sweep.theme / 2026-06-26

- id: no-xp-recompute-on-edit
  where: Workout Logs edit flow
  intent: editing a past session does NOT recompute its XP/stats (deliberate, anti-exploit)
  constraint: applies to edit-of-past only; a NEW-session miscompute is still a Correctness finding
  owner/date: project memory `workout-logs-redesign` / 2026-06
