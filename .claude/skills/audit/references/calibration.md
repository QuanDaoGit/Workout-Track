# Calibration corpus (the recall gate)

Codex F4: a clean audit result is only trustworthy if the workflow *can* catch the defect classes it
claims to. Before trusting a run (first run, or after big UI churn), seed these **known** defects and
confirm each is caught. If one is missed, fix the checklist/grounding/oracle **before** auditing real
surfaces. Keep these in a scratch branch or a temp scenario — they are deliberately wrong, do NOT
commit them to the app.

This corpus measures two numbers per run: **recall** (knowns caught / knowns) and **false-positive
rate** (flags on a known-good surface / total flags). Track them; a workflow change that lifts recall
but floods false positives is not an improvement.

## The four seeds (one per non-deterministic track + one lint)

| # | Class | Seed (deliberately break this) | Must be caught by |
|---|---|---|---|
| 1 | **Slop / hierarchy** | a temp scenario of a real page with one card given `EdgeInsets.all(3)` instead of `kSpace3`, and a heading dropped to `bodySmall` | Presentation pass on the PNG |
| 2 | **Token violation (lint)** | a `Container(color: Color(0xFF123456))` in a real widget | Deterministic lint grep — must fire with no model judgment |
| 3 | **Stale-state bug** | save a session via the real API, then mutate the cached `combat_stats` blob so the meter total disagrees with its rollup | State track (cache-vs-source-of-truth) |
| 4 | **Formula bug** | an off-by-one in an e1RM/volume helper fixture (e.g. `reps` instead of `reps-1` in Epley) | Correctness oracle (docs known-answer + invariant), NOT code-reading |

## Pass bar

- All 4 caught ⇒ the workflow is calibrated for this run; proceed to real surfaces.
- Any missed ⇒ the corresponding track is currently **blind**. Report "track X uncalibrated — clean
  result is NOT trustworthy" and fix before continuing. Never emit a "clean" verdict on an
  uncalibrated track.

Add a new corpus row whenever a real audit later finds a class these four didn't represent (so the
gate grows to cover every miss the workflow has ever made — see `learnings.md`).
