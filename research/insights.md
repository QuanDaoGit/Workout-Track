# Research Insights — Ironbit

> Seed document. Tag every item `[validated]`, `[assumption]`, or `[risk]`. Pre-launch = mostly assumptions.

### Progressive feature unlocking (workout-count feature drip) — directionally right for the GAME-LIKE goal, but precedent is hypothesis-grade for a TRACKER; gate meta surfaces only, never the tool core (2026-07-14)
Should meta features (Guild, Adventure, Shop, strength index…) unlock at workout-count milestones (3 → guild, 5 → X…), each with a standard unlock ceremony? Deep tier (core-loop/progression). **Codex evidence-review run (prompt-only, verdict *needs-attention* → 4 findings, all folded in — it downgraded the precedent transfer, forced the activation-vs-gating split, downgraded visible-locked to a hypothesis, and demanded an anti-guilt copy audit).** Builds on [[reward-economy]] (deterministic unlocks = right base), the S-curve richness finding, and "creative features: DEFER — fix core first" (a re-pacing of EXISTING features passes that bar; new surfaces don't).
- `[validated, precedent — but hypothesis-grade for transfer]` Progressive revelation is the universal mobile-game onboarding pattern, and the *gamified-wellness* comparables run the exact proposed mechanic: **Finch** stages unlocks by adventure count (stages at 7/22/42/67 adventures; shops unlock progressively; seasonal events after day 3) ([Finch wiki](https://finch.fandom.com/wiki/Stages_of_Growth)), **Habitica** unlocks drops/pets at level 3 explicitly "to help new players become used to the game" ([Habitica FAQ](https://habitica.fandom.com/wiki/FAQ)), **Duolingo** gates leaderboards behind 10 lessons, **Pokémon GO** gates gyms/raids at level 5. **Codex F1 (high): this is games/companion-apps evidence, NOT tracker evidence** — Ironbit's primary job is logging; a first-session user may read locked surfaces as *missing capability*, not progression. Treat transfer as a **hypothesis needing a first-session prototype check**, not established.
- `[validated, psychology — secondary-grade]` Milestone unlocks are a strong multi-drive motivator ([Yu-kai Chou](https://yukaichou.com/advanced-gamification/the-power-of-milestone-unlocks-in-gamification-design/)); goal-gradient/endowed-progress favor **visible-but-locked with a named condition** over hidden ([learningloop](https://learningloop.io/plays/psychology/unlock-features), [FDG2012 'Ville patterns](https://users.soe.ucsc.edu/~ejw/papers/lewis-motivational-game-design-patterns-fdg2012.pdf)). **Codex F3: pop-UX/game-design grade — visible-locked, threshold cadence, and the ceremony are experiment parameters, not proven design.**
- `[risk, Codex F2 (high) — the activation contradiction]` **~75% of new users churn in week 1 (directional), so anything gated past ~workout 5 is unseen by most users** → gated features must NOT be activation drivers, AND at least one identity/ritual/collection loop must stay day-1 (XP/level/stats/first quest/BIT). If Guild/Adventure are week-1 hooks, gating them at 3–5 workouts delays the hook past most churn; if they aren't, anticipation alone doesn't justify removing them. → per-gate funnel targets (see-locked → unlock → revisit) once instrumented.
- `[risk, Codex F4 — anti-guilt audit required]` Count-based no-deadline gates are the *least* guilt-prone shape (no lapse, no streak), but countdown copy ("3 workouts to go") can still read as debt/withheld belonging for injured/low-frequency users; general gamification criticism targets exactly this pressure family ([NPR/Adrian Hon](https://www.npr.org/2022/09/22/1124624702/are-you-being-tricked-into-working-harder)). → non-punitive locked copy (invitation, not debt), never gate *belonging* framing (BIT stays day-1), consider a preview/manual-reveal escape hatch.
- `[assumption — negative held after 2 dissent passes]` No evidence found of backlash against EARNED (non-paywall) gates in trackers/tools — fitness "locked features" complaints are overwhelmingly paywall-shaped. Honest boundary: earned-gate resentment would likely be phrased as "onboarding friction"/"forced gamification", and two queries in that vocabulary still found nothing specific — absence of evidence, not proof.
- `[validated, internal — the strongest FOR argument]` Most gate candidates are **already implicitly data-gated** (Guild cache/level need sessions; Adventure needs workout-charges; Shop needs gems; strength index needs lift history) — day 1 they render as hollow empty states. An explicit drip converts "empty/hollow" into "anticipated/earned" without withholding anything that works day 1. The S-curve finding (benefit peaks near mean richness) independently supports reducing simultaneous surface count early.
- **Decision feed (recommend):** YES to a **meta-drip, tool-core-never** shape: (1) never gate log/history/XP/stats/level/first-quest/BIT; (2) gate only data-empty meta surfaces, thresholds front-loaded (~workouts 1–7, dense early); (3) visible-locked with named condition + invitation copy (no debt framing); (4) one standardized unlock ceremony reusing the existing ceremony vocabulary; (5) grandfather existing installs (prudent migration, not evidence-backed); (6) treat thresholds/visible-locked as tunable experiment parameters with per-gate funnel instrumentation. → brainstorming/`/deep-feature` for the ladder + ceremony; pixels to `ironbit-design`. — an OFFLINE IDENTITY-GUILD (cooperative, body-neutral); real multiplayer is a deferred, minimal, opt-in Phase 2 — NOT a public social network (2026-06-29)
The user is reworking the hollow NPC-sim guild ("forge nod only, no real interaction, no accounts, generic card UI, no art") from scratch into something that feels like a gaming guild but fits a body-neutral workout app. **Six separate `/research` Deep flows** (workout-app social · Duolingo/Finch social-graph · social UI/UX + assets · social/competition psychology · gaming-guild mechanics · social backend infra) **+ two Codex-prompted gap-fills** (exercise-addiction/overtraining; shipped-then-removed-social postmortems + diorama a11y + youth/COPPA). **Codex evidence-review (Deep, prompt-only, verdict *needs-attention* → 8 findings, ALL folded in — it forced active-days-not-volume, downgraded BIT/Köhler + simulated-guildmates from "core mechanic" to prototype-gated experiments, reframed social as SECONDARY to identity/competence, and surfaced the 4 missing risk fields the gap-fills then closed).** Reconciles + supersedes the older "social = future opt-in, don't build comparison" + "offline is the wedge" risk notes below ([[profile-hero-card]] private-mirror call).
- `[validated, the spine — load-bearing]` **All 6 flows independently converge: COOPERATIVE/relatedness mechanics, not person-vs-person competition, are the evidence-supported default for a body-neutral fitness guild — and the body-neutral mandate is CONFIRMED by evidence, not merely asserted.** Competition has no net performance effect (splits into approach+/avoidance− paths, [Murayama & Elliot 2012 MASEM, 614 studies](https://www.semanticscholar.org/paper/The-competition-performance-relation:-a-review-and-Murayama-Elliot/cecdc21ffad8cd788e61ec19a6b82bdb1ff1b0d6)); leaderboard/social-comparison efficacy is UNPROVEN and demotivates/harms low performers + the body-image-vulnerable (women, beginners, ~50% gym-goers carry social-physique-anxiety), [JMIR 2020 scoping meta-review](https://pmc.ncbi.nlm.nih.gov/articles/PMC7148546/). Cooperation builds the *companion support* + relatedness Ironbit wants. **CONTRARY held (Codex F1):** a step-count RCT found competition sustained engagement longer over 3wk + inter-team hybrid beat pure-either — so engagement-optimal ≠ safety-optimal; the right hedge is **cooperative as the default safety posture, with any competition reserved as an OPT-IN, non-body-ranking experiment** (you-and-your-guild vs a shared goal / NPC "raid" target / time-boxed season, never public individual ranking), not categorically foreclosed.
- `[validated, the strategic reframe — Codex F5, load-bearing]` **The guild is an IDENTITY/COMPETENCE surface first, a social surface second.** Relatedness is the *weakest* SDT need as a direct predictor of exercise behavior ([Teixeira 2012 systematic review](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3441783/) — competence positive in 92% of samples, relatedness ~0%); it works through *belonging/identity/support*, not a satisfaction toggle. So **every guild feature must strengthen earned identity or mastery even if NO real social graph ever launches** — this protects the moat and de-risks the whole rework. Social Identity Theory: a guild motivates via belonging + shared purpose + *contribution/role* status, **not** member-ranking.
- `[validated, the flagship mechanic — but reshaped by Codex F2 + the overtraining gap-fill]` **A cooperative "Clan Games"-style pooled guild goal, but the pooled resource MUST be ACTIVE-DAYS (binary, ≤1 credit/person/day), NEVER pooled VOLUME (kg) or raw session count.** Volume is the one axis the overtraining consensus ([Meeusen 2013 ECSS/ACSM](https://pubmed.ncbi.nlm.nih.gov/23247672/)) ties to harm and it compounds a monotonic "more-is-better" gradient with no built-in stop; sessions can be farmed by fragmenting a workout; active-days is bounded, body-neutral, AND the more durable habit lever (instigation-habit, [Lally 2010](https://onlinelibrary.wiley.com/doi/abs/10.1002/ejsp.674)) — no efficacy-vs-safety tradeoff. Borrow Clash's structure: pool toward ONE shared goal → tiered cosmetic-gem rewards everyone who participated claims, with a **per-member daily cap + diminishing marginal credit** (the single highest-leverage guardrail — makes "overtrain to carry the team" structurally impossible) ([CoC Clan Games](https://clashofclans.fandom.com/wiki/Clan_Games)). **Additive-only — you can help, never hurt** (strip Habitica's shared-damage, its clearest anti-pattern).
- `[validated, anti-compulsion guardrails — the overtraining gap-fill, load-bearing for body-neutral]` The vulnerable profile (young, achievement-oriented, perfectionistic, body-image/ED-comorbid — exercise-addiction OR **3.71×** with disordered eating, [Trott 2021](https://pubmed.ncbi.nlm.nih.gov/31894540/)) *is* the gamified-RPG-fitness demographic → **protective defaults ON for everyone, never opt-in.** Concretely: (1) **a logged REST/recovery day counts as a valid contribution** (removes pressure to train through fatigue); (2) **resettable WEEKLY target + grace days — NO fragile cumulative streak** (broken streaks demonstrably sap motivation + breed guilt, [Silverman & Barasch 2023 JCR](https://www.psychologytoday.com/us/blog/ulterior-motives/202306/how-broken-streaks-sap-motivation)); frame a miss neutrally ("the guild rests this week"); (3) anchor the target to the **WHO floor (~2–4 active-days/wk reads as COMPLETE, not minimum-to-exceed)**; (4) keep Ironbit's two existing safety invariants as non-negotiable — **no weight/calorie coupling to exercise**, **gain-framed immutable identity** (no decay, protected rest, REBUILDING never red). HONEST BOUNDARY: no clinical proof gamification *causes* exercise addiction — the bridge from demonstrated intermediate harms (guilt/demotivation) to compulsion is inferred; the guardrails are low-risk + high-alignment, not efficacy-proven.
- `[validated, offline-renderable identity — the strongest on-doctrine surface, ships NOW]` Pure earned-identity guild devices are **fully offline-renderable in the single-player sim today, zero accounts, zero moderation:** a **craftable guild CREST** (pattern × class-tint, border tiers up with guild level — [CoC clan badge](https://clashofclans.fandom.com/wiki/Clan_Badge), maps onto Ironbit's monochrome+`ColorFilter.srcIn` recolor pipeline), **guild XP from your OWN training**, **collective milestone titles/frames**, a **cooperative shared-monument** that visibly grows from pooled training. **Keep ALL guild progression COSMETIC/identity-only, NEVER power/perks** — WoW removed guild perks because they became a barrier-to-entry + abuse vector ([Wowhead WoD](https://www.wowhead.com/news/guild-leveling-effectively-removed-in-warlords-of-draenor-241493)).
- `[validated, the look — Topic 3 + a11y gap-fill]` **A STATIC, always-populated "guild hall diorama" you glance at and tap into — NOT a navigable hub** (a walkable/gated hub adds friction; aliveness = ambient micro-motion in a still scene, Ironbit's existing room/diorama pattern is exactly right, reduced-motion-safe). The sim's superpower: **the hall can be guaranteed never-empty** (never show "0 online"/"no activity" — both an empty-state dead-end AND weak-social-proof failure, [NN/g](https://www.nngroup.com/articles/empty-state-interface-design/)). **A11Y (load-bearing, Codex F6):** a diorama is NOT inherently inaccessible but it must be a **visual layer OVER a semantic list, with the list-equivalent exposed to assistive tech** (don't gate actions behind the diorama) — every element a labeled `Semantics` node + value, state-change announcements (claimable quest, gem landed), contrast-audit BOTH lit AND dim states vs `kBg` (dim "secondary" states are the likely <3:1 failures), ≥24px targets, reduced-motion path, a plain-text readout (the body-map `TARGETS:` pattern). Asset inventory authored: crest, banner, roster tile, rank insignia, in-fiction presence pip (honest — never a fake "online now"), notice/quest board, co-op progress bar, NPC sprites, member-detail card, nod/kudos glyph, populated-but-quiet empty-state art, trophy/loot wall, 9-slice panel frame.
- `[validated, the Finch model — Topic 2]` If/when a REAL social graph exists, **Finch is the template: support-not-scoreboard — no public feed, no DMs, no ranking, mutual-consent, two tiers** (symmetric "train-together buddy" + asymmetric "cheer-me-on buddy"), and **BODY DATA NEVER ENTERS THE GRAPH** (share training *acts* — showed up, completed a quest, earned a title — never weight/metrics; Finch shares "showed up for self-care", never the mood journal). The async **gift / "good vibe" / friendship-tier** loop (Finch + Pokémon GO) is the first real-social mechanic to add — never needs live co-presence. Reject Duolingo's guilt levers (buried/lossy leaderboard opt-out, demotion-anxiety, "you let your friend down").
- `[risk → prototype-gated, Codex F3 + F4]` **Two big claims are DOWNGRADED from "core mechanic" to experiments needing validation before commitment.** (a) **Simulated/NPC guildmates** answering a complaint *about hollow simulation* is weakly supported (no evidence NPC "social" creates durable relatedness in fitness apps) — risk of rebuilding the same fake-feeling thing with more decoration. Require a prototype comparing **solo-identity progression vs NPC-guild-sim vs minimal-real-async support** before building; honesty guardrail = frame it as "your hall / your crew" (an identity surface), never as fake online friends. (b) **BIT as an effort-responsive Köhler "superior pace partner"** is promising (software partners can produce persistence gains, [Köhler meta n=1,912]) but the supporting primary was paywalled and there's a **null result when the partner was a fixed non-responsive ghost** ([PMC6523870](https://pmc.ncbi.nlm.nih.gov/articles/PMC6523870/)) — treat as an experiment with explicit min-viable-evidence (adaptive/responsive behavior, persistence + perceived-pressure measures, guilt/annoyance failure criteria), not a load-bearing bet.
- `[validated, the postmortem verdict — Codex F8, resolves "is the rework even worth it"]` **Every shipped-then-removed fitness-social case killed the LARGE/PUBLIC/OPEN/UGC surface; the SMALL/PRIVATE/GOAL-BOUND surface survived.** Habitica shut its public Tavern+Guilds (Aug 2023, low use + online-safety moderation cost) while small **Parties** thrived ([Habitica FAQ](https://habitica.com/static/faq/tavern-and-guilds)); Fitbit ripped out Groups/Feed/DMs/badges (May 2026); Fitocracy's feed died on neglected moderation/discovery; Pact/GymPact's money-stakes social collapsed into a ~$948K FTC settlement; Strong ships ZERO social as a marketed feature. → **A live UGC feed is a permanent moderation operating cost lethal to a solo/indie app; the rework should be a deepened SIMULATION + optional small private accountability "party", NOT a public social network — Ironbit's offline-local model sidesteps the entire moderation/discovery/online-safety/sunset-trust treadmill (a feature, not a compromise).** Also: Fitbit deleting earned badges burned trust → **keep earned identity artifacts (titles/frames/loot) LOCAL + PERMANENT, surviving any future social teardown by design.**
- `[validated, infra — Topic 6 + youth gap-fill; only if/when Phase 2]` **Two data planes: private training stays local-first in SharedPreferences (UNCHANGED); only shared social state is server-authoritative.** Provision a backend identity **lazily via anonymous auth, link a real provider only on opt-in** (Firebase + Supabase both support `signInAnonymously()` → link Apple/Google with no data loss) — preserves the no-sign-up offline default structurally. Lead options: **Supabase + PowerSync** (Postgres is the natural friend/guild/leaderboard fit; flat pricing) OR **self-hosted Nakama** (purpose-built groups/roles/leaderboards/friends/presence, but client-server not offline-first + real ops burden). **AVOID Firebase as the social store** (the leaderboard is its canonical read-cost landmine). **MODERATION is a legal launch-blocker** once strangers interact (COPPA/GDPR/DSA) and **no BaaS ships user-facing moderation tooling** → shrink the surface: handle-light, NO free-text chat/DMs at launch, structured signals + fixed-emoji + guild "nods" only. **Youth pattern (FTC-endorsed):** the offline core IS the compliant all-ages experience; **social = 13+ opt-in (16+ strict-EU), neutral non-defaulting age gate at the point of opting in; under-13 keep the full single-player game with zero PII → no verifiable-parental-consent machinery needed**; high-privacy defaults off-until-enabled (ICO AADC), no location, no dark-pattern share nudges.
- `[risk, Codex F7 — define before building]` **Phase-1 offline-first risks migration debt.** Before building the sim, define Phase-2 invariants: social entity IDs, a contribution-EVENT schema (so local active-day events can later sync), conflict rules (LWW is correct for append-only single-author training logs; shared state is server-authoritative), migration behavior, and **which Phase-1 simulated concepts are explicitly NON-PORTABLE** (NPC "members", deterministic fake numbers must never masquerade as real once real members exist).
- **Decision feed (recommend):** rework the guild into an **OFFLINE IDENTITY-GUILD**, phased: **Phase 1 (ships now, offline, zero accounts/moderation)** = the diorama hall + craftable class-tinted crest (border tiers with guild level) + guild XP from your own training + collective milestone titles/frames + a **cooperative ACTIVE-DAYS pooled weekly goal** (rest-counts, per-member daily cap, resettable, WHO-floor target, additive-only, BIT-voiced) + a prototype-gated NPC "crew" framed as your-hall-not-fake-friends; **Phase 2 (deferred, OPTIONAL, minimal)** = anonymous-auth async social — Finch-style mutual-consent buddies, gift/nod/friendship-tier loop, NO chat/feed/leaderboard, 13+ gated, two-data-planes; **DEFER/AVOID** = live competition (Clan Wars/raids), public leaderboards, free-text chat/DMs, money-stakes, real friend-graph location signals. Treat **simulated guildmates + BIT-as-Köhler-partner as prototype-validated experiments**, not assumptions. A **no-social alternative belongs in the decision record** (Strong/FitNotes prove zero-social is a positioning win) — the rework is justified ONLY as an *identity/competence* deepening that pays off even if real social never ships. → `/deep-feature` to build Phase 1; pixels/diorama to `ironbit-design`; prototype the 3 relatedness conditions + the active-days goal before committing. Links [[profile-hero-card]], [[workout-analysis]], [[quest-system rework]].
- **[implemented 2026-06-29 — Phase 1, solo-honest v1]** Shipped the OFFLINE IDENTITY-GUILD, rebuilt from scratch on `guild_v2` (old `guild_v1`/members/nods purged). The prototype-gated forks (Codex F3/F4) resolved toward **solo + OPEN slots — no NPC members, no fake friends** (the honest answer to the hollow-sim complaint) and **BIT-not-Köhler** (BIT hosts the hall + is the solo Strike target, never promoted to a pace-partner). Seven features, each its own `/deep-feature` cycle: (1) guild + roster (you + 5 OPEN slots; active-days reuse `trainingDaysThisWeek`); (2) identity = a craftable **code-drawn placeholder crest** (shape×charge×class-tint, level-tiered border) in the hall's centre bay + session-derived guild level; (3) **Weekly Cache** — a 3-active-day cooperative goal that **auto-banks 20 gems** (**Codex *needs-attention* → 6 findings all adopted**: active-days-not-volume, **auto-bank over manual claim**, ONE `now` → Monday-week key == active-days window, versioned `guildcache:v1:<key>`, ledger-derived banked, rest-safe target 3); (4) Legends = self-referenced weekly badges (active-days·streak·improved, "STEADY" never red); (5) rank ladder (Recruit→Leader from guild level); (6) **Strike** (renamed from "Forge Nod"; solo target = BIT, who cheers — forward-compat to member reactions); (7) BIT host + anti-guilt voice ("New week. No rush — show up when you can."). Full suite green (no new failures); ~30 guild tests + 5 goldens viewed. The Strava-style *local competition* the user wanted was reframed (Codex/research) into the cooperative Cache + self-referenced Legends — competitive ranking stays a Phase-2 opt-in. Phased real-social (Phase 2) + the no-social-alternative caveat stand unchanged.
- **[polish findings 2026-06-29 — coherence pass; user critique of the live screen]** Shipped guild drew "colors are fighting / not a system / what does Strike even do / the mini-avatar should show my frame." **Root cause: the autonomous build BYPASSED the app's own `ironbit-design` system** — the answers were already doctrine (now triangulated externally + Codex-reviewed, *needs-attention* → 5 findings folded in). `[validated]` **STRIKE is a placebo in solo** — a reaction/kudos is recipient-dependent (relatedness/reciprocity need an "other": peer-reviewed [JCMC liking-as-reciprocity](https://academic.oup.com/jcmc/article/28/2/zmac036/6987873), SDT, [Strava "kudos make you run"](https://www.sciencedirect.com/science/article/pii/S0378873322000909) works *because it's from others*); with no recipient it does nothing real + the user already saw through it → **cut Strike-as-kudos** (returns in Phase 2 with members). BUT (Codex F2) a daily guild *verb* is valid IFF it changes **durable state** (contribution meter / streak-protect / BIT-mood, with cooldown + visible consequence) — offer that or cut, never a relabeled cheer. `[validated]` **Earned cosmetics must render wherever the avatar appears** (Octalysis CD4 + peer-reviewed [Frontiers 2021](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2021.770139/full): customization→identification→intrinsic motivation holds WITHOUT an audience — the identity/collection channel survives offline-solo; *status* is audience-dependent, weak solo) → route every self-avatar through `LootAvatarFrame`, BUT **responsively** (Codex F3 + the integer-scale rule: a 260px frame can't render crisp at a 36px roster avatar → enlarge the host to 65/130 or a simplified hint; verify at scale). `[validated]` **Colors: the fix is SEMANTIC + HIERARCHICAL, NOT minimal** (Codex F1 — over-muting into a productivity UI kills the arcade identity; a vivid arcade HUD works when every accent MEANS something + there's a hero): reserve neon for ACTION only (enforce via a semantic-alias token layer over `tokens.dart`), keep the *categorical* budget (class violet/red/blue, rarity tiers = real meaning), pick ONE hero + mute supporting cards by **de-emphasis** (lower chroma+opacity, keep the hue) NOT by dimming the hero, cut the "cage of rectangles" (group by whitespace; border/elevation on the hero only), **gate on WCAG contrast** (Codex F4 — receded dim states are the <3:1 risk). `[validated]` **"Not a system" = bypassing the canonical primitives** — rebuild guild widgets on `arcade_card`/`arcade_bar`/`arcade_badge` (I re-rolled bespoke Containers + a forbidden `ClipRRect` smooth XP bar). `[open, Codex F5]` possible IA-density root cause (too many equal modules) — consider merging BIT-strip+identity and cache+legends ("this week") before a like-for-like rebuild; user's call. → a focused polish `/deep-feature` (pixels to `ironbit-design`). The `ironbit-design` "Colour hierarchy & accent discipline" + "Reach for the app's own primitive first" learnings already encoded this — reading them BEFORE the autonomous sprint would have prevented it.
- **[implemented 2026-06-29 — polish pass, full systemic rebuild + Strike cut]** Added `kActionPrimary = kNeon` semantic alias to `tokens.dart` (enforces "neon = action only"). **Cut Strike** → `guild_bit_strip.dart` is now a stateless voice-only host (BIT + line, no button). Routed the roster avatar through **`LootAvatarFrame` at a 65px (260÷4) integer-scale host** so the equipped frame renders crisp (`GuildMember` carries `framePath`/`frameCount`; the page loads `getEquippedItem(LootCategory.avatarFrame)`). Rebuilt every guild card on the canonical **`ArcadeCard`/`ArcadeBar`/`ArcadeBadge`** — the banned `ClipRRect` smooth XP bar → the real beveled `ArcadeBar`; `_RankChip`'s overloaded rank colours → a muted `ArcadeBadge`. Applied **one-hero hierarchy**: hall+crest = the vivid hero, identity header = a class-accent **sub-hero**, cache/legends/open-slots **receded** (lower border-alpha); **neon reserved for CUSTOMIZE only**, the BIT brand label de-neoned to `kText`, amber = cache reward, magenta = gems, class colour = identity. Codex F5 (IA-density merge) **deferred per the user** (chose like-for-like rebuild over merge). `flutter analyze` 0 issues; guild suite + nav green; page + roster goldens regenerated, viewed clean. Net: each card individually fine **and** the set reads as one system — nothing borrows the action colour.

### "Simple Mode" for experienced users — DON'T fork the app; the real ask is autonomy + tap-cost, served by adaptive defaults inside ONE mode (2026-06-28)
Should Ironbit add a separate **Simple Mode** stripping goal-setting / calibration / prefilled loadouts / suggested warm-ups for intermediate users who "don't care about the scaffolding"? **Deep tier** (core-loop + doctrine-touching). **Codex evidence-review run (verdict *needs-attention* → 4 findings, all folded in — it forced the 3-variant split + downgraded L4 + a wider competitor matrix).** Builds on the progressive-disclosure / choice-paralysis findings below + the soul-doctrine moat.
- `[validated, the reframe — load-bearing]` **Split the idea into 3 variants; the no-ship applies to only two.** (a) **Scaffolding-light / quick-start** (skip goal/calibration re-prompts, persisted defaults, faster logging) = *defensible and already half-built*. (b) **RPG-light** (strip identity/XP/loot/class) = **moat-destruction** — for Ironbit the RPG layer IS the product (earned-attachment wedge); removing it leaves a worse Strong clone. (c) **A user-facing Simple⇄Full toggle** = no-ship on modes evidence. The user's *named* friction (goals, setup, prefilled, warm-ups) is **pre-workout scaffolding, separable from the identity layer** — so the win is in (a), not a fork.
- `[validated, behavioral — reframed, triangulated]` **The experienced-user complaint is about AUTONOMY + TAP-COST, not "less product".** Reddit + multi-app reviews: serious lifters want their *own* program (not forced templates) and 2–3-tap logging with last-session numbers instantly visible; "friction breaks focus on a hard leg day" ([Setgraph reddit roundup](https://setgraph.app/ai-blog/best-workout-tracker-app-reddit), [BarBend](https://barbend.com/best-weightlifting-apps/), Liftosaur reviews). Do NOT convert "fewer forced steps" into "dumber app".
- `[validated, competitor — matrix, the negative holds]` **No leading tracker ships a per-user Simple⇄Full toggle — they differentiate at the PRODUCT level (which app you install) or via skip/adaptive, never a global mode.** Simple-by-default: FitNotes ("strips to the absolute essence, zero learning curve", offline, no account), Strong ("no fluff", fastest log), Stronglifts. Rich-by-default: Jefit (NSPI + 1,400 exercises), Fitbod (ML auto-gen). Adaptive not moded: Duolingo = placement test + "Jump Ahead" + per-lesson adaptive difficulty, *not* an advanced mode ([SensAI teardown](https://www.sensai.fit/blog/hevy-vs-strong-2026), [Setgraph alternatives](https://setgraph.app/articles/best-strong-app-alternatives-(2025)), [Duolingo adaptive](https://blog.duolingo.com/keeping-you-at-the-frontier-of-learning-with-adaptive-lessons/)).
- `[validated, UX — strong]` **Modelessness wins; a global mode meets none of the "mode is justified" criteria.** Tesler's Law (complexity is conserved, shift it to the system not a second UI); NN/g "Modes" — a mode pays off only for a *distinct prolonged task with clear persistent state*, else mode-slips/hidden-state errors + poor discoverability + **double maintenance** (two onboarding paths to QA forever). Progressive disclosure / smart defaults / SKIP affordances are the on-pattern alternatives ([NN/g Modes](https://www.nngroup.com/articles/modes/), [Tesler's Law](https://lawsofux.com/articles/2024/teslers-law/), [NN/g Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/)).
- `[risk → directional only, Codex F4]` **Gamification has an S-shaped (cubic) richness→adherence curve — benefit peaks ~mean, turns negative past ~+0.95 SD** (cognitive overload + autonomy-thwarting). KEY MODERATION cutting AGAINST the user's premise: **high digital-self-efficacy (≈experienced) users tolerate richness MORE, not less** (steeper up-slope, milder decline) ([Frontiers Psych 2025, Yang et al](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2025.1671543/full)). **Downgraded to DIRECTIONAL** (n=632 Chinese undergrads, intention-not-behavior, cross-sectional, common-method bias) — supports "keep rewards quiet/ambient, never nag", NOT a numeric product rule.
- `[validated, internal — reuse-first]` **The quick-start win is mostly already-built; extend the existing persisted-preference pattern, don't fork.** Warm-ups are *already* optional + unrewarded (skippable RAMP sheet, no skip penalty); loadouts are *already* editable (Replace); the demo cabinet *already* has a persisted per-feature HIDE toggle (`exercise_demo_hidden_v1` via `WorkoutDefaultsService`); calibration runs once. So "stop pre-filling / stop suggesting" = a few persisted defaults + a fast repeat-last-workout path, in ONE mode.
- **Decision feed (recommend):** **No separate Simple Mode.** Instead, treat experienced-user friction as **adaptive complexity inside one app**: (1) a fast quick-start / repeat-last-workout path + last-session numbers at a glance (autonomy + tap-cost, the real ask); (2) persisted "quiet/skip" preferences (don't re-suggest warm-ups, start from an empty/own loadout) reusing the `WorkoutDefaultsService` pattern; (3) keep gamification **ambient + non-nagging** (no streak/badge spam) so high-DSE users stay in the engagement zone; (4) **keep the identity layer intact** — it's the moat. If a "give me less" signal is ever wanted, it's a *progressive-disclosure setting*, never a product fork. → `/deep-feature` if pursued; pixels to `ironbit-design`. Links [[workout-analysis]].
- **[implemented 2026-06-29]** Shipped as `SimpleModeService` (`simple_mode_enabled_v1`, default OFF) + a Profile→Settings toggle. When ON it strips (render-time, read at screen init): warm-up advisory card + TRY suggestion (`exercise_session`), the **curated first-run** loadout default only (`start_workout._defaultIdsForGroup` — history defaults KEPT), and the progression re-opt-in nudge (`workout_summary`). KEPT: in-set Set-1 auto-copy + the whole RPG layer. **Codex opinion-review (Deep, *needs-attention* → 3 findings, all adopted):** F1 empty-loadout regresses tap-cost → keep history defaults, gate only the generic curated template; F2 umbrella-vs-granular two-sources-of-truth → "Suggested loads" row dims to "Off while Simple Mode is on"; F3 mid-session stale state → reads at screen init (same contract as `_progressionEnabled`), effective next screen. 9 tests (service + warm-up/TRY/auto-copy/curated-skip/history-kept, both states). Surfaced + fixed a latent `_SelectionCheckbox.dispose` crash (lazy ticker created during dispose). Residual visual gap: the Settings toggle row + dimmed-override appearance want an on-device glance (reuses the shipped `_SettingsToggleRow` + standard Opacity dim).
- **[implemented 2026-07-14 — surfaced in onboarding, doctrine held]** Added a **"Workout guidance"** step on `RemindersPrimerPage` that flips the *same* `simple_mode_enabled_v1` key — a reversible **Compact / Extra suggestions** choice, **pre-selected** from `Experience` (`simpleModeDefaultForExperience`: intermediate/advanced → Compact/ON), with a tap-to-reveal preview mock + "change anytime in Settings". The research **converged** on *derive → pre-fill → show → let them nudge* (not a silent default, not a blank forced choice, **never a Simple⇄Full "MODE"**) + **behavior-framed labels** (skill labels read as a competence ranking). **Codex plan-review *needs-attention* → 4 findings folded in:** F1 never persist a first-workout reduction *before the card is shown* (persist on-display + on-flip, **not** at the character-commit; kill-before-display fails **safe → OFF**); F2 the store is the single source of truth (shown == stored); F3 self-reported experience is a weak prior, so the intermediate default is defensible **only** because it's visible + one-tap-reversible + fail-safe (kept per explicit user instruction — de-risked, not overridden); F4 decouple guidance from the notification opt-in's TURN ON / NOT NOW (its own titled card + controls). Labels + the two-tier cut were the user's call; research/Codex shaped the *guardrails*, not the product decision. Spec: [2026-07-14-onboarding-guidance-preference.md](../docs/superpowers/specs/2026-07-14-onboarding-guidance-preference.md).

### Retention instrumentation — measure WEEKLY (non-daily app), instrument early for backward-cohort activation, never trust engagement-time for duration (2026-06-27)
Research for [ADR 0001](../docs/decisions/0001-usage-instrumentation.md) (Firebase Analytics opt-out + Sentry opt-in): how to track retention + the journey points (pre-workout, in-session duration, post-summary). Operational taxonomy + exact definitions live in [statistics/metrics-glossary.md](../statistics/metrics-glossary.md). **Codex evidence-review (Standard+Deep rigor, verdict *needs-attention* → 5 findings, all folded in).**
- `[validated, behavioral — the crux]` **A workout app is NON-DAILY (~3–4×/wk) → optimize WEEKLY retention / active-weeks / streak-establishment; classic D1/D7/D30 reads low and misleads as a *primary* metric** (keep it a secondary guardrail for comparability). N-day = return ON day N (stable); rolling/unbounded = on-or-after (forgiving but ambiguous) ([Amplitude](https://amplitude.com/blog/n-day-retention-for-mobile-games), [GoPractice](https://gopractice.io/product/day-n-retention-rolling-retention-and-the-many-facets-of-the-retention-metric/)). Pick ONE definition; user-local timezone; cohort by first_open AND first_workout_saved (Codex F2).
- `[validated, behavioral] + [risk]` **Activation is the #1 leading indicator; FIND it via backward cohort analysis** (users retained at W4 → the early action they shared) — so instrument the early journey richly NOW or that analysis is impossible later ([PostHog](https://posthog.com/product-engineers/activation-metrics), [Lenny](https://www.lennysnewsletter.com/p/how-to-determine-your-activation)). **RISK (Codex F5 + own discipline):** activation is correlation, not proven cause (survivorship bias) — "≥3 workouts in first 7 days" / `first_workout_saved` are **hypotheses to validate with an experiment**, never launch-justification copy (consistent with the prior "don't use retention as a launch justification" risks in this doc).
- `[validated, technical — load-bearing]` **Firebase `engagement_time_msec` is NOT a valid workout-duration proxy** — foreground-only, and Android can *over*-count background activity (mis-counts either way; Codex F3 verified vs GA4 docs [11109416](https://support.google.com/analytics/answer/11109416), [9191807](https://support.google.com/analytics/answer/9191807)). → log the app's own `actualDurationSeconds` as a `workout_saved` param; QA lock-screen/background/pause/crash/long-rest.
- `[risk, Codex F1 — load-bearing]` **Opt-out analytics skews retention cohorts** — measured population = analytics-enabled users only; a shift in opt-out rate can masquerade as a retention move; Sentry (opt-in) crash cohorts are incomplete; reinstall resets the app-instance id (reads as a new user). → report retention over the analytics-enabled population, segment by platform/app_version/channel, document Sentry as a subset.
- `[risk, Codex F4 — app-specific]` **Abandonment ≠ a missing `workout_saved`** — app-kill/crash/offline-batching/recovery aren't UX abandonment. → instrument terminal/recovery states (`workout_discarded`, `incomplete_workout_found`, `workout_recovered`, `workout_save_failed`) and derive abandonment only after a timeout, segmented by reliability.
- `[validated, competitor]` **Duolingo** models users as Markov states + tracks **7-day streak-establishment rate** as its leading retention indicator (DAU/MAU>50%, 600+ streak experiments, streak-freeze defuses loss-aversion) ([Duolingo](https://blog.duolingo.com/growth-model-duolingo/), [Lenny](https://www.lennysnewsletter.com/p/how-duolingo-reignited-user-growth)) → Ironbit analog = week-1 session count + habit establishment, mapping onto the existing LCK/streak + "Habit 3+/wk×2wk" KPI.
- `[validated, discipline — Codex F5]` Keep ~12–20 parameterized events (event = the *what*, params = context); register Custom Definitions; metrics-glossary = the data dictionary. Numeric claims (7% D7 = top-25%, funnels −25% churn, fitness D1 25–35% / D30 4–12%) are **directional only** (vendor/aggregator-grade, incompatible definitions) — don't set targets off them.
- **Decision feed (recommend):** instrument per the refined taxonomy now (incl. `workout_started` funnel + terminal/recovery states), report WEEKLY-primary + D-N guardrails over the analytics-enabled population, treat activation as a hypothesis to validate once data exists. → feeds the `AnalyticsService` implementation behind ADR 0001. Links [[workout-analysis]].

### Strength index rework — amplify INTRINSIC mastery via legible sections, refuse extrinsic chrome + opaque hero ranking (2026-06-26)
The user called the `StrengthIndexPage` flat momentum list "soulless rows of cards" and wants life/depth/motion/features. Decision target: [strength_index_page.dart](../lib/pages/strength_index_page.dart) + [strength_momentum_row.dart](../lib/widgets/strength_momentum_row.dart). **Codex evidence-review run (Deep, verdict *needs-attention* → 4 findings, all folded in).** Builds on (and is bounded by) [[strength-progression-presentation]] + the body-map-is-the-primary-browser concept + restraint/body-neutral doctrine. This screen is the **secondary completeness net** (body map = primary), so the rework is **restrained, not a maximalist dashboard**.
- `[validated, behavioral — the crux]` **"Life" must amplify the INTRINSIC mastery/competence channel, not bolt on extrinsic chrome.** Overjustification (Deci) — extrinsic rewards erode intrinsic motivation for already-intrinsic activity; mastery/competence + self-referenced progress are the safe, on-doctrine levers ([Yu-kai Chou SDT](https://yukaichou.com/gamification-analysis/self-determination-theory-guide-to-ryan-and-decis-motivation-framework/), [Gamification Hub](https://www.gamificationhub.org/designing-for-intrinsic-motivation-in-gameful-systems/)). **CONTRARY:** a gamified-fitness study found financial reward + social recognition *crowded-IN* intrinsic motivation ([PMC10807424](https://pmc.ncbi.nlm.nih.gov/articles/PMC10807424/)) — but it's weak (Chinese-only n=514, self-report, no boundary conditions, no element-level test) AND its crowd-in levers (money/leaderboards/social likes) are exactly the ones Ironbit's offline/private/body-neutral/no-IAP wedge rejects. → refuse extrinsic chrome regardless; the dismissal is sound on *both* evidence-quality and wedge grounds (Codex C1).
- `[validated, competitor — divergence]` Hevy/Strong buy "life" with **population Strength-Level tiers (Beginner→Elite) + social share** ([Hevy gym-performance](https://www.hevyapp.com/features/gym-performance/)) — **off our wedge**. Their on-doctrine part is the rich per-exercise DETAIL (multiple PR types, e1RM-over-time) which our `ExerciseHistoryPage` already does. So the LIST's job is glanceable self-referenced momentum + navigation; depth lives on tap. Reddit wants simplicity + visible upward trend, no paywall ([setgraph](https://setgraph.app/ai-blog/best-strength-training-app-reddit)).
- `[validated, RPG/taste]` The transferable "living stat system" devices ([KnightCore devlog](https://peacebinflow.itch.io/knightcore-ui-variant/devlog/1478111/-knightcore-ui-building-a-living-rpg-stat-system), [Game UI Database](https://www.gameuidatabase.com/)): **mastery-through-USE** (progression from repeated use, not arbitrary points), layered/grouped (not flat), journey framing, animated evolution — all INTRINSIC + identity-bearing.
- `[risk → resolved, Codex F1 — load-bearing]` **A self-referenced "MASTERY tier" (FAMILIAR→PRACTICED→MASTERED) still smuggles in a rank** — a barely-trained lift labelled "low" reads as judgment + completion pressure, contradicting restraint/body-neutral; the device is unvalidated for fitness. → express mastery-through-use as **neutral history signals** ("trained 14×", last-trained, recent consistency), **no judgmental tier ladder**; if tiers are ever tested, non-judgmental copy + explicit guardrails.
- `[risk → resolved, Codex F2 — load-bearing]` **An opaque "hero-lift" hierarchy breaks the completeness role** — promoting most-trained/recent/PR lifts buries stale/rebuilding/niche/user-important ones (the demotion trap the all-lifts net exists to avoid). → use **user-legible SECTIONS that segment without hiding** (e.g. NEW BESTS · RECENTLY TRAINED · REBUILDING/needs-a-look) + an optional **user-pinned** lift; **every lift always reachable**, no silent demotion. (Supersedes the older "a few hero cards" phrasing in [[strength-progression-presentation]] for this surface.)
- `[risk → resolved, Codex F3]` **Motion budget (a restrained secondary list):** entrance stagger ONCE on load (transform/opacity, 200–500ms, easeOutCubic, not on return-nav, not scroll-tied — stagger-on-scroll janks); **flourish ONLY on a genuine real PR** (the one focal celebratory beat); sparkline draw-on only for a pinned/fresh card; **no list-wide count-up**; reduced-motion → instant. Combining all micro-anims on every row = noise that drowns NEW BEST.
- `[risk → resolved, Codex F4]` **Make signed delta + est-max visually DOMINANT** (the magnitude truth); keep the sparkline **subordinate/shape-only** (per-row auto-scale misleads cross-row steepness scanning) — and not necessarily on every row. Plain-language verdict still leads.
- `[validated, body-neutral]` Plateau (HOLDING/REBUILDING) stays kind; the constructive frame = "normal; here's what's still moving" using a **truthful** secondary signal (consistency/sessions), **not** manufactured volume-progress (avoid nudging volume-chasing). Celebrate small wins (real PRs) ([Svetness "track without obsessing"](https://www.svetness.com/blogs/track-fitness-progress-without-obsessing)).
- **Decision feed (recommend):** restrained rework = (1) neutral mastery-through-use signal per lift; (2) legible completeness-preserving sections + optional pin; (3) magnitude-dominant rows, sparkline subordinate; (4) tight motion budget (entrance-once + real-PR flourish); (5) constructive kind plateau + inviting empty/first-PR states; (6) light features (sort recency/momentum, body-neutral filter chips, search). → `/deep-feature` + pixels to `ironbit-design`; prototype + usability-check the failure cases (barely-trained, stale, many lifts, no PRs, flat-e1RM-rising-volume). Links [[strength-progression-presentation]].
- **[implemented 2026-06-26]** Shipped on `StrengthIndexPage`: `StrengthRosterRow` (icon + big est-max + verdict GLYPH ★/▲/–/▼ + signed delta, amber flourish only on a real new best, down-glyph muted never red) + `LiftIcon`/`data/lift_icons.dart` (name-keyword → 13 movement-pattern pixel icons in `assets/icons/lift-icons/`, user-authored, recoloured `BlendMode.srcIn`, integer-scale crisp) + completeness-preserving momentum sections + filter chips + single `EST. MAX · <unit>` hint + reduced-motion-safe entrance stagger. Dossier keeps the denser `StrengthMomentumRow`. Full analyze clean; 7 mapping + 5 row (incl. golden) + 7 page (incl. golden) tests; both goldens rendered + viewed.
- **[implemented 2026-06-26 — pinned cards]** `PinnedLiftsService` (key `pinned_lift_ids_v1`, **3 max, block-and-tell** — no auto-evict) + `PinnedLiftCard` (the one rich surface: cyan, verdict word + delta + "trained N×" + sparkline w/ amber PR marker) at the **top of the ALL view only**, pulled out of its section. Pin via **long-press** (+ a custom Semantics action for a11y + a persistent "PINNED N/3" status line for discoverability); unpin via the card pin. **Codex plan-review (3 findings, all adopted):** F1 stale "ghost pins" could deadlock the cap with no unpin UI → `pruneTo` self-heals on load; F2 long-press-only is inaccessible/hidden → custom Semantics action + non-vanishing status line; F3 filter-independent cards make chip views lie → pins are **ALL-view-only**. 7 service + 3 card (incl. golden) + 3 page-pin tests; goldens viewed.

### Pre-launch app audit — a per-unit fan-out workflow beats one generic prompt, IF diversity + grounding are engineered (2026-06-26)
Should a generic "Audit the app comprehensively before launch" prompt be replaced by a dedicated front-end audit *workflow* that gives each page/section its own scoped pass, run autonomously and scaled to app size? The generic prompt empirically missed UI/UX slop, UX bugs, visual-hierarchy, and data-calc errors. **Codex evidence-review run (prompt-only, verdict *needs-attention* → 4 findings, all folded in — flipped "yes" to "yes, conditional on 2 prerequisites").** Decision target: a new audit skill/command (the workflow itself), not an app surface.
- `[validated, methodology — load-bearing]` **Decomposition + scoping beats one broad pass.** Three converging lines: (a) heuristic eval — one evaluator finds ~35% of problems, 3–5 independent evaluators ~75% ([NN/g](https://www.nngroup.com/articles/how-to-conduct-a-heuristic-evaluation/theory-heuristic-evaluations/), [CHI'92](https://course.ccs.neu.edu/is4300sp13/ssl/articles/p373-nielsen.pdf)); (b) LLM "lost in the middle" — 30%+ accuracy drop when target info sits mid-context, U-shaped RoPE attention decay ([Liu et al via explainer](https://www.morphllm.com/lost-in-the-middle-llm)); (c) LLM code review — tightly-scoped per-concern agents told what to look for AND ignore beat one broad multi-concern prompt; structured pass/fail specs converged in ~1.7 cycles vs 3.4 ad-hoc ([arxiv empirical](https://arxiv.org/html/2505.16339v1), [Cloudflare AI review at scale](https://blog.cloudflare.com/ai-code-review/)).
- `[risk, Codex F1 — load-bearing]` **The 35%→75% gain is from INDEPENDENT HUMANS, not repeated runs of the same model.** Fan-out alone may preserve the same model priors / vision limits / prompt-induced blind spots → a comprehensive-LOOKING process that re-misses the same defects. → **engineer diversity, not just parallelism**: different rubrics/personas per unit, ideally a second model on the vision pass, and a labeled defect-recall benchmark of *known historical misses* to prove the new workflow actually beats the old prompt before adopting it as doctrine.
- `[risk, Codex F2 — load-bearing, app-specific]` **The screenshot grounding channel is a PREREQUISITE deliverable, not an assumption.** Flutter web preview can't screenshot reliably ([[memory: env_flutter_web_preview]]); the existing `uxaudit` plugin pipeline assumes a live browser/DOM and won't drop in. → before any per-section checklist, prove a harness can capture every route/section at representative Android sizes with real fonts/assets/state, traceable screenshot→route→widget (golden-render→read PNG, or emulator + `flutter screenshot`).
- `[risk, Codex F3]` **False-positive control must be designed, not hand-waved** — heuristic eval runs ~50% false positives early ([MeasuringU/HE-vs-CW](https://measuringu.com/he-cw/)). A "reconciler" is not enough: needs explicit severity gates + accept/reject rules calibrated against the app's design system + a labeled sample, or audit fatigue kills the workflow. (The shipped `uxaudit` reconciler is the right shape — suppress catalog FAILs the design system justifies.)
- `[validated, decomposition — Codex F4]` **"Front-end audit" is not one thing — split into 4 tracks, with cross-track fixtures so defects don't fall between them:** (1) **presentation/heuristic** per section (token coherence, visual hierarchy, Nielsen, slop) grounded in a screenshot/golden; (2) **interaction/journey** walkthrough (onboarding→first workout→summary) — catches flow + cross-page issues per-screen passes miss, and task-based heuristic *walkthroughs* are more valid / fewer false positives than pure heuristic eval ([tandfonline](https://www.tandfonline.com/doi/abs/10.1207/s15327590ijhc0903_2)); (3) **domain correctness** (data calcs / e1RM / volume / XP) grounded in **code + tests, not screenshots** — a render audit cannot see a wrong formula; (4) **state/integration consistency** (persistence, resume, stale state, summary screens). The user's "data-calc misses" are track 3, not a visual audit at all — the key reframe.
- **Decision feed (recommend):** **Yes, build it** as a multi-agent skill mirroring the `uxaudit` spine (inventory → per-unit scoped audit w/ look-for+ignore checklist → grounded evidence → severity-rated findings → reconcile → synthesize/dedup → ranked fixes), fan-out one subagent per screen/section/journey so effort = app surface area (the user's "scale to app size" lever). **Gate adoption on the 2 prerequisites** (the Android grounding harness + a defect-recall benchmark vs the old prompt). → `/deep-feature` to build the workflow; pilot on ONE page first. Links [[workout-analysis]].

### Onboarding program preview — INFO-first progressive disclosure; DEFER customization (2026-06-26)
The onboarding program-selection gate now lets the *selected* card expand a read-only exercise preview; adjustment was **deferred** to the post-onboarding Program Detail page. Decision target: [program_selection_page.dart](../lib/pages/onboarding/program_selection_page.dart) + the shared [program_day_card.dart](../lib/widgets/program_day_card.dart). **Codex evidence-review run (verdict *needs-attention* → 2 findings, both adopted).** Builds on [[profile-hero-card]] discoverability + the onboarding-recap friction work.
- `[validated, frictionless/behavioral]` **Progressive disclosure is the right pattern** — collapsed card → tap to expand INFO → adjustment a level deeper ([UXPin](https://www.uxpin.com/studio/blog/what-is-progressive-disclosure/), [IxDF](https://ixdf.org/literature/topics/progressive-disclosure)). Showing program contents also meets the "see what I'll do / it's not generic" expectation (competitor norm: Muscle Booster/Fitbod/Caliber specify exercises/sets/reps).
- `[validated, contrary — load-bearing]` **Deep customization DURING onboarding risks choice paralysis** (Schwartz paradox of choice; >3-4 simultaneous choices drop completion; [thisisglance](https://thisisglance.com/blog/choice-paralysis-when-too-many-options-kill-your-apps-success), [UserTesting](https://www.usertesting.com/blog/how-to-use-the-paradox-of-choice-in-ux-design)) → **DEFAULT info-only; defer customization**. Validates the user's "mostly info, don't show adjust by default."
- `[validated, architecture — Codex F1]` **Don't mutate persistent state from a non-committed onboarding action.** Writing swaps to `program_exercise_swaps_v1` before the program is committed = a stale-state bug (swap A → abandon → A silently customized later). → onboarding preview is **read-only**; adjustment lives in Program Detail post-commit. (If inline adjust is ever wanted, it must be a *draft* committed only at program-commit, discarded on switch/manual/exit.)
- `[validated, IA — Codex F2]` **Separate "select" from "see details"** — don't overload a second tap on the card. The *selected* card gains an explicit **`VIEW EXERCISES`** affordance (discoverable, no mis-tap ambiguity at the commit gate). Collapses on program switch.
- `[validated, engineering]` **Reuse, don't duplicate:** the per-day card is ONE shared `ProgramDayCard` (read-only when `onSwapRequested` is null; swap-enabled on the detail page) — avoids the two-copies-drift trap.
- **Decision feed (shipped):** read-only `VIEW EXERCISES` expand on the selected onboarding card (shared `ProgramDayCard`, AnimatedSize reduced-motion-branched, lazy name load, a "customize anytime in Programs" pointer); adjustment deferred. Links [[profile-hero-card]].

### Body map at the START/CONFIRM (selected muscles) — cheap upgrade of a dead confirm; ambient preview evidence-favored over a blocking one (2026-06-26)
Should a body diagram light the SELECTED muscles at the exercise-selection confirm (when TRAIN/Continue commits)? Decision target: `showStartWorkoutConfirmDialog` ([start_workout.dart:73](../lib/pages/Workout%20session/start_workout.dart#L73)) — the single chokepoint both entry paths hit ([:231](../lib/pages/Workout%20session/start_workout.dart#L231)) — and a presentational reuse of the `_BodyFrame` paint. **Codex evidence-review run (verdict *needs-attention* → 3 findings; F1 partial-accepted, F2/F3 accepted).** Builds on [[workout-analysis]] + the body-map-on-summary entry below + body-neutral mandate.
- `[validated, placement — load-bearing]` **The start/confirm is a FORWARD-LOOKING PLANNING moment, which neutralizes BOTH hazards that made the summary placement risky:** the planning-framed competitor precedent FITS here (Fitbod surfaces muscle-targeting in its planning/recommendation), and the mostly-dark single-session body reads as **intent/focus** ("today's a chest day"), NOT the peak-end "incomplete" hazard it was at the remembered *endpoint*. This is the strongest of the three placements (start > history > summary).
- `[risk, precedent thin/NOVEL — Codex F1]` **No clear "body diagram on the confirm step" convention exists** (Hevy's is post-hoc stats; Fitbod's is in planning, not a confirm gate) → justify on INTERNAL value (a content-less "Begin the live session now?" gets a job at zero nav cost), not "everyone does it". And the **strong dissent** (NN/g: avoid confirm dialogs for FREQUENT REVERSIBLE actions → cry-wolf) tilts the evidence toward an **ambient preview on the NON-BLOCKING selection surface** (lights as you pick) over enriching the blocking confirm. Counter (why confirm still viable): the gate **already exists** (live-session state consequence) and the user asked for it → present BOTH, ambient evidence-favored, the choice is the user's intent call.
- `[risk, evidence-discipline — Codex F2]` Behavioral upside is **blog-tier, graded LOW** ("pre-session review → confidence/less decision-fatigue") → claim ONLY "cheaply upgrades a dead confirm + planning fit"; **no** confidence/preparedness/habit/retention claims in copy/PRD without a prototype test.
- `[risk, a11y + empty-state — Codex F3]` A color-coded body on a high-frequency surface is load-bearing, not "internal": needs **non-color text targets** (e.g. "TARGETS: CHEST · BACK · TRICEPS"), screen-reader semantics, and defined behavior for **no-selection / single-exercise sparse / unknown-mapping**. Binary "targeted" highlight only — DROP the weekly MEV/MAV ramp + zone words (meaningless pre-session).
- **Decision feed (recommend):** worth doing as a **cheap, low-risk upgrade of the existing confirm** (binary intent paint, reuse `_BodyFrame`, presentational, reduced-motion static) — BUT surface the **ambient selection-surface preview** as the evidence-favored alternative for the user to choose between. Frame value as utility, not retention. → Stage 3 opinion. Links [[workout-analysis]].

### Body map on the WORKOUT SUMMARY (today's session) — a prototype-gated MAYBE, not a ship (2026-06-26)
Should the coverage body map (today in HISTORY, showing rolling-weekly sets vs MEV/MAV zones) ALSO appear on the post-workout summary, lit by TODAY's session? Decision target: [workout_summary.dart](../lib/pages/Workout%20session/workout_summary.dart) + a single-session variant of [muscle_body_map.dart](../lib/widgets/muscle_body_map.dart). **Codex evidence-review run (verdict *needs-attention* → 4 findings, all folded in — it flipped the verdict from a confident yes to conditional).** Builds on the peak-end/post-workout-hierarchy/reserved-celebration findings below + [[workout-analysis]] + body-neutral mandate.
- `[validated, competitor — app-as-primary-source]` **A per-session worked-muscle visual is table-stakes** — Fitbod shows a worked-muscle heat map (after finishing AND in a Recovery/Body tab), Hevy highlights trained muscles in blue per workout, Strong shows muscle-group distribution ([Fitbod](https://fitbod.zendesk.com/hc/en-us/articles/360006269014-Muscle-Recovery), [Hevy](https://www.hevyapp.com/features/muscle-group-workout-chart/)). BUT (Codex F1, load-bearing) **precedent ≠ finish-screen placement**: Fitbod's is *recovery-framed* (forward-looking "what to train next"), which supports a persistent/planning surface, not a single-peak trophy. The evidence shows the visual should EXIST (✓ it does, in history), not that it belongs in the finish arc.
- `[risk, body-neutral + competence — Codex F2, load-bearing]` **A today-only body lights only a small region** (worst for beginner/short/single-exercise/focused sessions) → the salient visual is the DARK untrained body, which copy can't fully neutralize, landing on the peak-end remembered endpoint. Reads as "incomplete" after a good session. → if built, **conditional/opt-in** (only multi-muscle sessions; textual breakdown stays default for focused/low-volume), single-session accomplishment framing ("MUSCLES TRAINED", never "missed"), and **drop the weekly zone words (RESTED/LIGHT/ON TRACK/PLENTY) + MEV/MAV bars** — meaningless/scold-y for one session.
- `[risk, evidence-discipline — Codex F3]` **The retention case exceeds the evidence** (no quantitative data; the only "+40%" stat is an unverifiable cite, rejected). On the already-dense single-peak finish arc, the better-grounded risk is **novelty decay + reward dilution**, not proven lift. Downgrade the claim to a hypothesis: "may improve clarity of *what* was trained." Don't use retention as a launch justification.
- `[risk, a11y + doctrine — Codex F4]` A color/intensity-coded body shown after EVERY workout conflicts with the **reserved-celebration** doctrine (goes stale while stealing attention from the peak). Acceptance criteria before any build: non-color encoding, screen-reader equivalent, small-screen fallback, reduced-motion static, freshness rule (compact/collapsed default).
- **Decision feed (recommend):** **don't ship blind.** Separate "the map should exist" (done, in history) from "the map should be on the finish screen" (unproven). If green-lit, prototype 3 cases — focused-isolation / short-beginner / multi-muscle — with history placement as the **control**, testing remembered clarity WITHOUT denting completion satisfaction. **Cheaper adjacent win:** lightly upgrade the existing textual BREAKDOWN (e.g. muscle-group chips on its rows) for most of the clarity benefit without the dark-body hazard. → `/deep-feature` only on a green-lit prototype. Links [[workout-analysis]].

### Onboarding "build" panel — present it as BIT's REVERSIBLE recommendation, not an owned/assigned identity (2026-06-26)
How to PRESENT the merged Name-screen plan panel in a gaming aesthetic (not a gym spec table). **Codex evidence-review run (verdict *needs-attention* → 3 findings, all folded in).** Builds on the recap decision below + [[profile-hero-card]] hierarchy + the BIT companion doctrine + body-neutral mandate.
- `[validated, gaming-psych]` **Build/identity summaries land as identity via psychological OWNERSHIP, which the evidence ties to EFFORT + active CHOICE** (IKEA effect / effort-justification [IxDF](https://ixdf.org/literature/topics/ikea-effect); Octalysis Core Drive 4 Ownership [Yu-kai Chou](https://yukaichou.com/advanced-gamification/the-avatar-gamification-design-technique/); customized > pre-generated avatars for immersion [Badge Unlock](https://www.badgeunlock.com/2025/01/29/the-psychology-behind-character-customisation-understanding-player-identity-and-engagement/)).
- `[risk, load-bearing — Codex F1]` **Our class + program are ALGORITHMICALLY DERIVED, not hand-picked → the ownership effect does NOT transfer for free.** Causal framing ("your answers → this build") is an *inference*, not evidence. Worse: customization can REDUCE self-congruity ([ScienceDirect, abstract-only](https://www.sciencedirect.com/science/article/abs/pii/S0736585324000029)), so a derived class that clashes with the user's ideal self, hard-labelled "YOUR BUILD" at the irreversible Name commit, reads as the app *assigning an identity* — autonomy-undermining (SDT). → **Downgrade language from owned identity to REVERSIBLE RECOMMENDATION** ("Recommended starter build" / "BIT's readout"), show the causal inputs, give a clear path back to change answers before commit, treat strong "your build" copy as an unvalidated hypothesis.
- `[validated, UI — Codex F2]` **Legibility is the gating constraint; ship the smallest legible panel before any theatre.** Diegetic/cinematic UI clutters and harms comprehension at the worst moment (the irreversible commit) — the [minimal-HUD paradox](https://medium.com/@salamatizm/the-minimal-hud-paradox-how-dreams-of-diegetic-game-interfaces-often-lead-to-cluttered-nightmares-e9cf7fae9d73); Dead Space RIG / GoldenEye watch are diegetic exemplars but were heavily playtested for legibility. → plain GROUPED sections (class · program · schedule · causal source), **reduced-motion + screen-reader acceptance criteria before design handoff**, validate comprehension before adding an assembling/reveal beat. Gaming feel comes from FRAMING + the existing pixel-arcade language + BIT's in-world voice, **not** a stat grid.
- `[risk, body-neutral — Codex F3]` **"Loadout / build / min-max / character-sheet" framing pulls toward optimization/ranking** — off-doctrine, and riskier because private bodyweight/sex feed the recommendation. → hard constraints: **no scores, ranks, stat grids, power bars, body labels, weight emphasis, or comparative class language**; bodyweight/sex stay private inputs; output is a *starting plan that adapts*, not an optimized identity. The "character sheet/loadout" metaphor is the TRAP; "BIT's briefing / starter readout" is the safer diegetic frame.
- `[validated, game-UI]` Structural convention = grouped character-sheet/loadout, core visible by default, theme reflecting the character ([Game UI Database](https://www.gameuidatabase.com/) Loadout/Character-Intro). Reuse [[profile-hero-card]]: hierarchy from zoning + type-scale + whitespace FIRST, avoid "everything is a chip".
- **Decision feed (recommend):** a **BIT-presented "starter readout"** on the Name screen — BIT (the existing diegetic companion) hands the user a forward-looking recommendation derived from *their* answers: grouped plain rows (class as identity flavor · program · training days · a one-line "drawn from: goal + experience"), reversible (back to edit answers), legibility-first (motion optional, a11y-gated), zero scoring/min-max, weight private. Identity FLAVOR (BIT's voice + arcade skin) separated from the ALGORITHMIC recommendation it's dressing. → pixels to `ironbit-design`; flow change via `/deep-feature`. Links [[profile-hero-card]].

### Onboarding recap — DON'T add a standalone screen; merge "your build" INTO the Name screen (2026-06-26)
The user wants a "technical" validation/recap screen after **program selection** summarizing the choices so far. Decision target: the onboarding flow ([onboarding_flow_page.dart](../lib/pages/onboarding/onboarding_flow_page.dart), [program_selection_page.dart](../lib/pages/onboarding/program_selection_page.dart), [name_screen.dart](../lib/pages/onboarding/name_screen.dart), [start_gate_screen.dart](../lib/pages/onboarding/start_gate_screen.dart)). **Codex evidence-review run (prompt-only, verdict *needs-attention* → 3 findings, all folded in).** Builds on [[research-6-calibration]] (First-Win/commitment) and the body-neutral two-gate consent.
- `[validated, architecture — load-bearing]` **At program selection the EARLIER answers are already locked** (post-class-reveal `pushReplacement` + `PopScope(canPop:false)` on program selection). So a recap placed *there* surfaces goal/focus/experience/frequency/obstacle/class at the exact point a mistake is **discoverable but not fixable** → a read-only recap is a **failure amplifier**, not validation (Codex F1). Only **program + weekday schedule** remain editable; Name has a back button to program selection.
- `[validated, UX dissent — NN/g]` **A confirm/recap step is justified only for SIGNIFICANT + IRREVERSIBLE actions; for reversible ones prefer undo** ([NN/g confirmation dialogs](https://www.nngroup.com/articles/confirmation-dialog/)). Naming is exactly that irreversible commit (creates character + starts program + anchors schedule), so a *pre-name* legibility moment is on-pattern — but it must offer recovery (edit-back) or only recap still-editable fields, never read-only over locked ones.
- `[assumption, blog-grade — contested]` A summary framed as an assembled plan can lift completion ~20-30% via endowed-progress/commitment ([userpilot progress-bar psych](https://userpilot.com/blog/progress-bar-psychology/), [saasfactor activation](https://www.saasfactor.co/blogs/saas-user-activation-proven-onboarding-strategies-to-increase-retention-and-mrr)), BUT each extra utilitarian screen costs ~10-20% ([revenuecat](https://www.revenuecat.com/blog/growth/why-your-onboarding-experience-might-be-too-short/), [thisisglance](https://thisisglance.com/learning-centre/how-can-i-check-if-my-onboarding-flow-is-too-long)). Both figures are **blog-grade, no fitness/RPG or peer-reviewed backing, no Ironbit data** → the uplift doesn't clearly outweigh the screen-cost (Codex F2). The RPG "Confirm Character" convention ([Game UI Database](https://www.gameuidatabase.com/) catalogs it as a dedicated screen type) supports the *genre fit* but isn't proof it pays here.
- `[validated, design]` **A standalone recap risks cannibalizing the START GATE** — the post-name cinematic identity reveal (name/class/RECRUIT/LV.1/XP/quest). A separate pre-name reveal spends a "behold your build" beat twice, weakening the one emotional peak while paying a screen's friction (Codex F3). Keep Start Gate the sole full reveal.
- `[validated, body-neutral]` Recap goal/focus/program/schedule/class; **keep weight/sex private** (two-gate consent — used silently for calibration, never headlined as an identity stat).
- **Decision feed (recommend):** **No new standalone screen.** Merge a compact **"YOUR BUILD"** panel into the **Name screen** (goal · focus · experience/frequency · class · program · training days) — plan legibility right before the irreversible naming commit, at zero extra screen-cost — and preserve Start Gate as the only cinematic reveal. Add **edit-back affordances only where the flow supports edits** (program + schedule); do not recap locked fields as if fixable. If a true full validation is wanted, the *prerequisite* is relaxing the point-of-no-return so earlier answers become editable — a bigger change to scope deliberately. → `/deep-feature` (touches persisted flow + the identity payoff). Links [[research-6-calibration]].

### Strength surface = the BODY (tap a muscle → its lifts' momentum), not a list+search (2026-06-26)
The user rejected the flat strength index ("soulless rows of cards with a search bar") → reworked into Concept #1: the body map IS the strength browser. Decision target: `muscle_body_map.dart` dossier + `StrengthTrendService` + `body_map_regions.strengthByMuscle`. **Codex design-review run (verdict *needs-attention* → 3 findings, all integrated).** Builds on [[strength-progression-presentation]] (the prior strength-UX brief) + the body-neutral mandate.
- `[validated, soul]` **A contextual/spatial browser beats a flat list for soul, but loses what the grouping can't reach.** Tapping your own pixel body → that muscle's lifts + momentum fuses identity+competence and structurally can't become "cards + search." BUT (Codex F1) a body-only browser drops **un-mappable** lifts (bodyweight — no e1RM), **multi-home** lifts (bench → chest+triceps), and the "show me ALL my lifts" workflow → keep a **quiet flat completeness net** ("ALL LIFTS" route, every weighted lift once, filed under its **primary** muscle so it appears once, not cluttering synergists). Folded to [[ironbit-discoverability]].
- `[validated, body-neutral — load-bearing]` **Body-neutral ≠ hiding direction.** Relabeling a real estimated-strength drop as "HOLDING" is *dishonest* and contradicts a visible negative delta (Codex F3) → use a **named, non-punitive down state ("REBUILDING")**, never red/alarm, never suppressed. Honest *tone*, truthful *direction*. Extends the doctrine "absence of a reward is just absence" → "a decline is shown kindly, never hidden." Momentum band ±2.5% = HOLDING; `newBest`/`rising`/`rebuilding`/`fresh`.
- `[validated, IA]` **One surface, two clearly-scoped reads — don't blend (Codex F2).** The dossier mixes *this-week coverage* (header verdict) + *all-time strength* (the roster); label each scope explicitly (header "· THIS WEEK", roster = STRENGTH) so weekly-set dose and lifetime estimated-max aren't read as one number. Body shading stays **singular = coverage** (no strength-lens — one meaning per brightness channel).
- `[validated, honesty]` **The estimate is "est. max", never "best"/"record"** (a projection, not a performed lift); reserve PR/record for completed sets. Same Epley the detail chart plots (one source). Plain verdict, no "e1RM" (the jargon trap, caught twice — [[ironbit-jargon-vs-verdict]]).
- **Decision feed (shipped):** body-map muscle tap → strength dossier; secondary ALL LIFTS net; honest body-neutral momentum; coverage shading unchanged. Standalone searchable strength page demoted from primary to the completeness net. Links [[strength-progression-presentation]], [[workout-analysis]].

### Strength-progression presentation — SELF-REFERENCED progress + honest estimate-vs-record split, restraint over ranks (2026-06-26)
Reworking the strength surface (`StrengthIndexPage`) after the user judged it jargon-laden ("e1RM" unreadable — the *second* time, repeating the MEV/MAV miss) and "lame". Decision: how to present per-exercise strength progression engagingly + plainly. **Codex evidence-review run (prompt-only "review prose, no diff", verdict *needs-attention* → 4 findings, all agreed + integrated).** Builds on [[workout-analysis]], [[research-1-strength-normalization]], the ironbit-design "Domain jargon vs the plain verdict" learning, and the body-neutral mandate.
- `[validated, honesty — load-bearing]` **Distinguish a *completed record* from an *estimate*; never label e1RM "BEST".** e1RM is a calculated projection, not a performed lift ([Strength Journeys](https://www.strengthjourneys.xyz/articles/what-is-an-e1rm-estimated-one-rep-max)); competitors reserve "PR/record/best" for *actually completed* sets (Strong all-time best, Hevy PRs). Calling the estimate "BEST" makes a beginner think they lifted it (Codex F1, trust + training-safety). → label the estimate **"estimated max / est. top lift / projected"**; reserve **PR/record** for the real heaviest completed set (weight×reps). Two honest numbers, clearly split. Same family as [[advisory-derived-numbers]] (validate a shown number against its anchor).
- `[validated, body-neutral — load-bearing]` **Use SELF-referenced progress, not population ranks.** Absolute strength-standard tiers (Untrained/Novice/…) are bodyweight-class based, so an absolute-only tier (our body-neutral no-bodyweight path) **mis-tiers** a light vs heavy lifter, and a rank label is a **judgment on the person** (Codex F2) — the exact guilt/comparison the mandate forbids. Our wedge is *earned, private, your-own-journey* → progress vs **your own history** ("+5 vs last time", "+18 lb above your start", "best month yet"), no population tier, no bodyweight, no leaderboard (we're offline/solo — natural fit). Population **ranks stay a future opt-in** (needs bodyweight + validation), not the default.
- `[validated, dissent]` **Restraint over more game mechanics.** "Number-go-up"/PR dopamine is real ([game-design](https://www.strayspark.studio/blog/rpg-stat-systems-character-progression-design)), but gamification **over-justifies** (extrinsic crowds out intrinsic; it's scaffolding), scares beginners with competition, and **plateau/tier-stall demotivates** ([APA](https://blog.apaonline.org/2023/02/06/reflections-on-the-gamification-of-fitness/), [Wiley Consumer Psych 2026](https://myscp.onlinelibrary.wiley.com/doi/full/10.1002/arcp.70004)). No user evidence/telemetry pre-launch (Codex F3). → ship the **restrained, evidence-backed core** (plain "estimated max" + big number + visible **delta** + **beat-last-time** + neutral states like **"HOLDING"** never "STALLED"); celebrate **up** (real PRs), **silent on down** (no regression alarm). Rank/trophy-wall = prototype-behind-user-judgment, not default.
- `[validated, data-viz]` **Big number + signed-text delta beats a lone tiny sparkline.** Glanceable metric rows pair a large value + a **delta indicator** (▲ +5 lb / +6% vs last), optionally a spark ([Smashing real-time dashboards](https://www.smashingmagazine.com/2025/09/ux-strategies-real-time-dashboards/), [CDC sparkline](https://www.cdc.gov/cove/data-visualization-types/sparkline.html)); a standalone micro-sparkline (the current row) is the weakest pattern. **A11y (Codex F4):** every delta carries **signed text** (not arrow/color alone), color redundant, sparkline + badge have Semantics, the "estimated max" definition reachable by screen reader.
- **Decision feed:** rework = verdict-led, self-referenced **momentum** rows (state word + signed delta + big estimated-max, beat-last-time), real-PR celebration as the accent, **hero-lift hierarchy** (a few feature cards + compact tail) to kill the flat-list lameness; **defer** population ranks + trophy wall to opt-in prototypes. Plain language throughout (no "e1RM"; disclose the definition on tap). → `/deep-feature` implement; pixels via `ironbit-design`. Links [[workout-analysis]], [[research-1-strength-normalization]].

### First-class per-exercise e1RM — PROMOTE/CONNECT existing surfaces, don't build a dashboard (2026-06-26)
The audit's parked item #2 (e1RM trend per exercise, the one row every competitor beats us on). Decision: which surface makes the **existing** buried trend first-class. Key context: the e1RM chart already exists ([exercise_history_page.dart](../lib/pages/exercise_history_page.dart) — per-session Epley-e1RM `fl_chart` line + summary + set log); it's reachable but **2 hops deep** (Exercises library → `ExerciseDetailPage` → button → history) and the Logs hub entry ("Load Trends") is **capped at 3**. Decision target: `WorkoutLogsPage` Load-Trends section + `WorkoutLibraryPage` wiring. **Codex evidence-review did not engage this run** (returned a contentless `approve` on the empty branch diff — the prompt-only path that worked twice earlier this session punted here); a **manual adversarial pass** against a 7-item challenge list stands in (folded below). Builds on [[workout-analysis]], [[research-1-strength-normalization]] (Epley + relative-strength opt-in), [[research-4-combat-stats]] (directional-not-dosimetry / overclaim trap).
- `[validated, competitor]` **The dominant convention is a per-exercise DETAIL page (History/Charts/Records) reached via (i) a searchable exercise LIBRARY + (ii) a stats-hub's "most-logged exercises" list — NOT a bespoke "strength" destination.** Strong: tap exercise → About/History/**Charts** (1RM progression)/**Records** ([Strong](https://www.strong.app/)). Hevy: Profile→**Statistics** hub ("Main exercises" = most-logged, 30d/3m/yr) **and** Profile→**Exercises** library (search/filter) → detail w/ projected 1RM + Set Records chart + History + time-range ([Hevy stats](https://help.hevyapp.com/hc/en-us/articles/35702030346903-Hevy-Statistics-Explained-Track-Your-Training-Progress-and-Muscle-Growth), [Hevy exercise perf](https://www.hevyapp.com/features/exercise-performance/)). **Ironbit already has both analogues** (Logs = stats hub, "Load Trends top-3" = Hevy's "Main exercises", `WorkoutLibraryPage` = the library) → first-class = **promote + shorten**, not a new surface.
- `[validated, dissent — load-bearing]` **The dominant community complaint is NOT "progression is buried" — it's bloat: "too much stuff, too many taps, simplicity beats feature count."** Progress charts are highly motivating ("apps without decent charts lose users as they get more experienced") but new destinations are punished ([setgraph reddit roundup](https://setgraph.app/ai-blog/workout-tracker-app-reddit), [Cora](https://www.corahealth.app/blog/best-workout-tracker-reddit)). → add **reach** to the existing charts (browsable index + shorten the hop), **not** chrome. Strong caution **against Option C** (dedicated dashboard).
- `[risk, off-doctrine]` **Fitbod's "Strength Score" (0–100 ML aggregate) is the one dedicated-strength-destination precedent — and it's the wrong model for us.** It's an ML/cloud normalized metric ([Fitbod strength](https://fitbod.me/blog/estimated-strength/)) fitting Fitbod's *prescriptive auto-generating* philosophy, not a logger that "shows you the data" (Strong/Hevy/us). A derived score = the **VIT/recovery%-style overclaim trap** [[research-4-combat-stats]] + off the offline/body-neutral wedge. If C is ever built it must aggregate **real per-exercise trends/PRs**, never invent a score.
- `[validated, domain]` **Present the e1RM TREND, labelled an estimate — the relative change is the honest signal, not the absolute.** Epley is ~5–10% off at 2–10 reps, ~3–7% at 3–6, and **degrades >10 reps** ([Arvo formulas](https://arvo.guru/resources/one-rep-max-formulas), [OpenSIUC Brzycki/Epley validation](https://opensiuc.lib.siu.edu/cgi/viewcontent.cgi?article=1744&context=gs_rp)); 5–7% error ≈ 2–4 lb (trivial for trend reading). Our chart already labels "estimated 1RM" + caps ~12 reps. Optional honest alternative for purists: a **heaviest-actual-weight** view (no estimation). Competence/visible-deltas is THE hook (reused [[research-1-strength-normalization]]); PR markers on the line = safe-PR celebration (already settled).
- **Decision feed (recommend):** **A+B hybrid, reuse-first** — expand Logs "Load Trends" from top-3 into a browsable **strength index** (all logged lifts, sorted recency/frequency, search) → straight to `ExerciseHistoryPage`, and **shorten the library hop** (a Progress/History shortcut on/near `ExerciseDetailPage`). Lowest-effort, highest-fidelity-to-convention, no new destination, anti-bloat. **Defer C** (dedicated dashboard) unless a later identity/competence push wants it — and even then as an aggregate of real trends, never a Fitbod-style score. **Caveats:** competitor structure is vendor-doc not hands-on (offline env); exact effort depends on a code audit of the library→detail→history wiring. → `/deep-feature` Stage 1 audit confirms the wiring before scoping.

### Body-map time window — AVERAGE weekly sets over periodization-length windows, not totals (2026-06-26)
Feeds the body-map time-range/averaging-window selector (the parked audit item #3, the depth half of [[workout-analysis]]). Decision target: [muscle_body_map.dart](../lib/widgets/muscle_body_map.dart) + `MuscleCoverageService` window param + `WorkoutLogsPage`. Builds on the shipped body map (weekly sets vs MEV/MAV zones). **Codex evidence-review run (prompt-carried, verdict *needs-attention* → 5 findings folded in).**
- `[validated, structural]` **Window lengths ground in PERIODIZATION, not borrowed physiology.** 4 weeks = a hypertrophy **mesocycle / deload cycle** (deloads ~every 4–8 wk); 12 weeks = a **training block** (2–3 mesos; advanced 10–12 wk) ([mesostrength](https://mesostrength.com/blog/mesocycles-and-periodization-for-hypertrophy), [Alibaba Wellness](https://wellness.alibaba.com/fitlife/hypertrophy-mesocycle-duration-guide)). So "4-wk avg" = typical week across a meso; "12-wk avg" = across a block (≈ Hevy's "3 months"). This is the sound basis for the window *lengths* — **ACWR (acute 7d / chronic 28d rolling avg) is only a weak analogy** that "a rolling weekly average describes typical load"; its ratio/injury-prediction use is heavily criticized (Impellizzeri/Lolli — ratio distorts at low denominator, no rationale for spans, [Frontiers editorial](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2021.669687/full)) and we borrow **neither** the ratio nor any injury claim. A plain average has none of the ratio's instability.
- `[validated]` **Compute the weekly AVERAGE (calendar-week denominator), not the window total.** The body map shows one value/muscle against **weekly** MEV/MAV zones — a multi-week *total* vs a *weekly* band is nonsense, so averaging is *forced by our own zone design*, not a stylistic pick. Denominator = calendar weeks incl. rest/deload weeks (active-weeks would over-credit and hide that you trained 2 of 4 weeks — the chronic-coverage read is the whole point). Deload = legitimate ([RP Strength](https://rpstrength.com/blogs/articles/training-volume-landmarks-muscle-growth)).
- `[validated, competitor]` **Competitors mostly show TOTAL-over-range; weekly is the default view.** Fitbod Muscle Volume = total; Hevy = per-week totals as a time-series; StrengthLog map colors by sets over a chosen period (red ramp — we won't, body-neutral) ([Hevy](https://www.hevyapp.com/features/sets-per-muscle-group-per-week/), [Fitbod](https://fitbod.zendesk.com/hc/en-us/articles/16436302450711-Your-Workout-Report), [StrengthLog](https://www.strengthlog.com/how-to-track-muscle-growth-strengthlog/)). Our divergence to *average* is principled but a **comprehension risk (Codex F2)** → the number MUST be labelled **"avg/wk"**, never as a date-range filter; needs on-device sign-off (no usability test possible pre-launch/offline). Hands-on competitor avg-vs-total verification deferred (non-blocking — doesn't move our decision).
- `[validated, UX]` Segmented/preset control = **2–5 in-context options** ([Mobbin](https://mobbin.com/glossary/segmented-control)) → 3 `ArcadeChip` presets (This week / 4-wk avg / 12-wk avg), per-widget, **default = This week** (matches competitor default + keeps current behavior + lowest friction).
- `[risk, body-neutral — load-bearing]` **Longer windows raise the guilt surface** (chronic gaps more visible); SDT says competence drives adherence, guilt/rigid targets erode long-term motivation ([SDT/exercise](https://www.sciencedirect.com/science/article/pii/S1469029225000780), [MyFitnessPal study](https://studyfinds.org/fitness-app-motivation-study-myfitnesspal/)). → longer views **opt-in** (default This week = autonomy), neutral zone words (no "below target"/alarm-red, already shipped), a factual "includes rest weeks" note so deload-dimming is self-explanatory. **Rejected** an exclude-deload toggle (scope creep + own inaccuracy).
- **Decision feed:** add a 3-preset averaging-window selector to the body map only (not all of Logs); average over calendar weeks; label "avg/wk"; default This week; neutral opt-in framing. → `/deep-feature` Stage 3+. Links [[workout-analysis]], [[research-4-combat-stats]] (directional-not-dosimetry).

### Detailed per-muscle attribution — AUTHOR two splits by movement-pattern rule, don't import; involvement≠stimulus (2026-06-25)
Feeds the detailed body-map granularity (biceps≠triceps etc.). Audit found our bundled free-exercise-db already has 17 distinct muscle tokens, so most splits are **free** with a non-collapsing analyzer; only **two tokens** lack the needed granularity: `shoulders` (335 exercises) and `abdominals` (149). Decision target: a per-detailed-muscle analyzer + a small authored split layer. Builds on [[research-1-strength-normalization]] (author-our-own/PD provenance) and the fractional-0.5 finding. **Codex evidence-review not run** (local Codex broken / no-diff returns "no diff" per [.claude/codex-local.md]); manual adversarial pass against a 7-item list (folded below).
- `[validated, peer-reviewed]` **Deltoid-head attribution follows a clean movement-pattern rule.** Anterior = shoulder presses + front raises; lateral/middle = lateral raises (abduction); posterior = rear-delt raise / reverse fly / face pull / horizontal pulls / pull-ups ([PMC7706677 resistance-trained](https://pmc.ncbi.nlm.nih.gov/articles/PMC7706677/), [PubMed 24947920 single+multijoint](https://pubmed.ncbi.nlm.nih.gov/24947920/), [ScienceDirect systematic review](https://www.sciencedirect.com/science/article/abs/pii/S1360859222001607)). A movement can hit 2 heads (Arnold press = ant+lat; upright row = lat+ant; face pull = post+lat) → allow multi-head credit.
- `[validated, rule robust / per-exercise EMG noisier]` **Abs vs obliques: spinal FLEXION → rectus (crunch, leg raise, plank); ROTATION / LATERAL-FLEXION / ANTI-ROTATION → obliques (Russian twist, woodchop, side bend, Pallof, side plank)** ([SuppVersity EMG series](https://suppversity.blogspot.com/2011/07/suppversity-emg-series-rectus-abdominis.html), [PMC10824285 upper/lower rectus](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10824285/)). The kinematic rule is anatomy-grade even where per-exercise EMG magnitudes are noisy.
- `[validated, CONTRARY — load-bearing, honesty bound]` **Surface-EMG amplitude is NOT a validated hypertrophy predictor** ([Vigotsky 2022 Sports Med](https://link.springer.com/article/10.1007/s40279-021-01619-2), [Stronger by Science](https://www.strongerbyscience.com/emg-amplitude-tell-us-muscle-hypertrophy/)). BUT this critiques ranking exercises by *growth stimulus*, NOT identifying *which muscle moves* — that's biomechanics, robust. We attribute **involvement** (which head/region a movement works) for a **coverage** read, never a hypertrophy-magnitude claim → stays within "directional, not dosimetry" ([[research-4-combat-stats]]). Keep fractional 0.5 for indirect.
- `[validated, provenance]` **AUTHOR our own split, don't import.** Richer open DBs exist (wger 845+ has "Deltoid Anterior/Posterior"; ExerciseDB 11k has muscle heads) but wger data is **CC-BY-SA 3.0/4.0** → bundling forces attribution **+ share-alike on our data file** + an imperfect id/name-match to our free-exercise-db ids ([wger license](https://wger.readthedocs.io/), [exercemus open list](https://github.com/exercemus/exercises)). Our catalog is PD (Unlicense). Authoring two rule-based splits on **our own ids** keeps it PD-clean (informed-not-copied, same doctrine as the strength coefficients) and avoids the match fragility. Use wger/ExerciseDB only as a **read cross-check** for curated lifts.
- `[risk, per insight #1]` **Tier confidence; fail safe on the long tail.** Curated/common lifts get high-confidence overrides; ambiguous/uncatalogued movements **stay coarse** (keep `shoulders`/`abdominals` merged) rather than guess a head. No XP/stat path reads it (coverage-only) → no farm surface.
- **Decision feed:** ship a **detailed (non-collapsing) analyzer** (biceps/triceps/quads/hams/glutes/calves/lats/traps/lower-back splits are free), plus a **small authored override map** for the two splits — `shoulders`→{anterior,lateral,posterior}, `abdominals`→{rectus,obliques} — by movement-pattern rule + curated overrides, multi-head allowed, coarse fallback when unsure. Front/side/rear-delt and abs/obliques masks then light independently. → `/deep-feature` (this brief is its Stage 2). Links [[research-1-strength-normalization]], [[research-4-combat-stats]].
- **[implemented 2026-06-25 — scope #2 (curated), data layer only, no UI]** `MuscleCoverageService.weeklySetsByMuscle` (detailed, non-collapsing) + `data/muscle_splits.dart` (`splitDetailedMuscle` + a **60-exercise curated override map**). Mask-driven binary splits: `shoulders`→`front_delt` (anterior+lateral front cap) / `rear_delt`; `abdominals`→`rectus_abdominis` / `obliques` (Russian-twist/air-bike/renegade credit both). Un-curated splittable tokens **stay generic** (coarse, never guessed). Same fractional 1.0/0.5 + primary-wins-on-overlap; coverage-only, no XP/stat path. 13 unit tests incl. a **data-integrity test validating all 60 overrides against the real catalog** (mutation-proven: 0.5→1.0/drop-dedupe/guess-fallback all broke the right assertions; a typo'd id was caught by integrity). Full suite green bar the 6 pre-existing golden drifts. Consumers untouched. Lateral delt folds into the front-cap mask (art has front-cap + rear only); EMG attributes *involvement*, not hypertrophy magnitude.
- **[implemented 2026-06-25 — the SURFACE shipped]** The `MuscleBodyMap` widget ([muscle_body_map.dart](../lib/widgets/muscle_body_map.dart)) — a faithful port of the `assets/body_diagram` handoff prototype — now **replaces the Muscle Balance bars** in `WorkoutLogsPage`: a front/back pixel body whose muscles brighten by weekly sets (intensity via `Image`'s `opacity:` over the baked-glow masks — *not* the `Opacity` widget / `BlendMode.modulate`, both Codex-flagged for perf/distortion — `RepaintBoundary`, reduced-motion-static) + a read-only per-side meter (REST/BUILDING/OPTIMAL/HIGH, no amber). Driven by `data/body_map_regions.dart` (16-muscle region model + ported ramp + mask↔muscle map). **Codex Stage-4 plan review (real, needs-attention → 5 findings, all resolved in code):** F1 coarse→front-delt/rectus *only* (no false rear-delt signal); F2 ramp monotonicity + asset dims/manifest tests; F3 `Image.opacity` not modulate; F4 audited Muscle-Balance consumers (kept `_sessionVolumeByMuscle` for the week-chart); F5 zone tokens. **Both views rendered + viewed via golden** (masks/glow/ramp correct, REST empty, HIGH ▲); full suite green bar the 6 pre-existing drifts. Assets **downscaled ÷2 → 512×768, 10.6MB → 2.6MB** (Pillow `reduce(2)`, quality verified via re-rendered golden). Polish pass (user on-device): plain zone words `RESTED/LIGHT/ON TRACK/PLENTY` (MEV/MAV jargon removed), group-header hierarchy fixed, a one-shot scan-reveal (data brightness never pulsed, reduced-motion-safe).
- **[implemented 2026-06-26 — V2 tap-to-drill]** Tapping a muscle opens a bottom-sheet of the **exercises that fed it this week** (name + credited sets), each → `ExerciseHistoryPage`. Data: `weeklyContributors` on a shared `creditPerSet` helper + a single `muscleBreakdown` rollup → the meter **total** and the drill **list** derive from ONE crediting path (Codex F1/F2 — can't diverge; an un-curated `shoulders` exercise drills into FRONT DELT only, never rear; Russian-twist into obliques 1.0 + rectus 0.5; deleted exercise skipped by both). Sheet→history nav closes the sheet then pushes from the page context (F3). 13 tests (6 data: consistency/rollup/coarse/multi-region/deleted; 7 widget incl. the F3 nav + an empty-state drill), 3 goldens viewed. Full suite green bar the pre-existing drifts.
- **[Codex adversarial review — REAL, prompt-carried, verdict *needs-attention*, 2026-06-25]** (corrects the earlier "Codex broken" assumption — per [.claude/codex-local.md] the prompt-only `adversarial-review` *does* run; only repo-reading diff review is broken). **F2 (med) adopted + fixed:** full-credit multi-region inflated the MEV/MAV read (a Russian-twist set credited 1.0 to *both* rectus & obliques) → now the **dominant (first-listed) sub-region takes full weight, each extra takes half** (fractional method within the split; obliques 1.0 / rectus 0.5), test-locked. **F1 (high) + F3 (med) are body-map CONSUMER contracts, carried forward (not the data layer's to settle):** F1 — the analyzer emits *mixed* vocabulary (coarse `shoulders` for un-curated + `front_delt`/`rear_delt` for curated); the future body map MUST define a normalized display contract (map a coarse token to a documented default — e.g. light both delt masks — and never also double-count split keys) + a guard test. F3 — catalog coverage of the splits is low (~52/335 shoulders, ~17/149 abdominals) BUT the picker is curated-filtered so *logged* coverage is far higher; before the map ships, add a coverage report + a display fallback for coarse keys + instrument high-frequency coarse fallbacks. These are **required pre-conditions for the body-map build**, recorded here so they cannot be silently skipped.

### Workout analysis — the industry's two table-stakes we lack: a muscle BODY MAP + SETS-per-muscle/week (2026-06-25)
Audits our analysis surface ([workout_page.dart `_LogsTab`](../lib/pages/workout_page.dart:136)) vs the leading trackers, after the user judged ours "kinda mid" (no body-highlight visual, weaker layout/depth). Decision target: the Logs analytics surface + `CLAUDE.md` competence-growth/visible-deltas hook + body-neutral/anti-guilt mandate. Builds on [[research-1-strength-normalization]] (per-exercise standards) and [[research-4-combat-stats]] (VIT recovery overclaim). **Codex evidence-review not run** (no-diff research review returns "no diff" + local Codex broken on this box per [.claude/codex-local.md](../.claude/codex-local.md)); manual adversarial pass against a 6-item challenge list (folded below).
- `[validated]` **A muscle BODY MAP (anatomical silhouette, trained muscles highlighted/heat-shaded) is industry table-stakes — we're the outlier without one.** Hevy highlights trained body parts in blue on a muscle diagram + a "muscle heatmap" by absorbed volume ([Hevy training-chart](https://www.hevyapp.com/features/training-chart/), [Hevy sets/muscle/wk](https://www.hevyapp.com/features/sets-per-muscle-group-per-week/)); Fitbod's Recovery/Body tab is a 0–100% fatigue heat map ([Fitbod recovery](https://fitbod.me/blog/muscle-recovery/)); JEFIT ships muscle-activation maps ([JEFIT 2026](https://www.jefit.com/blog/best-fitness-apps-tracking-volume-sets-recovery-2026)); StrengthLog's heat map "turns red based on how many sets… over the past week" ([StrengthLog](https://www.strengthlog.com/how-to-track-muscle-growth-strengthlog/)). Ours = colored horizontal volume bars over 7 buckets, no body. Strongest single visual gap + most-named by the user.
- `[validated, accuracy lever]` **The science-aligned per-muscle metric is SETS / muscle / week, not raw kg volume.** Dose-response is counted in weekly sets; landmarks MEV ~6–10, MAV ~10–20 (12–16 large / 8–12 small muscles), MRV ~20+ ([RP Strength](https://rpstrength.com/blogs/articles/training-volume-landmarks-muscle-growth), [myliftingcoach](https://myliftingcoach.com/blog/understanding-volume-landmarks)); Schoenfeld 2017 graded dose-response (~0.37%/set), but landmarks are heuristics not validated constants. Hevy/JEFIT/StrengthLog all surface sets/muscle/week; JEFIT adds an "ideal sets per muscle group" target dashboard. **Ours shows kg-volume bars only → conflates a heavy compound day with high set-count and gives no "are my weekly sets in range" read.**
- `[validated, depth/layout]` **Leaders = a multi-timeframe per-muscle dashboard with drill-down, not a single fixed window.** JEFIT tracks volume per session / per muscle (7d/14d/1m/12m/lifetime) / per exercise + 1RM goals; Hevy offers 7d/30d/3m/1y/all with selectable muscles + week-vs-month compare; Fitbod adds e1RM-per-exercise. Ours: a fixed "last 30 days" balance, top-3 load trends, this-vs-last-week bar — no time-range selector, no per-muscle drill-down, e1RM only via a separate ExerciseHistoryPage.
- `[risk, body-neutral — load-bearing]` **A muscle map fits our mandate ONLY if framed as training COVERAGE, not a body-image/guilt surface.** The body-neutral mandate targets bodyweight/aesthetics; a map of *what you trained* is a competence/coverage signal, not a physique judgment — on-doctrine. BUT the common framing is a nudge ("if your legs are pale… it's time to squat" — StrengthLog) that edges toward guilt; keep our gentle "suggested next," neutral palette (no alarm-red "empty" muscle), opt-in, never a scold. Also: **Fitbod-style "recovery %"/freshness maps overclaim physiology** (model heuristic from session history, no HRV) — same trap as VIT in [[research-4-combat-stats]]; if we ever add freshness, label it schedule/coverage, not "recovery."
- `[assumption]` **An anatomical body map is buildable in our locked pixel-arcade language** as a bespoke `CustomPaint`/pixel-sprite silhouette with the 7 `kMuscleGroupColors` buckets shaded by set-count — no 3D/photoreal asset (off-brand). Front/back pixel torso, muscles as filled regions; reduced-motion-safe static. Needs an `ironbit-design` pass; feasibility/aesthetic unproven until prototyped.
- `[validated, repo-verified]` **Secondary-muscle data is ALREADY bundled — "adding" it is a loader change, not a sourcing project.** `assets/exercises.json` (the PD free-exercise-db) carries a `secondaryMuscles` array on every exercise; **601 / 873 (~69%) are non-empty**, and they use the *same* detailed-muscle vocabulary `muscleGroupForDetailed`/`_detailedToBucket` already maps ([muscle_groups.dart:18](../lib/data/muscle_groups.dart:18)) → they fold into the 7 buckets with **zero new mapping**. The `Exercise` model currently **discards** them (keeps only `primaryMuscle` = first of `primaryMuscles`, [workout_models.dart:116](../lib/models/workout_models.dart:116)); StatEngine reads raw `primaryMuscles` but never `secondaryMuscles`. → wire `secondaryMuscles` into the model + the coverage analyzer; **custom exercises** have no secondary field (single `primaryMuscle`) so they fall back to primary-only (acceptable; ~31% of built-ins are empty too).
- `[validated, peer-reviewed]` **Credit secondaries as fractional 0.5 sets (direct = 1.0, indirect = 0.5) — the evidence-backed weighting, not an arbitrary pick.** The fractional method "provided the strongest relative evidence for hypertrophy" in the Pelland/Steele dose-response meta-regression (67 studies, 2,058 participants) vs direct-only or total-count ([SportRxiv 537](https://sportrxiv.org/index.php/server/preprint/view/537), [Stronger by Science — Volume](https://www.strongerbyscience.com/volume/), [RP landmarks](https://rpstrength.com/blogs/articles/training-volume-landmarks-muscle-growth)). Caveat: free-exercise-db secondary attributions are community data (not EMG), 0.5 is a population best-fit (real indirect share varies by exercise), and ~31% have no secondary listed → treat as a **directional coverage signal, not exact dosimetry** (matches "directional not exact" in [[research-4-combat-stats]]); fractional sums (e.g. 14.5) need sensible rounding in the "weekly sets in range" read.
- **Decision feed:** the highest-leverage, on-doctrine upgrades are (1) add **sets/muscle/week** beside kg-volume (accuracy + the metric that matters), (2) a **pixel muscle body map** shaded by weekly sets (the headline visual, framed as coverage), (3) a **time-range selector** + per-muscle drill-down for depth. **Secondary crediting is now cheap (data already bundled, fractional 0.5 is evidence-backed) → fold it into v1 rather than deferring** — it makes a finer (sub-bucket) map honest. Defer/avoid: a Fitbod-style physiological "recovery %" map (overclaim + anti-guilt risk). → if pursued, `/deep-feature` (it touches a persisted model + scoring presentation + a new bespoke surface); body map pixels → `ironbit-design`. Links [[research-1-strength-normalization]], [[research-4-combat-stats]].
- **[implemented 2026-06-25 — data layer only, no UI]** Wired `Exercise.secondaryMuscles` from the bundled JSON (additive, legacy→`[]`, round-trips `toJson`) + a pure `MuscleCoverageService.weeklySetsByBucket` ([muscle_coverage_service.dart](../lib/services/muscle_coverage_service.dart)) crediting **1.0 primary / 0.5 secondary** working-set into the 6 real buckets over a rolling 7 d, with **per-exercise bucket-collapse dedupe (primary wins)** so collapsing detailed muscles can't over-credit (squat: glutes/hams alongside quads → Legs stays 1×). Counts working sets only (warm-ups excluded), skips partial/unknown-exercise. **Every muscle consumer untouched** → stats/balance/loot byte-identical (full suite green bar the 6 pre-existing profile/room/home golden drifts). 12 unit tests, mutation-proven (0.5→1.0 + drop-dedupe broke exactly the fractional/absorb/dedupe assertions). Nothing rendered yet — the body-map surface is the next, separate step.

### Profile hero CARD — role-legible identity composition (2026-06-22)
Tactical follow-up to the 2026-06-18 profile audit (which set the STRATEGY: private mirror / coherence /
hierarchy-by-size). New question: the hero **card's internal composition** — user critique that LV / NAME /
title / CHAMPION rank / LCK all read at the **same hierarchy** and "cheaply recycle the same chip frame," title
gets "nothing but a color." Decision target: [profile_page.dart](../lib/pages/profile_page.dart) `_buildHeroCard`
+ root `CLAUDE.md` identity-attachment doctrine. **Codex-reviewed evidence** (verdict *needs-attention* → 3
findings folded in). Pixel execution → `ironbit-design`.
- `[validated]` **"Everything is a chip/filled badge" is the literal documented anti-pattern** — reserve SOLID/filled
  badges for the SINGLE most important status; use outline/plain for lesser; map style to ROLE consistently, never
  arbitrarily ([Smart Interface Design Patterns](https://smart-interface-design-patterns.com/articles/badges-chips-tags-pills/),
  [Setproduct](https://www.setproduct.com/blog/badge-ui-design), [Mobbin](https://mobbin.com/glossary/badge)). → today's
  LV (amber filled) + RANK (red filled) + LCK (filled) are three peer chips = the anti-pattern; the fix is role-mapped
  styling, not a 4th chip.
- `[validated]` **Card hierarchy comes from ZONING + type-scale + framing-the-art, secondary info small & corner-anchored**
  ([Anatomy of a Card / Chen](https://fantastic-factories.medium.com/anatomy-of-a-card-840cdc2404c1),
  [Mangini](https://medium.com/@dylanmangini/4-layout-tips-for-designing-card-games-17cc98b89b96)). → name/title is the
  largest; level/rank become small stamps; XP a corner readout.
- `[validated, CONTRARY — load-bearing]` **Whitespace + typographic weight are the PRIMARY hierarchy tools; borders/
  frames/backgrounds are a LAST resort — "use sparingly, they create clutter"** ([NN/g](https://www.nngroup.com/articles/visual-hierarchy-ux-definition/),
  [Sessions College](https://www.sessions.edu/notes-on-design/visual-hierarchy-key-ux-principles-that-drive-results/),
  [IxDF](https://ixdf.org/literature/topics/visual-hierarchy)). → **the user's instinct to "add frames/sections" can
  BACKFIRE on a compact scroll-feed card**; fix hierarchy with type+spacing+zoning FIRST, add chrome only where whitespace
  fails. Codex concurred: evidence supports hierarchy *repair*, not a denser framed/namecard object.
- `[validated, layout-hypothesis]` **Title-as-epithet directly UNDER the name** (name primary, title smaller line beneath,
  level/rank compact stamps) is the cross-game nameplate convention ([GW2 wiki](https://wiki.guildwars2.com/wiki/Graphical_user_interface),
  Game UI Database "Rank & Position"). **Caveat (Codex):** that convention is MULTIPLAYER-signaling (others read your
  nameplate) — for our SOLO private mirror it's a sound *layout* hypothesis, not proof; bind title to name regardless.
- `[risk]` **An "earned namecard banner" (Genshin/Honkai) is context-mismatched + risks a redundant 2nd cosmetic axis** —
  those are collection-heavy FULL-SCREEN identity systems, not a compact offline feed card; we already have earned avatar
  frames + titles, and avatar-as-hero is only a hypothesis. A new earnable banner = scope creep + collection pressure vs
  the body-neutral/private mandate. → if ever explored, prototype as a STATIC skin, not a new earnable asset class.
- `[risk]` **Candidates must clear accessibility + overflow before build** — rank/title differentiated by COLOR only
  (title = purple text) fails color-vision users; add non-color cues (position/weight/icon/label). Acceptance-test long
  names, long titles, dynamic type, and **320dp × 1.3** narrow-width before any denser nameplate ships.
- **Direction:** best-supported = **typography-first nameplate** (Solution A) or the minimal defect-fix; defer the framed-
  plate (B) pending a 320dp low-fi test; treat the namecard (C) as a deferred horizon, static-skin-first.

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

### Haptics v2 — generous COVERAGE, disciplined INTENSITY; "continuous" = short controller-coupled pulse-trains (2026-06-23)
Feeds the app-wide haptic expansion ("Finch/Duolingo put haptics on app *motion*, not just buttons — press BIT, gems flying, demo start/stop, BIT boot/cheer, changing items in the bag; we're simplifying audio so haptics make up for it"). Extends the 2026-06-21 haptics entry (taxonomy/service/toggle settled & shipped — not re-litigated). Decision target: every interactive + animated surface across the app + the anti-guilt/juice doctrine. Full synthesis + per-surface contract: [haptics_research.md](haptics_research.md). **Codex-reviewed** (verdict *needs-attention* → all 5 findings folded in).
- `[validated, CONTRARY — load-bearing]` **The user's "haptics can never be too much" is contradicted on INTENSITY/DURATION, not coverage.** Android official ("less is more"; *"given buzzy haptics or none, choose none"*; overuse → users disable all) + **JCR peer-reviewed primary** ("Haptic Rewards", 2025): reward response is **quadratic in duration, peaking ~400 ms** — a 3,200 ms buzz *decreased* reward vs none and felt "punishing." → haptics amplify reward but via *timing*, not quantity. **Resolution: be generous with COVERAGE (subtlest `selectionClick` workhorse on routine taps/rows/chips/cards), disciplined with INTENSITY (heavier reserved for confirm/reward/destructive) and DURATION (no drones).** Defensible because the broad layer sits at the lowest rung + the Haptics toggle is the escape hatch the sources demand.
- `[validated, technical]` **Built-in `HapticFeedback` can't do true continuous haptics; simulate as a pulse-train of discrete one-shots** (also what Android recommends and what Finch's breathing guidance actually is). **Drive the train off the `AnimationController.addListener` with a threshold cursor + `while`-loop — NOT a `Timer.periodic`** (they drift; user feels it; a service Timer also leaks as a flutter_test pending-timer). The controller is the single timing source → haptic stops with the animation. Battery is a non-issue (~5–15 mJ/pulse).
- `[validated, per Codex]` **Silent-surface matrix + budget are mandatory** (else broad coverage = "disable all"): never on passive scroll, informational cards, disabled/gated taps, re-tap of the current tab, or <30 ms after a prior pulse (global coalesce in the service); shared wrappers default **silent**, opt-in only committing taps. **Gem flight: aggregate to ≤3 beat-keyed `selection` ticks + one final `reward`, NOT per-gem.** **Reduced-motion: pulse only when tied to an explicit user action / visible state change; suppress ambient train-replacements** (BIT idle boot → silent under reduced motion; gem-flight & BIT-cheer keyed to the tap/reveal stay).
- **Decision feed:** land infra first (one-shot service + global coalesce + a disposable `AnimationController`-coupled pulser helper + opt-in `HapticIntent` on `PhosphorTap`/`HoldDepress`/`ArcadeTap`, `ArcadeChip` default `selection`, `TrainNavButton` `tap`), then 9 **pure opt-in** per-screen batches. → built via `/deep-feature`; pixel/copy of any new surface → `ironbit-design`. Links [[research-13-reward-economy]] (juice without gambling/guilt).
- **[implemented 2026-06-30 — Haptics v3: enforce coverage structurally]** The v2 opt-in model (wrappers default silent, per-call-site `haptic`) proved **forgettable** — the guild Crest Forge shipped with zero haptics on every pick/drag because its taps used raw `GestureDetector`. **Comprehensive research** (reuse: v1+v2 settled the *feel*; the new question was enforcement-architecture — component-default-by-role is the cross-platform norm; lint/test enforcement is precedented) + **Codex (needs-attention → 3 findings folded)** resolved the **auto-wire-vs-overfire tension**: enforce **COVERAGE** with a CI test, keep **RESTRAINT** with the by-role taxonomy — two mechanisms, neither compromised. Shipped: (1) `test/tap_haptic_coverage_test.dart` — a comment/string + depth-aware source scanner that fails CI on any raw `GestureDetector(onTap:)`/`InkWell` outside the wrapper allowlist; **31-file shrink-only baseline** (gates NEW features cleanly) + an explicit `// haptic-ok: <reason>` marker for legit raw gestures (Codex F1: AST-aware + classify-not-grandfather, dependency-free scanner over the `analyzer` pkg to dodge SDK version-solving); (2) by-role wrapper defaults are the un-forgettable common path, decorative taps stay on the silent low-level wrappers (Codex F3: explicit decision at the boundary); (3) guild gaps fixed — CUSTOMIZE/thumbnails/swatches → `HoldDepress(selection)`, nav `_NavItem` InkWell → `ArcadeTap(selection)`, cache auto-bank → `reward`, **HSV picker drag fires `selection` only on quantized step-crossings** (Codex F2: per-pan-update at the 30ms coalesce = ~33/s = the forbidden drone). Skills updated so future features inherit it (ironbit-design finish-time audit + deep-feature Stage-5 acceptance). The opt-in default on low-level wrappers (researched anti-overfire) is **preserved** — this adds enforcement, never flips to default-on. `flutter analyze` 0; guild + nav green; coverage test green.

### Streak board rework — delete the color legend, make the 7-day strip self-evident; "Missed" never flagged on the glanceable hero (2026-06-23)
Triggered by a visible bug: the `_buildStreakHero` weekly board's legend clips its 3rd item ("Missed"). Root cause: the legend sits in `Expanded → SingleChildScrollView(horizontal)` sharing one row with `FULL MONTH →` ([workout_page.dart:1075-1118](../lib/pages/workout_page.dart:1075)) → 3rd item scrolls off with no affordance. Decision target: that board (WorkoutLogsPage hero) + root `CLAUDE.md` anti-guilt/body-neutral + ritual-return doctrine. Builds on [[research-7-streaks-recovery]] (weekly+shielded spine) and the existing body-neutral marker call in [calendar_day_marker.dart:47](../lib/widgets/calendar_day_marker.dart:47). **Codex evidence-review could not run** (local Codex broken on this box per [.claude/codex-local.md](../.claude/codex-local.md)); manual adversarial pass against a 6-pt list (2 refinements folded). Pixel execution → `ironbit-design`; build → `/deep-feature`.
- `[validated, UX]` **A separate color legend is a smell, not just mis-laid-out** — direct labeling beats legends (no back-and-forth matching, lower cognitive load; a viz that "stands on its own" needs no key); legends, when unavoidable, go BELOW/parallel to the viz, never inline beside a CTA in a clipping scroller ([Depict Data Studio](https://depictdatastudio.com/accessibility-quick-wins-remove-legends-and-directly-label/), [Lanke/Medium](https://medium.com/@sid.lanke.123/why-labeling-data-visualizations-beats-legends-a-no-nonsense-approach-11eda39bd4b), [xDgov standards](https://xdgov.github.io/data-design-standards/components/legends)). The strip's glyphs already differ by SHAPE (bar/outlined-box/rotated-tick) → the legend is decorative + a CVD-safe non-color cue already exists.
- `[validated, competitor]` **Every comparable app: NO negative "missed" marker on the glanceable weekly view.** Duolingo = checkmark/snowflake(frozen)/perfect-week-bar, misses absent-or-frozen ([DoF](https://duolingo.deconstructoroffun.com/mechanics/streaks)); Hevy = binary blue=trained / else=rest, streak=consecutive WEEKS + "rest days since" counter, no missed state at all ([Hevy](https://www.hevyapp.com/features/gym-consistency/)) — nearly our model; Apple/Streaks = filled cells/rings, absence = unfilled ([Smashing 2026](https://www.smashingmagazine.com/2026/02/designing-streak-system-ux-psychology/)).
- `[validated, behavioral; CONTRARY recorded+reconciled]` Anti-guilt streak design = remind how far you've come, break=pause-not-reset, show personal-best beside current ([Smashing](https://www.smashingmagazine.com/2026/02/designing-streak-system-ux-psychology/), [UX Mag "without shame"](https://uxmag.com/articles/the-psychology-of-hot-streak-game-design-how-to-keep-players-coming-back-every-day-without-shame), [Yu-kai Chou](https://yukaichou.com/gamification-analysis/streak-design-gamification-motivation-burnout/)). **Contrary:** streaks work via loss-aversion + a visible HONEST record of what you did; hiding all negatives removes the leverage ([everyday.app](https://everyday.app/blog/daily-habit-tracking/), [cohorty](https://blog.cohorty.app/the-psychology-of-streaks-why-they-work-and-when-they-backfire/)). Reconciled: weekly+shielded already threads it — keep the honest PROGRESS record (filled days, streak, spent shields), drop the shaming FLAG; the miss/abandoned ledger lives in FULL MONTH, not the hero. The strip already suppresses missed for new users + future days ([workout_page.dart:1226,1232](../lib/pages/workout_page.dart:1226)), so the "Missed" key is doubly wrong: clipped AND often phantom.
- **Decision feed:** **Option A (recommended)** — self-evident strip (filled=trained, today=ring, dim/empty=not-yet/rest, outlined-shield=protected), DELETE the color legend, replace with one progress line (`N of goal this week`, optional `· best: N wks`); FULL MONTH keeps its affordance. **Option B (fallback)** — key ONLY the ambiguous "Protected" glyph, on its OWN line below the strip in a `Wrap` (never a scroller, never beside the CTA). **Option C (do-not)** — keep all three + `Wrap` the overflow: fixes the clip but keeps an over-keyed, off-doctrine card advertising a failure-state. Guardrails: preserve past-missed vs future vs rest distinction; color never sole carrier (shape+position).
- **[implemented 2026-06-23 — user-directed variant]** User kept a **2-item legend** (Workout + Protected) and instead **removed the "Missed" symbol from the system entirely** — the `CalendarMarkerKind.missed` enum value, its slate marker + rotated-tick glyph, and the "Missed" legend item on BOTH the streak hero ([workout_page.dart](../lib/pages/workout_page.dart)) and the full calendar ([calendar_page.dart](../lib/pages/calendar_page.dart)); a missed day now renders no marker (the `suppressMissed`/`firstActivityDay` plumbing was dead and was removed too). The tap-detail still names a missed day in TEXT. Also changed `FULL MONTH →` cyan→neon-green and **deleted the Level/XP/rank card** from the Logs page (with its dead XP plumbing). Net effect lands close to the body-neutral intent (absence = unflagged blank cell) without dropping the whole key. Analyze clean; no test exercised these surfaces.

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

### Notification DELIVERY RELIABILITY — Tier-A backgrounded rest alert (2026-06-26, Codex-reviewed)
Follow-up to the 2026-06-21 foundation entry above; user asked whether the rest-timer notification is "secured"
(it isn't attacker-vulnerable — local-only, no INTERNET in release, receivers `exported=false` — the real soft
spot is *delivery*). Decision target: whether to add a foreground service / battery-optimization exemption to make
the backgrounded rest alert fire reliably, or keep best-effort. **Codex evidence-review = needs-attention → 3
findings resolved (API conflation corrected, re-arm path added, health-FGS qualified).**
- `[validated]` **Inexact is unusable for a 90s rest — but state the reason correctly.** `inexactAllowWhileIdle`
  → `setAndAllowWhileIdle()`: fires **within ~1 hour** of target on Android 12+, throttled to **~once / 15 min in
  deep Doze** (NOT the "10-min minimum" — that's `setWindow`'s window-clip-to-600000ms, a *different* API; Codex
  caught the conflation). Either way ≫ a 90s rest → best-effort due to **batching/throttling/OEM**, never a tight
  bound. ([alarms](https://developer.android.com/develop/background-work/services/alarms), [setAndAllowWhileIdle](https://developer.android.com/reference/android/app/AlarmManager#setAndAllowWhileIdle(int,%20long,%20android.app.PendingIntent)))
- `[validated]` **Light Doze starts the INSTANT the screen turns off** (Android 7+), "even when the user continues
  to move around" — so a short backgrounded rest does **not** dodge idle deferral (users pocket the phone → screen
  off). Kills the "short window stays warm" hope; exact alarms genuinely matter. ([doze-standby](https://developer.android.com/training/monitoring-device-state/doze-standby), [AOSP power](https://source.android.com/docs/core/power/platform_mgmt))
- `[validated]` **Exact-alarm permission choice = keep `SCHEDULE_EXACT_ALARM`, do NOT use `USE_EXACT_ALARM`.**
  `USE_EXACT_ALARM` is auto-granted+unrevocable but **Play-restricted to apps whose CORE function is alarm/timer/
  calendar** — a workout app with a rest-timer *feature* is a gray area → rejection risk. `SCHEDULE_EXACT_ALARM`
  (user-granted on 14+, declared, graceful fallback) is the defensible path (current). ([Play Console 16558241](https://support.google.com/googleplay/android-developer/answer/16558241), [schedule-exact-alarms](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms))
- `[validated]` **Do NOT add `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`** — apps get **rejected** under device-and-
  network-abuse policy unless Doze breaks the *core* function; sanctioned path is the `*AllowWhileIdle` modes the
  plugin already uses. ([Play dev community](https://support.google.com/googleplay/android-developer/thread/255896306), [doze-standby](https://developer.android.com/training/monitoring-device-state/doze-standby))
- `[validated]` **Do NOT add a foreground service *solely* for the rest alert** — Android 14 requires a declared
  FGS type; docs say prefer purpose-built APIs and start an FGS only *when the alarm fires*. ([fgs service-types](https://developer.android.com/develop/background-work/services/fgs/service-types), [fgs-types-required](https://developer.android.com/about/versions/14/changes/fgs-types-required))
- `[validated, qualified per Codex]` **`FOREGROUND_SERVICE_TYPE_HEALTH` is the legitimate fitness path — but only
  for a REAL live-workout capability**, not a sensor-less timer hack: the health FGS type carries runtime
  prerequisites (activity-recognition / sensor perms) → adding them just to qualify = privacy/Play friction. A
  workout "live activity" FGS during an active session would make rest timing reliable as a byproduct (what Hevy/
  Strong do) — a deliberate product feature, deferred. ([fgs service-types](https://developer.android.com/develop/background-work/services/fgs/service-types))
- `[validated, added per Codex]` **Re-arm exact alarms on permission GRANT, not just on resume.** Listen for
  `ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` + recheck `canScheduleExactAlarms()` + reschedule — if a
  user grants permission mid-rest, reconcile-on-open is too late for a sub-5-min window. ([alarms](https://developer.android.com/develop/background-work/services/alarms))
- **Decision feed:** keep the current design (SCHEDULE_EXACT_ALARM + contextual request + inexact fallback +
  boot-reschedule + reconcile-on-open); add nothing heavy. Two cheap hardening adds worth a small task: (1) exact-
  alarm re-arm on permission-state-changed; (2) honest user-facing copy that the backgrounded alert is best-effort.
  The live-activity health-FGS is the only path to *guaranteed* backgrounded timing and is a separate product call.

### Notification SECURITY & PRIVACY posture — threat model + future-content rule (2026-06-26)
User asked if the (rest-timer-only) notification system is "vulnerable." Decision target: record the threat model so
the local-only foundation decision is justified, and set the rule for when notifications grow to carry sensitive
content. Quick-tier passes (authoritative primary sources: OWASP MASVS + Android security/design docs); integrity
self-check, no Codex (facts uncontested). Reinforces the offline/private wedge + body-neutral mandate.
- `[validated]` **Local-only design eliminates the entire REMOTE surface.** Release build has **no `INTERNET`**
  (debug/profile only), no FCM/push → zero remote injection, zero off-device data, nothing to spoof. The notification
  receivers are all **`exported="false"`** (only `MainActivity` is exported, for the launcher). This is the safest
  notification architecture there is; the local foundation choice was the secure call.
- `[validated]` **Residual Android-platform surfaces are mitigated, not absent.** (1) **PendingIntent hijacking**
  (OWASP MASVS-PLATFORM / MASTG-TEST-0030) — mutable+implicit PendingIntents let a malicious app reach non-exported
  components; mitigated because `flutter_local_notifications` v22 builds **`FLAG_IMMUTABLE`** PendingIntents by
  default (Android 12+ mandate). (2) **NotificationListenerService** — a user-granted malicious listener can read
  notification *content* and extract PendingIntents **even on Android 15**; system-level + unpreventable → the only
  real defense is *not putting sensitive data in a notification*. ([pending-intent](https://developer.android.com/privacy-and-security/risks/pending-intent), [MASTG-TEST-0030](https://mas.owasp.org/MASTG/tests/android/MASVS-PLATFORM/MASTG-TEST-0030/))
- `[validated]` **Current Tier-A content is benign** ("Rest complete" / "Time for your next set") → `VISIBILITY_PUBLIC`
  is fine today; no change needed.
- `[validated, FORWARD RULE]` **When notifications grow to carry body metrics / weight / streak content (Tier B/C):
  never put the sensitive value in the notification.** Use generic redacted lock-screen text ("Time to check in", not
  "You're up 2.1kg") + per-channel `VISIBILITY_PRIVATE` (or `SECRET`) via `setVisibility()`/`setPublicVersion()`.
  This is defense-in-depth: visibility blocks shoulder-surf/lock-screen, *content-omission* blocks the NLS threat.
  Doubles as **body-neutral** enforcement (a weight delta in a notification violates both privacy and the mandate).
  ([Android notifications](https://developer.android.com/design/ui/mobile/guides/home-screen/notifications))
- `[validated]` **Legal framing:** fitness apps are mostly **not HIPAA**-covered, but **GDPR** treats fitness/health
  as personal (EU special-category) data; the recognized leak vector is exactly "in-app alerts with health info."
  Ironbit already wins the bigger battle (local-only → no third-party sharing, vs the [Duke 79%-share stat](https://www.dickinson-wright.com/news-alerts/app-users-beware)); the only residual is **on-device lock-screen exposure**, covered by the forward rule above. ([HHS health-apps](https://www.hhs.gov/hipaa/for-professionals/privacy/guidance/access-right-health-apps-apis/index.html))
- **Decision feed:** (1) the system is **not meaningfully attacker-vulnerable** — record this threat model so it's
  not re-litigated; (2) bake the forward content rule into the per-category-channel design *before* Tier B/C ships.

### Notification PERMISSION placement in onboarding — premature NOW, correct WHEN reminders ship (2026-06-26, Codex-reviewed)
User hypothesis: "notification permission usually goes in onboarding." Decision target: where/how to place the OS
POST_NOTIFICATIONS ask relative to the current onboarding flow (Welcome→ColdOpen→Problem→Solution→QuizA→Calib
Loading→ClassReveal→QuizB[…/frequency/…]→ProgramLoading→ProgramSelection→Name→StartGate→RootPage). Today the ask
fires at **first-workout-start** (`maybeAskRestPermission`→`requestPermissions`, OS dialog **directly, no primer**).
**Codex evidence-review = needs-attention → 3 findings folded in (scope-prematurity, magnitude-overreach, layering
state model).** Builds on the 2026-06-21 foundation entry (never cold at launch / prime first / opt-in −⅓ post-A13).
- `[validated, DIRECTIONAL — magnitudes are marketing-push, per Codex F2]` **Cold front-of-onboarding OS ask = worst
  opt-in; value-first + a pre-permission PRIMER + a soft "Not now" that does NOT fire the OS dialog = best** (and
  preserves the scarce Android-13 prompt — a denial is near-permanent). Treat the vendor %s (55-70 vs 30-40, +40-60
  priming, +30-50 soft-ask) as **direction, not prediction** — they're SERVER-PUSH growth stats; our notifications are
  LOCAL utility, so the *robust* core is the Android primary-doc guidance + the priming/soft-ask shape, not the numbers.
  ([Pushwoosh](https://www.pushwoosh.com/blog/increase-push-notifications-opt-in/), [Appcues](https://www.appcues.com/blog/mobile-permission-priming), [Android notif-perm](https://developer.android.com/about/versions/13/changes/notification-permission), [MoEngage A13](https://www.moengage.com/blog/android-13-push-notification-opt-ins-guide/))
- `[validated, the steelman for onboarding]` **Reach-vs-rate:** deferring maximizes per-ask RATE but >50% of new
  users churn after session 1, so deferring too long = never reach them. Sweet spot = value-first **within Day 0-3**,
  NOT a cold onboarding screen. ([Braze](https://www.braze.com/resources/articles/push-notifications-best-practices), [vmobify](https://vmobify.com/blog/app-onboarding-best-practices))
- `[risk, load-bearing — Codex F1]` **For the CURRENT rest-timer-only scope, an onboarding (Start-Gate) ask is
  PREMATURE** — the user hasn't started a workout or felt why a rest alert helps; the only shipped value lands DURING
  the first workout's first rest. → keep the ask **contextual** for now; onboarding placement is correct **only once a
  configurable training-day-reminder (Tier B) ships**, because THAT value is what lands in onboarding.
- **Decision feed (recommendation):**
  1. **Now (rest-timer only):** do NOT add an onboarding permission screen. Keep the contextual ask, but **wrap it in
     a primer** (today it hits the OS dialog raw) and move it to the **first rest** (value peak), with an equal-weight
     guilt-free "Not now".
  2. **When Tier B reminders ship:** add a **primed soft-ask at the Start Gate** (all value delivered, commitment peak,
     no mid-flow friction; alt = right after the **frequency** question for freshest value-link). Mascot-voiced,
     benefit-led, body-neutral, emphasize **local/on-device/private**; "Turn on"→OS dialog, "Not now"→no OS dialog.
  3. **State model (Codex F3):** replace the single `wasRestPermAsked` bool with a permission-INTENT state
     (not-asked / app-deferred / OS-granted / OS-denied) so layered asks never double-prompt in a session, distinguish
     OS-denied from app-deferred, and expose a Settings toggle for later opt-in.
  4. **Validation:** magnitudes are push-derived → confirm placement with a small test once there's traffic; pre-launch
     ship the conservative version. → flow change via `/deep-feature`; primer pixels/copy → `ironbit-design`.
- **[implemented 2026-06-26 — `/deep-feature`, Codex-reviewed plan]** Shipped Tier B. **Decoupled consent** (Codex
  F1): `isTrainingReminderEnabled` **default OFF** + `trainingReminderTimeMinutes` (default 08:00); the
  permission-INTENT enum (rec #3) was dropped as over-engineering — OS state derived live via `hasPermission()`,
  rest-alert ask kept fully independent (never stranded, Codex F2). `NotificationService.syncTrainingReminders()`
  **reconciles** (cancel ids 2001..2007 → weekly `matchDateTimeComponents.dayOfWeekAndTime`, Codex F3); `tz.local`
  from `flutter_timezone`; pure mutation-proven `trainingReminderSlots` planner. Primer (`reminders_primer_page`)
  placed **before the Start Gate** (user pick) in `name_screen._submit`; reminder time default **08:00** (user
  pick) + Settings time-picker. Re-sync on boot / weekday-edit / toggle / grant.

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

### Rest-time suggestion — drive it by EXERCISE TYPE (+ optional training-style), NEVER body-composition goal (2026-06-22)
Evaluates the user's ask "add rest-time suggestion depending on weight goal — different training has
different rest time." Decision target: [rest_preference_service.dart](../lib/services/rest_preference_service.dart)
(single global `last_rest_seconds`, **class-seeded** Tank 180 / Bruiser 90 / Assassin 60) +
[workout_defaults_service.dart](../lib/services/workout_defaults_service.dart) (`getRestSeconds`,
clamp 30–300) + [rest_timer_service.dart](../lib/services/rest_timer_service.dart) + the
`BodyGoal{cut,recomp,bulk}` model + body-neutral & anti-guilt mandates + competence/recovery-protection
doctrine. **Codex-reviewed** (verdict *needs-attention* → all 5 findings folded in; one extra search
loop on self-selected rest resolved the biggest gap).
- `[validated, strong]` **Rest by TRAINING goal is the textbook axis** (ACSM 2009 position stand
  [PubMed 19204579](https://pubmed.ncbi.nlm.nih.gov/19204579/) / [PDF](https://tourniquets.org/wp-content/uploads/PDFs/ACSM-Progression-models-in-resistance-training-for-healthy-adults-2009.pdf);
  de Salles 2009 review [PubMed 19691365](https://pubmed.ncbi.nlm.nih.gov/19691365/); NSCA): **strength**
  (heavy 1–6RM) **3–5 min**, **hypertrophy** (6–12RM) **1–2 min**, **power 3–5 min**, **muscular
  endurance** (20–30 rep) **≤30 s**. ACSM released a **2026 update** (first in 17 yrs,
  [ACSM](https://acsm.org/resistance-training-guidelines-update-2026/)) — could NOT confirm it changed
  the rest ranges; 2009 stands as the cited authority.
- `[validated, exercise-type]` **Fatigue (muscle mass / load / CNS demand) drives rest more than goal**
  — heavy **compound 2–3 min**, **isolation 60–120 s** ([Barbell Medicine](https://www.barbellmedicine.com/blog/rest-periods-during-training/)).
  This is the app's cheapest accurate lever: the exercise DB **already carries compound/isolation
  (`mechanic`) metadata**. **But it's a WEAK starting point, not "accurate"** (per Codex): the same
  exercise's rest also shifts with load, rep-range, proximity-to-failure, supersets, and conditioning.
- `[validated, SMALL/equivocal — hedge hard]` The old "**30–60 s short rest for hypertrophy via growth
  hormone**" is **debunked**; longer rest (>60 s) **modestly** favors hypertrophy and plateaus ~90 s,
  whole-body marginally favored *shorter*, effect sizes tiny (SMD ~0.1–0.17, CrIs cross zero), samples
  **predominantly young untrained males** ([Give it a rest, Bayesian meta 2024, PMC11349676](https://pmc.ncbi.nlm.nih.gov/articles/PMC11349676/);
  Grgic & Schoenfeld 2021). → never label any band "optimal for muscle growth"; frame as
  performance-recovery convenience.
- `[validated, THE CRUX — reframed per Codex]` **Body-composition goal is NOT a reliable rest driver.**
  Not the absolute "short rest doesn't burn fat," but: rest should **preserve performance and fit the
  set being trained**; in a deficit you keep resting adequately to hold strength + muscle ([Men's
  Journal](https://www.mensjournal.com/fitness/rest-between-sets-muscle-strength-longevity),
  [Healthline](https://www.healthline.com/health/fitness/rest-between-sets), [Coach Mark Carroll](https://coachmarkcarroll.com/keys-to-maintaining-muscle-in-a-deficit/)).
  **The app already quietly encodes the myth**: rest seeds from class, and class derives from `BodyGoal`
  → **cut→Assassin→60 s, bulk→Tank→180 s**. So "a cut goal gives you shorter rest" already ships — the
  exact body-neutral / leanness-chasing failure to avoid.
- `[validated, resolves the anti-guilt gap]` **Self-selected / autoregulated rest ≈ fixed rest** for
  both strength AND hypertrophy, and is more **time-efficient**; the literature does **not** support that
  hypertrophy needs shorter rest than strength ([fixed vs self-selected, PMC11503322](https://pmc.ncbi.nlm.nih.gov/articles/PMC11503322/),
  [Biolayne](https://biolayne.com/reps/issue-28/which-between-set-rest-interval-is-best-for-muscle-growth/)).
  → strongest evidence for a **gentle suggestion + "rest when you're ready" escape hatch**, not a rigid timer.
- `[validated, competitor]` Per-exercise rest is the **standard pattern**; **none** drive it by body-comp
  goal. **Hevy** = user-set default rest per exercise (5 s–5 min), **disable-able for intuitive rest**
  ([Hevy](https://www.hevyapp.com/features/workout-rest-timer/)); **Fitbod** = **auto rest by the
  difficulty of the lift**, varies per exercise/session ([Fitbod](https://fitbod.zendesk.com/hc/en-us/articles/360006340194-Rest-Timer)).
  → exercise-type-aware default + per-exercise sticky + disable matches precedent (Fitbod's "auto by
  difficulty" ≈ our compound/isolation lever).
- **Decision feed:** (1) **Decouple the first-run rest seed from `BodyGoal`/class** (or at minimum
  neutralize the cut→60 s link); migrate existing goal-seeded values neutrally — don't silently keep
  60 s because a user once picked "cut" [Codex high]. (2) Default driver = **exercise-type (compound
  ~2–3 min / isolation ~60–120 s) as a weak starting suggestion**, using the existing `mechanic`
  metadata — labelled recovery convenience, never "optimal." (3) Keep it a **suggestion**: overrideable,
  per-exercise sticky, first-class **skip / "ready when you are"**, easy disable for supersets/circuits,
  **no penalty/streak/judgment** for resting long or short; audit class seeds/labels/copy for implied
  moral judgment about rest. (4) **Optional, heavier:** if a goal axis is still wanted, capture an
  explicit **TRAINING goal (strength/hypertrophy/endurance)** — NOT body-comp goal — as an optional
  style that shifts the bands (new model + onboarding question; defer). **Caveat:** RCTs skew
  young-untrained-male, hypertrophy effect small → all bands are gentle defaults. → if pursued,
  `/deep-feature` (rest-seed decouple + per-exercise sticky + exercise-type default + migration); surface
  copy → `ironbit-design`. Links [[research-7-streaks-recovery]], the rest-timer-done notification entry.

### Rep target — the fixed kind-constant is the NOVICE default, not a universal target; let it FOLLOW demonstrated range (2026-06-22)
Feeds the `/deep-feature` #5 rep-target redesign in [progressive_overload_service.dart](../lib/services/progressive_overload_service.dart) (`_repTargetByKind` compound 8 / isolation 12 / bodyweight 15). Problem: the fixed target makes a 5-rep strength trainee perpetually "miss" 8 → a phantom deload every session (test `:455`/`:136`). Decision target: competence doctrine + anti-guilt/body-neutral + safety overlay. Builds on [[research-10-overload]] (experience-tiered, conservative, suggest-not-prescribe) + [[research-6-calibration]] (early reps = technique-learning) + [[research-12-quests]] (GST difficulty-to-skill). **Codex-reviewed (evidence)** — verdict *needs-attention*, 5 findings folded in below.
- `[validated, peer-reviewed]` **Evidence kills the *universal* fixed target, but does NOT by itself prove median-anchoring** [Codex F1]. Schoenfeld 2021 repetition-continuum re-exam ([PMC7927075](https://pmc.ncbi.nlm.nih.gov/articles/PMC7927075/)): hypertrophy is ~load-agnostic 5–30 reps near failure (volume-equated), but **strength (1RM) and local endurance keep rep-range specificity** → imposing 8 on a demonstrated low-rep trainee is specificity-wrong for their goal; there is no single canonical rep target. The *choice* of replacement (history-anchored range) rests on competitor precedent + product fit, not this paper.
- `[validated]` **The fixed 8–12 IS the evidence-based NOVICE default** ([ACSM Progression Models position stand 2009/2026](https://pubmed.ncbi.nlm.nih.gov/19204579/)): novices → 8–12 RM @ 60–70% 1RM, +2–10% load when 1–2 reps over target; 2026 update = train **near** failure (~2–3 RIR), not to failure. → Keep the kind-constant as the **novice default + sparse-data fallback**; the redesign only stops *imposing* it once the user demonstrates a different range. This is also the safety-conservative path [Codex F5].
- `[validated, double-progression]` Honoring the user's own range = **double progression** (work a range; add reps to the top across sets; then add load, reset to the bottom) — the standard guesswork-free intermediate method ([Legion](https://legionathletics.com/double-progression/), [Hevy Coach](https://hevycoach.com/glossary/double-progression/)) and **exactly Ironbit's existing `targetRepMin/Max` machinery** → reuse it; don't build new progression logic.
- `[validated, competitor-docs; NOT hands-on — narrowed per Codex F2]` Market leaders **don't auto-derive a rep target**: Strong/Hevy auto-fill **previous** weight+reps and let the user drive ([Strong review](https://repreturn.com/strong-app-review/)); Hevy's *target* = user/template "routine values", **distinct** from the "previous" column ([Hevy Help](https://help.hevyapp.com/hc/en-us/articles/34105442929943-Previous-Workout-Values-Vs-Routine-Values-How-to-Adjust-in-Settings)). Auto-suggestion is a niche (Stronglifts linear; RepXP/Dr. Muscle adaptive). → Two viable patterns: **(a) light auto-anchor from history** (the competence-hook, suggest-not-prescribe) or **(b) explicit user-set rep-range/goal** (the actual market pattern). Ironbit already shows "last: w×r", matching the "previous" convention.
- `[risk, per Codex F3]` **Sparse/novice data needs an explicit exclusion model**, not just a 5-set count: working sets only (warm-ups already separated in `ExerciseLog.warmupSets`), ignore partial/failed/outlier sets and stale old logs, anchor over **multiple sessions** (robust median, clamp per kind), else a few bad early logs become a durable wrong target.
- `[risk, per Codex F4]` **Audit the deload branch for the goal-shift / return / injury transition window** — a self-anchored target compared against *stale* history can still mark a user "short" (e.g. just switched 12s→5s; history still 12s). Mitigate by weighting recent sessions / short window so the target follows quickly, and keep miss copy descriptive + neutral (no "failure"), composing with the shipped #8 deload-threshold scaling.
- **Decision feed:** (1) Keep `_repTargetByKind` as the **novice default + sparse-data fallback**; (2) once **≥N sessions** of clean working-set history exist, derive a **target rep RANGE from a robust central tendency, clamped to a per-kind band** (kind sets the band; user's demonstrated reps set the point), feed into the **existing double-progression** path; (3) exclusion model (working-only, drop partial/outlier/stale, recency-weighted); (4) neutral, near-failure-not-failure copy; deload stays optional + descriptive. **Open product fork for the user:** light auto-anchor (default, suggest-not-prescribe) vs an explicit rep-range/goal pick (market pattern, heavier UI). → `/deep-feature` Stage 3+. Links [[research-10-overload]], [[research-6-calibration]].
