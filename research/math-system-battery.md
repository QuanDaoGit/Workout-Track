# Math-System Research Battery — Findings Log

> Plain-text findings for each research brief in the math-system overhaul the user commissioned
> (2026-06-21). One section per brief. Each brief ran the full `research` skill process —
> scope → decompose → multi-source search → SIFT + contrary-evidence pass → synthesis →
> **Codex adversarial review** → persist. Decision-tagged versions also live in `insights.md`.
>
> Lenses applied throughout: accuracy (real exercise science) AND user hook (gaming/progress
> psychology, dopamine-from-numbers), under the app's body-neutral + anti-guilt mandates.
>
> Battery: #1 exercise→strength ratios · #2 bodyweight · #3–13 per-system engagement sweep
> (XP, combat stats, class, calibration, VIT/LCK, decay, expeditions, overload, calories, quests,
> reward economy) · #14 creative lightweight features.

---

## #1 — Exercise→strength ratios (stat accuracy)  ✅ Codex-reviewed (needs-attention → resolved)

**Question:** convert a logged (exercise, weight, reps) into a comparable strength signal that
accounts for WHICH exercise it is, so a dumbbell curl and a barbell bench feed STR proportionally to
real strength, not raw kg.

**Core finding:** raw lifted kg is the wrong currency. The established, accurate, AND most-hookable
fix is to **normalize each lift against its own per-exercise, bodyweight- & sex-indexed strength
standard** — map the set's e1RM to a position in that lift's population distribution, yielding a
0–1 "strength quotient" that is comparable across exercises.

Findings:
- Per-exercise, bodyweight- & sex-indexed standards exist and are the right basis. Strength Level =
  153M+ lifts across 40+ exercises incl. isolation/dumbbell/bodyweight (curl, lateral raise, hammer
  curl, pull-ups, dips), tiered beginner ~5th..elite ~95th percentile.
  (strengthlevel.com/strength-standards, legionathletics.com/strength-standards, mecastrong.com)
- Do NOT use fixed inter-lift conversion ratios. Dumbbell total ~70–90% of barbell; strength curve
  dumbbell < barbell < machine — but it DRIFTS with training age and is only blog/forum-grade.
  Per-exercise standards sidestep conversion; reserve equipment/movement coefficients for the long
  tail. (leehayward.com, weightliftcalculator.com, Quora)
- Bodyweight normalization is allometric/sublinear (strength ~ BW^0.67; Wilks 5th-order poly,
  DOTS-2019 lower CV ~2.3% vs Wilks 3.2%, IPF GL). Per-exercise BW-indexed standards already bake in
  body size — no need to hand-roll Wilks per lift. (tommyodland.com, fitnessrec.com)
- A per-lift tier + aggregate "Strength Score" is a competence hook (SDT); the "Stronger" app ships
  exactly this. (Paschmann et al. 2025, J. Marketing)
- CONTRARY (Codex-sharpened): Strength Level's pop is self-selected lifters (stronger than general
  public) + inflated/estimated entries → absolute "stronger than X%" labels run high. Use as relative
  normalization; never as a literal population-percentile self-esteem claim.

Codex `needs-attention` → 3 guardrails folded in:
1. Don't bundle proprietary data. RESOLVED: the app already ships the public-domain free-exercise-db
   (mechanic/equipment fields) + OpenPowerlifting open data; author our own coefficient table, ExRx/
   Strength Level reference-only (ExRx is ad-supported, not bundleable).
2. Long tail must fail safe: the ~800-catalog can't all earn authoritative STR from shaky
   coefficients → uncatalogued lifts = low-confidence / "unranked", never gameable.
3. Separate INTERNAL normalization (always-on, feeds stats) from a USER-FACING percentile/tier
   (opt-in, confidence-labeled, neutral language, graceful missing-BW/sex handling, no max-attempt
   incentive).

Caveat to carry: normalizing away raw kg removes "weight on the bar" as the headline — some users
love watching kg climb, so keep a raw-load view ALONGSIDE the normalized stat, don't replace it.

**Decision feed:** redesign STR/AGI currency to a per-exercise normalized strength quotient (Epley
e1RM ÷ exercise BW+sex anchor → 0–1 → aggregate). Bundle an authored PD-grounded curated-lift
coefficient table + fail-safe long-tail fallback; surface a hedged, opt-in competence layer. If
pursued → /deep-feature (engine rewrite + migration + grandfather floor, like the v3 currency switch).

---

## #2 — Bodyweight integration into calculations  ✅ Codex-reviewed (needs-attention → 6 findings folded in)

**Question:** where should the user's bodyweight enter the math for accuracy, given the app is
body-neutral / anti-guilt and weight tracking is OPT-IN (off by default)?

**Core finding:** bodyweight genuinely improves accuracy in three places (calories, strength
normalization, bodyweight-exercise load) — but Codex correctly forced this from an *accuracy*
argument into a **consent + product-safety** argument. Bodyweight is sensitive data; using it and
displaying a metric derived from it are TWO SEPARATE GATES.

Findings:
- Calories = MET × bodyweight(kg) × hours. The app's fixed 70 kg ignores real BW (a 50 kg vs 110 kg
  user differ >2× for identical work); the engine already stores `bodyweightKgAtSave`. (MET
  calculators; topendsports, calculator.net) — claim grade: heuristic (calculator/edu sources).
- %bodyweight-per-exercise is the right model for bodyweight-exercise load: push-up ~64–70%, pull-up
  ~100%, squat ~77%, inverted row ~35–55% (ExRx "Calculating Actual Resistance"). The app's
  `bodyweightLoadFraction` is sound but the fractions are heuristic — validate vs a primary
  biomechanics source. (ExRx, StrongFirst, Strength Level)
