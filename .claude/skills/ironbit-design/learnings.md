# Ironbit design learnings — recurring UI/UX failure modes

Maintenance gate (per task): read this before designing; after, add **at most one** learning, and only
if it would have prevented a concrete defect or a repeated review finding. **Generalize, never
transcribe** — an entry is a reusable category. Search the headings first and **update the matching
category over appending a near-duplicate**; include the date/trigger. Cap ~40 content lines below this
header; when over, prune the least-recently-fired category **in the same edit**. End the task by
stating "No new design learning" or the category you touched.

### Foreign-shape tells
**Rule:** A perfect circle, a smooth diagonal bevel, a stock rounded-rect, or any Material-default
shape reads as *foreign* in a pixel-arcade app (a circle in particular screams "Material FAB"). For
distinctive shapes use a **4px / pixel-staircase cut-corner** geometry painted `isAntiAlias = false`
so the steps stay crisp. *Seen: the round center Train button → pixel-stepped keycap (2026-06).*

### Raw color & alpha literals
**Rule:** Raw color belongs only in `tokens.dart`. Everywhere else, import a token and express tints as
`token.withValues(alpha: …)` — a raw `Color(0x..)` / `.withOpacity` tint of a token is *still* raw hex
and drifts when the token changes. Grep changed files for `Color(0x` / `withOpacity` at finish-time;
add a shared token if no shade fits, don't inline. *Seen: `Color(0x0A00FF9C)` for an AmbientDrift tint
instead of `kNeon.withValues(alpha: 0.04)` (2026-06 eval).*

### Motion salience budget
**Rule:** Distraction ≈ velocity × contrast × size × count. Match the dials to the role — focal events
can be loud; an ambient "available/ready" cue under a surface the user is working in must keep **all
dials low** (slow, dim, small, few: one drifting element beats a sweep/bob/marching border). A looping
scale-pulse is a lazy "notice me" that conveys nothing and isn't in the vocabulary — reach for the
CRT/phosphor idioms, and lower the dials rather than picking a louder shape. *Seen: scale-pulse, then
sweep/bob rejected as too strong; ambient motes chosen for the armed Train state (2026-06).*

### Contrast by luminance, not hue
**Rule:** Legibility of particles/text/icons on a fill is driven by **luminance** contrast. On a
*bright* surface, a pale/near-white tint washes out — go dark-on-bright (and vice versa). Two bright
hues still have low luminance contrast. *Seen: near-white motes invisible on the neon keycap →
dark-green motes, denser (2026-06).*

### Information over decoration
**Rule:** When a surface needs an "active/alive" cue, make the motion **carry state** (a live timer, a
progress sweep) rather than pure decoration — it earns its motion and often recovers information lost
elsewhere. *Seen: the live Train button shows mm:ss, which also gave back the timer lost when the
persistent dock was removed (2026-06).*

### No redundant chrome bands
**Rule:** Don't add a label/hint strip that restates what an adjacent surface already shows — it
stacks a third band between content and chrome. Fold the cue **onto its element** (e.g. a caption that
changes state) instead. *Seen: the "READY · TAP TRAIN" hint bar removed; cue moved to the keycap
caption TRAIN→START (2026-06).*

### Reduced-motion needs a non-motion fallback
**Rule:** Freezing an animation under `disableAnimations` must leave a **still, legible signal** — a
label, a static frame, a Semantics announcement — never a dead/ambiguous control. Design the
no-motion state first, then add motion on top. *Seen: armed Train falls back to the START caption +
Semantics label when motion is off (2026-06).*

### Reach for the app's own primitive first
**Rule:** Before painting anything new, glob `lib/widgets/` + `widgets/motion/` and read the **nearest
existing surface** — the best style reference is the app's own code, not a generic catalog. Compose
from primitives (`PixelButton`, `ArcadeChip`, the motion wrappers, `arcade_route`, `neonGlow()`);
paint bespoke only when nothing fits, and then in the language. *Seen: keycap/motes/dioramas reused the
motion + token vocabulary rather than stock components (2026-06).*
