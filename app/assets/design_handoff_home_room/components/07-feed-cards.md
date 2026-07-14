# Component · Feed Card (below the fold)

Below the room sits a minimal card feed. At launch there is **one** card — today's
training prompt — deliberately peeking above the fold as the scroll cue. The feed is a
*companion* to the room, **not** the home itself (principle 1: one world, not eight cards).

## Markup

```html
<div class="feed">
  <div class="card mission-card">
    <div class="card-label">Today's muscle</div>
    <div class="card-title">UPPER BODY</div>
    <div class="card-chips">
      <span class="chip">CHEST</span>
      <span class="chip">BACK</span>
    </div>
    <div class="card-footer">
      <span class="card-meta">5 exercises · ~45 min</span>
      <span class="card-cta">START ON TRAIN <span>&rarr;</span></span>
    </div>
  </div>
</div>
```

## Anatomy

| Part | Font / color | Purpose |
|---|---|---|
| `.card-label` | small, muted | section kicker ("Today's muscle") |
| `.card-title` | PressStart2P, bright | the focus ("UPPER BODY") |
| `.chip` | ShareTechMono pills | sub-tags (CHEST, BACK) — flex row with `gap` |
| `.card-meta` | ShareTechMono, muted | terse facts ("5 exercises · ~45 min") |
| `.card-cta` | mint `#00FF9C` | action → routes to TRAIN |

`.feed` is `background:#11111F; padding:14px 16px 28px; display:flex; flex-direction:column;
gap:14px` — so additional cards stack with consistent spacing.

## Rules

- **The room is home, the feed supports it.** Keep the feed minimal; don't migrate room
  systems (Quests, Expedition, collection) back into cards (GUARDRAILS #5).
- The first card must **peek above the fold** (the room's `calc(100% - 58px)` height is
  tuned for this) — it's the Finch scroll cue. Don't let the room fill the whole viewport.
- **No filler cards.** One real, useful prompt beats a wall of widgets (GUARDRAILS #12).
- CTA copy ties to the nav: "START ON TRAIN →" points at the raised TRAIN button.
- Chips use a flex row with `gap` — not inline-block siblings.

## Native notes

A `Column` (or `SliverList` if the feed grows) under the room in one scroll view. Card =
`Container` with the token radius/elevation; chips = a `Wrap`/`Row` with `spacing`. CTA =
a `TextButton` routing to the training flow.