- Bodyweight is the index variable for allometric strength normalization (brief #1); per-exercise
  BW+sex standards bake it in. Use actual BW for the standard lookup.
- PEER-REVIEWED: calorie/weight-tracking apps drive shame + disordered-eating symptoms, esp. for
  body-image (vs health) use; the fix is intrinsic-motivation framing over rigid weight/calorie
  metrics. (ScienceDirect systematic review 2024; UCL 2025; PMC) — strongest claim in the brief.
- CONTRARY: lifting-calorie estimates are inherently inaccurate — MET derived from ONE reference
  subject (40 yo, 70 kg, male); consumer trackers off avg 27%, up to 93%. "Calories burned is a
  terrible way to judge a workout." (perform-360, meto, forhers)

Codex `needs-attention` → 6 findings folded in:
1. [high] Don't merely de-emphasize calories — **remove calories from the default/core experience**;
   if retained, explicit opt-in + plainly-labeled uncertainty. (A precision fix on a 27–93%-noisy,
   body-image-risky metric mostly lends it false legitimacy.)
2. [high] **Silent reuse of calibration bodyweight is a consent crossing.** Opting out of weight
   *tracking* ≠ consent to use that value for calories or body-salient achievements. Separate consent
   scopes: calibration-only · strength-normalization · calorie-estimation · ongoing tracking.
3. [high] **Two-gate model** — split every decision into (a) may BW be *used* for this feature's math,
   (b) may the resulting metric be *displayed*. Harm can come from knowing the app uses BW, from
   surfaced stats, or from export/history — not just prominent calorie UI.
4. [medium] "1.4× bodyweight" flex still foregrounds bodyweight → keep relative strength INTERNAL for
   tiering; default public achievements to skill/progression language; bodyweight-ratio display opt-in.
5. [medium] Bodyweight entry points under-scoped: also the overload flat-40 kg bodyweight-1RM base,
   XP/VIT if derived from estimated load/calories, MET selection. Inventory EVERY formula consuming
   load/calories/intensity/XP/VIT/tiers/badges; allow BW only for biomechanical load + opted-in
   normalization; NEVER for motivational scoring, streaks, guilt, or cross-user comparison.
6. [medium] Downgrade %BW + calorie-accuracy claims from "strong" to heuristics needing primary
   sources; only the body-image-harm claim is systematic-review grade.

**Decision feed (revised by Codex):** (1) Drop calories from the default experience (opt-in + uncertain
label if kept at all) — strongest body-neutral move. (2) Use actual BW for strength-normalization
lookup and bodyweight-exercise load (biomechanical use), behind a clear "used for accuracy" scope. (3)
Replace the overload flat-40 kg bodyweight-1RM base with `%BW × actual BW`. (4) BW entry stays
opt-in/once-at-calibration, sexed default when unknown, never nagged, never a comparison. (5) Public
achievements default to skill/progression language; bodyweight-ratio is an opt-in display. → if
pursued, /deep-feature with a consent-scope model + a per-formula BW inventory as the first gate.

---

## #3 — XP & Leveling (engagement)  ✅ Codex-reviewed (needs-attention → 6 findings folded in)

**Question:** make XP & leveling maximally hooking (dopamine/progress psychology) while sensible and
accurate, for an OFFLINE / no-social / body-neutral app.

**Core problem:** the current curve is **convex AND sparse** — 8 non-contiguous levels (1,2,3,5,10,15,
20,30); a ~50–100 XP session means level 20→30 is ~50–100 sessions for ONE level-up. That is the
worst case for dopamine cadence (few celebrations + a growing grind). The fix is a concave,
contiguous curve — but Codex rightly downgraded several hooks for wellness-fit.

Findings:
- A CONCAVE/logarithmic curve (fast early levels) maximizes casual/retention motivation via the
  goal-gradient effect; convex = RPG grind. (designthegame, gamedeveloper) — game-design grade, so
  TENTATIVE for fitness transfer (Codex).
- XP should be the visible COMMON CURRENCY connecting every mechanic (Duolingo XP→levels→leagues,
  retention 12%→55%; day-1 vs month-6 mechanics differ). Leagues are SOCIAL → out of scope; use a solo
  cadence. (trophy.so, strivecloud)
- Dopamine = anticipation: a visible filling XP bar + reliable FREQUENT level-ups + juicy celebration
  is the loop; surprise/variable loot is potent but slot-machine-adjacent. PRESTIGE/rebirth fixes the
  level-30 dead-end. (playmushies, medium/Gupta)
- MODERATE gamification beats sparse AND overloaded (S-curve, Frontiers 2025); participation XP
  (time+sets) rewards JUNK VOLUME — align with intensity/overload/PRs, keep an anti-guilt floor.
  (Frontiers 2025, PMC)

Codex `needs-attention` → 6 findings folded in:
1. [high] Concave curve risks HOLLOW progress decoupled from real (slow, plateau-prone) training →
   downgrade to tentative; tie XP to PROCESS milestones; explicitly separate "app progression" from
   "physical progress" so the numbers never feel manipulative once novelty fades.
2. [high] Prestige/rebirth must be **cosmetic/reflective ONLY — no power multiplier**, with
   recovery/deload-compatible completion paths (a multiplier turns it into a recovery-ignoring
   treadmill).
3. [high] Loot/variable rewards need ENFORCEABLE rules, not "non-predatory" intent: no loss aversion,
   no paid boosters, no streak penalties, no missed-day punishment, transparent odds / deterministic
   pity, rewards never imply moral failure.
4. [medium] Intensity/PR-weighted XP punishes beginners/deload/injury/older users → keep the FLOOR
   (completion/consistency) DOMINANT; PR/intensity = small optional accents; add deload/rehab/
   maintenance achievements that score safe INTENT, not raw progression.
5. [medium] The package OVER-STACKS (curve + spine + prestige + re-weight + loot) — contradicts the
   S-curve. SEQUENCE it: ship the curve + visible bar ALONE first, then add one mechanic at a time
   with retention/guilt/recovery/manipulation measures.
6. [medium] Dropping leagues is right, but the SOLO substitute is under-specified → evaluate
   personal-best "ghosts", quest arcs, collections, self-referenced milestones on their own evidence;
   don't borrow league-driven retention numbers for an offline design.

**Decision feed:** STEP 1 (safe, ship-first) — re-curve to concave + contiguous levels + an
always-visible "X XP to next level" bar; keep XP the visible spine; separate app-progression from
physical-progress in the UI. LATER, one at a time, behind guardrails — cosmetic-only prestige past the
cap; floor-dominant XP with small PR/intensity accents + deload/rehab/maintenance achievements;
hard-ruled non-predatory loot; a solo competition substitute (PB ghosts / quest arcs / collections).
→ if pursued, /deep-feature, staged not big-bang.

---

## #4 — Combat Stats (engagement)  ✅ Codex-reviewed (needs-attention → 5 findings folded in)

**Question:** make the STR/AGI/END radar + VIT + grades maximally hooking + meaningful. (Stat
ACCURACY/currency was brief #1; this is the presentation/engagement layer.)

**Core finding:** the bones are right (3-stat radar is the optimal count; a 0–100 readiness meter is
the best-validated health mechanic) — but Codex flagged two values-level problems the engagement
gloss was hiding: VIT overclaims physiology, and visible decay contradicts the anti-guilt premise.

Findings:
- "Number go up" is core dopamine; **3 core stats is OPTIMAL** (below 3 = nothing to build, above 6 =
  untrackable) → STR/AGI/END is well-chosen. Stats should tie to identity + have secondary effects +
  be TRANSPARENT. (StraySpark, howtomakeanrpg, TVTropes ThreeStatSystem)
- Fitness wearables converge on a 0–100 recovery/readiness score (Whoop Recovery, Garmin Body
  Battery); the strain↔recovery loop is "the best-designed behavior-change mechanism in consumer
  health tech." (the5krunner, Whoop)
- CONTRARY: stat decay is loss-aversion (shame/avoidance risk) AND physiologically too fast — real
  detraining is gradual (weeks; maintenance easy). Decaying from day 2 overstates real loss. (PMC,
  TrainerRoad/SPB detraining)

Codex `needs-attention` → 5 findings folded in:
1. [high] **VIT overclaims physiological recovery** — it's schedule-adherence only (no HRV/sleep).
   RENAME/qualify as a "schedule / rest-balance" score, disclose it is NOT physiological readiness,
   drop wearable-comparable "recovery" language (else it breaks trust when a user feels tired at high
   VIT).
2. [high] **Remove visible downward stat DECAY from core identity stats** — "soften + reframe" doesn't
   fix the core failure: a down-number still punishes absence and makes re-entry feel worse, a
   product-values contradiction for an anti-guilt app. Replace with non-punitive freshness / momentum /
   rested-state affordances that recover IMMEDIATELY without lowering earned stats.
3. [medium] STR/AGI/END loose mapping ("agility" from shoulders/core) risks long-term trust loss once
   formulas show → base the system on HONEST training dimensions (Push/Pull/Legs or
   Strength/Control/Endurance); keep fantasy labels only as a class-flavor layer over accurate ones.
4. [medium] Formula transparency can incentivize min-maxing (chase cheap stat deltas, over-repeat a
   movement) → show DIRECTIONAL explanations + recent-session traces, NOT exact exploitable weights;
   add balance guards (stat gain needs varied movement patterns over time).
5. [medium] A visible "strain/effort" number becomes a second score to chase (overtraining) → frame
   effort as a BOUNDED load signal relative to VIT/rest context, never a maximize-me score; moderate/
   recovery sessions must produce equally legitimate positive feedback.

**Decision feed:** keep the 3-stat radar + juicy deltas; rename VIT to an honest schedule/rest-balance
meter (no physiological overclaim); REMOVE visible core-stat decay → replace with an instantly-
recoverable "freshness/momentum" affordance; build stats on honest training dimensions with fantasy
labels layered on top; directional (not exact) transparency + balance guards; bounded effort signal,
not a strain score. → if pursued, /deep-feature; the decay removal + VIT rename are values fixes, do
them first.

---

## #5 — Class system  ✅ Codex-reviewed (needs-attention → 6 findings; Codex added CDC/HHS sources)

**Question:** make the 3-class system (Assassin/Bruiser/Tank = muscle-focus + theme + +20% focus-stat
bonus) a strong identity hook + meaningful choice, honestly.

**Core finding:** classes are a powerful identity hook (lean in), but the **+20% focus-stat bonus
incentivizes the unhealthy thing** — specializing in one area / skipping legs. The best fix (Codex's
strongest idea) is to **redefine classes as training STYLES that advance fastest through BALANCED
coverage**, with flavor changing how progress is *narrated* — not body-part specialization.

Findings:
- Classes are fundamentally an IDENTITY hook ("a role pre-loaded with archetypes"); value = unique
  abilities/flavor; lock-in makes replay repetitive. (gamedesigning, gamerant, TVTropes) Ironbit's
  classes are THIN — only a +20% focus bonus.
- Balanced training is functionally important — neglecting groups (esp. legs) → imbalance, postural
  problems, injury (bodytraininghub, fitnessvolt, GoodRx); authoritative: CDC = work ALL major muscle
  groups 2+ days/week ([CDC](https://www.cdc.gov/physical-activity-basics/guidelines/adults.html),
  [HHS PA Guidelines](https://odphp.health.gov/our-work/nutrition-physical-activity/physical-activity-guidelines/current-guidelines)).

Codex `needs-attention` → 6 findings folded in:
1. [high] Decoupling the bonus can GUT class identity unless replaced → define a **class invariant**:
   each class is a distinct visible identity WITHOUT making any muscle group strategically skippable;
   use class-specific quests/framing/balanced-training multipliers, not body-part XP optimization.
2. [high] **Loosen the destructive respec** — irreversible loss around an identity choice the user may
   not yet understand is anti-wellness; use reversible trial/preview/non-destructive switch, preserve
   earned progress, grace window.
3. [high] The conclusion is a HYPOTHESIS, not settled — gate a final decision on authoritative
   guidance + a competitor scan + a small prototype test (class comprehension, perceived
   meaningfulness, whether users pick unbalanced workouts to farm the bonus).
4. [medium] Recast imbalance from "proven injury risk" to a credible **incentive-design hazard** (no
   behavioral data that users min-max a fitness RPG to harm); CDC/HHS support a guardrail, not a
   causal injury claim.
5. [medium] Unique class abilities risk over-complexity (S-curve) → complexity budget: ONE lightweight
   passive/quest per class, no branching builds, no hidden formulas; cosmetics/voice/recap style are
   safer first steps than new abilities.
6. [medium] **Balance-first reframe (the strongest idea):** redefine classes as training STYLES /
   evolving identities (precision, power, resilience, consistency, recovery, or rotating focus) where
   EVERY class advances fastest through balanced coverage; class flavor changes how progress is
   narrated, not which body part to optimize.

**Decision feed:** lean into class as identity, but flip the mechanic from "specialize for a bonus" to
a **balance-first training-style identity** (class flavors the narration; balanced coverage advances
everyone); loosen the destructive respec; one lightweight passive/quest per class max; cosmetics/voice
first. Treat as a HYPOTHESIS → prototype-test before building. → if pursued, /deep-feature + a research
prototype.

---

## #6 — Calibration  ✅ Codex-reviewed (needs-attention → 4 findings folded in)

**Question:** make the onboarding calibration (first ≤3 workouts → measured 1RM → strength tier →
seed stats) a strong activation hook + accurate, without harming beginner self-efficacy.

**Core finding:** calibration is a real activation lever (personalized "this is MY character") — but
Codex was right that the **visible D-S grade and the 3-session freeze are the two risks**, and copy
alone can't fix a low grade being a beginner's first identity-defining result.

Findings:
- Calibration → a personalized starting character is a commitment-bias + endowed-progress + "First
  Win" hook; motivation-matched onboarding is the top activation filter. (sency, amalgama, dev.to)
- CONTRARY: self-efficacy is a top correlate of exercise; a discouraging start hurts; beginners should
  focus on BEHAVIOR not fitness-rank; build confidence gradually. (PMC self-efficacy; PMC novice
  1-year study)

Codex `needs-attention` → 4 findings folded in:
1. [high] **Hide/defer the D-S grade in onboarding for beginners** — a "D / untrained" first result is
   a rank-like judgment that copy can't neutralize; show behavior-first progress, reveal strength
   tiers only after early completion wins or explicit opt-in.
2. [high] **Replace the 3-session ratchet-freeze with provisional calibration + re-calibration** — early
   sessions measure technique-learning + conservative loads, so a freeze locks a novice to an
   under-rated baseline; keep stats provisional/"estimate"-labeled and auto-re-calibrate when later
   workouts exceed seed assumptions.
3. [medium] Endowed-progress evidence does NOT transfer cleanly to a LOW honest calibration (a low rank
   reads as judgment, not head-start) → separate PERSONALIZATION (avatar/name/class flavor, immediate)
   from GRADING (numeric/rank, deferred); downgrade the engagement claim for this implementation until
   user-tested.
4. [medium] Self-efficacy protection is an UNVALIDATED hypothesis (no Ironbit data, no competitor
   scan) → require novice onboarding interviews / comprehension checks / an A-B plan before committing
   to visible calibrated grades.

**Decision feed:** keep calibration as the personalization/First-Win hook, but DEFER the D-S grade for
beginners (behavior-first; reveal after wins/opt-in); make calibration PROVISIONAL with re-calibration
triggers instead of a hard 3-session freeze (label early stats as estimates); upgrade accuracy to
per-exercise standards (brief #1); separate immediate personalization from deferred grading. Treat
self-efficacy protection as a hypothesis → onboarding test. → if pursued, /deep-feature + user testing.

---

## #7 — Streaks / Consistency / Recovery economy (LCK, shields, rest)  ✅ Codex-reviewed (needs-attention → 5 findings)

**Question:** make the consistency/streak loop (LCK weekly streak → up-to-3× XP multiplier; shields;
rest-day rewards) maximally hooking without guilt or health harm.

**Core finding:** Ironbit's instincts are good (weekly not daily, rewards rest, shields = freezes) —
but Codex was right that the strength is *asserted not proven*, and the **3× multiplier is a value
cliff** that fights the anti-guilt premise.

Findings:
- Streaks weaponize loss aversion (losing hurts ~2×; +34% engagement) but have a dark side (breaking
  demotivates; hollow "don't lose" compliance; streak anxiety). Freezes/repair are the validated
  anti-anxiety net. (cohorty, apptitude, smashing)
- Daily-streak mechanics drive OVERTRAINING (injury, mood/sleep, immune); rest is critical (≥1/week;
  adaptation happens in recovery). (HSS, GoodRx, UHHospitals) → a daily "don't break the chain" is
  health-dangerous; Ironbit's weekly + rest-rewarding + shielded design avoids it.

Codex `needs-attention` → 5 findings folded in:
1. [high] Weekly-streak strength is ASSERTED, not evidenced → regrade as PROVISIONAL; weekly+forgiving
   may reduce overtraining but also remove the daily salience that makes streaks work. Test weekly LCK
   vs a non-streak consistency reward before calling it a strength.
2. [high] The up-to-3× LCK multiplier is a large VALUE CLIFF — losing it costs progression speed and
   feels punitive even with non-shaming copy (contradicts anti-guilt). Model LCK loss as a BOUNDED
   ADDITIVE bonus / taper-down / soft-reset; validate perceived punishment.
3. [medium] Shield design unvalidated both ways → test manual vs auto, visible vs quiet, caps;
   auto-forgiveness can erase the hook OR hide when the user should consciously re-plan → make shield
   depletion VISIBLE.
4. [medium] "Recovery counts" dilutes consistency unless eligibility is precise → define rules for
   planned rest / unscheduled recovery / illness / missed sessions, else the streak stops meaning
   workout consistency.
5. [medium] Boundary + observability failure modes → a miss late in a 7-day block invalidates a bigger
   unit (cliff; add partial-week credit); auto-shields can mask a downward disengagement trend until
   the multiplier suddenly drops (surface it, non-shamingly).

**Decision feed:** regrade from "keep" to "PROTOTYPE WITH GUARDRAILS" — keep weekly + rest-rewarding +
shielded as the direction, but reform the 3× multiplier into a bounded-additive/taper bonus so its
loss never stings; make shield use + depletion visible; specify recovery-eligibility rules; add
partial-week credit to soften the boundary cliff; drop the "most apps shame rest, we reward it"
marketing line without competitive evidence. → if pursued, /deep-feature + an A/B + anxiety/return
measures.

---

## #8 — Inactivity Decay  ✅ Codex-reviewed (needs-attention → 5 findings; the "split stat model" is the key)

**Question:** should inactivity have any mechanical consequence, and how to represent it without
guilt? (Brief #4 already said "remove visible decay"; this brief tests the mechanic itself.)

**Core finding:** decay is loss-framing on EARNED stats — the wrong lever for fitness AND anti-guilt.
But Codex sharpened the fix: don't just delete the consequence, **SPLIT the model** — immutable earned
stats (never decrease) + a separate, neutrally-framed current-readiness signal that can honestly
reflect a layoff.

Findings:
- PEER-REVIEWED: for fitness (a preventive/health-affirming behavior), GAIN-framed messages beat
  LOSS-framed, mediated by self-efficacy; loss-framing wins only for detection/screening. (ScienceDirect
  framing×fitness-apps; Rothman/Salovey) → "use it or lose it" is the wrong frame for a fitness app.
- From brief #4: real detraining is gradual (weeks; maintenance easy) → ×0.97/day from day 2
  overstates real loss; a visible down-number punishes absence (anti-guilt contradiction).

Codex `needs-attention` → 5 findings folded in:
1. [high] Removing ALL downward signal makes "capability" stats misleading after a layoff → **split
   immutable earned progression from a NEUTRAL current-readiness/calibration signal**: never decrease
   earned stats, but don't claim current capability is unchanged after long inactivity.
2. [high] A "momentum/freshness" bar can REPACKAGE loss (an empty bar = "you lost it") → guardrails:
   starts neutral, never labels the user "behind," recovers on ANY return workout, positive
   next-action copy, user-tested for shame interpretation.
3. [high] The framing evidence is about persuasive MESSAGES, not a numeric stat mechanic → downgrade
   "wrong frame" to a hypothesis supported by adjacent evidence; require product-specific validation.
4. [high] The conclusion skips decisions → narrow it: remove downward changes from EARNED stats,
   preserve a neutral readiness signal, prototype momentum w/ copy safeguards, qualitative + retention
   test.
5. [medium] No loss-framed decay in the DEFAULT; an opt-in "hardcore use-it-or-lose-it" challenge layer
   only if ever, with easy disable + separate telemetry (it reintroduces the anti-guilt dynamic).

**Decision feed:** retire the loss-framed decay multiplier on earned stats. Replace with a SPLIT
model — earned stats are immutable (your achievement, never drops) + a neutral, gain-framed
current-readiness/"momentum" signal (honest about a layoff, never shaming, recovers on any return).
Treat the framing→mechanic transfer as a hypothesis → prototype + test low-momentum states with
lapsed beginners. → if pursued, /deep-feature; pairs with #4's decay-removal.

---

## #9 — Expeditions / Adventure (BIT companion idle loop)  ✅ Codex-reviewed (needs-attention → 6 findings; toughest pass)

**Question:** make the workout→charge→send-BIT→4-8h→gems loop hooking + ethical for a body-neutral,
no-IAP wellness app.

**Core finding:** it's a validated idle/anticipation hook, defused of the predatory core by
non-monetization + workout-gating — BUT Codex rightly refused to bless "keep": non-monetization
doesn't neutralize variable reward + opacity + timed anticipation, and the loop isn't *proven* to
serve training. Downgrade to a **risk-gated keep/shrink/cut experiment.**

Findings:
- The expedition is an idle/AFK compulsion loop (action→anticipation→reward; the 4-8h wait is the
  dopamine; AFK respects time); idle has wellness precedent (CHI 2024 deep-breathing). (techguide,
  ericguan, CHI 2024)
- CONTRARY: idle/gacha turns predatory via monetization + FOMO + opaque odds (gambling-adjacent).
  Ethical mitigations: transparency, accessibility, autonomy, wellbeing cues, pity. (ACM dark-patterns,
  MDPI gacha) → Ironbit's 35% opaque "find" is gacha-adjacent; gems are earned (no IAP) = benign core.

Codex `needs-attention` → 6 findings folded in:
1. [high] Workout-gating + no-money is NOT sufficient → residual risks: compulsive timer-checking,
   sleep/work interruption, low-roll disappointment, exercising for CHARGES not health. Add criteria:
   capped/no notifications, no urgency copy, no loss on late return, no streak dependence, rest
   framing; test whether expeditions raise training QUALITY or just app-opens.
2. [high] "Keep" isn't proven to SERVE training → risk of drifting into "a collection RPG with
   exercise as a resource generator." Compare keep/shrink/cut vs PRD goals (workout start/completion,
   perceived pressure, whether users explain the training value WITHOUT mentioning loot).
3. [high] The conclusion both applies AND dismisses monetized-gacha evidence → downgrade "keep" to a
   PROVISIONAL experiment; non-monetization doesn't neutralize variable reward + opacity + anticipation.
4. [medium] Transparency was a principle, not a design → BOUNDED transparency: plain-language rarity
   bands, guaranteed progress after misses (pity), reveal outcome only on return, NO casino-style roll
   animation.
5. [medium] Companion attachment is the return TRIGGER → define **BIT-ethics rules**: no sadness for
   inactivity, no dependency language, no late-check-in punishment, rest-positive copy, optional
   disable of companion return prompts (else it's guilt-based engagement without money/FOMO).
6. [medium] The cosmetic gem economy isn't justified vs complexity → complexity budget: justify
   gems/cosmetics/variance/rarity/caps with a direct training-serving benefit, OR shrink to simple
   post-workout unlocks (no dispatch cap, variance, rarity, or rank-scaled payout).

**Decision feed:** treat the expedition as a PROVISIONAL, risk-gated mechanic, not a settled keep —
run a keep/shrink(cosmetic-only post-workout unlocks)/cut comparison against training outcomes. If
kept: residual-risk guardrails (no urgency/notification pressure, no late-return loss), bounded
transparency + pity for the find, explicit BIT-ethics copy rules, and a complexity budget. → if
pursued, /deep-feature + a user test; this is the brief most likely to argue for SHRINKING, not
expanding.

---

## #10 — Progressive Overload  ✅ Codex-reviewed (needs-attention → 6 findings)

**Question:** make the overload suggestion engine accurate + a competence hook, safely.

**Core finding:** the algorithm is real but one-size-fits-all (double progression for everyone, no
autoregulation, not equipment-aware); the upgrades are clear, but Codex insisted they stay
CONSERVATIVE + user-controllable, not auto-prescribed, and that PR celebration not push maximal lifts.

Findings:
- Progression is EXPERIENCE-TIERED: beginners → linear, intermediates → double progression, advanced
  → autoregulation (RPE/RIR for daily fluctuation); deload every 3–4 weeks. (strive-workout,
  rpe.training) Ironbit applies double progression to EVERYONE, no RPE.
- Progression suggestions are a strong COMPETENCE hook: pre-filled "beat last time" targets, PR
  dopamine, upward-trend charts > raw numbers. (setgraph, jefit)

Codex `needs-attention` → 6 findings folded in:
1. [high] **RPE/RIR is advanced opt-in ONLY** — beginner logging stays RPE-free (no evidence this
   audience tolerates mid-set ratings; defaulting it risks worse data + abandonment); add explainer +
   missing-data fallback.
2. [high] Experience-aware progression needs a real CLASSIFIER (self-report + logged history +
   per-exercise performance stability + explicit override); a wrong tier → wrong suggestions →
   **default uncertain users to the LEAST-aggressive progression**, user-correctable.
3. [high] **PR celebration must target SAFE PROCESS PRs** (consistency, rep quality, submax volume,
   pain-free sessions, ESTIMATED PRs) — not heavier load; avoid maximal-attempt language; suppress
   aggressive PR prompts after missed reps / long breaks (else it rewards ego-lifting/injury).
4. [high] Conclusion overgeneralizes coaching-blog models → automated prescription → downgrade grade;
   frame the engine as CONSERVATIVE suggestions with user control; validate via usability testing
   before prescriptive.
5. [medium] Fixed +2.5kg isn't equipment-aware → model available increments by exercise/equipment,
   allow +1 rep or micro-loads, no load jump when equipment can't support it (dumbbell/cable/
   bodyweight).
6. [medium] Don't IMPOSE periodized deloads (could feel punitive for casual users, and the app lacks
   readiness signals) → soft optional recovery prompts after repeated shortfalls / long sessions /
   pain flags.

**Decision feed:** keep the overload engine CONSERVATIVE + user-controllable (suggest, don't
prescribe); experience-tier it with a multi-signal classifier defaulting to least-aggressive;
equipment-aware increments + micro-loading; RPE/RIR advanced-opt-in; celebrate SAFE process PRs;
optional (not imposed) deloads. → if pursued, /deep-feature + beginner UX testing on RPE friction.

---

## #11 — Calories  ✅ Codex-reviewed (needs-attention → 3 findings; mostly settled by #2)

**Question:** what (if anything) replaces the calorie number, body-neutrally? (#2 already said DROP it
from the default — fixed-70 kg, 27–93% inaccurate, body-image-risky.)

**Core finding:** dropping default calories is well-supported — but Codex caught that replacing it
with a prominent WORK/volume number just relabels exertion (and is *more* gameable in an RPG where
volume already feeds XP). The faithful body-neutral answer is likely QUALITATIVE or SILENCE.

Findings:
- Intuitive-exercise / non-diet approaches shift focus from calories/body-shape to INTERNAL signals
  (how training feels) + effort/work metrics; moving FOR weight loss → burnout + a resentful
  relationship with movement. (todaysdietitian; ScienceDirect non-diet SR; Welltory)
- The profile research already says the on-brand lever is "a private progress mirror of the ACT of
  training, never body outcomes."

Codex `needs-attention` → 3 findings folded in:
1. [high] A quantified work/volume/time replacement INHERITS the optimization loop (more gameable
   here, since volume already drives XP) — "body-neutral" is partly semantic (work proxies energy). Do
   NOT auto-replace calories with a prominent work total → prefer a LOW-salience summary, cap/soften
   streak-like rewards, test qualitative recovery/enjoyment prompts vs work metrics.
2. [medium] Opt-in calories need a strict CONTRACT: hidden from onboarding defaults, uncertainty
   range, no goals/streaks/comparisons, easy removal, framed for advanced users who knowingly want
   rough energy context (else opt-in just reintroduces the harm behind a toggle).
3. [medium] The STRONGER body-neutral option may be qualitative reflection (energy/mood/confidence/
   soreness/perceived effort) or NO number at all → compare three defaults: no-metric (completion
   only) / qualitative feel check-in / low-salience quantified effort; test before featuring
   quantified work.

**Decision feed:** drop default calories (per #2). Don't reflexively replace with a work number — set
the post-workout summary hierarchy as completion FIRST, optional qualitative feel check-in SECOND,
quantified effort only if it proves helpful without raising compulsive use; calories become a strict
opt-in (advanced, uncertainty-labeled, no goals). → if pursued, /deep-feature + a default-summary A/B.

---

## #12 — Quests (goal-math)  ✅ Codex-reviewed (needs-attention → 5 findings)

**Question:** make the quest targets/rewards maximally motivating + well-calibrated. (Variety/
narrative/reward-juice was already researched 2026-06-17; this is the goal-math angle.)

**Core finding:** quests map cleanly onto Goal-Setting Theory, and the personalized Limit Break is the
"calibrate difficulty to skill" ideal — but Codex was right that broadly extending personalization is
gameable + can conflict with anti-guilt, so it's a SINGLE piloted experiment, not a rollout.

Findings:
- Goal-Setting Theory (Locke & Latham): clarity, CHALLENGE (calibrated to user skill), commitment,
  feedback, sub-goals. (hcigames, Drimify) Ironbit's fixed-threshold quests are trivial for advanced /
  hard for beginners; Limit Break's personalized target is the model.

Codex `needs-attention` → 5 findings folded in:
1. [high] Personalization is GAMEABLE + unstable (sandbag → easy target; spike week → punishing
   target) → before any expansion, bound it: robust baselines, week-over-week caps, min-data
   requirements, anomaly/deload handling, FREEZE the target once a period starts, decay after missed
   inflated targets; instrument manipulation + miss rates.
2. [high] GST "challenge" can conflict with ANTI-GUILT (a missed stretch goal → guilt/compensatory
   overtraining/shame) → stretch quests must be OPTIONAL experiments, recovery/skip-compatible, no
   streak/loss framing; measure guilt/pressure/unsafe-compensation before raising challenge density.
3. [high] Conclusion overreaches → downgrade to a hypothesis: keep Limit Break as the ONLY personalized
   stretch quest, PILOT ONE more behind safeguards, collect completion/miss/sentiment/overtraining-
   proxy/retention before broader rollout.
4. [medium] No principled FLOOR-vs-STRETCH ratio → define a success-rate policy (≥1 guaranteed floor
   always visible, a limited number of optional stretch quests; review on completion/skip/sentiment).
5. [medium] More personalization weakens CLARITY → require visible plain-language target previews
   ("based on your recent training, capped so it won't jump sharply"), within-period stability,
   bounded changes.

**Decision feed:** keep Limit Break as the proven personalized stretch; PILOT one more personalized
quest behind anti-gaming bounds (caps, min-data, within-period freeze, anomaly handling) + instrument
it; make all stretch quests optional + recovery-compatible + non-loss-framed; keep a guaranteed floor;
visible plain-language target previews. Treat as a hypothesis → measure before rollout. → if pursued,
/deep-feature + telemetry.

---

## #13 — Reward economy (gems, loot, cosmetics, potions)  ✅ Codex-reviewed (needs-attention → 5 findings)

**Question:** make the gem/cosmetic/loot economy maximally motivating + coherent. (Ties together #3
loot guardrails, #5 cosmetics, #9 gem complexity.)

**Core finding:** Ironbit's deterministic milestone unlocks are the well-being-aligned, collection-
driving choice — but Codex was right that this brief argues for a CONTRACTED MVP economy (not
expansion), that deterministic ≠ automatically delightful, and that dropping potions can't be done
without first deciding whether body-metric tracking belongs at all.

Findings:
- The field is moving AWAY from random loot boxes TOWARD deterministic/skill-based unlocks for
  well-being; random evokes bigger elation/disappointment but apathy when low-value. (ACM random-reward
  study; kevurugames) → Ironbit's deterministic milestone unlocks are the right base.
- Completionists chase 100% (collectibles/achievements) → repeated engagement; a SINGLE common currency
  is coherent; sinks prevent hoarding. (gamedesignskills, redappletech)
- The INCOHERENT bit: a POWER sink (XP-boost potions) inside a cosmetic/identity economy, tied to
  body-weight tracking (body-image-adjacent), reads grindy / mildly p2w / anti-body-neutral.

Codex `needs-attention` → 5 findings folded in:
1. [high] Deterministic-only OVERCLAIMS engagement → it only supports avoiding harmful randomness, not
   that all-deterministic stays delightful → keep deterministic ELIGIBILITY but add tested DELIGHT
   layers: pre-announced milestone tracks with surprise presentation, cosmetic-only mystery reveals
   with DISCLOSED odds/pity, rotating deterministic collections, celebratory unlock moments.
2. [high] Don't just DROP potions → first decide whether body-metric tracking belongs in a body-neutral
   app at all; if it stays, replace the reward with a non-power, non-weight-validating one + validate
   motivation (else you strand the feature).
3. [medium] Completionism isn't benign → anti-pressure constraints: no time-limited/missable
   collectibles, no decay, no daily-obligation framing, clear partial-completion states, opt-out/hide
   collection UI, recovery-friendly copy (collections = optional identity, not obligation).
4. [medium] The brief argues for CONTRACTION → recast as a MINIMUM VIABLE ECONOMY: one earned currency,
   FEW cosmetic-only sinks, NO power items, no duplicate unlock paths unless justified; instrument
   hoarding/spend before adding sinks/tiers.
5. [medium] Game→fitness evidence transfer underspecified → downgrade "strong" grades to hypotheses;
   validate grind perception, body-neutrality, potion value, collection appeal.

**Decision feed:** contract to a minimum-viable, COSMETIC-ONLY economy — one gem currency, few sinks,
no power items (resolve potions via the body-tracking-belongs? decision, not a reflexive drop);
deterministic milestone unlocks + disclosed-odds delight layers (no gambling); anti-pressure
completionism (no missable/decay, opt-out); instrument before expanding. → if pursued, /deep-feature +
spend/hoarding telemetry. Net: SHRINK + polish, don't grow.

---

## #14 — Creative lightweight features  ✅ Codex-reviewed (needs-attention → 4 findings; the capstone)

**Question:** what out-of-the-box, lightweight features expand hook + accuracy for an offline,
body-neutral RPG?

**Core finding (the honest capstone):** after 13 briefs that repeatedly said "shrink / don't
over-stack / fix the core first," the right answer to "what should we ADD?" is **DEFER new features**
— not a feature menu. The only genuinely cheap, low-risk, body-neutral add is the one-tap feel
check-in (#11); everything else is hidden-expensive or unproven.

Findings:
- "Reward showing up, not just performing well"; most gamified apps retain like NON-gamified →
  psychological QUALITY over quantity. Self-competition ("beat your past self"/ghost) is the offline,
  intrinsic, body-neutral lever — but the evidence is CARDIO apps (partial transfer to strength).
  (razfit, mindster, ghostworkout, getfitcraft)

CANDIDATE SHORTLIST (parked): 1) past-self "ghost" on a lift (#3 solo-competition); 2) BIT-voiced
narrative "chapters" (ritual); 3) one-tap qualitative FEEL check-in (#11); 4) "complete athlete"
balance meter (#5); 5) deterministic milestone "artifact" cards (#13); 6) readiness-aware "today"
suggestion (#4/#10).

Codex `needs-attention` → 4 findings folded in:
1. [high] A 6-feature shortlist CONTRADICTS the battery's own shrink finding → recast DEFERRAL-FIRST:
   nothing new until the core-loop reworks land, OR approve ONE tightly-scoped experiment after a
   baseline retention/quality audit (sequencing 1–2 doesn't resolve it).
2. [high] "Lightweight" is only true for the FEEL check-in. Ghost (historical matching, edge cases,
   new UI), chapters (authored content), balance meter (a scoring system + taxonomy), readiness
   (RPE/rest heuristics users come to rely on) are HIDDEN-EXPENSIVE → cost-band the list before
   calling anything lightweight.
3. [high] Highest-leverage doesn't follow — feel check-in is the ONLY genuinely low-risk candidate;
   ghost evidence is cardio + no user-demand data → ship feel check-in only if it supports the core
   rework; DEFER ghost to a prototype; DROP balance/readiness/artifacts/chapters from near-term.
4. [medium] Self-competition can RECREATE anti-guilt pressure (today vs a better past self = streak-
   like after illness/deload/injury) → if ever built: opt-in, compare to RECENT similar sessions (not
   all-time best by default), allow "show up" wins, suppress rivalry after layoffs, no loss/decay
   language.

**Decision feed:** DEFER new features — the battery's own evidence says fix the core first. The single
cheap, on-doctrine add is the one-tap qualitative feel check-in (and only as the #11 calorie
replacement). Park the rest behind a cost/evidence table (implementation surface, content burden, data
dependency, anti-guilt risk, evidence quality); approve at most ONE scoped experiment (ghost as a
prototype with recovery-safe guardrails) after a baseline audit. → the strongest "creative" move is
polishing the reworked core loop, not adding surfaces.

---

# Cross-cutting themes (the patterns Codex surfaced across all 14 briefs)

1. **Shrink, don't grow — fix the core before adding.** The S-curve ("moderate gamification beats
   overloaded") + "most gamified fitness apps retain like non-gamified" recurred everywhere. The
   honest net of the battery is: re-tune and SIMPLIFY the existing systems; the expedition economy
   (#9), the power-sink potions / reward economy (#13), and new features (#14) are all SHRINK
   candidates, not expansions.
2. **Anti-guilt is a hard mechanical constraint, not copy.** Repeatedly, kind wording was rejected as
   insufficient: remove loss-framed decay (#4/#8), defuse the 3× LCK value cliff (#7), no
   missable/FOMO/decay in collections (#13), defer the beginner D-grade (#6), no streak penalties /
   missed-day punishment in loot (#3), recovery-positive companion copy (#9). If a number can go DOWN
   or a moment can read as "you failed," it fails the mandate regardless of copy.
3. **Separate INTERNAL accuracy from USER-FACING display (two gates).** Recurred in #1 (normalize for
   stats vs show a percentile), #2 (use bodyweight vs display it — consent scopes), #4 (transparency
   directional not exact), #8 (immutable earned stats vs a neutral readiness signal). Almost every
   accuracy win must be split from its presentation, with the display gated/opt-in/neutral.
4. **Hypothesis, not conclusion — evidence doesn't auto-transfer.** Game-design blogs, wearables, and
   cardio apps were the bulk of the evidence; Codex repeatedly demanded downgrading "strong" to
   "hypothesis" for a body-neutral BEGINNER STRENGTH app and required prototype/user-testing before
   building (#3, #5, #6, #7, #10, #12, #14). Treat the whole battery as direction + hypotheses, not a
   ship list.
5. **Accuracy, hook, and body-neutrality usually ALIGN; when they conflict, body-neutral wins.** The
   happy case is #1 (per-exercise normalized strength is the most accurate AND the most hookable). The
   conflict cases (calories, decay, streak cliff, class focus-bonus, beginner grade) all resolve
   toward the body-neutral / anti-guilt / safety side.

## Suggested sequencing (lowest-risk, highest-value first)
- **Tier 1 — values + accuracy fixes (do first, mostly low-risk):** remove visible stat decay + rename
  VIT to a schedule/rest-balance meter (#4/#8); fix calories (use real bodyweight, or drop from
  default) (#2/#11); re-curve XP to concave + contiguous + a visible bar (#3); per-exercise normalized
  strength currency (#1, bigger — needs the data table + migration).
- **Tier 2 — reframes (medium, need design):** classes as balance-first training styles + loosen the
  destructive respec (#5); defer the beginner grade + provisional calibration (#6); reform the 3× LCK
  cliff into a bounded bonus + visible shields (#7); conservative experience-tiered overload + safe
  process-PRs (#10).
- **Tier 3 — shrink + validate (resist expanding):** contract the reward economy to cosmetic-only +
  resolve potions/body-tracking (#13); make the expedition a keep/shrink/cut experiment with
  BIT-ethics rules (#9); pilot ONE personalized quest behind anti-gaming bounds (#12); the one-tap
  feel check-in is the only cheap new add (#11/#14) — otherwise DEFER new features.

> Status: all 14 briefs are research direction + Codex-reviewed hypotheses, NOT approved builds. Each
> "if pursued" line routes to `/deep-feature` for the audit→plan→adversarial-review→implement pipeline,
> where the product-acceptance criteria and on-device verification live.
