# Radar Readability Validation

Last verified against code: 2026-06-02.

## Goal

The character radar is successful only if a person can read the visible stat shape quickly:

- STR-led radar should read as Bruiser training.
- AGI-led radar should read as Assassin training.
- END-led radar should read as Tank training.
- No visible stat should look dead for class-focus training.

The automated tests prove the engine can produce separated shapes. Human readability still needs a blind-read check.

## Study Artifact

Use:

```text
tool/radar_readability_study.html
```

For a portable folder that can be copied to another machine, run:

```text
dart tool/radar_readability_bundle.dart
```

This creates:

```text
build/radar_readability_study/
```

The bundle contains the study HTML, required local fonts, a participant-safe instruction sheet, a facilitator checklist, a receipts folder, and a short `README.txt`. You can also pass a custom output directory:

```text
dart tool/radar_readability_bundle.dart C:\Users\you\Desktop\radar-study
```

The study profiles live in:

```text
tool/radar_readability_cases.json
```

The HTML embeds the same fixture, and `test/stat_engine_test.dart` verifies the embedded cases match the JSON fixture and the current `StatEngine` outputs. If the engine changes, update the fixture and HTML together or the test should fail.

The page gives a one-time class key before the trial set:

- `ASSASSIN` = AGI-led profile
- `BRUISER` = STR-led profile
- `TANK` = END-led profile

Each trial then shows only the radar shape and axis labels (`STR`, `AGI`, `END`) for exactly five seconds. Per-profile helper copy such as `STR POWER`, `BUILD: POWER`, or class labels is intentionally absent from the exposure. After the radar disappears, the participant must guess:

- Assassin
- Bruiser
- Tank
- Not sure

The participant-facing study screen must not show the `>70%` pass threshold before trials; that target belongs in this validation document and scorer output only.

The artifact asks for a non-identifying participant code. If the field is blank, it generates one. The code is saved as `participantId` in the JSON receipt and included in the download filename.

## Protocol

1. Open `tool/radar_readability_study.html` in a browser, or open the bundled `radar_readability_study.html` created by `dart tool/radar_readability_bundle.dart`.
2. Enter a non-identifying participant code such as `P01`. Do not use real names.
3. Do not explain the hidden class for any profile.
4. Give the participant `PARTICIPANT_INSTRUCTIONS.txt`, or tell them only: "Learn the class key on the first screen. Then you will see each Ironbit stat radar for five seconds. Guess the hidden class using only the radar shape and axis labels."
5. Run the full nine-profile set.
6. Download the JSON result.
7. Repeat with enough participants to reduce one-person bias. A minimum useful smoke test is five distinct participants; a stronger pass is 10 or more.

## Scoring Receipts

Before collecting human receipts, generate the automated evidence report:

```text
dart tool/radar_readability_report.dart docs/radar-readability-evidence.md
```

This report summarizes the current fixture's visible axes, top stat per class, lead size, grade gap, and radar-only proxy accuracy. It is still proxy evidence; it does not replace the human blind-read gate.

Score downloaded receipts with:

```text
dart tool/radar_readability_score.dart <result.json> [more-results-or-directories]
```

To save a durable Markdown result for review:

```text
dart tool/radar_readability_score.dart <receipt-folder> --write-report docs/radar-readability-results.md
```

Examples:

```text
dart tool/radar_readability_score.dart C:\Users\you\Downloads\ironbit-radar-readability-results.json
dart tool/radar_readability_score.dart C:\Users\you\Downloads\radar-study-results
dart tool/radar_readability_score.dart C:\Users\you\Downloads\radar-study-results --write-report docs\radar-readability-results.md
```

For a one-command audit that checks the fixture, HTML study artifact, and human receipts together:

```text
dart tool/radar_readability_audit.dart <receipt-folder> --write-report docs/radar-readability-results.md
```

