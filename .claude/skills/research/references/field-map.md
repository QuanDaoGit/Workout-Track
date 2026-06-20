# Field map — detect the field, then research it right

> Source lists dated **2026-06-15**. Flag as stale on sight; refresh periodically.
> This file **points to** canonical doctrine — it does not restate it (see "Lenses" below).

Match the problem text against the **signals** column. Most Ironbit questions **blend 2+ fields** —
research each and weight effort by how load-bearing it is to the decision. **Safety/clinical is an
overlay**: when its signals appear, it fires *in addition to* whatever else matched and **forces the
Deep tier**.

## The fields

### 1. Exercise science
- **Signals:** volume, intensity, frequency, hypertrophy, strength, recovery, warm-up, 1RM/e1RM,
  detraining/decay, progression, periodization, rep ranges, rest intervals.
- **Sources:** PubMed/PMC, systematic reviews & meta-analyses, Sports Medicine / JSCR / MSSE,
  Stronger By Science, MASS (Monthly App Sci/Strength research review).
- **Evidence bar:** systematic review/meta-analysis > RCT > cohort > case/expert opinion — but a
  well-run lower study beats a poor higher one (design quality matters). **Stop** when independent
  reviews converge.
- **Query idioms:** exact phrases + `site:pubmed.ncbi.nlm.nih.gov` or `site:ncbi.nlm.nih.gov/pmc`;
  `filetype:pdf` for the paper; add `meta-analysis` OR `systematic review` to climb the hierarchy;
  add `resistance training` / the specific population to disambiguate.

### 2. Behavioral / gamification / habit
- **Signals:** motivation, streak, retention, reward, identity, loss aversion, over-justification,
  intrinsic vs extrinsic, SDT (autonomy/competence/relatedness), variable reward, habit loop, churn.
- **Sources:** peer-reviewed psychology / behavioral economics, Self-Determination Theory literature,
  Duolingo research/engineering blog, Nir Eyal *Hooked*, BJ Fogg behavior model, Duke/CHB labs.
- **Evidence bar:** peer-reviewed mechanism > pop-sci summary. Triangulate the *mechanism*, not just
  the claim. Beware lab-vs-field gaps and WEIRD-sample limits.
- **Query idioms:** name the mechanism (`self-determination theory exercise adherence`); add
  `randomized` / `field study`; `site:scholar.google.com` to find the primary paper behind a blog.

### 3. Competitor / market
- **Signals:** "how does Strong / Hevy / Fitbod / Duolingo / Habitica / Zombies Run do X", feature
  precedent, pricing model, onboarding flow, what's standard in tracker/habit apps.
- **Sources:** **the product itself** (screenshots, the app, its docs/changelog), product teardowns
  (LogRocket, Mobbin, growth blogs), app-store listings & reviews, subreddits (r/fitness, the app's sub).
- **Evidence bar:** the **product is the primary source** — corroborate second-hand claims against it.
  A teardown blog is secondary; a Reddit anecdote is a signal, not proof.
- **Query idioms:** `"<app>" <feature> site:reddit.com`; `<app> teardown`; app-store `<app> reviews`;
  the app's own `site:<app>.com` changelog/help. Reverse-engineer: flows → feature priority →
  onboarding-to-aha → retention loop.

### 4. UX / design pattern
- **Signals:** onboarding, empty/error/loading states, data-viz, mobile pattern, accessibility,
  reduced-motion, information hierarchy, gamified UI conventions.
- **Sources:** Nielsen Norman Group (NN/g), Laws of UX, Material 3, Apple HIG, WCAG, gov.uk design.
- **Evidence bar:** reputable UX research / platform guidance. **Defer the in-app *look* to
  `ironbit-design`** — this field gathers evidence/precedent, not pixels.
- **Query idioms:** `site:nngroup.com <pattern>`; `<pattern> mobile best practice`; `WCAG <topic>`.

### 5. Technical / Flutter
- **Signals:** package, plugin, platform API, build, performance, state management, Dart/Flutter idiom,
  SharedPreferences, animation/render specifics.
- **Sources:** **context7 MCP** (use it first — current docs, precise, cheap), pub.dev, docs.flutter.dev,
  api.flutter.dev, GitHub issues, Stack Overflow.
- **Evidence bar:** official docs / a maintained package; **version-correct** for this app's pinned
  Flutter/Dart. Prefer a current GitHub issue over an old SO answer.
- **Query idioms:** context7 by library name first; then `<error> site:github.com`,
  `<package> site:pub.dev`, `flutter <topic> site:docs.flutter.dev`.

### 6. Safety / clinical — OVERLAY (fires alongside any field; forces Deep)
- **Signals:** pain, injury, rehab/prehab, contraindication, medical condition, pregnancy/postpartum,
  youth / older-adult training, overtraining, RED-S, fatigue management, exertion limits, "is it safe to…".
- **Sources:** sports-medicine & clinical guidelines (ACSM, NSCA position stands, physio bodies),
  systematic reviews in clinical journals.
- **Evidence bar:** **authoritative clinical source required** — no blogs for a safety claim. Extract
  **demographic validity + recency**. **Hard boundary: no diagnosis, no prescriptive medical advice** —
  the app educates and defers users to professionals; research output must respect that line.

## Lenses (apply to every finding — do NOT restate doctrine here)
Judge findings against the app's non-negotiables. The **canonical sources** are:
- `research/CLAUDE.md` — body-neutral mandate, the competitive wedge (earned character attachment +
  offline/private + arcade identity), fact-vs-assumption tagging.
- Root `CLAUDE.md` → "Product doctrine" — the soul hooks (identity, competence, collection, ritual,
  recovery) and the design constraints.

If those docs change, this file's lens references follow them automatically — never hard-fork the
doctrine into here. **Maintenance:** every persisted insight in `research/insights.md` links back to
**(a)** the decision it informed and **(b)** the canonical doctrine section it was judged against.
