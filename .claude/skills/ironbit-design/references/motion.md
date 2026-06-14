# Ironbit motion — transitions, micro-interactions, and the salience model

Motion is where this app is most distinct and where it's easiest to go wrong. Two rules govern
everything here:

1. **Motion conveys state or meaning, never decoration.** A thing moves because something changed,
   because it's *active*, because you can act on it, or to carry spatial continuity between screens.
   "Make it move so it looks alive" is not a reason — find the *state* the motion represents.
2. **Every animation must survive reduced motion.** When `MediaQuery.of(context).disableAnimations`
   is true, freeze the motion and leave a **still, legible signal** (a label, a static frame, a
   Semantics announcement). A frozen control must still tell the user what it is and what it does.

## The salience model — how loud should this motion be?

The reason a motion feels "distracting" vs. "alive" is **salience**, and salience scales with four
independent dials:

> **distraction ≈ velocity × contrast × size × count**

- **velocity** — how fast it moves (and how abruptly it starts/stops; abrupt onsets capture the eye).
- **contrast** — luminance/color difference of the moving part against its background.
- **size** — how big the moving element is.
- **count** — how many things move at once.

Peripheral vision is tuned to motion, so a fast, high-contrast, large, or multi-element animation in
the corner of the eye **involuntarily pulls a glance** — fine for a focal event, wrong for an ambient
"available" cue while the user is reading something else.

**To choose the right loudness, match the dials to the role:**

| Role | Example | Dials |
|---|---|---|
| **Focal / event** — demands attention now | a level-up flash, a reward reveal, an error shake | high velocity/contrast OK, brief, then resolves |
| **Active / state** — "this is happening" | a live workout timer + marching segment ring | medium; carries *information*, sits where the eye already is |
| **Ambient / available** — "ready when you are", peripheral | the armed Train keycap's drifting motes | **all dials low**: slow, dim, small, few |

When something must move *constantly* without nagging (an "armed/ready" state under an area the user
is working in), keep **one** small, slow, low-contrast element — a single drifting mote beats a sweep,
a bob, or a marching border (those are too strong, and a marching border also collides with the
*active* state's vocabulary). Don't reach for a louder *shape* of motion to be noticed; lower the
dials.

## The Ironbit motion vocabulary (reach for these idioms)

The app's feel is **CRT / phosphor / arcade-cabinet**, not Material ripple or iOS spring. Compose
from these idioms (most are wrapped in `lib/widgets/motion/` — read those first):

- **Hold-depress** (`hold_depress`) — a physical press-down; the canonical tap feedback for buttons
  and cards. Pairs with a pressable "depth" face for keycap-style controls.
- **Phosphor tap / flash** (`phosphor_tap`, `strobe_flash`) — a brief glow bloom on tap or on a
  moment of impact (e.g. a stat gain). The CRT analogue of a ripple.
- **Ambient drift** (`ambient_drift`) — slow particle/mote drift for low-salience "alive" surfaces.
- **Power-on / focus frame** (`power_on`, `focus_frame`) — CRT power-on reveals and animated bezels.
- **Breathing glow** — a `neonGlow()` halo whose blur sigma slowly breathes (filter/`MaskFilter`
  drift), for an "energized/live" surface. Breathe the *halo*, don't scale the geometry.
- **Marching segments** — a dashed neon stroke whose phase advances around a path (PathMetrics dash
  offset) — reserved for the **live/active** state (it reads as "running"). Don't reuse it for
  ambient/ready, or the two states blur together.
- **Pixel-stepped geometry** — distinctive shapes use a staircase cut-corner, painted
  `isAntiAlias = false` so the steps stay crisp; segmented/stepped sweeps over smooth conic ones to
  match the pixel cadence. Round/circle is a foreign tell.

Avoid: a looping **scale-pulse** (the lazy "notice me" — it conveys nothing and isn't in the
vocabulary), animating width/height/top/left (jank + reflow), smooth glossy spinners (use
`pixel_loader`), and decorative parallax.

## Transitions between screens

Use `arcade_route` (`ArcadeRouteMotion.flow / fade / reveal`) rather than bare `MaterialPageRoute`, so
transitions stay in-language. Keep spatial logic consistent (forward vs. back), keep transitions
short (token durations: `kMotionFast 120 / kMotionBase 180 / kMotionPop 220`, curve `easeOutCubic`),
and make them **interruptible** — a tap/gesture cancels an in-flight animation; never block input.
Exit animations run a touch faster than enters.

## Implementation discipline

- Drive looping motion off an `AnimationController` gated in `didUpdateWidget`/`didChangeDependencies`
  so exactly one owner animates and a prop flip starts/stops it cleanly; **a prop flip does not fire
  `didChangeDependencies`** — handle it in `didUpdateWidget`.
- Stop and zero controllers under reduced motion; expose a `Semantics(label: …)` so the state is
  announced without the visuals.
- Paint crisp: `isAntiAlias = false` for pixel edges; for a shaped glow that respects a clipped/pixel
  silhouette use `filter: drop-shadow`/`MaskFilter.blur` (a rectangular `boxShadow` won't follow a
  `clipPath`).
