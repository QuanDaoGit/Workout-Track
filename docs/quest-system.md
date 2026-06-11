# Ironbit - Quest System

> **Purpose.** A self-contained explanation of how Ironbit's quests work, for someone who can see
> the app screenshots but has no access to the code. Numbers are the current shipped values for the
> earned-gem quest economy.

---

## 1. What Quests Are

Quests are Ironbit's return ritual: open the app, see what your character can earn today, train for
real, then claim the reward. They support three long-term hooks:

- **Ritual return:** daily and weekly resets give the user a reason to check in.
- **Competence growth:** objectives mirror real training behavior.
- **Collection desire:** side quests still grant permanent titles, and quest gems can unlock
  cosmetic frames/themes early.

Quests are auto-evaluated from real workout history. There is no manual "Done" button for anything
the app cannot verify. The only manual action is claiming a completed quest reward.

---

## 2. Buckets

| Bucket | Resets | Purpose | Reward |
|---|---|---|---|
| Daily | every day at 00:00 | show-up nudges | gems |
| Weekly | every Monday | weekly cadence | gems |
| Side | never | lifetime milestones | gems + title |

Each bucket is a fixed template list. Completion is recomputed from stored sessions. Daily and
weekly quests become claimable again in each new period; side quests are claimable once ever.

---

## 3. Daily Quests

Daily quests reset every calendar day and award **5 gems each**.

| Quest | Description | Completes when | Gems |
|---|---|---|---:|
| Show Up | Complete any workout today. | at least 1 completed workout today | 5 |
| Class Focus | Train one of your class focus groups. | today's completed workout targeted a class-focus group | 5 |
| Volume Floor | Log 1,000 kg total volume today. | today's total volume is at least 1,000 kg | 5 |

Class-focus groups:

| Class | Focus |
|---|---|
| Assassin | Shoulders + Core |
| Bruiser | Chest + Back + Arms |
| Tank | Legs |
| Vanguard | all groups count |

---

## 4. Weekly Quests

Weekly quests reset Monday at 00:00 and award a fixed weekly sweep of **50 gems**.

| Quest | Description | Completes when | Gems |
|---|---|---|---:|
| First Quest | Complete 1 workout | at least 1 workout this week | 5 |
| Second Quest | Complete 2 workouts | at least 2 workouts this week | 5 |
| Set Smith | Log 10 total sets | at least 10 sets this week | 10 |
| Balanced Path | Train 2 muscle groups | at least 2 distinct target groups this week | 10 |
| Hour Trial | Train 60 total minutes | at least 60 minutes this week | 20 |

The Weekly section also shows a five-segment progress bar, one lit segment per completed weekly
quest.

---

## 5. Side Quests

Side quests are lifetime milestones. They award **100 gems each** and still grant their existing
title reward.

| Quest | Description | Completes when | Title reward | Gems |
|---|---|---|---|---:|
| First Forge | Complete your first workout | at least 1 lifetime workout | Iron Novice | 100 |
| Set Smith | Log 25 total sets | at least 25 lifetime sets | Set Smith | 100 |
| Time Trial | Train 300 total minutes | at least 300 lifetime minutes | Time Keeper | 100 |
| Four Guilds | Train Chest, Back, Arms, and Legs | at least 4 distinct target groups lifetime | Guild Walker | 100 |
| Iron Ledger | Reach 10,000 kg total volume | at least 10,000 kg lifetime volume | Volume Knight | 100 |

Titles remain achievement-only. They cannot be purchased with gems.

---

## 6. Gems And Legacy XP

New quest claims award gems and write `xp: 0` into the claim record. The gem ledger is separate:
quest gem awards are idempotent by claim key, so retrying a claim cannot duplicate gems.

Legacy quest claims that already stored XP still count toward total XP. This prevents existing users
from losing levels. Going forward, workout XP, recovery XP, XP potions, and cache XP remain the XP
sources; quests are the earned-gem source.

---

## 7. Claim Lifecycle

```text
trains for real -> engine recomputes from session history
        |
        v
COMPLETED (auto) -> tap claim -> CLAIMED -> gems added to local ledger
        |                              |
   "+N GEMS" button                    + side quests also grant title
```

- A quest is claimable only when `completed && !claimed`.
- Claiming records the gem amount, timestamp, and optional title.
- The confirmation copy is `Claimed +N gems`.
- Daily and weekly claims are keyed by their period; side quest claims are lifetime keys.

---

## 8. Inventory Relationship

Gems are local-only and earned-only. There is no IAP, billing, subscription, paid pack, or server
economy in this version.

Frames and themes may have gem prices so the user can buy them early from Inventory:

| Type | Item | Gems |
|---|---|---:|
| Frame | Stone | 150 |
| Frame | Bronze | 300 |
| Frame | Silver | 600 |
| Frame | Gold | 1200 |
| Frame | Neon | 2000 |
| Frame | Inferno | 3500 |
| Frame | Void | 6000 |
| Theme | Stone | 300 |
| Theme | Forest | 1200 |
| Theme | Inferno | 3500 |

Default frame/theme items remain free. Deterministic milestone unlocks still exist; gem purchases
are early cosmetic unlocks, not the only way to acquire cosmetics.

---

## 9. Data Sources

All completion checks read completed sessions, bucketed into today, this week, or lifetime:

| Metric | Meaning |
|---|---|
| workouts | count of completed sessions in the period |
| sets | total logged set rows across those sessions |
| muscle groups | count of distinct target muscle groups chosen for those workouts |
| minutes | sum of actual session durations |
| volume | sum of logged `reps * weight` across all sets |
| class focus | whether a session target group is in the class focus set |

Partial and abandoned sessions do not complete quests. Week boundaries are Monday-based.

---

## 10. Screen Copy

Each quest card shows title, description, progress, and one of:

- `+N GEMS` when claimable
- `CLAIMED` once claimed
- `+N` with the earned-gem icon when incomplete

The Home mission reward chip also uses gem copy for quest rewards. Live workout XP remains XP.

