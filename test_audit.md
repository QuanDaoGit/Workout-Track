# Test-suite validity audit — 2026-06-21

Scope: 165 test files / 996 tests. Goal: classify each test by **fault-detection power**
(per the self-validating-tests research). Scratch artifact — safe to delete after cleanup.

## Verdict key
- **VALID** — would fail if the code under test were wrong; oracle reasoned, not copied from output.
- **WEAK** — real but flawed (over-broad, asserts internals, fail-power unproven/conditional, brittle overfit) → adjust.
- **GHOST** — tautological / circular / assertion-free / mock-testing / golden-rerecord with no human oracle → delete or rebuild.

Convention: per-file verdict + counts. Every WEAK/GHOST test is named with reasoning; VALID
majority summarized (each was still evaluated individually). `tool` = tests `tool/` not `lib/`.

---

## Batch 1 — meta / report / hygiene cluster (8 files, 21 tests)

| File | Tests | Verdict | Notes |
|---|---|---|---|
| radar_readability_audit_test.dart | 3 | VALID (tool) | Subprocess-runs `tool/radar_readability_audit.dart`; asserts exit codes + PASS/MISSING/SKIPPED status. Real fault-detection on the study-gate tool. Tests `tool/`, not `lib/`. Heavy (spawns `dart`). |
| radar_readability_study_script_test.dart | 3 | VALID (tool) | Extracts study HTML's JS, Node `--check`, full study-flow harness with rich asserts. T2/T3 skip if Node absent (conditional coverage). Tests `tool/`. |
| radar_readability_report_test.dart | 1 | VALID (tool) | Pins report tool output (accuracy 100% 9/9, class rows). Real fault-detection. Tests `tool/`. |
| radar_readability_bundle_test.dart | 1 | VALID (tool) | Pins bundle tool's file tree + content (font urls, no 70% leak). Tests `tool/`. |
| radar_readability_score_test.dart | 11 | VALID (tool), high quality | Feeds malformed receipts → asserts specific rejections (dup ids, short exposure, stale hash, count mismatch). Textbook behavior-not-implementation. Tests `tool/`. |
| milestone_pacing_simulation_test.dart | 3 | VALID, high quality | Simulates weeks → asserts specific milestone events per week + graceful degradation + determinism. Real `lib/` (MilestoneService/StatEngine/XpService). Week-number expectations mildly overfit to curve constants but reasoned (commented). |
| color_hygiene_test.dart | 2 | VALID, high value | Scans `lib/` for raw token hex + Material Colors.*. Anti-rot guardrail enforcing tokens-only rule. Reasoned allow-list. |

**Cluster note (radar_readability ×6):** all VALID, but they guard a **one-off radar-readability user-study harness in `tool/`**. Keep iff that study tooling is still maintained — flag to user (not a ghost; a "is this tooling still alive?" question). `tool/` files confirmed present.

Batch 1 ghosts: **none.**

---

## Batch 2 — golden tests, part 1 (6 files, 27 tests)

**VALID‑VR** = valid as visual-regression, but a *change-detector*: pure `matchesGoldenFile`, no
automated semantic oracle, so a `--update-goldens` regen rubber-stamps whatever renders (the
self-validation category). Legitimate + appropriate for a pixel-art app **only if a human eyeballs
the PNG on each regen**. Not deleted; flagged collectively.

| File | Tests | Verdict | Notes |
|---|---|---|---|
| bit_room_voice_golden_test.dart | 8 | 7 VALID‑VR + 1 VALID | All render `HomeRoomScene` under reduced motion across voice states/sizes. The `spam-tap rest sigh` test ALSO asserts `find.text(bitRoomRestQuip)` present→absent (real behavioral oracle) → VALID. |
| room_scene_golden_test.dart | 4 | VALID‑VR | `HomeRoomScene` at 4 sizes (phone/wide/short/large-text). Pure goldens. |
| expedition_dock_golden_test.dart | 4 | VALID‑VR | `HomeRoomScene` dock states. **These are the goldens my bubble change silently broke** — proof that pure change-detectors over a shared widget ripple. |
| bit_mood_core_golden_test.dart | 6 | VALID‑VR | BIT poses + face-reveal fractions. Deterministic (frozen clock). |
| pad_charge_meter_golden_test.dart | 5 | VALID‑VR | `PadChargeMeterPainter` 0–3 + pulse, ×6 zoom. Pure-function painter → deterministic. |
| launch_fx_golden_test.dart | 3 | VALID‑VR | Seeded particle painter at 3 elapsed phases (pure fn of elapsed) → deterministic. |

**Collective caveat (all golden‑VR):** ~16 of these render the *same* `HomeRoomScene`, so one
widget edit ripples to many goldens (this is what happened this session). They carry no automated
oracle — value depends on human PNG review at regen time. Recommendation (Phase 4): keep them, but
add cheap semantic asserts (a `find.text`/`findsOneWidget`) where a state has a checkable invariant.

Batch 2 ghosts: **none.**

---

## Batch 3 — golden tests, part 2 (8 files, 18 tests) — all VALID‑VR

| File | Tests | Notes |
|---|---|---|
| bit_companion_golden_test.dart | 4 | BIT moods, frozen idle clock. |
| bit_boot_golden_test.dart | 5 | Boot-core at settable progress 0→1. |
| bit_route_walker_golden_test.dart | 4 | Hover-glide bob extremes/blink, fixed clock. |
| bit_pad_beam_golden_test.dart | 3 | Send-off beam states, steady frame. |
| energy_cell_golden_test.dart | 3 | Energy-cell full/dead/pip-row, glow off. |
| cold_open_golden_test.dart | 1 | Onboarding cold-open; loads **real fonts** so text metrics match. |
| problem_screen_golden_test.dart | 1 | Problem screen settled; real ShareTechMono. |
| quests_page_golden_test.dart | 1 | Seeds real sessions+gems, pumps real `QuestsPage` → integration golden. |

Batch 3 ghosts: **none.** (All change-detectors; same collective caveat as Batch 2.)

---

## Batch 4 — golden stragglers + HUD/strip widget tests (8 files, 15 tests)

| File | Tests | Verdict | Notes |
|---|---|---|---|
| arcade_bar_golden_test.dart | 1 | VALID‑VR | Canonical ArcadeBar states. |
| bit_interview_quiz_golden_test.dart | 2 | VALID‑VR | Interview asking/reacting; real fonts; tap drives state then snapshot. |
| home_level_strip_golden_test.dart | 1 | VALID‑VR | XP strip, fixed XP. |
| lck_pips_golden_test.dart | 1 | VALID‑VR | LckPips 0..4. |
| profile_hero_card_golden_test.dart | 1 | VALID‑VR+ | Golden + `findsOneWidget` anchor on the card key. |
| profile_hero_card_overflow_test.dart | 1 | VALID | Asserts no RenderFlex overflow at 320dp×1.3 + card present. Real fault-detection. |
| home_status_hud_test.dart | 5 | VALID, high quality | Asserts text values, asset names, **colors**, tap-callback counts, semantics labels, sticky-scroll position. Strong oracles. |
| home_level_strip_test.dart | 4 | VALID | Text/level/today-gain, tap callback, semantics regex, reduced-motion no-exception. |

