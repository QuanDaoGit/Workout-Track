# Research Insights — Ironbit

> Seed document. Tag every item `[validated]`, `[assumption]`, or `[risk]`. Pre-launch = mostly assumptions.

### Stat-engine accuracy — per-exercise NORMALIZED strength, not raw kg (math-system research #1, 2026-06-21)
Feeds the planned stat-engine redesign (the user wants stats that are accurate AND hooking; today STR sums Epley e1RM credit in raw kg, so a dumbbell curl and a barbell bench are conflated). Decision target: root `CLAUDE.md` soul (competence growth / visible deltas) + body-neutral & anti-guilt mandates + the v3 intensity-credit engine in [stat_engine.dart](../lib/services/stat_engine.dart). **Codex-reviewed** (verdict *needs-attention* → its 3 findings folded in below; one extra search loop resolved the data-licensing gap).
- `[validated]` **Per-exercise, bodyweight- and sex-indexed strength standards are the right normalization basis** — map each logged lift to its position within ITS OWN population standard so a curl and a bench become comparable, instead of summing raw kg. Strength Level = 153M+ lifts across 40+ exercises incl. isolation/dumbbell/bodyweight (curl, lateral raise, hammer curl, pull-ups, dips), tiered beginner ~5th..elite ~95th pct ([Strength Level](https://strengthlevel.com/strength-standards), [Legion](https://legionathletics.com/strength-standards/), [MecaStrong](https://www.mecastrong.com/weightlifting-strength-standards/)). Strongest single accuracy lever AND the most hookable. Confidence high.
- `[validated, directional]` **Do NOT build fixed inter-lift conversion ratios** (dumbbell ~70-90% of barbell; machine > barbell > dumbbell) — real but they DRIFT with training age and are only blog/forum-grade ([Lee Hayward](https://leehayward.com/blog/converting-dumbbell-bench-to-barbell-bench/), [weightliftcalculator](https://www.weightliftcalculator.com/blog/dumbbell-to-bench-press-calculator/)). Per-exercise standards sidestep conversion; reserve equipment/movement coefficients for the long-tail fallback only. Confidence medium.
- `[validated]` **Bodyweight normalization is allometric/sublinear** (strength ~ BW^0.67; Wilks 5th-order poly, DOTS-2019 lower CV ~2.3% vs Wilks 3.2%, IPF GL) and per-exercise BW-indexed standards already bake body size in — no need to hand-roll Wilks per lift ([tommyodland](https://tommyodland.com/articles/2023/relative-strength-wilks-ipf-gl-and-allometry/index.html), [fitnessrec](https://fitnessrec.com/articles/wilks-score-for-powerlifters-compare-your-strength-across-all-weight-classes)). DOTS is the reference if lifts are ever summed into one Strength Score. (Direct input to research #2 — bodyweight.)
- `[validated; risk per Codex]` **A per-lift tier + aggregate Strength Score is a competence hook (SDT)** (the "Stronger" app ships exactly this — [AMA/Paschmann 2025](https://journals.sagepub.com/doi/10.1177/00222437241275927)) BUT **separate INTERNAL normalization (always-on, feeds stats) from a USER-FACING percentile/tier (opt-in, confidence-labeled, neutral language)**: Strength Level's reference pop is self-selected lifters (stronger than the general public) + inflated/estimated entries → absolute "stronger than X%" labels run high; comparative ranking also risks load-chasing + body-image harm vs the anti-guilt/body-neutral mandate. Define the display contract (missing BW/sex, nonbinary, novice, injury, opt-out, no max-attempt incentive) BEFORE any tier copy ships.
- `[validated, per Codex]` **The long tail must fail safe, not fake-confident** — standards cover only ~40-100+ popular movements; the ~800-exercise catalog can't all earn authoritative STR credit from unstable coefficients (gameable/unfair). Covered curated lifts → full normalized credit; uncatalogued lifts → low-confidence / movement-pattern-only / "unranked," never authoritative.
- `[assumption→feasibility; resolves Codex high finding]` **Offline data ships WITHOUT proprietary bundling** — the app already bundles the **public-domain** [free-exercise-db](https://github.com/yuhonas/free-exercise-db) (800 exercises w/ `mechanic`=compound/isolation + `equipment` + force), so the fallback model is grounded in PD metadata we own; **[OpenPowerlifting](https://old.openpowerlifting.org/data.html)** (open data) anchors the big compound lifts. **Author our own per-exercise difficulty-coefficient table** informed by (NOT copied from) ExRx/Strength Level — ExRx is ad-supported copyrighted content, not bundleable. Coefficient VALUES still need validation → the standards-data provenance/license is the build's first gate.
- **Decision feed:** redesign STR/AGI currency to a **per-exercise normalized strength quotient** — keep Epley e1RM as the per-set input, divide by the exercise's bodyweight+sex strength anchor → 0..1 quotient → aggregate to the visible stats (fixes curl-vs-bench unfairness directly). Bundle an authored PD-grounded curated-lift coefficient table + a fail-safe long-tail fallback; surface a hedged, opt-in competence layer. → if pursued, `/deep-feature` (engine rewrite + migration + grandfather floor, like the v3 currency switch). Next: research #2 (bodyweight) is the index variable, then the combat-stats engagement brief.

### Bodyweight in the math — a CONSENT problem, not just accuracy (math-system research #2, 2026-06-21)
Feeds the math redesign. Decision target: body-neutral + anti-guilt mandates + [calorie_service.dart](../lib/services/calorie_service.dart) (fixed 70 kg) + the opt-in weight-tracking model. **Codex-reviewed** (needs-attention → 6 findings; the retry-with-anti-bail-framing produced the substantive pass — see [[codex-no-diff-bail]]).
- `[validated, peer-reviewed]` Calorie/weight-tracking apps drive shame + disordered-eating symptoms (esp. body-image use); intrinsic-motivation framing beats rigid weight/calorie metrics ([ScienceDirect SR 2024](https://www.sciencedirect.com/science/article/pii/S174014452400158X), [UCL 2025](https://www.ucl.ac.uk/news/2025/oct/emotional-strain-fitness-and-calorie-counting-apps-revealed)).
- `[validated]` Calories = MET × BW × hours, and lifting-calorie estimates are inherently noisy (MET from a single 70 kg/40 yo/male reference; trackers off 27–93%) ([perform-360](https://perform-360.com/the-fallacy-of-calories-burned/)). The app's fixed 70 kg is the literal MET baseline → fixing it is a small precision gain on a metric too noisy to feature.
- `[validated, heuristic]` %BW-per-exercise (push-up ~64–70%, pull-up ~100%, squat ~77%) is the right bodyweight-load model ([ExRx](https://exrx.net/WeightTraining/Bodyweight)); validate fractions vs a primary source.
- `[risk, per Codex]` **Two-gate consent model:** opting out of weight *tracking* ≠ consent to reuse calibration BW for calories/achievements. Split (a) may BW be USED per feature (biomechanical load + opted-in normalization only), (b) may the derived metric be DISPLAYED. Never feed BW into motivational scoring/streaks/comparisons.
- **Decision feed:** DROP calories from the default experience (opt-in + uncertain label if kept); use actual BW silently for strength-normalization + bodyweight-exercise load + replace overload's flat-40 kg base; public achievements default to skill/progression language (bodyweight-ratio = opt-in display). → /deep-feature with a consent-scope model + per-formula BW inventory as the first gate. Links [[research-1-strength-normalization]].

### XP & leveling — re-curve concave, but SEQUENCE the hooks (math-system research #3, 2026-06-21)
Feeds the math redesign. Decision target: [xp_service.dart](../lib/services/xp_service.dart) (convex + 8 non-contiguous levels; lvl 20→30 ≈ 50–100 sessions) + soul (competence/visible deltas) + anti-guilt + S-curve doctrine. **Codex-reviewed** (needs-attention → 6 findings).
- `[validated, game-design grade→tentative for fitness]` A concave/logarithmic curve (fast early levels + always-visible bar) maximizes casual retention via goal-gradient; the current convex+sparse curve is worst-case dopamine cadence ([designthegame](https://www.designthegame.com/learning/courses/course/fundamentals-level-curve-design/level-curves-art-designing-game-progression), [gamedeveloper](https://www.gamedeveloper.com/design/quantitative-design---how-to-define-xp-thresholds-)).
- `[validated]` XP = the visible COMMON CURRENCY connecting every mechanic (Duolingo retention 12%→55%); leagues are social/out-of-scope → solo cadence ([trophy.so](https://trophy.so/blog/duolingo-gamification-case-study)). `[validated]` Moderate gamification beats overloaded (S-curve, [Frontiers 2025](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2025.1671543/full)); participation XP rewards junk volume.
- `[risk, per Codex]` Hooks need wellness guardrails: separate app-progression from physical-progress (hollow-number risk); prestige = **cosmetic only, no power multiplier**, deload-compatible; loot needs **enforceable** rules (no loss aversion/paid boosters/streak penalties/missed-day punishment, transparent odds/pity); PR/intensity XP must keep the completion FLOOR dominant (don't punish beginners/deload/injury); add deload/rehab/maintenance achievements scoring safe intent.
- **Decision feed:** STEP 1 (ship-first, safe) = re-curve concave + contiguous + visible bar, alone. THEN one-at-a-time behind guardrails: cosmetic prestige, floor-dominant XP w/ small PR accents, hard-ruled loot, solo-competition substitute (PB ghosts/quest arcs/collections). Staged, not big-bang. Links [[research-4-combat-stats]].

### Combat stats — keep the radar, but VIT overclaims + decay breaks anti-guilt (math-system research #4, 2026-06-21)
Feeds the math redesign. Decision target: [stat_engine.dart](../lib/services/stat_engine.dart) (STR/AGI/END radar, VIT recovery meter, decay) + soul (competence) + anti-guilt. **Codex-reviewed** (needs-attention → 5 findings).
- `[validated, game-design]` 3 core stats is the OPTIMAL count (Ironbit's STR/AGI/END is well-chosen); stats want identity + secondary effects + transparency ([StraySpark](https://www.strayspark.studio/blog/rpg-stat-systems-character-progression-design), [TVTropes ThreeStatSystem](https://tvtropes.org/pmwiki/pmwiki.php/Main/ThreeStatSystem)). `[validated]` 0–100 readiness scores (Whoop/Garmin) are the best-validated health mechanic ([the5krunner](https://the5krunner.com/garmin-features/training/training-readiness/)).
- `[risk, per Codex — high]` **VIT overclaims physiology** (it's schedule-adherence, no HRV) → rename to a schedule/rest-balance score, no wearable "recovery" language. **Remove visible downward stat DECAY** — a down-number punishes absence (anti-guilt contradiction; and detraining is really gradual/weeks per [TrainerRoad](https://www.trainerroad.com/blog/detraining-what-happens-when-you-lose-fitness/)) → replace with instantly-recoverable "freshness/momentum".
- `[risk, per Codex — medium]` loose stat→muscle mapping (AGI from shoulders) → honest dimensions (Push/Pull/Legs) with fantasy labels layered on; transparency must be directional not exact (anti min-max) + balance guards; any "strain" signal must be bounded, not a maximize-me score (anti-overtraining).
- **Decision feed:** keep radar + juicy deltas; rename VIT; remove visible decay (values fix, do first); honest dimensions under fantasy labels; directional transparency; bounded effort. Links [[research-5-class-system]].

### Class system — flip from "specialize for a bonus" to balance-first training STYLES (math-system research #5, 2026-06-21)
Feeds the math redesign. Decision target: [class_definitions.dart](../lib/data/class_definitions.dart) + [stat_engine.dart](../lib/services/stat_engine.dart) class bonus + identity-attachment doctrine + body-neutral/safety. **Codex-reviewed** (needs-attention → 6 findings; Codex surfaced CDC/HHS).
- `[validated]` Classes are a strong IDENTITY hook (lean in) but value comes from flavor/abilities, not a thin stat bonus ([gamedesigning](https://gamedesigning.org/gaming/rpg-classes/), TVTropes). `[validated, guardrail]` Balanced training matters — CDC: all major muscle groups 2+ days/wk ([CDC](https://www.cdc.gov/physical-activity-basics/guidelines/adults.html)); so the **+20% focus-stat bonus is a credible incentive-design hazard** (it rewards skipping legs/balance), though not proven to cause injury.
- `[risk, per Codex]` Decoupling the bonus can gut identity unless a class INVARIANT is defined; the destructive respec should be loosened (reversible/preview); keep a complexity budget (1 lightweight passive per class); treat as a HYPOTHESIS needing a prototype test.
- **Decision feed (strongest reframe):** redefine classes as training STYLES (precision/power/resilience/consistency/recovery or rotating focus) where EVERY class advances fastest through BALANCED coverage — class flavors the *narration*, never which body part to optimize. Loosen respec; cosmetics/voice first. → /deep-feature + prototype. Links [[research-6-calibration]].

### Calibration — defer the beginner grade, make it provisional not frozen (math-system research #6, 2026-06-21)
Feeds the math redesign. Decision target: [calibration_service.dart](../lib/services/calibration_service.dart) (3-session 1RM→tier→seed, ratchet-up-freeze) + activation + self-efficacy/body-neutral. **Codex-reviewed** (needs-attention → 4 findings).
- `[validated]` Calibration = a commitment-bias + endowed-progress + "First Win" activation hook ([sency](https://www.sency.ai/post/revamp-your-onboarding-innovative-practices-for-fitness-apps)). `[validated, contrary]` Self-efficacy is a top exercise correlate; a discouraging start hurts; beginners should focus on behavior not rank ([PMC self-efficacy](https://pmc.ncbi.nlm.nih.gov/articles/PMC6003667/)).
- `[risk, per Codex — high]` **Hide/defer the D-S grade for beginners** (a "D/untrained" first result is a judgment copy can't neutralize); **replace the 3-session freeze with provisional + re-calibration** (early sessions measure technique-learning → a freeze locks an under-rated baseline). Separate immediate personalization (avatar/name/class) from deferred grading; treat self-efficacy protection as an unvalidated hypothesis (test it).
- **Decision feed:** keep calibration as the First-Win hook; defer the grade (behavior-first, reveal after wins/opt-in); provisional calibration w/ re-calibration triggers, not a hard freeze; upgrade accuracy to per-exercise standards (#1). → /deep-feature + onboarding test. Links [[research-7-streaks-recovery]].

### Streaks/recovery — right instincts, but the 3× LCK cliff fights anti-guilt (math-system research #7, 2026-06-21)
Feeds the math redesign. Decision target: [rest_service.dart](../lib/services/rest_service.dart) (LCK weekly streak, shields, recovery XP) + [xp_service.dart](../lib/services/xp_service.dart) LCK multiplier + ritual-return/recovery-protection doctrine + anti-guilt. **Codex-reviewed** (needs-attention → 5 findings).
- `[validated]` Streaks weaponize loss aversion (lose ~2× gain; +34% engagement) with a real dark side (anxiety, hollow compliance); freezes are the anti-anxiety net ([cohorty](https://blog.cohorty.app/the-psychology-of-streaks-why-they-work-and-when-they-backfire/)). `[validated, health]` Daily streaks → overtraining; rest is critical ([HSS](https://www.hss.edu/health-library/move-better/overtraining)). Ironbit's WEEKLY + rest-rewarding + shielded design avoids the daily-chain trap.
- `[risk, per Codex]` The strength is PROVISIONAL not proven; the **up-to-3× LCK multiplier is a value cliff** (losing it = lost progression speed = punitive even with kind copy) → make LCK loss bounded-additive/taper/soft-reset; make shield use + depletion VISIBLE (auto-forgiveness can mask disengagement); specify recovery-eligibility rules; add partial-week credit (boundary cliff).
- **Decision feed:** keep weekly+rest-rewarding+shielded direction; reform the 3× multiplier into a non-stinging bounded bonus; visible shields; precise recovery eligibility; prototype + A/B before claiming it as a strength. Links [[research-8-decay]].

### Decay — retire loss-framing; SPLIT immutable earned stats from a neutral readiness signal (math-system research #8, 2026-06-21)
Feeds the math redesign (pairs with #4). Decision target: [stat_engine.dart](../lib/services/stat_engine.dart) decay factor + anti-guilt/body-neutral. **Codex-reviewed** (needs-attention → 5 findings).
- `[validated, peer-reviewed]` For fitness (preventive behavior), GAIN-framing beats LOSS-framing, via self-efficacy ([ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0747563217305320); Rothman/Salovey) → "use it or lose it" decay is the wrong frame. Detraining is gradual (brief #4) → ×0.97/day overstates loss.
- `[risk, per Codex]` Don't just delete the consequence — **split immutable EARNED stats (never decrease) from a neutral current-READINESS signal** (honest about a layoff, neutrally framed). A "momentum" bar can repackage loss (guardrails: starts neutral, never "behind," recovers on any return). The message→mechanic framing transfer is a HYPOTHESIS; no loss-framed decay in the default (opt-in hardcore only, with telemetry).
- **Decision feed:** retire the decay multiplier on earned stats; earned = immutable, add a neutral gain-framed readiness/momentum signal; prototype + test lapsed beginners. Links [[research-9-expeditions]].

### Expeditions — provisional/risk-gated, not a settled keep; likely SHRINK (math-system research #9, 2026-06-21)
Feeds the math redesign. Decision target: [adventure_service.dart](../lib/services/adventure_service.dart) + [../docs/PRD.md](../docs/PRD.md) core-loop + anti-guilt + the BIT companion doctrine. **Codex-reviewed** (needs-attention → 6 findings, the toughest pass).
- `[validated]` The send-BIT loop is a real idle/anticipation hook (the 4–8h wait = dopamine), defused of the predatory core by no-IAP + workout-gating ([CHI 2024 idle-for-health](https://dl.acm.org/doi/10.1145/3613904.3642430)). `[validated, contrary]` idle/gacha turns predatory via monetization+FOMO+opaque odds ([ACM dark patterns](https://dl.acm.org/doi/fullHtml/10.1145/3491101.3519837)); the 35% opaque "find" is gacha-adjacent.
- `[risk, per Codex]` non-monetization does NOT neutralize variable-reward + opacity + timed anticipation; residual risks (compulsive timer-checking, exercising for charges not health); not proven to SERVE training → **downgrade "keep" to a keep/shrink/cut experiment**. Bounded transparency + pity for the find; **BIT-ethics rules** (no sadness/dependency/guilt for inactivity, rest-positive, disablable prompts); complexity budget for the gem economy.
- **Decision feed:** treat as PROVISIONAL — run keep/shrink(cosmetic-only post-workout unlocks)/cut vs training outcomes; if kept, residual-risk guardrails + bounded-transparency find + BIT-ethics copy. Most likely argues for SHRINKING. Links [[research-10-overload]].

### Progressive overload — conservative suggestions, experience-tiered, SAFE PRs (math-system research #10, 2026-06-21)
Feeds the math redesign. Decision target: [progressive_overload_service.dart](../lib/services/progressive_overload_service.dart) + competence doctrine + safety. **Codex-reviewed** (needs-attention → 6 findings).
- `[validated]` Progression is experience-tiered (beginner linear → intermediate double → advanced RPE/RIR autoregulation); deload 3–4 wks ([rpe.training](https://rpe.training/guides/understanding-progressive-overload/)). Ironbit uses double-progression for all, no RPE. `[validated]` Suggestions are a competence hook (beat-last-time, PR dopamine, trend charts) ([setgraph](https://setgraph.app/ai-blog/best-app-to-log-workout-tested-by-lifters)).
- `[risk, per Codex]` keep the engine CONSERVATIVE + user-controllable (suggest not prescribe); RPE = advanced opt-in only; experience-tier via a multi-signal classifier defaulting to least-aggressive; equipment-aware increments + micro-loading; **celebrate SAFE process PRs** (consistency/rep-quality/pain-free/estimated, not maximal load; suppress after misses/breaks); deloads optional not imposed.
- **Decision feed:** conservative experience-tiered suggestions, equipment-aware, RPE advanced-opt-in, safe-process PR celebration, optional deload prompts. → /deep-feature + beginner UX test. Links [[research-11-calories]].

### Calories — drop default (per #2); replacement is qualitative/silence, NOT a work number (math-system research #11, 2026-06-21)
Feeds the math redesign. Decision target: [calorie_service.dart](../lib/services/calorie_service.dart) + body-neutral. **Codex-reviewed** (needs-attention → 3 findings). Builds on #2.
- `[validated]` Intuitive-exercise/non-diet research shifts focus from calories to internal signals + how training feels ([todaysdietitian](https://www.todaysdietitian.com/newarchives/0123p48.shtml), [ScienceDirect non-diet SR](https://www.sciencedirect.com/science/article/abs/pii/S1499404614007969)).
- `[risk, per Codex]` a prominent WORK/volume replacement just relabels exertion (more gameable in an RPG where volume feeds XP) → don't auto-replace; the faithful body-neutral default may be qualitative (feel check-in) or silence (completion only). Calorie opt-in needs a strict contract (hidden, uncertainty-labeled, no goals/streaks).
- **Decision feed:** drop default calories; post-workout hierarchy = completion FIRST, optional qualitative feel check-in SECOND, quantified effort only if proven safe; calories = strict advanced opt-in. → /deep-feature + default-summary A/B. Links [[research-12-quests]].

### Quests (goal-math) — Limit Break personalization is the model, but pilot it, don't roll it out (math-system research #12, 2026-06-21)
Feeds the math redesign. Decision target: [quest_service.dart](../lib/services/quest_service.dart) (fixed thresholds + personalized Limit Break) + anti-guilt. **Codex-reviewed** (needs-attention → 5 findings). Builds on the 2026-06-17 quest-rework insight.
- `[validated]` Quests map onto Goal-Setting Theory (clarity/challenge/commitment/feedback/sub-goals); difficulty must be calibrated to user skill ([hcigames](https://hcigames.com/understanding-gamification-through-goal-setting-theory/)) — Limit Break's personalized target is that ideal.
- `[risk, per Codex]` personalization is gameable (sandbag→easy, spike→punishing) → needs anti-gaming bounds (caps, min-data, within-period freeze, anomaly handling) BEFORE expansion; GST "challenge" conflicts with anti-guilt (missed stretch → guilt/overtraining) → stretch quests must be optional + recovery-compatible + non-loss-framed; keep a guaranteed floor; visible plain-language target previews (clarity).
- **Decision feed:** keep Limit Break; PILOT one more personalized quest behind bounds + telemetry (don't broadly roll out); optional non-punitive stretch + guaranteed floor; measure before rollout. Links [[research-13-reward-economy]].

### Reward economy — contract to a cosmetic-only MVP; deterministic + delight, not power sinks (math-system research #13, 2026-06-21)
Feeds the math redesign. Decision target: [gem_service.dart](../lib/services/gem_service.dart) + [loot_registry.dart](../lib/data/loot_registry.dart) + [xp_boost_service.dart](../lib/services/xp_boost_service.dart) + collection-desire doctrine. **Codex-reviewed** (needs-attention → 5 findings). Ties #3/#5/#9.
- `[validated]` The field moves AWAY from random loot boxes toward DETERMINISTIC/skill unlocks for well-being ([ACM random-reward](https://dl.acm.org/doi/fullHtml/10.1145/3491102.3517642)); single currency + sinks = coherent ([gamedesignskills](https://gamedesignskills.com/game-design/economy-design/)). Ironbit's deterministic milestone unlocks are the right base.
- `[risk, per Codex]` deterministic ≠ automatically delightful (add disclosed-odds reveals, surprise presentation, rotating collections — no gambling); the **XP-boost potion is an incoherent power sink** tied to body-weight tracking → don't reflexively drop, first decide whether body-metric tracking belongs at all; completionism needs anti-pressure (no missable/time-limited, no decay, opt-out); the honest conclusion is CONTRACTION, not expansion.
- **Decision feed:** contract to a minimum-viable COSMETIC-ONLY economy (one currency, few sinks, no power items); deterministic unlocks + disclosed-odds delight; anti-pressure completionism; instrument spend/hoarding before expanding. SHRINK + polish. Links [[research-14-creative-features]].

### Creative features — DEFER; the answer to "what to add" is "fix the core first" (math-system research #14, 2026-06-21)
Feeds the math redesign (capstone). Decision target: soul doctrine + offline/body-neutral + the battery's own shrink/S-curve finding. **Codex-reviewed** (needs-attention → 4 findings).
- `[validated]` "Reward showing up, not just performing well"; gamified apps retain like non-gamified → QUALITY over quantity ([mindster](https://mindster.com/mindster-blogs/fitness-app-user-retention/)). Self-competition ("beat your past self"/ghost) is the offline intrinsic lever but the evidence is CARDIO ([ghostworkout](https://ghostworkout.com/)).
- `[risk, per Codex]` a 6-feature shortlist contradicts the battery's shrink finding → DEFER new features until the core reworks land (or ONE scoped experiment after a baseline audit); only the one-tap FEEL check-in (#11) is genuinely lightweight + low-risk; ghost/chapters/balance-meter/readiness are hidden-expensive; self-competition can recreate anti-guilt pressure after a layoff (needs recovery-safe guardrails).
- **Decision feed:** DEFER new features; the single cheap on-doctrine add is the feel check-in (as the #11 calorie replacement); park the rest behind a cost/evidence table; the strongest "creative" move is polishing the reworked core, not adding surfaces. Links [[research-1-strength-normalization]].


### Haptics — a semantic `HapticService` mirroring `SfxService`; built-in API broad layer + `vibration` pkg for 1–2 landmarks (2026-06-21)
Feeds a planned app-wide haptic-feedback feature ("Duolingo/Finch add vibration to buttons/actions/animations").
Today haptics are **ad-hoc at 2 sites** (`HapticFeedback.mediumImpact()` in [quests_page.dart:107](../lib/pages/quests_page.dart:107)
claim + [solution_page.dart:124](../lib/pages/onboarding/solution_page.dart:124)) with **no central service, no toggle, no
VIBRATE permission** in the manifest. Decision target: root `CLAUDE.md` soul (ritual/reward juice, identity/competence
beats) + anti-guilt mandate + the reduced-motion/juice doctrine already locked in the quest-claim entries below.
**Codex evidence-review could not run** (local Codex broken on this Windows box — see [.claude/codex-local.md](../.claude/codex-local.md));
adversarial pass done manually against a 7-item challenge list (folded into the tags/risks).
- `[validated]` **Flutter's built-in `HapticFeedback` is the zero-cost broad layer and needs NO `VIBRATE` permission** for
  `lightImpact/mediumImpact/heavyImpact/selectionClick` — they route through Android `View.performHapticFeedback()`
  (the app already fires `mediumImpact` with no VIBRATE in the manifest → corroborates). Only `HapticFeedback.vibrate()`
  and the `vibration` pkg hit the `Vibrator` service and **require** the permission ([haptic_feedback pkg](https://pub.dev/packages/haptic_feedback),
  [flutter_vibration docs](https://context7.com/benjamindean/flutter_vibration/llms.txt)). **Tradeoff:** the built-in API
  **respects the user's system touch-feedback setting** (correct a11y default) but is therefore **weak/absent when the user
  disabled it**, and is **OEM-inconsistent** — e.g. `heavyImpact()` no-ops on some Samsung devices while `mediumImpact` works
  ([flutter#73987](https://github.com/flutter/flutter/issues/73987)). → must on-device test on target hardware.
- `[validated]` **The `vibration` pkg (`/benjamindean/flutter_vibration`, High rep) is the path for "designed" patterns** —
  `hasVibrator()` / `hasAmplitudeControl()` (Android 8+/API26) / `hasCustomVibrationsSupport()`, custom `pattern:[wait,on,…]`
  arrays, `amplitude` 1–255, `duration`. It **bypasses** the system touch-feedback gate (consistent, expressive) and **needs**
  the auto-merged VIBRATE permission ([context7 docs](https://context7.com/benjamindean/flutter_vibration/llms.txt)). Reserve it
  for **1–2 landmark "chunky" moments** (level-up, big quest claim) — matching the pixel "chunky impact, not soft" grammar from
  the loud-pixel entries below — behind capability checks with `heavyImpact()` fallback. (`haptic_feedback` pkg is the
  cross-platform-semantic alternative; we're Android-only so `vibration` fits better.)
- `[validated]` **UX bar: sparing, consistent, peak-timed.** "If you can't say what a haptic communicates in one sentence,
  it's unnecessary"; apply the SAME feedback to the SAME trigger class across the app (learnability); fire at the **exact
  visual/audio peak** (delay feels unnatural); tier — subtle tick = success, sharper = warning/destructive, gentle bump =
  boundary ([UX Pilot](https://uxpilot.ai/blogs/enhancing-haptic-feedback-user-interactions), [Boréas guidelines](https://pages.boreas.ca/blog/piezo-haptics/guidelines-of-haptic-ux-design),
  [Android haptics UX](https://source.android.com/docs/core/interaction/haptics/haptics-ux-design)). Respect the existing
  "≤3–5 feedback triggers/sec / once-per-claim not per-gem" rule.
- `[validated]` **Competitor cut — borrow the craft, not the guilt.** Duolingo treats haptics as one **unified
  micro-interaction language** synced with motion+sound: 3D button-depress buzz, correct/incorrect ticks, lesson-complete
  celebration, streak-milestone hit — **landmark celebration reserved** to stay powerful ([Duolingo micro-interactions](https://medium.com/@Bundu/little-touches-big-impact-the-micro-interactions-on-duolingo-d8377876f682),
  [925studios breakdown](https://www.925studios.co/blog/duolingo-design-breakdown)). Finch = **gentle, perfectly-timed
  weight** on achievements + soft "petting" contact + breathing-rhythm guidance, **never startling, never punitive**
  ([webisoft Finch](https://webisoft.com/articles/finch-self-care-app/), [Sophie Pilley](https://www.sophiepilley.com/post/the-magic-of-finch-where-self-care-meets-enchanted-design)).
  We already reject Duolingo's **guilt notification engine** (entry below) — that rejection is about *application*, not the
  haptic *craft*; the micro-interaction patterning is borrowable. **No "punishment buzz" for a missed day/streak** (anti-guilt).
- `[validated, internal-doctrine]` **Haptics get their OWN opt-out, NOT auto-killed by reduced-motion.** WCAG 2.3.3 governs
  *visual* motion (vestibular); haptics are tactile, not a vestibular trigger, and are an a11y **aid** for some users — so,
  like `SfxService` (sound plays under reduced motion, has its own mute per the loud-pixel entry), haptics should fire under
  reduced motion but ship a dedicated **Haptics** toggle. `[assumption]` some sensory-sensitive users still want them off →
  the toggle covers it; the system setting also covers the built-in layer.
- **Decision feed — proposed v1:** a `HapticService` mirroring `SfxService` (singleton, static `enabled` flag, **every call
  guarded try/catch fail-open** per the "platform-plugin calls must fail open in tests" learning) + a `HapticSettingsService`
  (`haptics_enabled_v1`, default on, read into the flag at boot) + a **"Haptics" `_SettingsToggleRow`** beside Sound in
  [profile_page.dart](../lib/pages/profile_page.dart). Expose a **small semantic vocabulary** (`selection()`/`tap()`/`success()`/
  `reward()`/`warning()`) so call sites name intent, not raw impacts, and tuning lives in one place; migrate the 2 existing
  call sites onto it. **Start with the built-in `HapticFeedback`** for the broad layer (zero permission, respects user choice);
  add the **`vibration` pkg only if** a designed landmark pattern earns its keep, gated by capability + `heavyImpact()` fallback.
  **Key `[assumption]` that would flip the engine choice:** that the built-in impacts feel strong/consistent enough on the
  user's target devices — settle by on-device test; if too weak, promote `vibration` to primary (accepting the permission +
  loss of system-preference respect). → if pursued, `/deep-feature` (new service + settings toggle + boot wiring + call-site
  migration); pixel/copy of the toggle → `ironbit-design`.
- **[implemented 2026-06-21 — FOUNDATION only]** `HapticService` ([haptic_service.dart](../lib/services/haptic_service.dart),
  semantic `selection/tap/success/reward/warning`, fail-open) + `HapticSettingsService` (`haptics_enabled_v1`, default on) +
  boot wiring ([boot_service.dart](../lib/services/boot_service.dart)) + the 2 ad-hoc sites migrated to `reward()` (byte-identical
  feel). Self-validating test (channel-arg assertions, mute, fail-open) — mutation-checked. **Deferred to the surface pass:**
  the visible Settings "Haptics" toggle row (needs a pixel icon) and any *new* triggers; `reward()` is medium for now (the seam
  for the `vibration`-pkg landmark upgrade).
- **[surface pass implemented 2026-06-21 — 6 deep-feature processes, full suite 1062 pass / only the 5 pre-existing golden
  drifts fail]** P1 `PixelButton` keystone (`HapticIntent` enum + `fire()`; default `tap`, per-button override, `none` opt-out →
  all 74 buttons) · P2 Settings **Haptics** toggle (`sound-haptic-ring.png`) + `selection()` on nav/chips/toggles · P3
  `reward()` at level-up / PR / loot-unlock · P4 `success()` on Finish Exercise/Workout + weight CONFIRM, light `selection()`
  per non-PR set · P5 `warning()` on destructive *commit* buttons (delete / discard / reset / class-switch AGREE / idle
  DISCARD) · P6 rest-timer-done `success()` from `RestTimerBar`'s dispose-managed ticker (overshoot-guarded, `cancel()`-deduped,
  covers both rest surfaces). Each: manual adversarial pass (Codex unavailable per
  [.claude/codex-local.md](../.claude/codex-local.md)) + analyze-clean + per-process regression; keystone & rest tests
  mutation-proven. **Still open:** the `vibration`-pkg landmark upgrade for `reward()`; broad `FilledButton` coverage (P1
  centralizes `PixelButton` only — `FilledButton`s like the summary "BACK TO HOME" stay silent).

### Onboarding finishes off-schedule — activation grace for session 1, not an Explore-only gate (2026-06-21)
Evaluates a proposed fix for the "two clocks" onboarding bug (the home last-workout card → `_startWorkout`
→ "TRAIN ANYWAY? planned recovery" dialog on a non-training-weekday for a 0-workout user). The user's idea:
warn at the weekday-picker if TODAY isn't selected, and on a rest-day finish replace the StartGate's
"start workout today" with **Explore-only**. Decision target: builds on the [2026-06-20 "two clocks/anchor"
decision] (below) + root `CLAUDE.md` soul (ritual/first-session) + anti-guilt mandate + the `[risk]` long
onboarding. **Codex evidence-review could not run** (no-diff research review returns "no diff" per
[.claude/codex-local.md](../.claude/codex-local.md); additionally the local Codex runtime is currently broken
on this Windows box — every shell spawn exits −1); adversarial pass done manually against a 8-item challenge list.
- `[validated, industry-benchmark]` **For a fitness app the first completed workout IS the activation event;
  replacing it is the biggest negative lever.** "If onboarding doesn't end in a completed workout you failed
  the job"; first-workout completers retain/monetize materially better; TTV target <5 min; early activation
  ≈ 7-day→3-month retention (~69%) ([fitness onboarding](https://dev.to/paywallpro/fitness-app-onboarding-guide-data-motivation-completion-an0),
  [Amplitude TTV](https://amplitude.com/blog/time-to-value-drives-user-retention), [digia](https://www.digia.tech/post/mobile-app-onboarding-metrics/)).
  Caveat: vendor/industry benchmarks, not peer-reviewed; the "2–3× LTV" is single-source → directional.
- `[validated, industry-benchmark]` **"Jump in" beats passive tours → "Explore first" is the *weakest*
  activation substitute.** Action-first ≈ +50% activation vs passive; tour completion 3-step 72% → 7-step 16%
  ([Product School](https://productschool.com/blog/product-strategy/user-onboarding), [Userpilot](https://userpilot.com/blog/interactive-walkthroughs-improve-onboarding/)).
- `[validated]` **Stakes reframe — "finish on a rest day" is the MAJORITY path, not an edge case.** At 3
  training days/wk, ~57% of users finish onboarding on a non-training day (~43% at 4/wk). So the rest-day
  StartGate governs most first sessions → an Explore-only gate is a broad activation hit, not a corner fix.
- `[validated, peer-reviewed]` **The schedule-purist steelman (implementation intentions) is real but MODEST
  and forward-looking.** Specific when/where aids PA habit formation at small effect sizes (d≈.14–.31), via
  recurring same-context repetition — argues for honoring the schedule **from session 2**, not gating session 1
  ([PMC imagery+II](https://pmc.ncbi.nlm.nih.gov/articles/PMC11920387/), [PMC RCT](https://pmc.ncbi.nlm.nih.gov/articles/PMC6440859/)).
- `[validated]` **Competitor precedent is split; the specific pattern is novel.** Weekday-gated apps exist
  (Gymverse only enables chosen days; Sweat/Runna schedule-by-day) but activation-first leaders start now
  (Ladder "press Start Workout"; Fitbod builds a ready workout) — matching the prior "weekday-lock isn't
  dominant" finding. **No surveyed app warns "today isn't a training day" at pick-time or Explore-gates the
  first session** ([Sweat](https://support.sweat.com/hc/en-us/articles/115006926987-How-do-I-use-the-Planner-to-schedule-and-track-my-workouts), [Ladder](https://www.joinladder.com/)).
- `[validated, peer-reviewed]` **Autonomy (SDT) cuts both ways:** don't show a contradictory forced
  "train today" when they chose today as rest, **but** don't remove the option either — autonomy = offering a
  meaningful, skippable choice, not deciding for them ([SaaSUI](https://www.saasui.design/blog/saas-onboarding-ux-examples)).
  Warning microcopy: intentional friction is only justified for high-stakes/irreversible acts; weekday-picking
  is low-stakes + reversible → make it an **informational note, not a confirmation gate** (and never guilt-framed,
  per anti-guilt doctrine).
- **Decision feed — recommend "activation grace for session 1":** (1) first-ever workout available **today, any
  weekday** (Day 1 "begins when you do it"); weekday schedule governs from session 2 — this *also* fixes the bug
  (a 0-workout user's today isn't labeled recovery, so the dialog never fires). (2) StartGate **keeps a real
  start path** (primary or obvious secondary), never Explore-only. (3) Pick-time line is **informational +
  one-tap "Add today,"** not a warning/gate. **Key `[assumption]` that would flip it:** that the first *workout*
  (not the identity/StartGate character beat) is Ironbit's aha — settle with funnel instrumentation post-launch.
  → if pursued, `/deep-feature` (StartGate + `_startWorkout` rest-gate + onboarding picker); surface → `ironbit-design`.

### Notification system foundation — LOCAL (not push), opt-in, anti-guilt (2026-06-21)
Feeds a planned notification-system foundation. Decision target: reconcile [../docs/PRD.md](../docs/PRD.md)
"Out of Scope: Push notifications" + the re-engagement [risk] below + root `CLAUDE.md` anti-guilt/offline
doctrine. **Codex evidence-review could not run substantively** (this machine's Codex expects a branch diff;
a no-diff research review returns "no diff" — see [.claude/codex-local.md](../.claude/codex-local.md)); the
adversarial pass was done manually against a 6-item challenge list (sharpened the retail-push caveat + the
measurement gap below).
- `[validated]` **"Push" out-of-scope ≠ all notifications — the bar targets SERVER-DRIVEN push, local is open.**
  PRD/roadmap/app-briefing list "push notifications" grouped with accounts/cloud-sync/social/AI/ads/IAP, reason
  "shift attention away from the self-contained loop" / "retention boundaries" — all backend/external-party,
  network-dependent things. On-device **local/scheduled** notifications need no backend/account/network → they
  *preserve* the offline/private wedge and send **zero data off-device**. They are the direct answer to the
  standing `[risk]` "Offline/no-account means no remarketing or re-engagement channel post-install." **Scope
  reconciliation is a USER call** — keep server-push out, bring local in. `[risk]` falsifier: if "no push"
  was meant as a *philosophy* ("we never ping you"), not a tech bar — confirm intent before building.
- `[validated]` **Reminders raise exercise adherence — but the effect DECAYS and depends on prior commitment.**
  Weekly gym reminder +13% frequency, held 3 months ([gym field RCT](https://www.cambridge.org/core/product/3A77551499C8CEF7738E64AB10DF8F35/core-reader));
  HabitWalk micro-RCT: prompts+cues+commitment aid PA habit formation ([Wiley](https://iaap-journals.onlinelibrary.wiley.com/doi/10.1111/aphw.12605),
  [PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11635918/)); older-adult + cardiac-rehab RCTs positive
  ([PMC reminders](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7318722/), [PMC cardiac](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8296287/)).
  Contrary: effect decays; works only if the user already wants the behavior.
- `[validated, contrary]` **Notification fatigue → opt-out/uninstall — BUT this evidence is mostly RETAIL/MARKETING
  push.** 1 push/wk → ~10% disable, ~6% uninstall; non-personalized frequency ↑ uninstalls + ↓ open rate
  ([retail freq study](https://www.researchgate.net/publication/351932011_Mobile_apps_in_retail_Effect_of_push_notification_frequency_on_app_user_behavior),
  [Appbot 2026](https://appbot.co/blog/app-push-notifications-2026-best-practices/)); ~⅓ intend to mute sources,
  ~½ adopt DND, 60% follow through 2yr ([arXiv 24h-no-push](https://arxiv.org/pdf/1612.02314)). `[assumption]`
  the transfer to **user-configured, opted-in UTILITY notifications** (rest-timer-done, a reminder you set) is
  weak — those are *wanted*, far less fatiguing. → treat fatigue stats as a CEILING for the re-engagement tier,
  not a reason to skip utility notifications. **Pre-launch: no analytics yet → can't A/B copy/timing; ship
  conservative defaults.**
- `[validated]` **Anti-guilt is the correct stance; Finch is the model, Duolingo the foil.** Duolingo's notif
  engine = loss-aversion/guilt ("missed practice" framed as moral failure), criticized as dark patterns
  ([webdesignerdepot](https://webdesignerdepot.com/the-art-of-duolingo-notifications-the-subtle-manipulation-of-language-learners/));
  Finch = gentle, **no penalty for missed days**, "just enough to help, never enough to overwhelm"
  ([webisoft](https://webisoft.com/articles/finch-self-care-app/)). App doctrine forbids guilt/loss-punishment.
  → reward the act, never punish absence; a skipped reminder is silent. (Guilt is empirically the *strongest*
  hook — Duolingo 300M — but vendor-% + forbidden here; do not borrow it.)
- `[validated]` **Competitor cut:** pure trackers (Hevy/Strong) use notifications for **in-session utility** —
  rest-timer-done, live-activity, PR alerts ([Hevy rest timer](https://www.hevyapp.com/features/workout-rest-timer/),
  [Hevy live activity](https://www.hevyapp.com/features/live-activity/)) — not guilt re-engagement. → borrow the
  utility model + Finch's gentle reminder; reject the gamified-habit guilt loop.
- `[validated]` **Permission is fragile post-Android-13 → prime before asking.** Android 13 (API33) requires the
  `POST_NOTIFICATIONS` runtime grant; opt-in rates dropped (gaming lost ~⅓) ([MoEngage](https://www.moengage.com/blog/android-13-push-notification-opt-ins/),
  [CleverTap](https://clevertap.com/blog/android-13-push-notification-opt-ins/)). → soft-ask/priming with value
  context BEFORE the system prompt, asked at a contextual moment (after the user enables a reminder), never cold at launch.
- `[validated]` **Technical foundation = `flutter_local_notifications` + `timezone`.** `zonedSchedule(TZDateTime,…)`
  (old `schedule()` deprecated); set device tz at startup (DST safety). Android 14 (API34): `SCHEDULE_EXACT_ALARM`
  not auto-granted, `exactAllowWhileIdle` without it **throws** → request it OR (preferred) default to **inexact**
  and degrade gracefully; `USE_EXACT_ALARM` only if to-the-minute precision is essential (Play reviews it).
  `RECEIVE_BOOT_COMPLETED` + boot receiver to reschedule after reboot; per-category channels.
  ([pub.dev docs](https://pub.dev/packages/flutter_local_notifications), [issue #1995](https://github.com/MaikuB/flutter_local_notifications/issues/1995)).
  `[risk]` OEM battery killers (Xiaomi/Huawei/Samsung) can drop scheduled alarms → **best-effort delivery, never
  promise exactness**; reconcile/reschedule on app open as the safety net.
- **Decision feed — proposed v1 foundation (tiered, all opt-in + capped + anti-guilt + offline):** a local
  `NotificationService` mirroring the app's service pattern (own SharedPreferences key, `nowProvider`-injectable)
  wrapping the plugin + timezone; per-category channels + per-category user toggles; pre-permission priming;
  inexact-default + graceful fallback; boot reschedule; reconcile-on-open. **Tier A** in-session utility
  (rest-timer-done — reuses `RestTimerService`; lowest doctrinal risk, ships first, justifies the
  permission+channel plumbing). **Tier B** opt-in scheduled **workout-day reminder**, time personalized from the
  user's own history (`RestService.trainingWeekdays` already exists) — the re-engagement answer. **Tier C**
  (defer) state-ready nudges (expedition charge ready, quest claimable). → `/deep-feature` task (new subsystem +
  PRD scope reconciliation + permission flow). Pixel/copy surfaces → `ironbit-design`.

### Quest-claim "loud pixel" burst — the SOUND (chunky-but-bright, self-generated, pre-rendered variants) (2026-06-20)
The user locked the "loud pixel" burst (see entry below) and wants a NEW SFX fitting its fast/chunky nature.
Current sound is `assets/audio/quest_claim.wav` — code-described as "one **ascending** chiptune arpeggio" @0.7
(a rising *sparkle*, wrong for an explosion). Stack: `audioplayers ^6.1.0`, WAV. **Load-bearing constraint:**
`SfxService` holds ONE `_current` player and **stops+disposes it on every `_play`** ([sfx_service.dart:34](../lib/services/sfx_service.dart:34))
→ two play calls in quick succession interrupt each other; `playQuestClaim()` currently fires once on the LAST
gem landing. Decision target: root `CLAUDE.md` soul (ritual/reward juice) + the card-burst entry below.
Codex-reviewed (evidence, *needs-attention* → resolved into the tags).
- `[validated]` **Chunky = a short percussive IMPACT, not a rising arp.** ~100–300ms, sharp attack + fast
  decay + clean cutoff, square/NES wave, a **pitch DROP** (med-high→low); pro技法 = a short **noise-burst
  transient** at the attack for a click/thump ([SFX Engine retro sounds](https://sfxengine.com/blog/how-to-create-retro-game-sounds)).
  A pitch *rise* reads "collect/level-up"; a *drop* reads "impact". (Current arp is the wrong direction.)
- `[validated]` **Keep it rewarding, not destructive — "chunky but bright".** Pure explosion/noise can read
  hit-hurt/negative; satisfying reward audio **layers** an impact element (thump/crisp hit) WITH a short
  **bright tonal tail** (2–3-note chiptune blip) ([reward SFX](https://sfxengine.com/sound-effects/reward)).
  Chunky transient leads, bright tail keeps it positive. `[risk, per Codex]` the pitch-drop+noise is exactly
  what can tip into "damage" — the bright tail mitigates but is **unproven → must on-device A/B**.
- `[validated]` **Audio fatigues FASTER than visuals on repeat → vary it.** Repeated identical SFX = audio
  fatigue; fix with per-play pitch/timbre/volume variation, "share a core identity with slight variations"
  ([A Sound Effect](https://www.asoundeffect.com/game-audio-immersion/), [SFX Engine UI audio](https://sfxengine.com/blog/best-practices-for-game-ui-sounds)).
  `[refine, per Codex]` prefer **2–3 pre-rendered WAV variants** (matched loudness+envelope) as the primary
  method; `setPlaybackRate` (audioplayers, changes speed+pitch together) is a *fallback* — on a 100–300ms SFX
  it shifts attack/decay/cutoff and can distort the chunk, so only use if the fastest render still sounds
  chunky on Android. Tier to the same landmark axis as the visual (daily = small blip, landmark = full burst).
- `[validated]` **Integration — don't just drop the landing chime; prototype 3.** The single-player interrupt
  means a t0 burst + a separate landing chime via `SfxService` would cut each other off. `[refine, per Codex]`
  compare: **(a) one premixed launch→landing WAV** fired once at t0 (sidesteps the interrupt, keeps gem-landing
  causality — likely best); (b) t0 burst only (landings = haptic + wallet-pulse + BIT cheer); (c) a bounded
  **2nd low-latency `AudioPlayer`** for a landing tick (audioplayers supports multiple instances). Pick by
  perceived causality + fatigue, not just the singleton limit. Respect "max 3–5 feedback triggers/sec".
- `[validated]` **Source = self-generate (clear to ship, tunable).** bfxr/jsfxr/sfxr (Explosion/Hit/Powerup
  presets → export WAV): output rights are clear — as3sfxr output is **CC0**, bfxr grants "full rights to all
  sounds made with bfxr … commercial or otherwise", sfxr tool is MIT ([bfxr](https://www.bfxr.net/),
  [as3sfxr](https://www.superflashbros.net/as3sfxr/), [sfxr.me](https://sfxr.me/)). Beats Freesound (licenses
  vary; CC0 filter = no attribution). `[per Codex]` store a **provenance note** with the asset (generator +
  version/URL + preset/params + date + output-rights source); avoid Freesound/Pixabay unless the exact license
  snapshot is saved. **NOTE: do not download any file without asking the user first.**
- `[validated]` **Accessibility:** sound-off already handled (`SfxService.enabled` mute, non-essential/guarded);
  sound is **not** a vestibular trigger, so it MAY still play under reduced motion (the current snap path does)
  — reduced motion gates the visual shake/shards, not audio. **Acceptance criteria (per Codex):** 2–3 candidate
  renders + loudness check (LUFS/peak) + Android A/B vs the current arp before final selection. → asset choice +
  build belong to the loud-pixel `deep-feature`.

### Quest-claim "card burst" juice — pixel grammar, landmark-gated, coexist with the gem-fly (2026-06-20)
The user wants the WHOLE quest card to "burst" on CLAIM and doubts a "smooth bubble burst" fits the
pixel aesthetic. Today the card does button-squash → dim-to-CLAIMED while gems fly to the wallet
([quests_page.dart:314](../lib/pages/quests_page.dart:314)); a prior outward `GemClaimBurst` was deleted.
Decision target: root `CLAUDE.md` soul doctrine (ritual return / reward juice) + the quest-rework note
above. Codex-reviewed (evidence, verdict *needs-attention* → resolved into the tags below).
- `[validated]` **The user's instinct is right: a soft, round, alpha-gradient "bubble-pop" is the foreign
  tell — reject it.** The app's own motion doctrine ("round/circle is a foreign tell", paint
  `isAntiAlias=false`, CRT/phosphor, avoid smooth glossy) + retro-pixel-UI precedent (dithering, CRT
  scanlines, neon glow, chunky multi-state sprites) ([Pope Tech a11y motion](https://blog.pope.tech/2025/12/08/design-accessible-animation-and-movement/),
  retro-pixel-UI sources) make the on-brand "burst" = a hard 1–2-frame **white/neon flash** + **chunky
  aliased square shards** (pixel confetti) + optional **dither-dissolve** + a short **squash**, painted
  crisp. `[refine, per Codex]` it is **not** "all softness is off-idiom" — *round geometry* is the tell;
  dithered glow + a crisp limited-frame shine still fit.
- `[validated]` **Juice is success-dependent polish, not a substitute — over-juice backfires.** Canonical
  practitioner juice = squash/stretch, flash, particles, screen-shake, sound ([itch.io "juicy"](https://itch.io/blog/1059831/making-a-game-feel-juicy-with-simple-effects)),
  but the **contrary**: exaggerated feedback becomes a crutch / false agency / homogenization when overused
  ([Wayline "The Juice Problem"](https://www.wayline.io/blog/the-juice-problem-how-exaggerated-feedback-is-harming-game-design)).
  Reinforces the app's own "don't over-pop / S-shaped richness" finding.
- `[validated, directional]` **Reserve the LOUD burst for landmarks; restrained by default.** Duolingo
  "reserves celebration for landmarks to keep it powerful"; Habitica fires a brief (~0.5s) earn-only hit per
  check-off (its loss/punishment is the dark pattern we reject) ([deconstructoroffun](https://www.deconstructoroffun.com/blog/2025/4/14/duolingo-how-the-15b-app-uses-gaming-principles-to-supercharge-dau-growth)).
  `[refine, per Codex]` gate by **quest type / landmark status FIRST** (side quest / Limit Break / weekly
  clear / first-claim-of-session), then optionally scale by amount — the existing `kBigRewardThreshold=50` is
  an *implementation convenience, not the primary axis* (frequency + context drive annoyance, not gem count).
- `[validated]` **The burst must COEXIST as the launch IMPACT, not a competing focal event.** Salience
  ≈ velocity × contrast × size × count; the existing gem-fly→wallet count-up draws the cause→effect loop and
  must stay the primary signal. `[risk, per Codex]` adding a full-card event at t0 raises contrast/size/count
  exactly when the flight begins → **carry an explicit NULL option** (strengthen the button squash/flash +
  gem launch only) and require an **on-device side-by-side** before committing to a full-card burst.
- `[validated]` **Honesty:** shards are decorative — keep the gem **count** the truth (flight already caps at
  8 sprites, shows the real amount). `[per Codex]` make shards visually distinct (white/neon **squares**, not
  magenta gem-like) so they don't read as "more gems than I won"; count prominence is the real safeguard.
- `[assumption→tune on device]` **Game-feel timing are STARTING RANGES, not constants** ([eastondev game-feel](https://eastondev.com/blog/en/posts/dev/20260521-game-feedback-feel/),
  single-source on the ms): flash ~50–100ms (30ms imperceptible, 150ms blurry), particles ~+50ms (20–30,
  200–400px/s, 0.5–1s life), card-shake 2–3px small → 8–10px big, 0.1–0.3s eased-off, impact resolving
  ~within 100ms, ≤3–5 triggers/sec. Validate across Android refresh rates; separate cited craft from our
  validated behavior.
- `[validated]` **Reduced-motion / vestibular gate (standing rule, reinforced):** WCAG 2.3.3 — interaction
  motion must be disable-able; ~35% of adults 40+ have vestibular disorders ([W3C 2.3.3](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html)).
  **Shake is the highest-risk lever** → small amplitude, ALWAYS off under `disableAnimations` (snap to
  CLAIMED + dimmed + snapped wallet, the existing path). Perf: one `CustomPainter` + single `Ticker` +
  `RepaintBoundary`, ≤~24 shards, controllers built in `initState`, fired once + guarded against re-fire
  across the optimistic reload — reuse the `GemFlightLayer` ticker pattern. → pixel look to `ironbit-design`;
  tiering/state logic to `deep-feature`.

### Program day rescheduling — reorder the sequence, don't weekday-lock (2026-06-20)
The user wants to let users move a program's sessions/rest "to different days" (e.g. "Monday→Tuesday"),
proposed as drag-and-drop, surfaced at program selection (onboarding + settings) reworking the training-goal
step. Findings, tied to the program-system decision:
- `[validated]` **The user's "weekday" framing is a proxy for slot order, not a real calendar need.** Ironbit's
  program model is deliberately **sequence-based, not calendar-locked** ([docs/program-system.md](../docs/program-system.md) §5):
  "current day" is an index that advances on completion, never tied to real weekdays. "Move Monday→Tuesday /
  recovery→Monday" is satisfiable by **reordering the 7-slot cycle** (which session/rest comes first), which fits
  the existing model with zero migration risk. True calendar-weekday binding is a *separate, larger* model change.
- `[validated]` **Behavioral evidence favors the sequence model over hard weekday-locking.** Planning training as a
  *sequence of sessions* (vs fixed weekdays) means a missed day doesn't derail progression and kills the
  all-or-nothing guilt ([strategy-business](https://www.strategy-business.com/article/A-flexible-routine-can-help-you-change-for-good),
  [hiptrain](https://www.hiptrain.com/b/flexible-workout-schedules-consistent-fitness-busy-professionals)). Aligns with
  the forgiveness/anti-guilt doctrine already in the app ("empty board reads quiet, never a guilt-poke"). Caveat
  `[contrary]`: fixed schedules build habit automaticity better, and flexible plans can drift via decision fatigue —
  but the cycle still imposes order, so we keep structure without the calendar lock.
- `[validated]` **Competitor split: weekday-binding is NOT the dominant convention.** Strong schedules routines by
  day-of-week; JEFIT is calendar-based (heaviest planner, oldest UI). But **Hevy** — the most popular modern tracker —
  uses a **routine-library + folders** model with **no hard weekday lock**, and Fitbod generates per-session. So the
  closest-to-Ironbit modern leaders deliberately avoid calendar-locking. ([just12reps compare](https://just12reps.com/best-weightlifting-apps-of-2025-compare-strong-fitbod-hevy-jefit-just12reps/),
  [hevy routines](https://www.hevyapp.com/features/gym-routines/))
- `[validated]` **Drag-and-drop is the right *gesture* but must not be the *only* path.** Hevy uses tap-hold drag to
  reorder exercises within a routine and routines within folders — so D&D is an established, expected gesture for
  *reordering*. But mobile D&D has real motor/screen-reader/precision costs; WCAG guidance is to always pair it with a
  non-drag fallback (up/down buttons, or a "move to" picker) ([accessibilityspark](https://accessibilityspark.com/drag-and-drop-accessibility/),
  [pencilandpaper](https://www.pencilandpaper.io/articles/ux-pattern-drag-and-drop)). → ship drag **+** up/down arrows.
- `[validated]` **The real problem is TWO disconnected schedule models.** Ironbit already has a calendar-weekday
  schedule — `RestService.trainingWeekdays` (the Settings → TRAINING GOALS weekday picker) — but it only drives
  **shields / planned-recovery credit / streak protection / "successful week"** ([rest_service.dart:210](../lib/services/rest_service.dart:210),
  [:440](../lib/services/rest_service.dart:440)), NOT which workout you do. The program (`weekSchedule`) drives the
  workout by **sequence index**. When a program is active, program days take precedence and the weekday picks are
  overridden → the picker *feels cosmetic* to the user (their words). The two systems never reconcile.
- **Decision feed (revised after the user picked HYBRID + "make TRAINING GOALS systematic"):** unify the two models.
  Let the weekday schedule become the **anchor** that the program's sequence maps onto, so picking "Mon/Wed/Fri"
  actually places *this program's sessions* on those weekdays (and the rest of the cycle on the rest of the week),
  driving BOTH the workout AND the shield/recovery credit from one source. Keep the sequence model's **forgiveness**
  (a missed weekday doesn't hard-fail; it rolls), so we get the habit-anchor of fixed weekdays without the
  all-or-nothing guilt. Surface it as the reworked TRAINING GOALS step (onboarding + settings) with **drag/tap to
  assign sessions to weekdays + arrow/picker fallback** (never drag-only, per WCAG). This is now a `/deep-feature`
  task (model reconciliation + migration), not just a UI reorder. → `ironbit-design` owns the surface;
  `deep-feature` owns the RestService↔ProgramService reconciliation + migration of existing `trainingWeekdays`.

### Onboarding program-picker — fix selection/step visibility WITHOUT auto-scroll or a CTA hijack (2026-06-20)
The program-selection screen opens at the top; the recommended program can be the 3rd (off-screen) card, so
users don't perceive a selection and never scroll to the optional weekday step below the cards. Two fixes were
proposed: (1) auto-scroll to the recommended card on load; (2) make the primary CTA scroll-to-the-step instead
of advancing. Findings:
- `[validated]` **Auto-scroll on load is the wrong mechanism — but the goal is right.** Forcing scroll removes
  user control and disorients ([scrolling UX](https://medium.com/@Alekseidesign/the-psychology-of-scrolling-ux-design-insights-for-mobile-apps-ae6eb5ea99bf)).
  The clean fix for "recommended isn't visible" is to **order the recommended program FIRST** (top of list) so
  it's seen with zero scroll; a gentle `ensureVisible` on the selected card is the fallback if order must stay
  fixed. Don't animate the whole page on load.
- `[validated]` **A primary CTA whose action ≠ its label is an anti-pattern.** A button must transparently
  communicate its exact outcome ([NN/g button states](https://www.nngroup.com/articles/button-states-communicate-interaction/),
  [PatternFly](https://www.patternfly.org/components/button/design-guidelines/)). "START THIS PATH" that scrolls
  instead of proceeding breaks that. The *only* legitimate CTA-scrolls cousin is "submit → scroll to first
  ERROR" — an error/validation detour that still submits and requires focus management ([Bristol pattern](https://design.bristol.gov.uk/docs/patterns/scroll-to-first-error)).
  Our optional step is not an error, so the hijack isn't justified. (User suspected this — confirmed.)
- `[validated]` **The step is invisible because of a "false bottom."** When the first screen looks complete,
  users stop scrolling even when content exists below ([NN/g page fold](https://www.nngroup.com/articles/page-fold-manifesto/)).
  ~50% scroll immediately *if* above-the-fold looks promising. Fix = signal more-below: **cut off the last card
  at the viewport edge** + an explicit scroll cue, OR hoist the step out of the scroll list.
- **Decision feed:** (a) **Reorder the recommended program to the top** (selection seen on load, no auto-scroll).
  (b) For the optional weekday step, prefer a **compact, always-visible affordance pinned above the CTA** — a
  one-line `Training days · Mon·Wed·Fri ▸` summary that opens/expands the picker — over burying it below the
  cards or adding a screen (onboarding is already long, a flagged drop-off risk). NOT auto-scroll, NOT a CTA
  hijack. Hand the pixel/interaction to `ironbit-design`.

### Home quest board — IN-ROOM furniture, not a feed card (2026-06-19, supersedes the card peek)
The user redirected the home quest-peek from a feed card into **diegetic furniture mounted in the `HomeRoomScene`
diorama** (a compact "digital quest board" on the chamber wall that routes to the Quests tab). Decision findings,
grounded in `room_scene.dart` geometry:
- `[validated]` **Placement = the bare left-middle wall, mirroring the world-window (asymmetric balance).** The wall
  is right/top-loaded (world-window TR, pad bottom-C); the left-mid wall is dead space with a *reserved mount point*
  already coded in `_RoomShellPainter` (left column). A counterweight there balances the heavier window
  ([asymmetric balance](https://www.kittl.com/blogs/symmetrical-asymmetrical-balance-in-art-adv/)) and stays clear of
  the two no-go zones: BIT's negative-space halo ([breathing room keeps the hero the focal anchor](https://www.animatorisland.com/composition-what-is-breathing-room/))
  and the center lane the voice bubble grows into. Top-center (bubble + too thin) and mid-right (overloads the window
  side) are both worse.
- `[validated]` **Size = window-scale; do NOT shrink BIT.** Shrinking the hero weakens the focal point — wrong lever.
  The empty left-mid wall fits the board at ~window scale without touching BIT/pad. If a bigger/central board is ever
  wanted, shrink the **pad footprint**, never BIT's dominance. (User offered to shrink both; answer = unnecessary.)
- `[validated]` **Treatment = a digital terminal with a minimal glance + glow-when-claimable.** Room-scale screens
  demand [instant legibility](https://vsquad.art/blog/what-hud-games-complete-guide-game-interfaces) — no quest names;
  show a `QUESTS` caption + a 5-seg weekly bar + 1–2 check rows. The tap signifier reuses the dispatch-pad doctrine
  (an in-world interactable must announce itself): **amber edge-glow + lit gem pip when a reward is claimable**, a
  calm steady-lit screen otherwise (never dark/dead, never a nag).
- `[validated]` **A 2nd interactive wall object is on-strategy (a "wall of functional furniture"), with guardrails.**
  Base-room convention (Fallout-Shelter / gacha-dorm) supports a growing hub (window=world, pad=expedition,
  board=quests, nameplate=identity, + the reserved mount points). Guardrails: (a) board stays subordinate — BIT keeps
  the brightness lead; (b) only ONE accent pulses at a time — coordinate the board claim-glow with the pad armed-glow
  (≈2–3 active accents). **Implementation risk to gate:** the board's right edge vs. the centered voice-bubble on a
  long advice line — prove with a width × text-scale golden matrix (bubble is transient + higher-z, so minor corner
  layering is acceptable). Pixel look + exact px → `ironbit-design`.

**Mockup check (2026-06-19) — the user's QUESTS-crate states vs the settled treatment.** The four-state crate
(IDLE / 1·2 READY / WEEK CLEARED: a `QUESTS` cap + 5-seg cyan bar + caption, a solid-amber "N READY" button on the
ready states) is the right *direction* but diverges from the settled treatment in three decision-relevant ways:
- `[validated, refine]` **The loud solid-amber "N READY" button over-competes — demote it to the settled claimable
  cue (amber edge-glow + lit gem pip), not a raised bright button.** It breaks the entry's own guardrails: *board
  stays subordinate / BIT keeps the brightness lead*, *only ONE accent pulses at a time (coordinate with the pad
  armed-glow, ≈2–3 active accents)*, and *calm steady screen, never a nag*. A big amber CTA on the wall becomes the
  room's hottest element and steals BIT's focal lead.
- `[validated, refine]` **Furniture = a glance that ROUTES to the Quests tab; don't host the full CLAIM transaction on
  the wall panel.** The settled treatment routes to the tab; the claim juice (gem-fly to wallet + BIT cheer,
  `quest_claim_flight.dart`) belongs on the board/tab, not on the diorama furniture. Tap-to-claim *on the furniture*
  is a NEW interaction to validate, not the default → tap the board = open Quests; the board only *signals* claimable.
- `[validated, refine]` **The two-line lowercase caption ("2/5 weekly · nothing to claim") fails room-scale
  legibility** ([HUD instant-legibility, no quest names](https://vsquad.art/blog/what-hud-games-complete-guide-game-interfaces))
  → keep the `QUESTS` cap + 5-seg bar + at most one short status token; the prose lives on the tab.
- Pixel: match the bar to the pad's cyan LED (`pad_charge_meter.dart` `_lit`) so board+pad read as one system; crate
  face → `kCard` emboss. → `ironbit-design`. Evidence-challenge folds into the build's deep-feature Stage-4 (no fresh
  Codex run — settled research, reused).

---
**Superseded (kept for rationale):** the earlier card-peek research below — `_buildWeeklyQuestsCard` already exists
(`N/5` count + segmented bar + `VIEW ALL >`, routes via `onViewQuests`); the principles (subordinate, surface the
*actionable* state, BIT-voiced) carry over to the in-room board even though the surface changed.
- `[validated]` **A home peek of an already-tabbed feature is clutter UNLESS it surfaces an actionable/glanceable
  state the tab would hide** — duplicate nav is only justified by a real usability win (discoverability / lower
  cognitive load), not "displaying the same info twice" ([UXPin](https://www.uxpin.com/studio/blog/ux-design-patterns-focus-on/),
  [Justinmind](https://www.justinmind.com/blog/navigation-design-almost-everything-you-need-to-know/)). → the peek
  must show the **actionable quest state** (a *claimable* quest "● READY", the next quest's progress), not a bare
  "you have quests". A pure count is borderline; surfacing the claim/next-step earns its place.
- `[validated]` **Gamified-task apps surface the actual quest on home, not just a count** — Duolingo puts the daily
  quest *on the home screen* (chest tab for the rest); Habitica's home *is* the task list ([Duolingo](https://blog.duolingo.com/new-duolingo-home-screen-design/),
  [Habitica](https://www.androidpolice.com/gamifying-daily-habits/)). Material: summary card + an `action area`
  ("VIEW ALL") at the bottom. → show **1–2 real quest rows** (the next/most-relevant + any claimable), a tiny
  BIT-voiced line (match the board's header), the count/bar, and the `VIEW ALL` route — keep BIT the voice.
- `[validated]` **It must be visually SUBORDINATE to the primary mission CTA** — secondary content must not compete
  in size/colour; "when everything is emphasised, nothing is"; scale separates primary↔secondary
  ([uxpilot](https://uxpilot.ai/blogs/visual-hierarchy)). → a **compact full-width card** (kCard, ~kSpace3 pad,
  ~1–2 rows, ≈100–140px), muted (neon reserved for the mission CTA + the `VIEW ALL` link), below the hero diorama.
  **Position:** group it with the `AdventureCard` (the secondary reward-hook tier) after the mission — *not* buried
  last in the feed. Pixel look → `ironbit-design`; Codex evidence-challenge folds into the redesign's deep-feature Stage-4.

### Main color theme — cool-arcade vs iron-forge (2026-06-19)
Feeds a possible brand re-theme (the user asked to reconsider the main palette). Audit truth: cool indigo base
(`#11111F/#1C1C34/#36365E`), neon-green hero (`kNeon`, 335× / 66 files — 2.6× the next accent), amber #2 (128×),
then cyan/red/magenta; the cool end is crowded (neon `#00FF9C` ≈ BIT turquoise `#17D6CC` ≈ cyan `#00BFFF`) and the
total sprawls to ~8–9 hues (incl. muscle violet `#9B59B6`, orange `#FF6B1A`, class violet `#B14DFF`). Color lives in
**3 places** — tokens (cheap to change), ~45 procedural raw-hex palette files (medium), and **baked PNGs** (BIT raster
sprites, 4 window PNGs, pad PNG, 3 adventure biomes × 3 parallax layers + 13 loot sprites + emblems, gem/economy icons,
~150 control-icon pack, class icon art — expensive, a token change does NOT touch them).
- `[validated]` **Neon-green-on-dark is a cyberpunk/hacker cliché OUT of category but DISTINCTIVE within fitness** —
  fitness branding skews blue/teal/white/clean ([Stellen](https://www.stellendesign.com/colors-for-fitness-branding/),
  [Hevy Coach](https://hevycoach.com/fitness-branding-ideas/)); green-on-black is "the hacker aesthetic"
  ([DevPalettes](https://devpalettes.com/neon-color-palettes/), [Page Flows](https://pageflows.com/resources/cyberpunk-color-palette/)).
  → the green is in-category equity, not generic; don't ditch it *only* for being a cliché.
- `[validated]` **Palette temperature shapes mood/identity, not measurable performance** — warm (red/orange/amber) =
  intensity/power/strength; cool (blue/green) = calm/focus/recovery; the color→performance effect is thin (2022
  meta-analysis, 69 studies) ([Les Mills](https://www.lesmills.com/articles/color-psychology)). → the critique is that
  Ironbit's *dominant* hue is cool (sci-fi/terminal) while its **soul is strength/grit**; the warmth that matches the
  mood (amber/ember) is only a secondary accent. Identity-argument, not a performance claim.
- `[assumption]` **An "iron-forge" warm lean fits the name + soul + existing warm-earthy biomes** — forge palette
  (iron grey / ember orange / forge amber / charcoal) is a documented "strength/power/craftsmanship" identity
  ([colorpalette.org](https://colorpalette.org/blacksmith-metalsmith-forge-color-palette/)). → recommended lean: KEEP the
  indigo-iron base + scope-C cleanup (one hero, resolve the cool crowd, tokenize one-offs) regardless; re-weight WARM
  (amber/ember carries identity, neon demoted to a "go/tap" signal) rather than a teardown. **Open decision (user's
  taste call):** cool-arcade wedge vs iron-forge — the evidence can't pick; needs the user's intent before a
  deep-feature plan. Pixel execution → `ironbit-design`.

### Semantic vs brand color tokens — DECOUPLE the quality ladders (2026-06-19)
Decision for the color-hygiene pass (Bucket B: rank/rarity/muscle/calendar reuse brand hex as *meaning*).
- `[validated]` **Design-token best practice = layered primitive→semantic/alias, and brand colours must be
  SEPARATED from functional colours** so a brand recolor only edits primitives while role tokens stay put
  ([UXPin](https://www.uxpin.com/studio/blog/color-consistency-design-systems/),
  [DSP](https://designsystemproblems.com/token-management/semantic-vs-primitive-tokens/),
  [Contentful](https://www.contentful.com/blog/design-token-system/)).
- `[validated]` **Loot-rarity / rank colours are a cross-game CONVENTION** (common white · uncommon green · rare
  blue · epic purple · legendary gold) players transfer between games ([TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/Main/ColorCodedItemTiers)).
  Ironbit's `LootRarity.color` ALREADY follows it — so coupling rarity to the brand would **break a recognizable
  ladder** on re-theme. Decisive for decoupling.
- `[validated]` **Over-abstraction is real ("token fatigue" / "indirection hell")** — don't alias everything; but
  *"semantic naming from the start costs nothing; adding it later costs weeks"* ([webdesignerdepot](https://webdesignerdepot.com/token-fatigue-when-abstraction-eats-itself/)).
- **DECISION:** rank (`kRankS..D`) + rarity (`kRarity*`) become their **own fixed tokens** holding the current
  hexes (byte-identical now, independent on re-theme); **calendar-state markers ALIAS brand tokens** (workout-done
  legitimately follows the active colour); the muscle map stays (already token-clean — flag a categorical decouple
  at re-theme time). **Do NOT** add a full `kBrandPrimary` alias over kNeon's 335 uses — over-engineering for a
  solo pre-launch app. Captures the cheap-now/costly-later asymmetry exactly where stakes are highest.

## Core assumptions (to validate post-launch)
- `[assumption]` Visible, *earned* RPG progression improves training consistency vs. plain logging.
- `[assumption]` Character attachment (avatar + name + class + rank + frame) is the strongest
  long-term retention hook.
- `[assumption]` A repeatable ritual loop (mission → workout → summary → character growth) matters
  more than one-off novelty after week 2.
- `[assumption]` Collection desire around frames, titles, themes, and ranks can carry motivation
  through slow physical-progress periods.
- `[assumption]` The target user values privacy/offline enough that "no tracking" is a real draw.
- `[assumption]` Pixel-arcade identity attracts more than it repels for a fitness audience.

## Open risks
- `[risk]` Onboarding is long (cinematic, multi-screen) — drop-off could be high. Measure the funnel
  ([../statistics/instrumentation-plan.md](../statistics/instrumentation-plan.md)).
- `[risk]` No social/competition loop (out of scope) may limit retention for some users unless the
  character-attachment loop is strong enough.
- `[risk]` Offline/no-account means no remarketing or re-engagement channel post-install.

## Competitive landscape (to fill in `competitive/`)
- Gamified fitness apps that feel disposable are the foil — Ironbit's contrast is an identity the
  user keeps strengthening through real training.
- Note: most competitors are online/account-based; the offline+private stance is differentiating.

## Validated
- _(none yet — pre-launch)_

## Decision notes

### Profile / identity surface — audit + direction (2026-06-18)
Audit ([profile_page.dart](../lib/pages/profile_page.dart)): 3 tabs — (0) character sheet (avatar→
customizer, editable name, rank+level badges, XP bar, LCK multiplier, "N rewards ready", a glance strip
[training days / quests done / titles], stat radar, class, inventory shortcut, opt-in body metrics);
(1) cosmetics (loot frames); (2) settings (training defaults, units, class-change, support). All the
soul-doctrine identity hooks are present; the weakness is it reads as *character-sheet + settings
drawer*, with the pieces siloed rather than telling one story. Decision target: [../docs/PRD.md](../docs/PRD.md)
identity hooks + soul doctrine (identity attachment). Codex-reviewed (evidence).
- `[validated]` **Self-monitoring is the strongest, most on-brand lever (not the avatar).** Monitoring
  goal *progress* has a **large effect on behavior (d=0.79)** but **no reliable effect on outcomes
  (d=0.14)** (Harkin et al. 2016 meta-analysis, 138 studies, N≈19,951 —
  [Semantic Scholar](https://www.semanticscholar.org/paper/Does-monitoring-goal-progress-promote-goal-A-of-the-Harkin-Webb/71c6265bf7a8ded9084ff21a417cd63d6f4119ea),
  [self-regulation meta-review](https://pmc.ncbi.nlm.nih.gov/articles/PMC7571594/)). → the Profile's job
  is a **private progress mirror of the ACT of training** (consistency/streak, rank journey, titles &
  frames collected, milestones) — **never body outcomes**, which also satisfies the body-neutral mandate.
  Reframe the flat glance strip into one coherent identity narrative.
- `[validated, principle]` **Coherence** (Duolingo): one shared currency feeding streak/rank/achievement
  makes a system feel coherent, not fragmented ([case study](https://trophy.so/blog/duolingo-gamification-case-study)
  — *exact retention %s are vendor/blog, illustrative not evidentiary*). → our XP/LCK/quests/titles/frames
  are siloed widgets; the profile is where they should cohere into "who you've become."
- `[validated]` **No users + body-neutral → the profile is a private mirror, not a comparison/signaling
  surface.** Social comparison & leaderboards risk demotivation + body-image harm
  ([CHI 2025](https://dl.acm.org/doi/10.1145/3706598.3713737),
  [Frontiers 2025](https://www.frontiersin.org/journals/public-health/articles/10.3389/fpubh.2025.1632598/full),
  [JMIR scoping review](https://www.jmir.org/2020/3/e15642/)). Keep **share-ready artifacts** (rank/title/
  frame/"card") for *future opt-in* social — don't build comparison.
- `[assumption]` **Avatar identification ("character-as-hero")** may lift intrinsic motivation/effort
  (Proteus effect) — but evidence is mostly **VR** + one non-immersive 2D runner, requires avatar
  *ownership*, with an explicit gap for 2D mobile loggers
  ([Proteus review](https://www.tandfonline.com/doi/full/10.1080/07370024.2022.2103419),
  [CHI 2025 VR](https://dl.acm.org/doi/10.1145/3706598.3713203)). → cheap to try (we already have the
  pixel-face customizer) but a **hypothesis**, not a validated bet; don't over-invest in fidelity.

### Quest system rework — variety, narrative, reward juice (2026-06-17)
Feeds a planned quest-system rework (audit: the tab reads "colorless/boring"). Decision target:
[../docs/PRD.md](../docs/PRD.md) Quests + root `CLAUDE.md` soul doctrine (ritual return). Mechanisms
literature/competitor-`[validated]`; the *product fit* `[assumption]` until a deep-feature plan + on-device
review. **Audit:** quests are hardcoded constants (same 3 daily / 5 weekly / 5 side every period —
[quest_service.dart](../lib/services/quest_service.dart)), gems-only + XP hardcoded `0` on claim, no BIT
voice/narrative, flat reward ladder, generic Material `Card` chrome, claim burst spatially divorced from the
wallet counter.
- `[validated]` **Rotation/variety is the anti-staleness engine** — Duolingo refreshes 3 daily quests from a
  varied pool daily + a weekly re-rolling Friends Quest + monthly challenge; Finch uses themed journeys +
  seasonal events ([Duolingo quests](https://3isolution.org/duolingo-guides/duolingo-quests-guide-daily-friend-and-monthly-challenges/),
  [Finch](https://webisoft.com/articles/finch-self-care-app/)). → **Ironbit fit:** a local quest **pool with
  deterministic daily/weekly selection** (mirrors the Guild's "deterministic per ISO week" + loot milestones;
  no backend needed).
- `[validated]` **Variable-ratio reward is the strongest schedule** (slot-machine effect; dopamine stays
  elevated under unpredictability) ([habit loop in games](https://dev.to/krizekster/the-habit-loop-hidden-in-every-game-youve-ever-loved-14kn),
  [Storyly](https://www.storyly.io/post/gamification-strategies-to-increase-app-engagement)). `[validated, contrary]`
  **but extrinsic/expected/contingent rewards crowd out intrinsic motivation** (overjustification / motivation-crowding;
  [Overjustification](https://en.wikipedia.org/wiki/Overjustification_effect)) — consistent with Deci 1999 (this file).
  → reward the **act** (legible), keep gems cosmetic-only, ladder + occasional rare payout, never let the number
  become the reason to train.
- `[validated]` **Narrative makes a chore mean something** — Zombies,Run! draws on Octalysis Core Drive 1 (Epic
  Meaning) + 7 (Unpredictability) where most fitness apps stop at accomplishment; Habitica/Finch wrap tasks in
  fiction ([Yu-kai Chou](https://yukaichou.com/gamification-analysis/top-10-gamification-in-fitness/),
  [Zombies,Run!](https://en.wikipedia.org/wiki/Zombies,_Run!)). → **highest soul-per-effort lever: put BIT on the
  quest board** (assigns contracts, reacts on claim, frames the weekly arc) — the one major surface with no
  companion voice today.
- `[validated]` **Reward-claim juice = currency flies from the claim point to the wallet counter** (draws the
  cause↔effect loop), with an anticipation pause, count-up on landing, the *actual* amount (don't inflate
  particles), distinct sound + landing pulse ([Game Economist currency animations](https://www.gameeconomistconsulting.com/the-best-currency-animations-of-all-time/),
  [game juice](https://gamedev4u.medium.com/when-you-play-a-great-game-it-feels-good-d23761b6eccf)). → our current
  `GemClaimBurst` sprays shards *outward* (no number, no wallet link); the header count-up already exists — connect
  them. Reduced-motion still fallback (WCAG 2.3.3, standing rule).
- `[risk]` **The most powerful Duolingo/Habitica hooks run on guilt + loss-aversion** (streak-death anxiety, sad
  owl, missed Dailies damage your character) — widely criticized as dark patterns
  ([Duolingo dark patterns](https://opinionsandconditions.substack.com/p/duolingo-owl-dark-patterns-digital-guilt)).
  **Ironbit's anti-guilt/body-neutral doctrine forbids this** (same call as BIT absence-states + Finch earn-only).
  → borrow variety/variable-reward/narrative/juice; **reject loss-punishment**. A missed quest is absence, never a penalty.
- `[validated]` **Hierarchy by size** — a flat list where every quest is the same weight fails; feature a hero quest,
  add per-quest progress bars (goal-gradient), make title-granting side quests a big deal
  ([Game UI principles](https://www.justinmind.com/ui-design/game)). *(In-app look owned by `ironbit-design`.)*
- `[validated, directional]` **Claimed-amount display — price tag vs reward reveal** (feeds the quest-claim
  port-handoff delta: the handoff put the gem amount on the card; we don't). A *pre-claim* number on the card is a
  **price tag** (transactional → removed, body-neutral, "not a price tag"); a *post-claim* "+N" by the wallet is a
  **reveal** (celebrates the act). Leading apps surface the earned amount as a post-claim reveal — Habitica gold
  pop-up, Duolingo XP/gem reward beat ([Habitica gold](https://habitica.fandom.com/wiki/Gold_Points),
  [Duolingo rewards](https://duolingoguides.com/duolingo-rewards/)) — common + legible. `[validated, contrary]`
  **don't over-pop:** saccharine per-action congratulation annoys, excess juice = cognitive overload/exits,
  extrinsic-number over-reliance = over-justification ([Usability Geek](https://usabilitygeek.com/positive-reinforcement-ux-design/),
  [S-shaped richness](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12554716/)). → wallet **count-up is the primary
  signal**; an optional **single modest "+N" float** (gem-magenta, fades, once/claim — never on the card) is the
  legible add; no amount on the card stands either way.

### Quest "Limit Break" — personalized weekly-volume target (2026-06-18)
Feeds the rotating quest bucket (the "Limit Break" weekly quest): set a weekly total-volume target
(kg moved) from the user's own history that is "doable but a little stretch", rounded to nearest 100.
Body-neutral (kg-moved, not body weight; optional, unpunished). Decision target: the quest-pool rework
([insights.md] quest-rework note + root `CLAUDE.md` soul/recovery doctrine). Mechanisms `[validated]`;
the exact factor `[assumption]` until on-device tuning.
- `[validated]` **Progress volume *gradually*** — productive range ~10–20 hard sets/muscle/week; "start
  low, add slowly (a set every 2–4 weeks, not weekly), more-is-not-better" ([RP Strength](https://rpstrength.com/blogs/articles/training-volume-landmarks-muscle-growth),
  [Outlift](https://outlift.com/hypertrophy-training-volume/)). → small bump, never a leap.
- `[validated, contested]` **ACWR sweet spot 0.8–1.3, danger >1.5** (acute=last 7d vs chronic=mean of
  prior 3–6 wk) ([ScienceForSport](https://www.scienceforsport.com/acutechronic-workload-ratio/),
  [PubMed pitfalls](https://pubmed.ncbi.nlm.nih.gov/32502973/)) — its predictive validity is **disputed**,
  so use as a directional ceiling, not a prevention claim. → cap the stretch at **≤1.3× baseline**.
- `[validated]` **Goal-setting: challenging-but-attainable beats easy/vague ~90% of the time, but the
  curve is curvilinear — past one's ability, performance drops** (Locke & Latham; [overview](https://positivepsychology.com/goal-setting-theory/)).
  → a real stretch, capped well short of impossible.
- `[validated]` **Competitor precedent = the same pattern:** Apple Activity rings review weekly, suggest
  the next goal from the *previous week's* performance, "challenged but not overwhelmed"
  ([Apple Support](https://support.apple.com/guide/iphone/adjust-your-activity-ring-goals-iph9a08e004e/ios)).
- **→ Recommended formula:** `target = round100( avg(last ≤4 completed ISO-weeks total volume) × 1.15 )`,
  clamped to `[×1.05, ×1.30]`. Baseline = recent **average** (not the peak week). Cold-start: needs ≥1
  completed week — if 0, **exclude Limit Break from rotation**; with 1–2 weeks use ×1.10 (noisier). Volume
  is a **noisy proxy** → keep it a gamified nudge, never a prescription.

### BIT interview — typewriter transitions + tap-to-continue (2026-06-17)
Feeds the calibration-quiz BIT bubble (decision: replace the cross-fade with a typed reveal; pacing to
tap-to-continue). Mechanisms `[validated]`; the *feel* `[assumption]` until on-device sign-off.
- `[validated]` **A typewriter/teletype reveal is ON-character for a *robot* mascot** (terminal/CRT
  idiom; constant interval = mechanical vs variable = human) — the reframe that flips the generic
  "typewriter is bad UX" finding into a fit. Keep it **fast + consistent** (~22 ms/char ≈ 45 cps; game
  dialogue runs 20–40 cps).
- `[risk]` **Typewriter's failure mode: slower than reading → users wait / immersion breaks; screen
  readers read partial words; moving letters can dizzy.** → MUST allow **tap-to-skip** (first tap
  completes the line), put the **full line in Semantics**, and **show full text under reduced motion /
  accessibleNavigation** ([fix-the-typewriter](https://dev.to/savvasstephnds/the-problem-with-the-typewriter-effect-and-how-to-fix-it-2731);
  [a11y motion](https://blog.pope.tech/2025/12/08/design-accessible-animation-and-movement/)).
- `[validated]` **Tap-to-continue (manual) > auto-advance** for self-paced dialogue agency — the reader
  sits with a line as long as they like; auto-advance risks rushed-or-waiting and the right speed is
  per-reader ([VN self-pace](https://vnpaths.com/how-to-play-visual-novels/)). → dropped the auto-advance
  timer; subtle "tap to continue" hint, tap anywhere advances (two-tap: tap completes the type, tap goes).

### Home scroll parallax (2026-06-16)
Feeds the Home-room parallax (decision: plan `home scroll parallax`; in-app look owned by
`ironbit-design`). Mechanisms `[validated]`; the *feel* `[assumption]` until on-device sign-off.
- `[validated]` **Parallax improves perceived depth/immersion/engagement but NOT usability** — the
  Purdue study (n=86) + UX consensus found no usability gain ([UXPin](https://www.uxpin.com/studio/blog/3-crucial-ux-considerations-going-parallax/),
  [Purdue](https://docs.lib.purdue.edu/dissertations/AAI1544322)). → justified only as *delight* on the
  identity-hero room, kept subtle (daily surface → novelty fades).
- `[validated]` **Accessibility gate** — scroll parallax can trigger vestibular reactions; WCAG 2.3.3
  requires it be disable-able ([Web Axe](https://www.webaxe.org/vestibular-issues-parallax-design/)). →
  gated on `disableAnimations`.
- `[risk]` **Pixel-art shimmer** — fractionally translating crisp sprites breaks the grid. → drift only
  the soft far-wall background; sprites untouched. Shipped: subtle intra-room background drift.

### Onboarding solution screen — BIT + first "level-up" (2026-06-15)
Research feeding the screen-3 redesign (decision: [../docs/PRD.md](../docs/PRD.md) onboarding;
companion doctrine in root `CLAUDE.md`). Mechanisms are literature-`[validated]`; the *product
application* is `[assumption]` until on-device comprehension/pressure testing.
- `[validated]` **Informational/verbal positive feedback raises intrinsic motivation via perceived
  competence; tangible, expected, contingent rewards undermine it; controlling/pressuring praise is
  inert** (Deci/Koestner/Ryan 1999 meta n=128; CET). **Precondition: competence feedback needs a
  prior act** — invalid on screen 3 (pre-action). → screen-3 BIT = autonomy-support + expectation/
  curiosity, *not* competence-affirmation; reserve competence beats for post-calibration / first workout.
- `[risk]` **A prominent onboarding "level-up" before any training risks over-justification +
  unearned-trophy (cheapens the first *real* level-up) + overpromise.** Mitigation `[assumption]`:
  render it as a clearly **non-awarding preview/simulation** (e.g. ghost/locked meter fill, "here's
  what every rep will do"), keep the first earned level-up as the bigger moment. The preview-vs-reward
  distinction is **not directly evidenced** — must be comprehension-tested.
- `[validated]` **Juice motivates via competence + curiosity, strongest when *success-dependent*; raw
  amplification can backfire by impeding agency** (CHI'24 pre-registered n=1,699) — *directional* for a
  2s beat. → prominent ≠ louder; anticipation→payoff, restraint, no strobe/shake dependency.
- `[validated]`→`[assumption]` **Anthropomorphic agents act as Bandurian role models and form genuine
  parasocial bonds, but bonds build over use** (virtual-companion HCI). → screen 3 is BIT's *first
  handshake* (relatedness initiation), not a mature ally; attachment is earned across the flow.
- `[risk]` **Guilt/pressure mascot framing backfires** (Duo dark-pattern criticism; guilt appeals
  repel). → BIT stays warm/supportive/autonomy-respecting, never guilt or hype. Ties to body-neutral:
  a "level-up" must read as the *character* growing from the *act* of training, never a body/perf grade.

### Bar visual system — same frame, vary the fill (2026-06-16)
Feeds the canonical `ArcadeBar` decision (root `CLAUDE.md` theme conventions). Industry practice is
literature-`[validated]`; the *fit* to this fitness-RPG is `[assumption]` until on-device review.
- `[validated]` **One shared frame (track + outline), differentiate by the FILL — colour + functional
  mode — not bespoke per-bar styles.** RPG GUIs keep the fill *separate from the outline* so it
  recolours/re-themes without redrawing the frame ([RPG HUD practice](https://opengameart.org/content/rpg-hud);
  [NN/g design systems](https://www.nngroup.com/articles/design-systems-101/)). This is exactly the
  user's "frame + filling material" model. Inconsistent bar styles break recognition + brand cohesion
  ([Carbon](https://carbondesignsystem.com/components/progress-bar/usage/)).
- `[validated]` **Taxonomy — differentiate *between* categories, not within:** progress-to-goal (XP /
  program path / quest count) · resource **meter** (depletes/recovers — VIT) · **timer** (countdown) ·
  system loading (indeterminate → `pixel_loader`, not a bar)
  ([UXPin trackers vs indicators](https://www.uxpin.com/studio/blog/design-progress-trackers/)).
- `[validated]` **Uniform juice = polish:** smooth fill (never snap) · delayed "ghost/trail" delta on
  change · bright leading-edge "charge front" · colour-flip + flash on completion/level-up — all
  reduced-motion-safe ([game juice](https://itch.io/blog/1059831/making-a-game-feel-juicy-with-simple-effects);
  [MMProgressBar delayed bars](https://feel-docs.moremountains.com/mm-progress-bar.html)).
- **Open work:** express the VIT meter + rest timer as fill *modes of the same `ArcadeBar` frame* (retire
  the bespoke `_VitalityTintedBar` *style* while keeping its meter *behaviour*); add charge-front +
  ghost-trail juice.

### Avatar frame cosmetics — self-contained assets on a shared spec (2026-06-20)
Feeds the avatar-frame asset rebuild (decision: new frame set + kill the inner-box bleed in
`loot_avatar_frame.dart`; in-app *look* owned by `ironbit-design`, the render/state change by
`deep-feature`). App-specific render math is `[assumption]` until size-validated.
- `[validated]` **Frame cosmetics = a fixed square canvas with a centered transparent SAFE-AREA
  "aperture" all frames share, decorative bits allowed to OVERFLOW the avatar bounds** — the same
  "shared frame, vary the fill" recognition principle as the bar system. Fix for the "chunky/non-uniform"
  complaint: author the whole set to ONE aperture + a fixed border-thickness band + shared outline/palette/
  grid; "consistency > individual asset quality" ([Discord decoration guidelines](https://github.com/decor-discord/.github/blob/main/GUIDELINES.md);
  [pixel-art assets](https://pixnote.net/en/learn/game-assets/); [style guide](https://www.sprite-ai.art/blog/2d-pixel-art-style-guide)).
- `[assumption]` **Discord's specific 1.2× canvas ratio** (decoration = 1.2× the avatar) is community/
  third-party precedent, not official docs — borrow the *principle* (safe-area + overflow), tune the exact
  ratio on-device.
- `[validated]` **Pixel-art render: `FilterQuality.none` (nearest-neighbor) + INTEGER scaling only;
  `BoxFit.fill` is wrong** (anisotropic stretch distorts pixels) — the current widget stretches each frame
  PNG with `BoxFit.fill`, the technical root of the chunky look (plus Impeller edge-stretch
  [flutter#145264](https://github.com/flutter/flutter/issues/145264)). → pin a source canvas + a few
  integer-friendly display sizes; **the small inventory thumbnail is the hard case** (validate per-size).
- `[assumption]` **Full-bleed fixed-canvas PNG vs 9-slice vs per-size exports is a BAKE-OFF, not settled**
  — the widget renders at several sizes (130/128/180/260 + tiles), exactly 9-slice's use case; but
  decorative frames (flames/particles, unique corners, overflow) lack a repeatable edge. → prototype one
  thin + one chunky frame across all three, judge by screenshots at every real size.
- `[validated]` **Inner-box bleed is a bounded 2-call-site fix** — `LootAvatarFrame` is used only in
  `profile_page` (identity card; `framePath` null = the default "just a box") and `shop_page` preview
  (always passes a frame). Make the FRAME the only border source: default renders `frame_iron`, equipped
  suppresses the separate 1px box border (keep the kBg backdrop for face contrast). No other surface
  regresses (inventory tiles draw frame art alone; customizer/guild/home don't use it).
- `[risk]` **Static vs animated is a real tension** — Discord decorations are animated (collection/identity
  hook); static is the perf/bundle/reduced-motion-safe default. → static base, optional **1–2-frame neon
  "shine"** on rare/epic only (on-brand per the burst finding), reduced-motion-gated.
- **Acceptance criteria (carry into the build):** aperture must not crop the face; frame ≠ legibility/
  contrast loss; cap PNG master dimensions + bundle budget for the full set; body-neutral/soul lens =
  frames are identity/collection (on-doctrine), never body outcomes.

### Onboarding solution screen — face reveal as the peak (2026-06-16)
Deeper passes feeding the screen-3 build (decision: screen-3 redesign + companion doctrine, root
`CLAUDE.md`). Mechanisms literature-`[validated]`; the *feel* is `[assumption]` until on-device review.
- `[validated]` **Peak-end rule** (meta-analytic, large effect r≈0.58; duration-neglect): make screen 3
  a deliberate emotional **peak**, amplified by contrast with the screen-2 low; one clear peak > a busy
  montage → the **face reveal is the single peak**; the level demo is subordinate.
- `[validated]` **A revealed face/eyes drives bonding:** eye contact + a held gaze → trust, empathy, and
  reward-region brain activity; **eyes-only** lets users project emotion; a **blink** = the sign of life
  (HCI/affective). **Delayed reveal** pays off the withheld mystery (Zeigarnik); **minimalist pixel is
  uncanny-safe**. → screens 1–2 faceless = the setup; screen 3 = the payoff.
- `[validated]` **Strong/steady ≠ cold:** a dependable figure is a **secure base** (safe haven enabling
  autonomous exploration) — strength reassures when **steadfast, not stern**. → BIT's neutral face +
  strong voice, copy **leads with protection then resolve** ("sternness check", not just a cuteness check).
- `[validated]` **Animation weight:** heavy/slow easing reads as gravitas/solidity; **avoid bouncy
  `easeOutBack`** for the power-up/reveal.
- `[validated]` **A persistent subject carries transition meaning:** BIT held across the problem→solution
  cut (rest-aligned cross-fade, then morph *after* the cut) reads as "the companion that slumped with you
  now stands up for you" — continuity = the relationship.
- `[risk]→[assumption]` **Keep BIT subordinate:** revealing BIT before the user's character exists risks
  making the companion the protagonist → BIT is **presenter/guide** on screen 3; the start gate stays the
  user-hero's bigger embodiment (acceptance criterion). Real level-up grammar stays reserved for the
  earned post-workout moment (removed the fake "+1 LV" quiz handoff; fixed two WCAG-2.3.1 strobes).

### Onboarding quiz — BIT interview voice + "promise" reactions (2026-06-16)
Feeds the BIT-voiced calibration quiz (decision: `docs/PRD.md` onboarding "interview voice" planned
follow-up; companion doctrine in root `CLAUDE.md`). Mechanisms literature-`[validated]`; the *product
fit* is `[assumption]` until on-device comprehension testing.
- `[validated]` **The "promise" reframe is a coping plan / implementation intention** — turning a named
  obstacle into a simple if-then ("when boredom hits → rotating quests") has a real but **modest** effect
  (PA d≈0.31; up to d≈0.65 across health behaviors), shrinking when the situation differs from the plan
  and interacting with self-efficacy ([Bélanger-Gravel 2013](https://www.tandfonline.com/doi/abs/10.1080/17437199.2011.560095);
  [Gollwitzer & Sheeran 2006](https://cancercontrol.cancer.gov/sites/default/files/2020-06/goal_intent_attain.pdf)).
  → keep each promise **one simple reassuring if-then**, never a rigid contract.
- `[validated]` **"Feeling understood" drives relatedness/well-being** (Reis 2017; Reis et al. 2000) — the
  upside BIT's reflection reaches for.
- `[validated]→[assumption]` **A non-human agent that *claims to feel* backfires** (USF 2026, 3 exps:
  mirroring the user's emotion → psychological **reactance** + lower perceived competence;
  [EurekAlert](https://www.eurekalert.org/news-releases/1124985)). **Design hinge:** the chosen aha —
  **"reframe into a promise" (demonstrated understanding via *action*) is the SAFE form**; pure validation
  ("I know that's hard") is the risky one. **BIT must never say "I understand how you feel"** — it earns
  understanding by naming the specific thing + what the system does about it. (USF context was
  service-recovery; our just-bonded mascot in a non-complaint moment is lower-risk → drives a copy rule,
  not a scope cut.)
- `[assumption]` **Savor + CONTINUE is defensible *only if the beat delivers visible value*** — the
  labor-illusion/effort-heuristic ([Buell & Norton 2011](https://www.hbs.edu/ris/Publication%20Files/Norton_Michael_The%20labor%20illusion%20How%20operational_f4269b70-3732-4fc4-8113-72d0c47533e0.pdf))
  says *visible meaningful* effort raises value, but onboarding friction is the top churn source
  (decision fatigue after ~2 choices; a fitness app's 3-step intro → +44% completion). → react on **only
  the 4 emotional questions**, not all 7; a generic beat would be dead friction.
- `[validated, directional]` **Reacting to the FIRST multi-pick is sound** (primacy + satisficing) — but
  phrase the promise as "**one** of the things you named," never "**the** thing," so it never feels wrong.
- `[validated]` **Competitor precedent:** Finch (card quiz the **pet reacts to**, gradual personality
  reveal — but *light* reactions), Fabulous (**commitment checkboxes** as "promise to a friend" + "why"
  framing), Duolingo ("**why are you learning?**" motive question). The pattern is proven; the risk is
  making BIT's promise heavier/more canned than Finch's light touch.

### Home "Today's Mission" card — hierarchy polish (2026-06-16)
Feeds the Home mission-card polish (decision: plan `leave-the-action-model`; in-app *look* owned by
`ironbit-design`). User chose to **keep starting a workout on the center Train nav button** and polish
visuals only. Mechanisms `[validated]`; the *fit* `[assumption]` until on-device sign-off.
- `[validated]` **Accent competition** — ≤2 focal accents per section; "five accent colours is a common
  mistake; when everything is important, nothing stands out"
  ([NN/g](https://www.nngroup.com/articles/visual-hierarchy-ux-definition/),
  [Moburst](https://www.moburst.com/blog/color-hierarchy-in-ux-design-how-it-influences-users/)). → on a
  no-in-card-CTA content card, **neon is reserved for the card border (structure) + the progress-bar fill
  (the one interior focal point)**; header / path-label / NEXT demoted to muted; one amber reward chip.
- `[validated]` **Goal-gradient / endowed progress** — keep the `X/N → reward at 100%` meter; reward
  anticipation rises with proximity
  ([endowed progress](https://medium.com/@davidteodorescu/design-perfect-ux-tasks-the-endowed-progress-effect-7461ca20076c)).
  Milestone reward stays a **quiet locked teaser** ("PATH REWARD AT 100%"), scoped distinct from the
  immediate per-session reward chip — avoids over-justification (Deci et al., this file).
- `[validated]` **Anticipation/Zeigarnik** — keep the next-up teaser but **demote it + drop the repeated
  focus line** (the label + when carries the forward pull; full detail is seen on arrival).
- `[risk]` The **box-in-a-box** nesting (a bordered panel inside a bordered card) reads as drift —
  *unless* the inner panel is a deliberate **common-region zone** grouping related items (Gestalt;
  [NN/g](https://www.nngroup.com/articles/common-region/)). One *weighted* panel earns its keep; one
  box per element is the "cage of rectangles" anti-pattern.
- `[validated]` **Section-consistency** — mixing bordered + unbordered sections at the *same* tier
  reads as accidental; be consistent within a tier, weight across tiers
  ([UX Design World](https://uxdworld.com/designing-ui-cards/); a single-element border still *suggests
  a relationship*, [DesignerUp](https://designerup.co/blog/ui-design-tips-boxes-and-borders/)). → the
  bare NEXT row beside the framed PATH was the orphan; both became `ArcadeCard` zones, NEXT lighter.
- **Shipped direction (2026-06-16):** node-trail explored + **dropped** for a zoned layout — white hero
  (unboxed) + sub-label tight to the title + **two weighted common-region zones** (primary PATH = bar +
  count + locked `REWARD`; lighter NEXT) both via `ArcadeCard` + an in-card neon **START TRAINING** (the
  action model reverted; funnels through the same `_startProgramWorkout` launcher as the center Train
  button). `[assumption]` pending on-device sign-off.

### Bottom nav — center Train/START keycap color collision (2026-06-16)
- `[validated]` **`kNeon` is role-overloaded in the bottom nav.** The active-tab indicator (icon+label),
  the center keycap face, *and* its TRAIN/START caption all render full `kNeon` — so the same green means
  both "you are here" (selection) and "do this" (primary action). The primary CTA can't be told apart from
  the selected-tab state by color. → Decision driver for any nav-button polish.
- `[validated]` **Canonical pattern separates these two roles.** Material 3 assigns the **primary** color
  to the FAB/key action and a **secondary** treatment to the nav active indicator (filled icon in a pill) —
  they are deliberately *not* the same color
  ([M3 nav bar](https://m3.material.io/components/navigation-bar/guidelines),
  [M3 color roles](https://m3.material.io/styles/color/roles)). A center action also *loses* prominence when
  it sits beside an equally-prominent nav element ([m2 FAB](https://m2.material.io/components/buttons-floating-action-button)).
- `[validated]` **The differentiator need not be a new hue.** Color-hierarchy consensus: keep one accent and
  separate roles by **brightness/saturation + fill-style + shape/elevation**; the brightest/highest-contrast
  treatment goes to the single most important action
  ([owlestudio](https://www.owlestudio.com/app-color-combinations-guide/16373/),
  [supercharge](https://supercharge.design/blog/a-guide-to-colors-in-design-systems)).
- `[validated]` **Tension (real):** single-accent + shape/depth differentiation (Duolingo: one green for all
  primaries, distinguished by the 3D pressable depth signature —
  [refero](https://styles.refero.design/style/7088d695-362b-4e09-b325-fa8136d4f350)) vs distinct-color CTA
  ([UX Movement: don't use the brand color for the CTA](https://uxmovement.substack.com/p/why-you-shouldnt-use-your-brand-color)).
  → For Ironbit, a hue-swap is **constrained**: `kAmber`=reward/gems and `kCyan`=secondary/recovery are
  already owned, so recoloring the keycap risks a *new* collision (same lesson as the BIT turquoise fix).
  Preferred fix breaks the collision by **stepping the active tab down** (dimmer/quieter selected state) so
  the full-bright neon keycap is the lone "go," reinforced by elevation/form — not by minting a CTA hue.
  `[assumption]` pending direction pick + on-device sign-off.

### Currency (gems) — give it a reserved colour slot (2026-06-16)
Feeds the gem-art rework (decision: recolour the gem currency; in-app *look* owned by `ironbit-design`).
Precedent `[validated]`; the chosen hue `[assumption]` until the palette mock + user pick.
- `[risk]` **The gem currently double-books reserved colours and is inconsistent** — the icon
  (`icon_gem.png`) renders **green** (= `kNeon`, the protected *action* colour) while the claim-burst
  sprays **amber** (`kAmber`, = reward/XP). So gem rewards blur into XP on the summary, and the
  currency has no single identity. Compounds the `kNeon` role-overload noted in the nav-keycap entry
  above. → give gems **one reserved hue**, used consistently across all ~7 surfaces (icon, burst,
  wallet, payout, report).
- `[validated]` **Leading apps give currency its own identity colour, off the brand primary** —
  Duolingo blue gems (brand is green) ([duoplanet](https://duoplanet.com/duolingo-gems-and-lingots/),
  [wiki](https://duolingo.fandom.com/wiki/Gem)); Finch multicolour "Rainbow Stones," earn-only/no-punish
  ([review](https://webisoft.com/articles/finch-self-care-app/)); games use blue/purple/cyan as the
  "premium" convention ([iconography](https://www.webdesignerhub.org/iconography-and-currency-design-in-mobile-games/)).
- `[validated]` **The real principle is "don't reuse a colour that already carries meaning," not
  "avoid the brand colour"** — reusing a semantic/functional hue confuses (brand-red == error-red)
  ([UXPin](https://www.uxpin.com/studio/blog/color-consistency-design-systems/),
  [CodiLime](https://codilime.com/blog/the-importance-of-color-in-ux-and-ui-design/)); on dark game UIs
  hue differentiation beats lightness ([game UI palette](https://colorarchive.org/guides/game-ui-color-palette/)).
  → free premium-reading slots in Ironbit's full palette: **magenta/fuchsia** (most distinct; keep it
  pink-ward of Assassin violet) or a **pushed blue** (gem convention, must clear `kCyan`). Keep the
  faceted-gem *form* (familiarity).
- `[validated]` **Borrow legibility/earned-value, NOT spend psychology** — gems are earn-only,
  cosmetic-only, offline/no-IAP; the "premium currency drives purchases" rationale is monetization the
  app rejects (body-neutral/soul doctrine). The gem should read *earned-precious*, never *for-sale*.

### Expedition dock — wiring dispatch into the diegetic home-room pad (2026-06-17)
Feeds the pad→Expedition wiring (decision: `/deep-feature` pad-dispatch; mechanic shipped in
`AdventureService`; in-app *look* owned by `ironbit-design`). Mechanisms `[validated]`; the *feel/fit*
`[assumption]` until on-device comprehension testing. Evidence-coverage challenge consolidated into the
deep-feature Stage-4 Codex opinion review (avoids a 3rd foreground Codex run).
- `[validated]` **A diegetic/world-integrated control's signature weakness is discoverability + pacing**
  — players miss info, and teams often fall back to traditional UI to stay readable
  ([diegetic dilemma](https://indieklem.substack.com/p/19-the-diegetic-dilemma-benefits),
  [Native UI](https://nativeui.substack.com/p/diegetic-interfaces),
  [Wayline](https://www.wayline.io/blog/diegetic-interfaces-game-design)). Tappability is a *perceptual*
  judgment from **signifiers**; perceived-vs-actual mismatches are a measurable defect (Swearngin & Li,
  CHI'19 tappability model, precision 90.2% — [arXiv](https://arxiv.org/abs/1902.11247); Norman
  signifiers, [affordances](https://www.parallelhq.com/blog/what-are-affordances-in-design)). → **The pad
  must carry an explicit dispatch signifier** (label/glyph + a gentle "ready" pulse when a charge is
  available + a one-time first-run hint) — never rely on pure diegetic discovery; but don't over-clutter
  (minimal-HUD paradox).
- `[validated]` **Time-gated dispatch (pick→send→"out"+timer→return→collect) is a proven loop** (Genshin
  expeditions 4/8/12/20h; AFK-style real-time expeditions; idle principle = simple repeatable loop + early
  wins + visible reward proximity) ([idle principles](https://ericguan.substack.com/p/idle-game-design-principles),
  [GameAnalytics](https://www.gameanalytics.com/blog/how-to-make-an-idle-game-adjust)). `[validated, contrary]`
  **Its failure modes:** timewalls that gate *core* progress too early, "waiting > doing," timers "too
  needy to leave but too slow to engage" ([Mr.Mine](https://steamcommunity.com/app/1397920/discussions/0/3008927444643341958/)).
  → Ironbit sidesteps these **by construction**: dispatch is OPTIONAL atop the real core loop (workouts),
  the 4–8h wait gates only cosmetic gems (never progress), never punished. Keep the out-state glanceable
  (countdown + "back ~Nh"), never a thing to tend.
- `[risk]` **Companion-absence must NOT read as neglect/loss.** Attachment tracks *frequency of presence*
  ([AI-companion attachment](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12833267/)), and the classic
  "pet leaves on neglect" mechanic (Tamagotchi/Finch departure) is an explicit **guilt dark-pattern** —
  it works *because* users feel guilt/loss ([Yu-kai Chou](https://yukaichou.com/advanced-gamification/the-pet-companion-design-in-gamification/),
  [Tamagotchi effect](https://focusdog.app/magazine/tamagotchi-effect-virtual-pets-and-focus/)) — exactly
  what Ironbit's anti-guilt/body-neutral doctrine rejects. → BIT's dispatch-absence reads **voluntary,
  purposeful, temporary, place-held** ("off scouting *for you*, back ~Nh"): hold his spot on the dock
  (empty-but-traced dock + countdown = object permanence → "coming back" = anticipation/Zeigarnik), keep
  it short vs presence, **never** decay/withering/"he misses you." Comprehension-test that an empty dock
  reads "coming back," not "he left."
- `[validated, reuse]` **Launch + absence need still, legible reduced-motion fallbacks** (WCAG 2.3.3, already
  gated on `disableAnimations`; heavy easing = gravitas, avoid bouncy `easeOutBack`; pixel shimmer caution —
  see the parallax + face-reveal entries). → under reduced motion BIT transitions to "out" with a Semantics
  announcement (no fly-up); out/returned states must be legible as static compositions.

**Follow-up (2026-06-18) — the discoverability `[risk]` is now `[risk-confirmed]` on-device.** User looked
at the shipped pad and reported (a) "not clear how to dispatch" and (b) the DISPATCH label + charge pips
"clash with the light effect." This is the predicted diegetic failure, not a new one.
- `[risk-confirmed]` **A diegetic object with only a buried label is not perceived as tappable.** The
  diegetic literature is explicit: without clear interaction cues players don't realize an object is
  interactive, "especially without traditional UI buttons or prompts"; fix is to **augment the object with
  an explicit labeled/iconned signifier + a ready cue** — not pure diegetic discovery (the predicted
  failure), and not over-clutter (minimal-HUD paradox) ([yamii diegetic guide](https://www.yamii.shop/2026/04/04/diegetic-ui-guide/),
  [diegetic dilemma](https://indieklem.substack.com/p/19-the-diegetic-dilemma-benefits), CHI'19 tappability +
  Norman signifiers above). → keep the pad as the world dock (soul: diegesis), but the dispatch affordance
  must read as a **button** (verb + glyph, the app's PixelButton/keycap idiom), carry a gentle **ready
  pulse** when a charge exists (still prescribed, still unbuilt), and a **one-time first-run hint**.
- `[validated]` **Competitor convention = an explicit, labeled, low-friction send CTA — never tap-an-ambiguous-object.**
  Genshin dispatches via a labeled "Dispatch Character" menu + a "Claim" button, and was *simplified to
  one-click* claim/dispatch as QoL ([GamerBraves](https://www.gamerbraves.com/genshin-impact-finally-introducing-one-click-expedition-reward-claim-quick-enhancements-and-more-qol-in-4-3/),
  [Gamepur](https://www.gamepur.com/guides/how-expeditions-work-in-genshin-impact)); Whiteout Survival = "send
  your heroes out with **one tap**" via a clear affordance. → make DISPATCH a crisp, obvious, one-tap CTA.
- `[validated]` **CTA-over-FX clash is figure-ground: a neon CTA must not sit on a same-hue bloom.** Glow
  reduces legibility unless paired with a dark layer and **contrasting** colour; size/value/placement make
  the CTA the *figure* ([punchev](https://punchev.com/blog/6-tips-for-improving-the-user-interface-of-your-game),
  [trinergy](https://www.trinergydigital.com/news/ui-ux-for-game-design-key-elements-for-gamified-interfaces)).
  The defect: neon-green DISPATCH + pips render *on* the neon-green pool — same hue, so the dark chip alone
  can't separate them. → lift the CTA off the bloom onto a calm contrast field (own keycap/value), let the
  green glow stay ambient "powered/ready" ground; drop or fold the redundant pips so two neon elements don't
  fight the FX. (Pixel execution → `ironbit-design`.) Evidence-challenge consolidates into the redesign's
  deep-feature Stage-4 Codex review, per this entry's standing precedent.

**Follow-up (2026-06-18) — pointer-callout geometry/typography (user chose a "TAP TO DISPATCH" leader-callout pointing at the pad).**
- `[validated]` **A side callout does NOT fit beside the *centred* pad on a phone — that's the clip, not a tuning miss.**
  Room math (kx≈1.06 @360dp): pad spans x≈101–259 (150·kx wide), so side gutters are only ~84–100px; a 2-line
  "TAP TO DISPATCH / ×2 charges left" needs ~140–160px ⇒ it overflows the right edge. Top-right is the
  world-window (x≈247–343, y≈13–93), top-centre is the advice bubble, top-left the nameplate — so the side bands
  are the only free real estate, and they're too narrow. → either **shorten copy to fit a ≤~120·kx right-clamped
  box** (drop "charges left"; the token = "charge", "×2" = count) **or** use a **single-row ribbon in the ~32px
  band just above the pad** (the only way the full verb fits one line).
- `[validated]` **Edge-safe + non-occluding placement rules** (NN/G mobile overlays, [Material tooltips](https://m3.material.io/components/tooltips/guidelines)):
  never cover the target or adjacent controls; reposition/clamp in 8dp steps to stay fully on-screen; test across
  widths. → **≥16·kx gutter** from every screen edge; callout must not overlap pad/BIT/advice-bubble/world-window/
  nameplate; **max width ≤~150·kx** (Material plain-tooltip ceiling = 200dp, rich = 320dp).
- `[validated]` **Type minimums:** Material tooltip = 14sp; mobile body min ~16px, **never below ~12sp** for short
  labels ([fontfyi](https://fontfyi.com/blog/mobile-typography-accessibility/)). → label line **≥12·kx**, count
  line **11–12·kx** mono, label ≥ count; use **body/mono, NOT PressStart2P** beside the pad (the pixel caps font is
  too wide to fit the gutter — the user's mixed-case screenshot already did this right).
- `[validated]` **Leader-line convention** ([CAD Setter Out](https://cadsetterout.com/drawing-standards/technical-drawing-standards-leader-lines/)):
  angle **15–75° (prefer 45°), never horizontal/vertical**, short **horizontal elbow** at the text, text never
  touches the line, leaders don't cross other lines. → ~45° leader to the **pad's right shoulder** + a small
  node/reticle; must not cross BIT or the beam (it won't — keep it right of centre).
- `[validated, contrary]` **A *permanent* pointer-label risks clutter / banner-blindness** (persistent ≠ transient
  tooltip; [Appcues](https://www.appcues.com/blog/tooltips), NN/G). → keep it a **quiet state readout**: show only
  when a charge is ready, retire to nothing at zero; optionally **drop the "TAP TO" verb after the first successful
  dispatch** (coachmark for new users → bare `◈ ×2` readout after), so it never nags. Pixel execution →
  `ironbit-design`; Codex evidence-challenge folds into the redesign's deep-feature Stage-4.

**Pivot (2026-06-18) — user rejected BOTH the labeled callout AND the ribbon as cluttery; go label-LESS, intrinsic, least-friction.**
- `[validated]` **Mark the action via the object's OWN state, not a separate label.** The interactable convention
  is an intrinsic glow / coloured outline / pulse / armed-state on the object — best in *busy* scenes (the room is
  busy) ([Game Design Snacks](https://game-design-snacks.fandom.com/wiki/Highlighting_Interactable_Objects_Helps_the_Player_Recognize_them_in_a_Busy_Space),
  Unity affordance system). → the centred **pad+beam carry the "armed/ready" signifier themselves** (no gutter
  problem, no text clutter, no neon-on-pool clash); **tap the pad = dispatch** (already the tap target — this is a
  *reduction*).
- `[validated, contrary]` **A static glow alone is missed** (camera/pixel-hunt; "highlighting alone may not be
  sufficient"). → the pad must **animate INTO the armed state** (a one-time power-up the eye catches) then settle to
  a low-salience breath, **plus a one-shot first-run coachmark**; never rely on a steady glow.
- `[validated, contrary]` **A literal "!" badge reads as an F2P monetization nag** ("loud annoying… intrusive
  pressure", [BHVR forum](https://forums.bhvr.com/dead-by-daylight/discussion/420718/exclamation-mark)). → use a
  **directional up-cue (▲ / beam pulse)** + **BIT's eager gaze**, never "!".
- `[validated]` **Companion-initiated readiness is the lowest *cognitive* friction** — pet-initiated cues + idle
  states drive engagement ([Yu-kai Chou](https://yukaichou.com/advanced-gamification/the-pet-companion-design-in-gamification/)),
  and a character's gaze/attention cue points the eye. → **BIT looks UP at the beam + an eager ready pose** teaches
  the action wordlessly — but keep it **eager, not needy** (anti-guilt / Tamagotchi, per the absence entry above).
- `[validated]` **Direct-manipulation "flick BIT up the beam" is a delightful accelerator, not the primary** —
  flick-to-throw is standard, but gestures aren't self-discoverable, so make it **optional + hinted, layered on the
  tap** ([GameMaker gestures](https://www.gamedeveloper.com/design/using-gestures-in-mobile-game-design)). Bonus:
  flick ≠ tap, so it **coexists with BIT's tap easter egg** (tap = cheer/rest, flick-up = dispatch).
- → **Recommended model:** pad **arms** (power-up → quiet breath) + **BIT leans/looks up eagerly** + **tap to send**
  (1 tap, centred, label-less, no clutter/clash) + one-shot first-run hint; optional **flick-up** delight. Pixel
  look → `ironbit-design`; Codex evidence-challenge folds into the redesign's deep-feature Stage-4.
- `[shipped 2026-06-18]` **Resolved label-less + intrinsic.** After the callout/ribbon/slotted-cells were all
  rejected as cluttery/chunky, the user supplied a `pad-charge-meter` handoff: the pad's **own strip** becomes a
  **3-segment LED** (0–3 cyan) + a static armed glow — *nothing protrudes*, no label, no nag at zero
  (`widgets/room/pad_charge_meter.dart`). The dispatch console shows the charge as the **energy-cell icon + `N/3`**.
  Tap-the-pad (existing) opens the console. The label was the wrong instinct the whole time; the **object's own
  light** is the answer.

### Expedition charge economy + reward juice (2026-06-18 audit)
Feeds a `/deep-feature` fix of the expedition flow (audit found: meter-only-at-home consistency bug; flat report
ceremony; the 0-charge "dead pad"; earn-while-out confirmed working).
- `[validated]` **The charge IS the workout reward — don't auto-regen it.** Earn-by-real-action is the model of
  every fitness-reward app (Sweatcoin, Runtopia, LifeCoin, Earn It — [JumpTask roundup](https://jumptask.io/blog/get-paid-to-workout/));
  none auto-generate. Auto-regen/stamina-refill would break Ironbit's "real training is the fuel" spine. → keep
  1 charge / workout-day, banked ≤3; **do not** add a timer/regen.
- `[validated]` **The 0/1-charge state is *structural*, so design the empty-state, don't fight the economy.** You
  spend a charge ~daily but earn it only on workout days (~3–5/wk), so 0–1 is the common reading and the cap of 3 is
  rarely hit. A near-empty resource reads as **dead/broken** unless designed: don't look broken, *suggest momentum*,
  **nudge not shame** ([Setproduct](https://www.setproduct.com/blog/empty-state-ui-design), [Eleken](https://www.eleken.co/blog-posts/empty-state-ux)).
  → the empty pad must read **"train to charge BIT's energy"** (a *discharged* dock awaiting fuel, intentional),
  never a dead strip; and the **persistent sense of progress lives in the accumulating GEM balance**, not the
  transient charge meter (so 0 charges ≠ "no progress"). Ironbit's "scarcity" is benign — **not** a monetized
  timewall ([energy-system criticism](https://mobilefreetoplay.com/eliminating-energy/) is about IAP gates; we have none, and the expedition is optional atop the real loop).
- `[validated]` **Reward reveals need juice — pop/particle/fly/shine — but `[validated, contrary]` brief, skippable,
  non-manipulative.** Juice (a coin "pop", a chest's particle burst, collectibles flying out each with a shine) makes
  loot *feel* rewarding ([Design Lab](https://thedesignlab.blog/2025/01/06/making-gameplay-irresistibly-satisfying-using-game-juice/),
  [juicy-effects](https://gamedev4u.medium.com/when-you-play-a-great-game-it-feels-good-d23761b6eccf)); but reward
  screens that "take longer than expected" want a **skip** ([PSU](https://www.psu.com/news/how-mobile-games-adapt-to-player-attention-spans/)),
  and a slot-machine *suspense* roll on a random find would be the manipulative anti-pattern Ironbit rejects (body-
  neutral: the reward is for the **earned workout**, presented cleanly). → the report should reuse the **quest gem-fly**
  (`quest_claim_flight.dart`) for the gem count-up, **pop the item in with a rarity-colour flash** (not a fade), and be
  **tap-to-skip** — never a "rolling…" suspense beat on the find.

### Home-room perceived depth — static pictorial cues (2026-06-20)
Feeds a depth pass on the Home-room diorama (decision: in-app look owned by `ironbit-design`; this is
the evidence). Perceptual mechanisms are literature-`[validated]`; the *dark-palette fit* is
`[assumption]` until on-device. Pairs with the existing [Home scroll parallax](#home-scroll-parallax-2026-06-16) entry.
- `[validated]` **Pictorial depth cues are processed PRE-ATTENTIVELY (200–500ms, automatic, no
  cognitive load) — incl. named 3-D depth cues** ([pre-attentive](https://en.wikipedia.org/wiki/Pre-attentive_processing),
  [Data&Beyond](https://medium.com/data-and-beyond/pre-attentive-processing-what-your-brain-notices-first-6f4759fc5b51)).
  This is *why* depth feels subconscious. → for "users don't even notice it," prefer **static pictorial
  cues (shadow/contrast/aerial perspective/AO)** over motion/parallax (the cue users DO notice + the
  vestibular/WCAG gate). Static depth is the low-friction, reduced-motion-identical path.
- `[validated]` **Aerial perspective = desaturate + lower contrast + cool/veil distant objects** — the
  strongest recession cue ([d5](https://www.d5render.com/posts/atmospheric-perspective-for-aerial-rendering),
  [artsology](https://artsology.com/blog/2025/09/atmospheric-perspective-in-art/)). `[assumption]` **In a
  dark indigo room headroom is thin** — recession goes toward *cool darkness* not a bright haze, with
  little saturation left to remove ([night-scene](https://www.21-draw.com/mastering-atmospheric-perspective-in-night-time-scenes/)).
  → veil the world-window freely; **must be whisper-subtle**; the quest-board's claimable amber cue
  must override the veil (function beats recession).
- `[validated, contrary]` **Recede by VALUE/CONTRAST/SATURATION, never blur.** "Low contrast does not
  imply blurriness"; simulated blur is *perceptually weak* in naturalistic images ([(In)Effectiveness
  of Simulated Blur](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4598133/)) — and blur breaks the pixel
  grid (shimmer, see parallax entry). → keep all sprites crisp; tier depth by luminance only.
- `[validated]` **Contact/anchoring shadows seat an object on its surface** — strongest grounding cue;
  shadows originate at the base, light-direction-consistent ([ground-contact, PubMed](https://pubmed.ncbi.nlm.nih.gov/34280102/),
  [Material elevation](https://m2.material.io/design/environment/elevation.html) — shadow is "the only
  visual cue indicating separation between surfaces"). → small soft shadow *below* window + quest board
  (room key light is from above). **A self-luminous element (BIT) casts light, not shadow** → separate
  him with a radial wall-darkening *pedestal* behind him, NOT a drop-shadow.
- `[risk]` **"Crisp-on-hover" is undeliverable** — Android touch app, no hover state. → drop it; the
  board recedes statically and lifts only on its claimable state / on tap feedback.
- `[validated]` **Occlusion/overlap is the most reliable depth cue of all** and was under-weighted in
  the 5 ideas — it needs no saturation/contrast headroom, so it's the *most* dark-room-robust.
  Mostly already exploited via z-order (pad occludes pool, BIT in front of beam). → before adding
  veils, make the **overlap ordering unambiguous**; it's free depth. A self-lit BIT can also throw a
  faint **cast-light bloom** onto the near wall (the positive form of the "pedestal") — a near-plane
  cue with no headroom dependency.
- `[risk]` **Accessibility contrast-floor:** any recession veil must not push the nameplate/board text
  or icons below WCAG legibility minima, and should be **suppressed under OS high-contrast / reduce-
  transparency** (not just reduce-motion). Lower-contrast ≠ free.
- `[assumption→soften]` Two self-corrections from the adversarial pass: (a) the **dark-scene window
  veil is the weakest, possibly-cosmetic move** — lead with the headroom-independent cues
  (occlusion, contact shadows, AO, cast-light), treat the veil as optional polish; (b) the
  **"pedestal not shadow" call is sound *reasoning* (self-luminous physics + contrast-by-luminance),
  not a cited finding** — label it as such.
- → **Lowest-friction package (revised):** unambiguous occlusion + static value/contrast plane-tiering
  + contact shadows + deepened corner-AO/cool-horizon + a faint BIT cast-light bloom — all confined to
  `_RoomShellPainter` + the two wall-fixture widgets; no animation, no interaction, geometry untouched.
  Much of the AO is already shipped (ceiling gradient, vignette, floor gradient, neon seam) — this
  deepens it. The window aerial veil is *optional* last polish, gated off under high-contrast.

### Recovery-day card → cyan + breathing header register (2026-06-21)
Applied the validated cool=calm/recovery color finding (above) to the Home mission card. Decision:
the rest/recovery mission cards use **`kRecoveryAccent` (semantic alias of `kCyan`) + a slow ~4.5s
"breathing" brightness on the TODAY'S MISSION header** (`CrtBreathe`) — the calm third register beside
`active` (neon + glint sweep) and `calm` (muted + flicker). Fixes a defect where the *program* recovery
card was themed `kNeon` (energetic "go-train" green incl. a green KEEP RESTING CTA — a mixed message),
and unifies it with the already-cyan non-program recovery card.
- `[validated]` Cool blue/green = calm/recovery; color signals **mood, not measurable recovery** (so
  it's the right lever for *signaling* "this is rest"). Slow ~4–6s breath = resting-respiratory-rate
  calm (Calm/Headspace/Apple Breathe). Codex-hardened: a **semantic token alias** (not `kCyan`
  directly, so the rest theme can diverge from kCyan's Tank/Legs roles), header-only breath (no
  card/border/glow pulse), and the header register **defaults to calm** so an unknown state never reads
  active/recovery.
