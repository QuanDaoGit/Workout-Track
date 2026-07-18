# Rest-Day Recovery Insights

Date: 2026-07-18
Status: Approved direction, spec for review
Owner surfaces: `app/lib/pages/home.dart` (both recovery mission cards)

## Problem

The blue KEEP RESTING button on the program recovery card (`_buildProgramRecoveryMissionPanel`, home.dart:1821) shows a transient "Recovery day in progress." notice and nothing else. Users read it as broken. The non-program recovery card (`_buildRecoveryMissionPanel`, home.dart:1949) has no primary action at all. Recovery XP already auto-grants in the background (`RestService.ensureAutomaticRecoveryForToday`), so there is no pending reward for the button to collect.

## Decision

The button opens a bottom sheet where BIT delivers one recovery insight per rest day, drawn from a curated pool of 30 to 40 short, accurate recovery facts. Each rest day surfaces an insight the user has not seen before, until the pool is exhausted, then the rotation wraps with honest framing. No XP, no streak mention, no training nudge.

Research basis (deep-research run, 2026-07-18, 26 sources, 22 verified claims): perceived competence is the strongest single driver of intrinsic motivation in fitness apps (JMIR SEM, beta = .346), intrinsic motivation is what predicts continued use, and a rest-day surface must not add reward pressure or streak guilt. A small learning moment fits all three constraints. Novelty ("new info each rest day") gives a real reason to open the app on a low-intent day without nudging anyone to train.

## What ships (v1)

### 1. Content pool: `app/lib/data/recovery_insights.dart`

A const list of `RecoveryInsight` entries, following the `bit_room_copy.dart` pattern (const pool + pure picker, unit-testable).

```dart
class RecoveryInsight {
  final String id;        // stable, e.g. 'sleep_growth_window'
  final String category;  // sleep | fuel | adaptation | mobility | mind
  final String text;      // BIT-voiced, 1-3 sentences, plain language
}
```

Content rules:
- Accurate, mainstream recovery science only. No contested claims, no supplement pushing.
- Body-neutral per the PRD mandate. No weight, appearance, or calorie framing.
- BIT's voice: short, warm, a little wry. Reads like the existing room advice lines, one register up in substance.
- Never a training nudge and never guilt. "Your muscles are rebuilding today" is fine. "Don't lose momentum" is banned.
- 1 to 3 sentences. The sheet is a glance, not an article.

Sample entries (the full pool of 30 to 40 gets drafted at implementation and reviewed as content):

- (adaptation) "Training breaks you down. Rest is when the rebuild happens. Today the construction crew is on site."
- (sleep) "Most muscle repair runs during deep sleep. Tonight's sleep is part of the program."
- (fuel) "Protein still matters on rest days. The rebuild needs materials."
- (adaptation) "Feeling sore two days after? That's DOMS. It's adaptation working, not damage."
- (mind) "Recovery isn't the absence of training. It's the half of training you can't see."
- (mobility) "A short walk today speeds recovery. Blood flow carries the repair supplies."

### 2. Rotation: `app/lib/services/recovery_insight_service.dart`

Owns one SharedPreferences key, `recovery_insight_state_v1`, per the one-service-one-key convention. State: `{ seenIds: [...], lastShownId, lastShownDayKey }`.

Selection logic, pure and injectable (`nowProvider` for tests):
- Same day, reopened: return `lastShownId` (stable within a day, no slot-machine feel).
- New rest day: pick deterministically from the unseen set, seeded by an FNV hash of the day key (the Quest and Guild rotation pattern). Record it as seen.
- Pool exhausted: clear the seen set and continue rotating, with the sheet noting the wrap once ("You've heard the full briefing. Refreshers from here.") so the "new" promise stays honest.

### 3. Surface: `app/lib/widgets/recovery_insight_sheet.dart`

A bottom sheet in the calm recovery register (cyan `kRecoveryAccent`, `ArcadeCard` idiom):
- A faced `BitMoodCore` (neutral, idle float), the canonical `BitSpeechBubble` carrying the insight text.
- A small category tag (e.g. `SLEEP`) in ShareTechMono, muted.
- One dismiss affordance. No secondary actions in v1.
- Reduced motion: static BIT, no entrance animation. Screen reader: the insight text is the semantics source.

### 4. Wiring in `home.dart`

- Program recovery card: `onPrimary` opens the sheet. Button label changes from KEEP RESTING to `RECOVERY BRIEFING` (the button now delivers something, the label should promise it).
- Non-program recovery card: gains the same primary button and sheet. TRAIN ANYWAY stays secondary on both.
- The old `showArcadeNotice` call is deleted.

## Explicitly out (deferred, not rejected)

- The optional 60-second mobility flow link (reuse of `warmup_sheet.dart`). Phase 2 candidate.
- Personalized insights (class, VIT, recent training references). The `id`/`category` structure leaves room.
- A "how do you feel" check-in. Separate feature with its own data questions.
- Any reward attached to opening the sheet. Recovery XP stays auto-granted and silent.

## Guardrails (hard constraints)

- No XP, gems, streaks, or claim mechanics anywhere in this feature.
- No copy that frames rest as a risk, a gap, or a thing to push through.
- One insight per day. Reopening shows the same one.
- The sheet must work offline and with an empty history (new user on a program that starts with rest).

## Testing

- `recovery_insight_service_test.dart`: same-day stability, new-day advance, determinism for a fixed day key, exhaustion wrap, corrupt-state recovery (bad JSON resets cleanly, no crash).
- Content invariant test, following the room-copy pattern: every insight id unique, text non-empty, category in the allowed set, and a banned-word check (no "streak", "don't skip", "burn", "calories", "weight") to enforce the guardrails at the pool level.
- Widget test: sheet renders an insight, dismisses, respects reduced motion.
- `flutter analyze` clean, existing tests green.

## Risks

- Content quality is the feature. A wrong or preachy fact erodes trust in BIT. Mitigation: the pool ships as reviewable content in one file, with the invariant test as a floor and human review as the bar.
- The "new each rest day" promise degrades at pool exhaustion. Mitigation: honest wrap copy, and the pool size (30 to 40, consumed 2 to 3 per week) gives months of runway; extending the pool later is a one-file edit.
