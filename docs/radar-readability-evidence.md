# Ironbit Radar Readability Evidence

- Generated: 2026-06-02T07:59:17.370383Z
- Fixture: radar_readability_cases_v1_2026-06-01
- Visible axes: STR, AGI, END
- Dominant lead threshold: 40 points
- Proxy classifier accuracy: 100.0% (9 / 9)
- Proxy pass threshold: > 70.0%
- Distinct class tops: PASS
- No visible dead stat: PASS

These fixture stats are the 20-session class-typical radar cases used by `test/stat_engine_test.dart`; that test verifies the fixture values against the current `StatEngine`.

| Case | Expected | Top Axis | Radar Guess | Lead | Grade Gap | STR | AGI | END | Correct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A1 | ASSASSIN | AGI | ASSASSIN | 176 | 0 | 336 | 512 | 332 | yes |
| A2 | ASSASSIN | AGI | ASSASSIN | 177 | 0 | 371 | 548 | 366 | yes |
| A3 | ASSASSIN | AGI | ASSASSIN | 177 | 0 | 376 | 553 | 366 | yes |
| B1 | BRUISER | STR | BRUISER | 218 | 1 | 564 | 346 | 297 | yes |
| B2 | BRUISER | STR | BRUISER | 219 | 1 | 559 | 340 | 248 | yes |
| B3 | BRUISER | STR | BRUISER | 212 | 1 | 538 | 326 | 286 | yes |
| T1 | TANK | END | TANK | 101 | 0 | 353 | 319 | 454 | yes |
| T2 | TANK | END | TANK | 111 | 0 | 379 | 345 | 490 | yes |
| T3 | TANK | END | TANK | 146 | 0 | 378 | 344 | 524 | yes |
