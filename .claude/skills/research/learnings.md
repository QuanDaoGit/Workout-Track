# Research learnings — recurring failure modes

Maintenance: **generalize, never transcribe** (feature-specific findings stay in the plan/insights doc).
Update an existing category over adding a near-duplicate. Cap ~30 content lines below this header;
when full, prune the least-recently-fired category.

### Single-sourced load-bearing claim
**Rule:** A claim that decides a feature, score, or doctrine must rest on **≥2 independent** sources —
two blogs citing the same study is one source. Corroborate against a primary, or label it
`[single-source]` and lower confidence. *Seeded 2026-06.*

### False-Quick tier selection
**Rule:** A narrow-sounding question that actually shapes the core loop, persistence, safety, or
positioning is **not** Quick. Pick the tier by an up-front observable rule (persisted? feature-shaping?
safety? competitor?), not by a post-hoc "that was easy". When unsure, default Standard. *Seeded 2026-06.*

### Secondary-source agreement mistaken for saturation
**Rule:** Don't declare saturation until a **dissent/limitation query** is on record and **≥1 primary
source** is traced. Echoing secondary sources converge early and hide the contrary evidence, demographic
limits, and recency shifts that flip the answer. **Phrase dissent queries in the *complainer's*
vocabulary, not your taxonomy** — a negative only counts after the folk phrasings are tried (users say
"forced gamification"/"onboarding friction", not "earned progression gate"). *Seeded 2026-06; vocabulary
clause via Codex, feature-drip review (2026-07).*

### Blended field missed → wrong sources (and wrong source *type*)
**Rule:** Most app questions span 2+ fields (a "rewarded warm-up" is exercise-science **and** behavioral
**and** competitor) — route to all. **And every UX/feedback question carries a *context-of-use* leaf**
(where/when it fires, what else occupies that channel): a gym feature's audio competes with the user's
own earbuds music/podcast — a whole listening-context dimension the field sweep missed until Codex
flagged it (interaction-SFX review, 2026-07); enumerate the channel's competing occupants before
designing into it. Also match the source **type** to the question: a **craft / how-it-
should-look-or-be-built** question needs technique sources (tutorials, breakdowns), **not stock-asset /
catalog listings** — those name the artifact, they don't teach it. And **verify the deliverable actually
embodies the craft** (a "pixel-art" mock with rounded corners + a blur glow doesn't). *Seen: a "best bar"
pass treated stock-image hits as pixel-art evidence and shipped a soft, non-pixel mock until the user
pushed back (2026-06).*

### Safety/injury routed as general training
**Rule:** Pain/injury/rehab/contraindication/pregnancy/age claims are the **Safety/clinical overlay** —
authoritative clinical source required, demographic + recency captured, and a hard **no-diagnosis /
no-prescriptive-medical-advice** boundary. Never let a blog carry a safety claim. *Seeded 2026-06.*

### Mechanism (or reuse precedent) transferred without its precondition
**Rule:** A cited mechanism — **or a same-app / *competitor* precedent you reuse** — only transfers if
its **precondition / context holds in the target**. Check the boundary before importing: competence-
feedback presupposes a prior *act* (invalid pre-action); "verbal/human reward" ≠ a *fictional agent*; a
lab effect ≠ a 2-second beat; a precedent from one UI context is the wrong authority for another (chat
bubble → in-world balloon ABOVE, tail down); **a competitor *having* a feature ≠ it belongs at *our*
surface/moment — its placement + framing are part of the precondition** (a recovery-framed map in a tab
≠ a trophy on a single-peak finish screen). State the precondition + whether it holds, or downgrade to
analogical. *Seen: CET/CHI findings on a pre-action onboarding screen; BIT's chat-bubble layout reused
in-world; Fitbod/Hevy muscle-map precedent over-read into finish-screen placement until Codex split
"feature exists" from "belongs here" (2026-06).*

### Metric/instrumentation research without a measurement contract
**Rule:** Before recommending *what to track*, define the **measurement contract**: population/denominator
(esp. under opt-out analytics — opt-out-rate shifts masquerade as metric moves), exact definition + timezone
+ cohort anchor, and **terminal/recovery states** (a missing success event ≠ failure: app-kill/crash/offline-
batch/recovery aren't abandonment). Treat activation/retention "drivers" as correlation → label hypotheses,
not causes. *Seen: a retention-instrumentation pass had the right events but under-grounded denominators,
weekly-metric definitions, and the abandonment lifecycle until Codex flagged all three (2026-06).*