For the full goal gate, including automated engine/UI proxy tests plus the artifact/receipt audit:

```text
dart tool/radar_readability_goal_gate.dart <receipt-folder> --write-report docs/radar-readability-results.md
```

If you only need to verify the local fixture and HTML artifact before collecting participants:

```text
dart tool/radar_readability_audit.dart --artifact-only
dart tool/radar_readability_goal_gate.dart --artifact-only
```

The scorer:

- requires the expected study id
- requires `mode = radar_only_v1`
- requires the current fixture version
- requires the expected protocol hash covering the study id, mode, fixture version, exposure time, visible axes, dominant-axis threshold, and all fixture case stats/classes
- requires a non-empty `participantId`
- rejects duplicate participant IDs across the scored files
- requires valid `startedAt` and `completedAt` timestamps
- rejects receipts whose elapsed time is shorter than the nine required five-second radar exposures
- requires `exposureMs = 5000`
- requires each response to include `radarExposureMs >= 4900`
- requires response `trialIndex` values to be exactly `1..9` in receipt order
- requires all nine responses per participant
- rejects duplicate or missing radar case IDs; every fixture case must be covered exactly once
- counts `NOT SURE` as incorrect
- validates every response against the current fixture case id, class, and STR/AGI/END values
- recomputes `correct`, `total`, and `accuracy` from responses and rejects mismatched top-level receipt summaries
- reports aggregate accuracy, participant count, per-participant accuracy, per-class accuracy, response timing, and misses
- exits with code `0` only when aggregate accuracy is greater than `70%` and at least five participant receipts are present

The audit command also checks the protocol-defining HTML contract: the `390x844` frame, radar canvas dimensions, class-key mappings, four guess choices, five-second exposure timer, radar hiding before guesses, receipt payload fields, and executable study-script syntax when Node is available. The test suite also runs the study script in a lightweight Node harness to verify the start-trial, timed-hide, guess, and receipt-emission path. The audit exits with code `0` only when both artifact checks and receipt scoring pass. Without receipts, it fails by design unless `--artifact-only` is used.

The goal gate command runs the focused automated tests first (`stat_engine`, `stat_card`, `stat_radar_read`, and the study-script runtime harness), then runs the audit. `--artifact-only` mode is useful before collecting participants, but it is not completion evidence because it skips human receipts.

## Pass Criteria

The goal criterion is:

```text
accuracy > 70%
```

Count `NOT SURE` as incorrect. Do not remove failed profiles from the denominator. Product-level evidence requires at least five distinct `radar_only_v1` participant receipts scored together; one clean receipt is a smoke test, not proof.

The current automated proxy uses the same threshold, but it is not a substitute for human evidence:

```text
flutter test test/stat_engine_test.dart
```

Specifically:

```text
radar-only classifier reads class-typical variants above seventy percent
```

## Current Class-Shape Invariant

The study cases intentionally use only visible radar stats:

| Axis | Intended read |
|---|---|
| STR | Bruiser |
| AGI | Assassin |
| END | Tank |

The UI highlights a dominant axis only when the top stat leads the second stat by at least `40` points. This keeps noisy near-ties from pretending to be a clear class shape.

The visible axes, dominant-lead threshold, and axis-to-class readability mapping are centralized in `lib/models/stat_radar_read.dart`. The app UI, fixture report, scorer, and audit all read that same contract.

## What To Do If The Study Fails

If human accuracy is below threshold, fix the artifact being read, not the test:

- Increase separation in the stat engine only if the training data truly warrants it.
- Improve axis label placement, contrast, or dominant-axis emphasis.
- Add a short in-app explanatory line near the stat board only if it does not name the user's class directly.
- Do not add class labels to the radar itself; that would invalidate the blind-read goal.

## Evidence Status

As of 2026-06-02:

- Engine proxy: present and passing.
- UI dominant-axis proxy: present and passing.
- Human blind-read evidence: not collected yet.
