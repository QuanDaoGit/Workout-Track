# Research techniques — the transferable craft

The grounding behind these is in the plan doc; the working rules:

## Decomposition — a bounded issue tree (Standard / Deep)
Hierarchical decomposition is the same tool consulting calls an *issue/hypothesis tree* (MECE), AI
calls an *AND-OR tree* (branch-and-bound / alpha-beta), and LLM agents call *Tree of Thoughts* — three
unrelated fields converge on it. Its efficiency comes **entirely from pruning, never from completing
the tree**: expand one level, score each branch by **decision-relevance + uncertainty**, prune the
known/irrelevant, deepen only what one query can't settle (≤1 recursion by default). SKILL.md Stage 1
has the operational steps; this is *why*, plus the three ways it misleads:
- **Non-separability** *(analogical caution, imported from optimization — not a proven
  research-methodology law):* if branches actually interact, a clean MECE tree **hides** the
  cross-cutting issue. When dimensions look coupled, add a cross-cutting leaf instead of forcing a split.
- **Over-decomposition (granularity gap):** atomic leaves lose meaning. Stop when a leaf is one
  targeted query away from an answer.
- **Recombination cost:** splitting then re-synthesizing isn't free — never decompose a question that
  was already directly searchable.

*(Sources: McKinsey-style MECE issue/hypothesis trees; AND–OR trees & branch-and-bound; Tree of
Thoughts arXiv 2305.10601; PruneRAG per-node decomposition-confidence scoring.)*

## Query formulation (operators)
Turn a vague question into a precise query by **stacking operators**:
- `"exact phrase"` — lock a term of art (e.g. `"minimum effective volume"`).
- `site:` — restrict to a trusted domain (`site:pubmed.ncbi.nlm.nih.gov`, `site:nngroup.com`, `site:reddit.com`).
- `filetype:pdf` — jump to the actual paper/report, not a summary of it.
- `OR` / `-` — widen synonyms (`hypertrophy OR "muscle growth"`) or exclude noise (`-supplement`).
- `intitle:` — demand the term in the title for on-topic precision.
- **Stack them:** `"resistance training" "meta-analysis" filetype:pdf -supplement`.
- **Refine iteratively:** first query maps the space; later queries narrow using the vocabulary the
  results taught you (the real term of art, the key author, the canonical study).

## Tool routing (cheapest-correct first)
- **context7 MCP** for any library/framework/API doc — current and precise; beats crawling.
- **WebSearch** for web knowledge — the *result summaries* often answer it; don't fetch reflexively.
- **WebFetch** only to read a full page for a **load-bearing or contested** claim.
- **The product itself / app store / Reddit** for competitor reality.
- **Parallelize** independent searches in one message; serialize only when a query depends on the last.

## Source evaluation — SIFT first, then deeper
**SIFT** (fast, do this every time):
1. **Stop** — don't trust on sight; note what you actually need from this source.
2. **Investigate the source** — who/what is it, what's its agenda? (One lookup.)
3. **Find better coverage** — is there a stronger source for the same claim? Prefer it.
4. **Trace** claims/quotes/data to the **original** context — summaries distort.

**Lateral reading** — judge a source by what *other* sources say about it (open new tabs), not by how
polished it looks. Professional fact-checkers read laterally, not vertically.

**CRAAP/RADAR** (slower, for a key source you'll lean on): Currency, Relevance, Authority, Accuracy,
Purpose. Use when a single source is about to carry real weight.

## Evidence grading
- Climb the hierarchy where it exists (exercise/clinical): **meta-analysis/systematic review > RCT >
  cohort > case/expert opinion** — but a **well-run lower study beats a poorly-run higher one** (design
  quality matters more than label).
- **Grade and label** each claim in the output: `[established]`, `[contested]`, or `[single-source]`,
  plus a confidence note.

## Triangulation & the contrary-evidence guardrail
- **Never single-source** a load-bearing claim — corroborate with **≥2 independent** sources (not two
  blogs citing the same study).
- **Actively seek dissent:** for each load-bearing claim run **≥1 query for limitations/criticism**
  and **trace ≥1 primary source**. Agreement among similar *secondary* sources is **not** confirmation.
- For exercise/behavioral studies, record **demographic validity** (trained vs untrained, sex, age)
  and **recency** — both flip applicability for this app's beginner→intermediate, body-neutral users.

## When to stop — saturation vs satisficing
- **Saturation:** stop when new searches stop surfacing new load-bearing facts — **but only after the
  dissent query is on record** (early agreement is a false floor).
- **Satisficing:** match effort to the tier's "good enough" bar (bounded rationality). A Quick fact
  check doesn't earn a literature review; a doctrine-shaping claim doesn't get to stop at one blog.
- Name the diminishing-returns call explicitly instead of crawling forever.

## Synthesis shape
Group findings **per sub-question**. Each finding:
`claim — [grade] — confidence — caveat/tension — [source](url)`.
Call out conflicts and the app's recurring **accuracy-vs-hook** tension. End with what's still **unknown**.