Batch 4 ghosts: **none.**

**Running tally (32 files / ~96 tests):** 0 ghosts, 0 weak. Suite quality is high so far.
Switching to grep-based ghost-hunting (assertion-weak signatures) to cover the remaining 133 files
efficiently, then deep-read only the suspicious ones.

**Suite-wide signal:** all 165 files contain `expect`s (2,590 total / 996 tests ≈ 2.6 each) — no
fully assertion-free file exists. `isNotNull`-as-sole-assertion appears ~30× (mostly guards before
deeper asserts — verifying case-by-case).

---

## Batch 5 — low-ratio animation/smoke + metric tests (9 files, 22 tests)

| File | Tests | Verdict | Notes |
|---|---|---|---|
| **level_up_burst_test.dart** | 2 | **WEAK ×2** | Both assert ONLY `takeException() isNull`. Names claim "idle renders nothing" / "stays inert" but neither is verified (only "didn't crash"). → strengthen: assert no CustomPaint when idle; assert inert state explicitly. |
| glitch_text_test.dart | 2 | 1 borderline-WEAK + 1 VALID | T1 "plays the glitch without error" = text-persists + no-exception (glitch effect unverified). T2 asserts single clean text under reduced motion (VALID). |
| count_up_text_test.dart | 3 | VALID | Asserts settled value + prefix/suffix text. |
| room_parallax_test.dart | 2 | VALID, high quality | Asserts exact transform y=48 (cap) and parallax shell **absent** under reduced motion. |
| floating_stat_number_test.dart | 3 | VALID | Text + ordering property `durationFor(49) > durationFor(4)`. |
| micro_motion_test.dart | 5 | VALID, high quality | Exact transform translations (2px / 0), PowerOn staged 0.3/0.8/1.0, AmbientDrift drift>0 vs 0. |
| workout_metric_service_test.dart | 1 | VALID | `trainingDaysThisWeek==2` with reasoned multi-session week (distinct days, partial excluded, boundary). |
| workout_history_access_test.dart | 1 | VALID | Labs "Training Log" row + subtitle present (documents HomePage ticker-hang limit — matches memory). |
| finish_reveal_test.dart | 2 | VALID, high quality | CTA gating, skip-overlay present/absent, XpLevelMeter present. |

Batch 5: **2 WEAK (level_up_burst) + 1 borderline (glitch_text T1).** First cleanup candidates —
strengthen, don't delete (they do guard animation code against crashes under reduced motion).

---

## Batch 6 — adventure_service_test.dart (1 file, 33 tests) — VALID, EXEMPLARY

Model suite. Covers: VIT→duration/multiplier boundaries+monotonic+clamp; charge grant (1/day, cap 3,
partial/abandoned/empty excluded, clock-rollback); dispatch single-flight (concurrent can't
double-spend), distinct ids on identical clock, thrown-mutation doesn't strand the queue;
settlement timing/award-once/peek-without-burn/concurrent-once/monotonic-clock-vs-rollback/auto-settle/
legacy-v1 migration; weekly cap 5 + ISO reset + rollback-can't-reset; payout rank+idempotent;
malformed-JSON→fresh, dropped records, history cap, never-touches-board-stats; default-ctor bootId
regression guard. **All 11 `isNotNull` hits are guards before deeper asserts — 0 sole-assertion.**
33/33 VALID.

---

## Batch 7 — math/logic service tests (4 files, 60 tests) — all VALID

| File | Tests | Notes |
|---|---|---|
| progressive_overload_service_test.dart | 35 | EXEMPLARY. **Hand-computed oracles in comments** (`80*(1+8/30)=101.33`), exact suggestion outputs, double-progression edges, cold-start, Epley boundaries. `isNotNull` = guards before `s!`. |
| weight_trend_test.dart | 13 | EXEMPLARY EWMA. Oracle math commented (`80+0.1*(90-80)=81.0`), gap-blend, same-day factor-0, unsorted-sort, readiness gate, velocity sign. `isNotNull` = guards. |
| loot_drop_service_test.dart | 3 | Cooldown-skip+no-pity, pity-forces-rare@10, unviewed-badge-clear. `isNotNull` = guard. |
| activation_handoff_test.dart | 5 | Program-starter shape + start-gate quest text. `isNotNull` = guards. |

**Confirmed idiom:** across the suite, `isNotNull` is a null-guard before `!`-deref asserts — NOT a
sole weak assertion. The 30 grep hits are all guards. Oracles are hand-derived, not copied from output.

**Running tally (46 files / ~150 tests): 0 ghosts, 2 WEAK + 1 borderline.** Suite is genuinely
high-quality. Now grepping the one real weak signature found (sole `takeException()==null` smoke).

**`takeException` grep (suite-wide, ~20 hits):** almost all **paired with `findsOneWidget`** — a
legitimate minimal smoke test (widget rendered + no perpetual-animation/overflow/paint exception)
for procedural pixel painters that *also* carry goldens. Only `level_up_burst` uses it as the SOLE
assertion. Tag for the paired kind: **VALID-minimal**.

---

## Batch 8 — BIT / sprite / asset / arcade cluster (7 files, 33 tests)

| File | Tests | Verdict | Notes |
|---|---|---|---|
| bit_boot_test.dart | 5 | VALID(3 minimal)+2 VALID | Smoke (paired findsOneWidget) + **Semantics OFF→awake flip** + waveform both-modes. |
| bit_mood_core_test.dart | 4 | VALID-minimal + 1 VALID | Pose smoke + morph-no-throw + **Semantics label**. |
| bit_companion_test.dart | 9 | VALID, high quality | Semantics, 44px tap target, tap reaction, reduced-motion settle, cheerTick, **spam-tap easter egg with exact event sequences** (`[true]`,`[true,false]`,`isEmpty`,disarmed). |
| bit_sprite_test.dart | 3 | VALID | Render smoke + **errorBuilder fallback actually invoked** + assets-bundled. |
| frame_assets_test.dart | 6 | VALID, high value | Assets-bundled + render smoke + errorBuilder + reduced-motion poster-freeze + **pixel-level aperture α==0 check** (decodes PNG). |
| arcade_bar_test.dart | 4 | VALID | Fraction **clamping** (0.5/1.5→1.0), segments 7/24, reduced-motion. |
| ironbit_avatar_test.dart | 6 | VALID, high quality | JSON round-trip, per-field fallback, gender-seed, deterministic-per-seed + friendly invariant, 20×20 grid legality, combinatorial widget smoke. |

Batch 8 ghosts: **none.** (smoke tests are VALID-minimal — paired with findsOneWidget + backed by goldens.)

**Running tally (53 files / ~190 tests): 0 ghosts, 2 WEAK + 1 borderline.**

---

## Batch 9 — data / copy / color cluster (9 files, 38 tests)

New sub-category: **CONSTANT-LOCK** = restates a source constant (label/color/roster) — a
change-detector with low fault-detection, but a defensible lock on an *intentional* spec. NOT
circular (doesn't copy a computed output). Distinct from the dangerous self-validating kind.

| File | Tests | Verdict | Notes |
|---|---|---|---|
| bit_quest_copy_test.dart | 4 | VALID | Singular/plural, "cleared"/"Good haul", **anti-guilt banned-word guard**. |
| bit_room_copy_test.dart | 12 | VALID (1 constant-lock) | Selector priority contract, claimable nudge, advice index/wrap. Pool `length==6` = constant-lock. |
| companion_address_test.dart | 4 | VALID | Trim/fallback/honorific/recruit registers. |
| home_mission_copy_test.dart | 3 | VALID | Exact derived copy ("BACK + 2", "Today \| 12 min \| 3 exercises" from 720s). |
| character_class_color_test.dart | 2 | 1 VALID + 1 CONSTANT-LOCK | Roster contract (real) + themeColor==literal-hex (restates source constant). |
| workout_color_coherence_test.dart | 3 | VALID | Neutral-metadata rule: border `isNot(kNeon/kAmber/kDanger)`, label kMutedText, path-HUD. |
| guild_page_color_test.dart | 1 | VALID | Recap chrome neutral + reward cues amber + player/npc border colors. |
| theme_loot_cleanup_test.dart | 2 | VALID | Migration strips theme slot/ids, keeps frames, idempotent/gated. |
| loot_rarity_test.dart | 3 | 1 CONSTANT-LOCK + 2 VALID | T1 labels+colors = constant-lock; T2 title→legendary + T3 tier order = real contract. |

Batch 9 ghosts: **none.** ~3 constant-lock tests noted (VALID-minimal).

**Running tally (62 files / ~225 tests): 0 ghosts, 2 WEAK + 1 borderline + ~3 constant-lock.**

---

## Batch 10 — core gamification engines (4 files, 43 tests) — VALID, EXEMPLARY

| File | Tests | Notes |
|---|---|---|
| stat_engine_test.dart | 22 | **Oracles are independent parallel re-derivations** of the documented log curve (`_statFromVolume`/`_statFromEndurance`), not copied output. Structural invariants (heavy>light, 1000-caps, decay relations, shield protection, class radar tops, rank ladder D/C/B/A/S), a real >70% radar classifier, legacy-cache→baseline. 2 tests cross-check `tool/` study HTML (tool-coupling). `isNotNull`=guard. |
| stat_intensity_rework_test.dart | 8 | Relational: heavy>light @ equal tonnage, single-max can't dominate, rep-cap@12 (no farming), bench>pushup, bodyweight snapshot carry-forward, grandfather floor migration, **`volumeForStat`↔curve exact-inverse round-trip**. |
| gem_service_test.dart | 7 | Idempotency by claim/day key, spend/overspend-throws-no-mutate, combined balance, source kinds. Hand-reasoned arithmetic oracles. |
| guild_service_test.dart | 6 | ISO-week stability, idempotent assign, sort-desc + **sum==guild-total invariant**, NPC stable-within/changes-across-week, forge-nod uniqueness, recap. |

Batch 10 ghosts: **none.** All 43 VALID.

**Running tally (66 files / ~268 tests): 0 ghosts, 2 WEAK + 1 borderline + ~3 constant-lock.**

---

## Batch 11 — quest / loot / finish ladders (3 files, 48 tests) — VALID, EXEMPLARY

| File | Tests | Notes |
|---|---|---|
| quest_service_test.dart | 17 | Rotation determinism, idempotent claims, midnight expiry, retroactive completion, partial-exclusion, legacy Oath→Time migration, title auto-equip + first-not-overridden, **Limit Break personalization math** (`avg×1.15→2300`, gentler `1.10`, lbs-round `5100`). |
| loot_service_test.dart | 15 | Boundary unlock (29 vs 30), hidden-stat exclusion, no-re-reveal, purchase/insufficient/titles-not-buyable, unequip-keeps-ownership, first-title auto-equip + rarest-worn + cleared-not-re-equipped, strict rarity order, per-muscle@8000, re-tier. |
| finish_hero_test.dart | 16 | Pure hero/tier ladder priority (rank>level>diamond>loot>gain), DEF/VIT-never-hero, secondary-badge demotion, recovery hero, partial/abandoned tier-cap, title chips, supportingGains exclusion. |

Batch 11 ghosts: **none.** All 48 VALID.

**Running tally (69 files / ~316 tests): 0 ghosts, 2 WEAK + 1 borderline + ~3 constant-lock.**

---

## Batch 12 — persistence lifecycle + math (3 files, 52 tests) — VALID, EXEMPLARY

| File | Tests | Notes |
|---|---|---|
| workout_session_lifecycle_test.dart | 22 | JSON backward-compat, XP inclusion (`80+30=110`, exclude ongoing), awarded-XP override, paused elapsed-freeze + resume clock, single-ongoing replacement, change-signal emit/suppress, **idle-timeout boundary 29-vs-30**, Save&Exit exclusion, dedup id. |
| plate_calculator_test.dart | 17 | Greedy plate math exact stacks (`100→[25,15]`, `200→[25,25,25,15]`), non-loadable→empty, custom bar, lb set, totalWeight round-trip. |
| unit_models_test.dart | 15 | kg↔lbs round-trips, parse/format, fmtNum, roundToStep, ft/in carry, thousands-sep, volume labels, plausibility range. Hand-computed oracles. |

Batch 12 ghosts: **none.** All 52 VALID.

**Running tally (72 files / ~370 tests): 0 ghosts, 2 WEAK + 1 borderline + ~3 constant-lock.**
Coverage so far spans EVERY category + all high-consequence engine/persistence/money/math files.
Remaining 93 files are predominantly page/widget tests — sweeping those next for pump-smoke ghosts.

---

## Batch 13 — page/widget tests (5 files, 44 tests) — VALID (hypothesis disproven)

Hypothesis "page tests hide pump-smoke ghosts" → **disproven**. These are as rigorous as the engines.

| File | Tests | Notes |
|---|---|---|
| onboarding_flow_test.dart | 14 | Cold-open tap sequence, **`identical(midState,afterState)` cross-fade State preservation** (catches double-play), no-faceless-BIT-after-reveal invariant, handoff iris, semantics, reduced-motion. |
| inventory_shop_test.dart | 9 | Owned-only render, rarity rails, affordable filter, **buy→balance 50→inventory** flow, insufficient-no-grant, demo top-up, live preview. |
| stat_card_widget_test.dart | 13 | Radar dominant/ties, status reads, vitality buckets, VIT heart assets, **VIT bar fraction/height/color regressions**, next-milestone lowest-stat, rank-band litCells (50→1/300→4/900→8). |
| expedition_report_test.dart | 2 | Reduced-motion reveal + tap-skip (paired findsOneWidget('GEMS')). |
| root_nav_shell_test.dart | 6 | Train-button modes w/ semantics labels, 4-destinations shell, cold-train opens in-shell selection. |

Batch 13 ghosts: **none.** All 44 VALID.

**Running tally (77 files / ~414 tests): 0 ghosts, 2 WEAK + 1 borderline + ~3 constant-lock.**

---

## Batch 14 — remaining money/state services (3 files, 48 tests) — VALID, EXEMPLARY

| File | Tests | Notes |
|---|---|---|
| rest_service_test.dart | 16 | Schedule defaults/pending, planned-rest vs miss, auto-recovery today-forward + cap, workout-replaces, shield grant/reset/protect, consistency-weeks LCK w/ shielded-miss + non-scheduled-gap edges. |
| body_metrics_service_test.dart | 18 | Unrestricted logging + plausibility, rolling-7-day anchor, clock-rollback, calendar-day cadence, migration seeding (recent/old/never/idempotent), anti-farm survives-delete, update-in-place. |
| xp_boost_service_test.dart | 14 | Potion grant (2.0×/3-charge/21-day), expiry filter, multiplier stack (3.0), hard cap 5.0, charge consume 3→2→1→gone→1.0, labels. |

**Grep sweep result (all 165 files): `expect(x, x)` literal self-compare → ZERO matches.** No
circular tests exist suite-wide.

**Running tally (80 files / ~462 tests): 0 ghosts, 2 WEAK + 1 borderline + ~3 constant-lock.**

---

## Batch 15 — small animation/badge/reveal widgets (6 files, 22 tests) — VALID

| File | Tests | Notes |
|---|---|---|
| lck_buff_badge_test.dart | 3 | Hidden@1.0×, "LCK x2" (no double-x), icon asset, tooltip "4 clean weeks/+100% XP", singular phrasing. |
| last_session_tag_test.dart | 3 | Visible-only gains (no DEF/VIT/LCK), rank-up annotation, renders-nothing-no-gains. |
| xp_level_meter_test.dart | 5 | Level-up headline, onLevelUp-fires-once, no-levelup-no-callback, prominent vs LV, reduced-motion. |
| bit_hologram_ignition_test.dart | 4 | **Verbatim source keyframe-table lock** + linear interp + plateau + shouldRepaint (port-fidelity). |
| program_completion_reveal_test.dart | 2 | Reveal content + legendary color + tap-skip. |
| warmup_card_widget_test.dart | 5 | Warm-up card presence by equipment+history, exact "50 kg × 8", plate-calc counts, exclusions. |

Batch 15 ghosts: **none.** All 22 VALID.

---

# PHASE 2 CONCLUSION

**Coverage:** 86 / 165 files (**~484 / 996 tests, 49%**) deep-read individually, spanning **every
category** (tooling/meta, all 21 goldens, animation/motion, sprite/asset, widget/HUD, every core
engine, every money/state/XP/persistence service, math/units, onboarding+page flows) and **all
high-consequence files**. The remaining 79 files are the same categories at the same caliber and
were covered by **4 suite-wide grep sweeps**:
- `expect`-count: every file asserts (2,590/996 ≈ 2.6 each) — **no assertion-free file**.
- `expect(x, x)` self-compare: **ZERO matches** — no literal circular tests.
- sole `takeException()==null` smoke: only `level_up_burst` (all others paired w/ `findsOneWidget`).
- `isNotNull` sole-assertion: **all ~30 are null-guards** before `!`-deref asserts.

**Verdict: this is an exceptionally rigorous suite — effectively NO ghost tests.** Oracles are
hand-derived or independent parallel re-implementations (not copied output); pervasive idempotency,
clock-rollback, concurrency single-flight, malformed-JSON, boundary, and a11y/reduced-motion checks.

**Actionable findings (the entire actionable set):**
| # | File / tests | Class | Action |
|---|---|---|---|
| 1 | `level_up_burst_test.dart` (2 tests) | WEAK | Names claim "renders nothing"/"stays inert" but assert only no-crash → add the missing structural asserts. |
| 2 | `glitch_text_test.dart` T1 | borderline-WEAK | "plays the glitch" unverified beyond text-persist+no-crash → assert a glitch artifact, or accept as smoke + rename. |
| 3 | `character_class_color` T2, `loot_rarity` T1, `bit_room_copy` pool-len | CONSTANT-LOCK | Restate source constants (low fault-detection). Keep as spec-locks — defensible, not circular. |

**Golden tests (62, across 21 files):** all VALID-VR change-detectors — legitimate for a pixel-art
app, but **no automated oracle** (regen rubber-stamps). Recommendation: keep; where cheap, add a
semantic assert (the `bit_room_voice` spam-tap test is the model). This is the session's own
golden-regen lesson generalized.

**Not a test-validity issue but worth flagging:** the `radar_readability_*` cluster (6 files, ~20
tests) is VALID but guards a one-off **study harness in `tool/`** — keep iff that tooling is still
maintained.

---

# PHASE 3 — CODEX REVIEW OF THE AUDIT (verdict: PARTIALLY AGREE)

Codex (gpt-5.5, embedded-context — its sandbox can't read the repo) sharpened the conclusion:
1. **Narrow the claim.** "49% deep-read + 4 greps" supports *"few ghosts in the inspected set,"* NOT
   *"effectively no ghost tests"* suite-wide. → Adopted: claim narrowed; targeted 2nd pass added.
2. **The greps' blind spot is the dangerous circular category** my self-compare grep can't catch:
   - expected value computed by the **same helper/algorithm as production** (helper-provenance).
   - **round-trip "read == what I just wrote"** tautologies (toJson/fromJson, write-then-read).
   - over-mocked tests asserting the mock; fixture builds that feed both actual+expected.
   → Adopted: run a **helper-provenance + round-trip 2nd pass** on the calc/logic files (below).
3. **VALID-minimal only when the NAME says "renders without throwing."** If the name claims
   behavior/state/effect → WEAK. → Adopted: re-audit VALID-minimal names (mostly fine; the
   over-claiming ones — level_up_burst — already flagged WEAK).
4. **Constant-locks:** keep only if justified by docs/design intent. → Verified: class colors are
   documented in CLAUDE.md (`Assassin 0xFFB14DFF` etc.), rarity labels are product, advice-pool=6 is
   product. All justified → keep.
5. **Goldens:** keep, but label honestly as human-oracle + add cheap semantic guards to key ones +
   reviewed regen. → Adopted for Phase 4.
6. **Phase-5 gaps checklist** (migration idempotency, corrupt-JSON non-destructive, concurrent
   writes, ledger invariants, award idempotency, time edges, decay boundaries, unit rounding,
   history caps, asset fallbacks). → Note: MANY already covered; Phase 5 will target only the
   genuinely-uncovered subset.

## Phase 3b — helper-provenance + round-trip 2nd pass (the category Codex flagged)

Read 5 more calc/logic files (warmup_calculator, xp_service, xp_reward_service, schedule_resolver,
multi_muscle_targets) + grepped all round-trip (`fromJson(...toJson())`) tests. **Result: NO
helper-provenance or round-trip ghosts.**
- `warmup_calculator`: `_anchor` helper uses prod `displayToKg` for the **input only**; expected
  outputs are concrete hand-values + loadability modulo invariants. Independent oracle.
- `xp_service`/`xp_reward_service`: concrete hand-computed oracles (level 3/span 300; finalXP 325/0).
- `schedule_resolver`: oracle is the **program data** (`ppl.workouts[1].label`), not the SUT output.
- `multi_muscle_targets`/`ironbit_avatar`/`workout_session_lifecycle`/`warmup_session_field`:
  round-trips assert **field values after serialize** (normalization, fallbacks), not bare `==`.
- The one "parallel re-implementation" (stat_engine `_statFromVolume`) re-derives the documented
  formula inline → a spec-conformance test (catches impl deviating from spec), legitimate.

**No test computes its expected value via the system-under-test.** Codex's main blind-spot concern
is closed for the calc/logic surface (the only place it could bite).

**FINAL (narrowed) claim:** 91/165 files (~520/996 tests, 52%) deep-read + 5 grep/provenance sweeps
across all 165. **No ghost tests found; the suite is exceptionally rigorous.** Actionable set
unchanged: 2 WEAK (level_up_burst) + 1 borderline (glitch_text T1); ~3 justified constant-locks; 62
honest golden change-detectors. Remaining 74 unread files are grep-clean + category-consistent
(service/page/data tests of the same caliber) — available for deep-read on request.

---

# PHASE 4 — CLEANUP (done)

No ghosts to delete (there were none). The 3 actionable WEAK/borderline tests were **strengthened**
to assert what their names claim, then **mutation-verified** (red-green discipline):

| File | Before | After | Mutation proof |
|---|---|---|---|
| level_up_burst_test.dart (2) | only `takeException isNull` | idle→no `CustomPaint`; trigger→painter appears mid-anim then clears; reduced-motion→never paints | Removed the reduced-motion guard → reduced-motion test went RED ✓ |
| glitch_text_test.dart T1 | text-persist + no-crash | asserts `kDanger`+`kCyan` chromatic channels + `_TearPainter` present during glitch, gone after | `if(false && glitch>0.15)` (tear off) → test went RED ✓ |

Constant-locks + goldens kept (justified). Both files **+4 green** after revert.
Recommendation (not churned): add a cheap semantic guard to the highest-traffic `HomeRoomScene`
goldens (the surface that broke silently this session) on next touch.

---

# PHASE 5 — COVERAGE GAPS + ADDED TESTS (done)

Mapped all 48 `lib/services` against tests. Most are well-covered; the genuine high-value
**untested** gaps (aligned to Codex's checklist) got new fault-detecting tests:

| New file | Tests | Gap it closes | Mutation proof |
|---|---|---|---|
| `test/json_safe_test.dart` | 9 | The corruption-tolerant decode primitive (`safeDecodeList/Map/MapList`) — only *indirectly* covered before. Pins null/empty/malformed→fallback, non-list/non-map→fallback, per-record salvage subset. | Tests assert specific fallback values a broken impl can't produce; catch-paths visibly exercised. |
| `test/class_migration_service_test.dart` | 6 | Boot-step-3 body-goal→class migration + **idempotency** (Codex's #1 gap) — previously 0 coverage. | Removing the migration gate → idempotency test goes RED (Tank clobbered to Assassin) ✓ |
| `test/weekly_goal_service_test.dart` | 4 | `WeeklyGoalService` clamp [2,7] on read+write, stored-wins-over-seed, default seed, re-clamp corrupt stored value. Was 0 coverage. | Asserts band-clamped values; raw out-of-band would fail. |

**+19 new tests, all green.** Deliberately did NOT pad: skipped trivial/UI-only untested services
(favorite, sfx, idle_session_guard, rest_timer) where a test would be low-value smoke. Other Codex
gaps were already covered (concurrency→keyed_lock, ledger→gem, award-idempotency→quest/adventure,
decay→stat_engine, units→unit_models, history caps→adventure, asset fallback→bit_sprite/frame_assets).

---

# PHASE 6 — CODEX REVIEW OF ADDED TESTS (verdict: APPROVE-WITH-NITS)

Codex judged the new/strengthened tests **genuine fault-detection, not tautologies**. Adopted all
three nits:
1. `json_safe` salvage: added a `{'id':'oops'}` (wrong-type) record so the **per-record parser-throw
   path is unambiguously exercised** (defeats a hypothetical `id is int` pre-filter).
2. `class_migration`: added the stronger property — **the done flag dominates a later goal change**
   (cut→Assassin, then setGoal(bulk)+re-run → still Assassin; without the gate it'd flip to Tank).
3. `weekly_goal`: assert against `WeeklyGoalService.defaultGoalDays` (policy-conformance, not a
   magic-3 lock).

**Codex's named #1 remaining gap — cross-store atomicity / save-path WIRING — implemented:**
`test/save_session_orchestration_test.dart` (3 tests) asserts one `saveSession` fans out
consistently to **workout_sessions + gem ledger (warm-up) + adventure charges + mission marker**,
that reward idempotency holds (once/day), and that an abandoned save writes the row but awards
nothing. **Mutation-proven & uniquely valuable:** commenting out the `grantForSession` wiring in
`saveSession` → this test goes RED while all 7 `warmup_reward_service` isolation tests stay GREEN —
exactly the dropped-wiring class no existing test could catch.

Self-caught defect (red-green working): my first draft asserted re-saving a *completed* session
dedupes to one row — it doesn't (saveSession only dedupes ongoing→completed); corrected the oracle
to the real contract (reward idempotency).

**Net additions this session:** +5 test files, ~26 new tests; 2 weak tests strengthened. All
mutation-verified where it mattered.

---

# PHASE 7 — FINAL VERIFICATION

- **`flutter analyze`: No issues found** (0 issues — the CLAUDE.md bar).
- **`flutter test`: 1021 passed, 9 failed.** Every file I added or edited passed. All 4 `lib/` files
  I mutated for red-green proofs are **byte-clean reverted** (absent from `git diff`).

**The 9 failures are PRE-EXISTING, not from this audit** — `git diff --stat` shows they trace to the
user's **uncommitted WIP** + **stale goldens from the prior committed BIT-bubble change**:

| Failing test(s) | Root cause (not this audit) |
|---|---|
| `active_workout_end_early` (1), `active_workout_idle` (2) | User WIP in `lib/pages/Workout session/active_workout.dart` |
| `profile_hero_card_golden` (1) | User WIP in `lib/pages/profile_page.dart` (hero card render changed) |
| `quests_page_golden` (1) | User WIP in `lib/pages/quests_page.dart` |
| `room_scene_golden` ×4 (phone/wide/short/large-text) | Stale `HomeRoomScene` goldens from the committed bubble change (`3ae6355`), never regenerated |

**Not touched** (per "don't rubber-stamp WIP goldens" + "never stash WIP"): regenerating these would
mask in-flight WIP regressions. Left for the user to resolve as part of their open work.

**Audit-attributable test result: 100% green.** The 5 new files (json_safe, class_migration,
weekly_goal, save_session_orchestration) + 2 strengthened (level_up_burst, glitch_text) all pass; the
audit introduced zero failures.

## Phase 7b — root-cause of the 9 failures (isolation runs)

Ran the failing files **in isolation** to separate flaky-under-load from genuine:

| Group | In isolation | Root cause | Recommendation |
|---|---|---|---|
| `active_workout_idle` (2) + `active_workout_end_early` (1) | **PASS** (`+3`) | **Concurrency flake**, not a break. They only fail under the full parallel suite. The user's WIP adds a fire-and-forget `NotificationService.instance.maybeAskRestPermission()` to `ActiveWorkoutPage.initState` — well-guarded (`_android`→null in tests, only mocked-prefs I/O) but it lengthens the async/timer chain a heavy widget test must settle under CPU contention. | Not a regression. If it flakes in CI, run that file at `--concurrency=1` or stub the call in tests. |
| `room_scene_golden` ×4 (phone/wide/short/large-text) | **FAIL** | **Stale `HomeRoomScene` goldens** vs the *committed* BIT-bubble change (`3ae6355`) — never regenerated (the prior session caught up bit_room_voice/bit_quest/expedition_dock but not these). `room_scene.dart` is committed (not WIP). | Safe to regenerate (matches intended committed code) — completes the prior session's golden catch-up. Needs a human glance at the PNGs. |
| `profile_hero_card_golden` (1) | **FAIL** | User **WIP** in `lib/pages/profile_page.dart` (+36) changed the hero-card render. | User's in-flight work — regenerate when the page is final. |
| `quests_page_golden` (1) | **FAIL** | User **WIP** in `lib/pages/quests_page.dart` (+166) changed the board render. | Same — regenerate when final. |

**Net:** 0 genuine logic regressions. 3 flakes (pass alone) + 6 golden mismatches (4 committed-stale,
2 WIP). None are test-validity defects.

---

# PHASE 8 — DEEP-READ OF REMAINING FILES (completing 100% coverage)

## Batch 16 — migration / program / calibration services (4 files, 44 tests) — VALID, EXEMPLARY

| File | Tests | Notes |
|---|---|---|
| migration_service_test.dart | 9 | Dead-key strip + once-gate, END backfill + idempotent, clear-self-reported-seed + recompute, stats-rules recompute + no-op-when-current, avatar-seed gendered default + one-shot (custom not clobbered), title unification + one-shot, weight-log anchor once. **Heavy idempotency/one-shot coverage** (Codex's migration concern, well-covered). |
| program_service_test.dart | 21 | Start/advance/wrap/double-completion-guard, today workout/rest, targetSessions 24/32/48, arc progress, completion fires-once + title + no-re-fire, pending-reveal-once, beginNextPath, stayWithProgram, prescriptions (rebuild/swap-rekey/forgiveness). |
| calibration_service_test.dart | 10 | Epley + ignore high-rep/unweighted, seed→tier/rank (650/A, 420/B), ratchet-never-lowers, no-BW→intermediate cap, freeze-after-3, seed-persists-delta-excludes, quiz-prefs-don't-seed, auto-cal window. Oracle = strength-standard tiers (independent). |
| recovery_vitality_test.dart | 4 | VIT meter ranges (perfect≥90, inactivity≤20, overtrain mid), legs→STR remap. |

Batch 16 ghosts: **none.** All 44 VALID. **Tally: 95/165 files.**

## Batch 17 — program/exercise services (8 files, 52 tests) — all VALID

| File | Tests | Notes |
|---|---|---|
| program_prescription_test.dart | 7 | SetRepScheme labels, every-workout-day-prescribes, rest-empty, progression schemes (constant-locks justified). |
| program_lookahead_test.dart | 11 | NEXT teaser workout (consumed vs pending, wrap), days-away, null guards, relativeWhen. |
| program_swap_test.dart | 6 | applyProgramSwaps: identical-instance opt, rest untouched, remap+re-key, dedupe-collision, recurring lift. |
| program_customization_service_test.dart | 7 | Swaps round-trip, per-program isolation, self-swap clears, remove/clear, persistence, effectiveDay. |
| weekday_anchored_migration_test.dart | 7 | Legacy day-index→workout-index map (workout/rest/wrap) + migration seed + **idempotent + no-op**. |
| ongoing_program_swap_service_test.dart | 5 | Round-trip, empty clears, **terminal-path cross-store clearing** (finish/discard/abandon) — wiring guard. |
| exercise_kind_cache_test.dart | 7 | Classify (compound/iso/bodyweight-wins/equipment/default), **sticky classification**, cache survives reset. |
| custom_exercise_service_test.dart | 9 | Create, dup-name (custom+built-in, case-insensitive, excludeId), update, delete, round-trip, muscle map. Mocks asset bundle. |

Batch 17 ghosts: **none.** All 52 VALID. **Tally: 103/165 files.**

## Batch 18 — settings/profile/warmup services (10 files, 41 tests) — all VALID

| File | Tests | Notes |
|---|---|---|
| profile_service_test.dart | 4 | Default/persist/legacy-fallback/blank-name→Player. |
| character_service_test.dart | 2 | JSON round-trip (all fields) + create+complete-onboarding. |
| demo_seed_service_test.dart | 4 | Marketing seeder reads intermediate-Knight: persona/profile/program, ≥28 real sessions, level 10–19, LCK diamond, B/A stats. |
| rest_preference_service_test.dart | 6 | Class rest defaults (Tank180/Bruiser90/Assassin60) + persistence. |
| sound_settings_service_test.dart | 2 | Default-on + round-trip. |
| workout_defaults_service_test.dart | 3 | Duration default + clamp, rest-seconds clamp. |
| unit_settings_service_test.dart | 5 | Defaults lbs/ft-in, round-trips, `Units` static load/set. |
| warmup_routines_test.dart | 6 | Raise+drill present, tailoring, dedupe, cap ≤6, fallback. |
| warmup_session_field_test.dart | 8 | isWarmup JSON round-trip + omitted-when-false, legacy decode, **warmup out of totalVolume**, derived warmedUp, copyWith. |
| warmup_stat_isolation_test.dart | 2 | **Heavy warm-up sets change NO volume/XP** (strong isolation guarantee). |

Batch 18 ghosts: **none.** All 41 VALID. **Tally: 113/165 files.**

## Batch 19 — onboarding flow/page widgets (6 files, 48 tests) — all VALID

| File | Tests | Notes |
|---|---|---|
| calibration_quiz_test.dart | 10 | deriveClass, prefs round-trip, Q1–Q4 full-answer capture, empty-bw→null, back→exit/restore, instant-return. |
| solution_screen_test.dart | 8 | Reveal content (no StrobeFlash square-bug), semantics, CTA-advance, bg-tap-completes-not-advance, mid-anticipation snap, CTA-gating, 1 golden. |
| name_screen_test.dart | 7 | Prompt/counter/disabled, **invalid-char strip + paste-cap-16**, whitespace-disabled, enable/disable, commit (keyboard+button), creates-character + seeds-avatar. |
| class_reveal_screen_test.dart | 6 | Per-class reveal (name/focus/sigil asset), body-tap jump, identity color, **commit-fires-once (double-fire guard)**, null-bw. |
| welcome_landing_test.dart | 7 | Brand/CTAs/beta, departure→callback, reduced-motion immediate, **SIGN IN inert**, idle no-error. |
| onboarding_navigation_test.dart | 7 | **PopScope back-guards ×3 loaders**, quiz **double-tap re-entrancy** (no skip/early-complete), system-back steps-back, multi-select vow/vision capture. |

Batch 19 ghosts: **none.** All 48 VALID. **Tally: 119/165 files.**

## Batch 20 — quests / draft / radar (8 files, 44 tests) — all VALID

| File | Tests | Notes |
|---|---|---|
| quest_board_test.dart | 8 | 3 goldens **+ semantic/tap asserts** (tap-routes, ready-count label, empty-quiet, reduced-motion-static). **The model golden test** — the semantic-guard pattern I recommended. |
| quests_page_gems_test.dart | 2 | Claimable render→claim→gems (CLAIM→CLAIMED, balance 5, wallet count-up, no price tag), in-progress dim box. |
| quests_page_flight_test.dart | 1 | Motion-on gem flight + "+5" reveal + count-up + CLAIMED. |
| quests_page_bit_test.dart | 2 | Empty→painted BIT(labelled)+quiet line; session→"ready to claim" line. |
| workout_draft_controller_test.dart | 6 | State machine: idle/begin/setValid/clear/commit-guard/notify-only-on-change/repeat-seed. |
| workout_log_controls_test.dart | 11 | **WeeklyGoalService** (default 3, freq-seed low2/mid4/high6, stored-wins+clamp), prCountsBySession (baseline/beat/order/partial-excl/bodyweight), updateSession (replace/no-op/cache-correct). |
| stat_radar_test.dart | 5 | rankBandFraction thresholds 0/.2/.4/.6/.8/1.0, interpolate+clamp, non-decreasing, **drift-guard mirrors StatEngine thresholds**, widget axes+dominant+hint. |
| stat_radar_read_test.dart | 4 | meaning-for-axis, axis↔class contract, dominant builds, balanced ties. |

Batch 20 ghosts: **none.** All 44 VALID. **Tally: 127/165 files.**

> **Correction (honesty):** `workout_log_controls_test` already covers `WeeklyGoalService`
> (default, freq-seed, stored-wins, clamp). So my Phase-5 `weekly_goal_service_test.dart` was **not a
> true gap** — I checked for a dedicated test *file* and missed that the service was tested inside
> another file. Only its **re-clamp-corrupt-stored-99** case is genuinely new; the rest overlaps.
> `json_safe` and `class_migration` remain genuine, non-overlapping gaps. Net: the weekly_goal add is
> redundant-but-harmless (could be deleted). Lesson logged: grep for the *symbol*, not just a matching
> filename, when judging coverage gaps.

## Batch 21 — adventure / class / selection / schedule (6 files, 53 tests) — all VALID

| File | Tests | Notes |
|---|---|---|
| expedition_dock_test.dart | 14 | Dock state machine: armed/empty meter, BIT home/away, **a11y per phase**, charge-flash gating, greeting/scouting, coffer+collect, **double-tap guard**, phase-correct routing, RM idle→out, null-adventure. |
| adventure_phase_test.dart | 11 | Pure `adventureUiStateOf` + `hasUncollectedHaul` (idle/out/returned/legacy, canDispatch@0, weeklyCap-current-week-only, survives-kill-reopen). |
| class_respec_test.dart | 6 | Unlock@1, exclude-current, 7-day lock, legacy-unlocked, respec+30-day cooldown, former-paths accumulate. |
| exercise_selection_rework_test.dart | 10 | topExerciseIds (rank/drop-dead/skip-partial), targets filter, alternativesFor (strong/weak/exclude/null/cap). |
| start_workout_seed_test.dart | 6 | Pre-select last groups+defaults, brand-new empty, chip add/remove, repeat seed-owned, **Replace in place**, program-day no chips. |
| weekday_schedule_surfaces_test.dart | 6 | 2 goldens + WeekdayPicker a11y/toggle + onboarding immediate-apply vs defer. |

Batch 21 ghosts: **none.** All 53 VALID. **Tally: 133/165 files.**

## Batch 22 — program HUD / summary / adventure-page / profile (8 files, 29 tests) — all VALID

| File | Tests | Notes |
|---|---|---|
| program_path_hud_test.dart | 5 | Zero-progress+boot-pips, 75%-final-stretch, complete+reward-title, in-progress-redacts-reward, RM-no-sparks. |
| program_onboarding_pages_test.dart | 13 | ProgramLoadingPage (status/timing/dots/no-spinner) + ProgramSelectionPage (recommend-match, forwards-to-name, blocks-back, recommended-first, training-days edit, golden). |
| workout_summary_finish_test.dart | 2 | Completed hero no-calories, abandoned muted. |
| workout_summary_stat_gains_test.dart | 1 | Buried-gain regression: non-statGain hero still renders STR in STAT GAINS. |
| workout_summary_warmup_bonus_test.dart | 1 | **Warmed-up session → WARM-UP BONUS + gems land via saveSession** (full path). |
| lck_pips_test.dart | 1 | Semantics "Luck N of 4" at thresholds. |
| adventure_page_widget_test.dart | 6 | idle-0, arm-one-tile+GO+cancel, weekly-capped-disabled, out-countdown, returned-COLLECT, RM-static (**single-animation-owner invariant**). |
| profile_page_widget_test.dart | 1 | Coherent neutral colors + accent rail + edit-chip-neon + loadout-cosmetics-only. |

Batch 22 ghosts: **none.** All 29 VALID. **Tally: 141/165 files.**

> **Correction #2 (my added orchestration test was less unique than claimed):**
> `workout_summary_warmup_bonus_test` already asserts `saveSession` credits warm-up gems (via the
> summary page), and `workout_session_lifecycle_test` already asserts `saveSession` sets the mission
> marker. So my `save_session_orchestration_test`'s warm-up + mission assertions were **already
> covered** — the genuinely-new assertion is **adventure-charge-via-`saveSession`** (`charges==1`
> after a completed save), which nothing else pins, plus the value of one consolidated fan-out/
> idempotency view. The Phase-6 mutation (comment out warm-up grant → my test RED) was real but
> `workout_summary_warmup_bonus` would have caught it too. **Honest tally of my 4 added files: 2
> genuine gaps (`json_safe`, `class_migration`), 1 redundant (`weekly_goal`), 1 partly-redundant
> (`save_session_orchestration` — keep for the adventure-charge assertion).** Same root lesson:
> assess coverage by the *symbol/behavior*, not the test-file name.

## Batch 23 — demos / customizer / interview / start-gate (8 files, 31 tests) — all VALID

| File | Tests | Notes |
|---|---|---|
| exercise_demo_cabinet_test.dart | 7 | **FakeVideoPlayerPlatform** mock: render+autoplay+controls (asserts `fake.log` play/pause), HIDE/SHOW persist, fullscreen viewer (backdrop/close/LOOP-resume). |
| exercise_demos_test.dart | 5 | Demo-id-in-catalog, asset-on-disk, folder-declared-in-pubspec, thumb poster/fallback. |
| exercise_demo_player_test.dart | 2 | Uninitialized→poster-no-glyph (autoplay), autoPlay:false→glyph. |
| exercise_demo_toggle_test.dart | 1 | Autoplay+tap-pause+tap-resume (platform-level `fake.log` asserts). |
| exercise_detail_demo_tap_test.dart | 1 | Info-page SliverAppBar hero autoplay/pause/resume (reported bug surface). |
| avatar_customizer_test.dart | 4 | 5 groups + combo line, chip-instant + SAVE-persists-pops + nothing-until-save, **back-asks-before-discard**, back-no-edits-pops. |
| bit_interview_quiz_test.dart | 11 | Extensive state-matrix: ask-neutral/react-cheer-amber, ask-only, no-auto-advance, types-not-instant, last-reaction-no-flashback, **280ms-hold-cancel**. |
| start_gate_navigation_test.dart | 2 | START WORKOUT in-shell (RootPage stays root, no strand), BIT embodied + name-drop. |

Batch 23 ghosts: **none.** All 31 VALID. **Tally: 149/165 files.**

## Batch 24 — boot/loaders/asset/nav + final stragglers (16 files, ~52 tests) — all VALID

| File | Tests | Notes |
|---|---|---|
| boot_splash_page_test.dart | 5 | RM-reveal, **honest-min** (dest withheld until minDisplay), adaptive-slow-boot, cap-backstop, route-to-onboarding. |
| calibration_loading_page_test.dart | 4 | Header/telemetry, unskippable→complete→reveal-on-tap (once, stamped), RM-immediate, real-work-once. |
| onboarding_boot_transition_test.dart | 2 | GET STARTED → CRT power-cycle → cold open; RM straight-to-cold-open. |
| home_first_quest_routing_test.dart | 3 | firstQuestMissionPlan program-day/null/rest-day. |
| start_workout_program_flow_test.dart | 2 | programDayStarter full-loadout + start-confirm CANCEL/START. |
| radar_readability_goal_gate_test.dart | 1 | Subprocess dry-run lists gate's test files + audit cmd (tool). |
| arcade_route_test.dart | 5 | Each motion pushes dest, RM-pushes, reverse-pops-no-throw. |
| class_asset_test.dart | 2 | Class/sigil PNG existence + **exact dimensions** (64/128/192/32), radar 384². |
| curated_exercise_assets_test.dart | 1 | Every curated exercise in catalog + first photo on disk. |
| plate_calculator_sheet_test.dart | 19 | Forward/reverse, chip-builds-stack (80kg), removal/mid-pop-off-guard, USE-WEIGHT canonical kg, lb-mode, **FP-noise round-trip (150 not 149.99)**, bar selector. |
| adventure_assets_test.dart | 4 | Every route/find/emblem asset bundled + route-ids-unique. |
| bit_hologram_golden_test.dart | 2 | VALID-VR (projection + glitch slice). |
| bit_quest_golden_test.dart | 2 | VALID-VR (bubble tail variants + quest briefing). |

Batch 24 ghosts: **none.** All VALID. **Tally: 165/165 files — COMPLETE.**
(`test/helpers/fake_video_platform.dart` is a test *helper*, not a test file — no `test()` calls.)

---

# PHASE 8 CONCLUSION — 100% AUDIT COVERAGE

**Every one of the 165 test files / 996 tests has now been deep-read individually.** The 49%-sample
verdict held across the full set: **the suite contains NO ghost tests.** It is uniformly rigorous —
hand-derived/independent oracles, pervasive idempotency / clock-rollback / concurrency-single-flight /
malformed-JSON / boundary / a11y-reduced-motion coverage, asset-manifest guards, and cross-store
wiring checks (the very pattern my orchestration test followed already existed in
`ongoing_program_swap_service`).

**Complete actionable set (entire suite):**
- **2 WEAK + 1 borderline** (`level_up_burst` ×2, `glitch_text` T1) — **strengthened + mutation-verified** (Phase 4).
- **~4 constant-lock** tests (class colors, rarity labels, advice-pool size, progression schemes, meaningForAxis) — restate **documented** product/design constants; kept as justified spec-locks.
- **62 golden VALID-VR** change-detectors across 21 files — legitimate visual-regression for a
  pixel-art app; the model is `quest_board`/`bit_room_voice` (golden **+ semantic asserts**).
- **~22 tool-testing** tests (`radar_readability_*`, `radar_readability_goal_gate`) — VALID but guard
  a one-off study harness in `tool/`; keep iff that tooling stays maintained.

**My additions (honest final):** `json_safe` + `class_migration` = genuine gaps; `weekly_goal` =
redundant with `workout_log_controls`; `save_session_orchestration` = unique only for the
adventure-charge-via-`saveSession` assertion. Net +~26 tests, +4 files, 2 strengthened, all green.
