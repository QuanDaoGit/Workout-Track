# Ironbit — Program System

> **Purpose.** A self-contained explanation of how Ironbit's training-program system works, for an
> agent that has the screenshots but **no access to the codebase**. Everything is explained inline.
> Values are the actual shipped data as of 2026-06-02 (pre-launch, no live data).

---

## 1. What programs are, and why they exist

A **program** is an optional, structured training plan that replaces ad-hoc "what should I train
today?" decisions with a guided, ordered weekly schedule. When a program is active, the app knows
what *today's* session should be, pre-selects the muscle groups, and pre-fills a curated set of
exercises.

**Intention (how it serves the product doctrine):**
- **Ritual return** — there is always a clear "today's day," so opening the app has an obvious next
  action.
- **Competence growth** — beginners get a sensible path instead of a blank picker; the schedule
  itself is the structure.
- **Lower decision friction** — choosing exercises is the part people stall on; the program does it.

**Hard rules:**
- Programs are **strictly opt-in**. The manual Start-Workout flow is always available; a program
  just *prefills* it.
- **Only one program is active at a time.**
- A program **never changes how a workout is scored.** A program session is a normal logged workout
  — stats, XP, quests, and overload all treat it identically. The program layer only picks
  *targets/suggestions* and tracks *where you are in the schedule*.

---

## 2. The three programs (the catalog)

There are three built-in programs. Each is a fixed **7-slot weekly cycle** mixing workout and rest
days.

| Program | Tier | Days/week | Recommended | The 7-day cycle |
|---|---|---|---|---|
| **Full Body 3×** | Beginner | 3 | 8 weeks | A · rest · B · rest · C · rest · rest |
| **Upper Lower** | Intermediate | 4 | 8 weeks | Upper · Lower · rest · Upper · Lower · rest · rest |
| **Push Pull Legs** | Intermediate/Advanced | 6 | 8 weeks | Push · Pull · Legs · Push · Pull · Legs · rest |

Tier drives a color badge: anything containing **ADVANCED** → red, **INTERMEDIATE** → amber,
otherwise → cyan.

**Full descriptions (shown in-app):**
- *Full Body 3×* — "Three balanced training days with recovery between runs."
- *Upper Lower* — "Four focused sessions split between upper and lower body."
- *Push Pull Legs* — "Six-day gym split for repeatable strength practice."

---

## 3. Anatomy of a program

A **Program** holds: `id`, `name`, `description`, `tier`, `daysPerWeek`, `recommendedWeeks`, and a
**`weekSchedule`** — an ordered list of **ProgramDay** entries (one per slot in the cycle).

A **ProgramDay** holds:
- `dayNumber` (1–7), `label` (e.g. "PUSH", "FULL BODY A", "REST"),
- `type` — **workout** or **rest**,
- `focus` — a *muscle-focus* tag (only on workout days),
- **`suggestedExerciseIds`** — the day's **exercise bucket**: a curated list of specific exercises.

### 3.1 Focus → muscle groups (what a workout day actually targets)

Each workout day's `focus` maps to canonical target muscle groups (the same buckets the Start
Workout chips use) and to a human focus summary:

| Focus | Target muscle groups | Summary shown |
|---|---|---|
| **push** | Chest, Shoulders, Arms | "chest – shoulders – triceps" |
| **pull** | Back, Arms | "back – biceps" |
| **legs** / **lower** | Legs | "legs" |
| **upper** | Chest, Back, Shoulders, Arms | "chest – back – arms" |
| **fullBody** | Full Body | "chest – back – legs – arms" |
| **shouldersCore** | Shoulders, Core | "shoulders – core" |
| *(rest day)* | — | "recovery scheduled" |

*(The focus enum also defines `chestTriceps`, `backBiceps`, and `shouldersCore` for future splits;
the three shipped programs only use push/pull/legs/upper/lower/fullBody.)*

### 3.2 The exercise bucket

Every workout day carries **5 curated exercise IDs** (real catalog exercises, e.g.
`Barbell_Bench_Press_-_Medium_Grip`, `Wide-Grip_Lat_Pulldown`, `Barbell_Squat`). This is the
"bucket" the program suggests for that day. Example — *Push Pull Legs, Day 1 (PUSH)*:

```
Barbell Bench Press · Incline Barbell Bench Press · Dumbbell Flyes
· Triceps Pushdown · One-Arm Triceps Extension
```

When a program workout launches, the **first 3 IDs of the bucket become the picker's top
suggestions** (in plain manual mode that slot is filled by your *own* most-used exercises instead).
The user is never locked in — they can deselect suggestions and add anything else.

### 3.3 Permanent exercise swaps (customization)

Per-session deselect/add doesn't stick. For a lift a user can't or won't do (no rack, bad knee), they
can set a **permanent swap** from **Program Detail** — tap a prescribed lift in the WEEK SCHEDULE and
pick an alternative from that day's muscle pool. The swap is **per-program**: it replaces that lift on
**every** day the program prescribes it, and the replacement **inherits the original's sets × reps
target**. Swaps are reversible (revert restores the original) and are stored as user preferences
(`program_exercise_swaps_v1`), independent of arc progress — they survive quitting and restarting the
program. The replacement then flows automatically into every launch (the pre-filled review screen) and
gets its own progressive-overload history. A swap can never duplicate a lift already in the day.

---

## 4. How a program wires into the user's workout (the flow)

```
Programs Library ─► Program Detail ─► START PROGRAM (confirm if switching)
        │
        ▼
   Home knows "today's day"  ──workout day──►  mission: start today's session
        │                                          │
        │                                          ▼
        │                      Start Workout opens PRE-FILLED:
        │                        • target groups = day's focus → muscle groups
        │                        • picker top 3 = day's exercise bucket
        │                        • flagged as a "program workout"
        │                                          │
        │                                          ▼
        │                       log it like any workout ─► Summary "Save & Exit"
        │                                          │
        │                              advanceDay(): move to next slot,
        │                              +1 completed session, wrap week if needed
        │
        └──rest day──► auto-credited as planned rest (feeds recovery/VIT),
                       auto-rolls forward to the next slot when the date changes
```

**Step by step:**

1. **Selection.** In **Programs Library**, the user taps a program → **Program Detail** → **START
   PROGRAM**. If another program is already active, a dialog warns *"Progress will reset. Workout
   history stays saved."* before switching. This writes a fresh `ProgramProgress` (week 1, day
   index 0).

2. **Home surfaces today.** On load, Home asks the program for the **active progress** and **today's
   day**. A workout day becomes the day's mission/CTA; a rest day shows as recovery.

3. **Launch (the wiring).** Starting today's program workout passes the day's **target muscle
   groups** (from its focus) and its **suggested exercise IDs** into the Start Workout screen, and
   marks the session as a *program workout*. So the user lands on a screen that's already pointed at
   the right muscles with the right exercises queued.

4. **Logging.** From here it's the normal flow (pick/confirm exercises → log sets → summary). The
   session is tagged as belonging to the program so a mid-workout quit-and-resume still knows it's a
   program session.

5. **Completion advances the schedule.** Saving a program workout calls **advanceDay()**: it moves
   `workoutIndex` to the next workout (wrapping to `currentWeek + 1` when the cycle completes) and
   increments `completedSessions`. A **once-per-day guard** prevents double advancement if you log
   twice in a day.

6. **Rest is calendar-derived.** Any non-training weekday is a planned-rest day natively (it
   protects your streak and feeds the VIT recovery meter) — the program no longer stamps or rolls
   rest slots. (The user *can* still "train anyway" on a rest day; that workout counts and advances
   `workoutIndex` like any other.)

See §5 for the full weekday-anchored model.

---

## 5. The scheduling model — weekday-anchored, forgiving

As of the 2026-06-20 rework the schedule is **weekday-anchored**: the **TRAINING GOALS** weekday
picker (Settings, and an optional onboarding step) is the single anchor that decides **which
weekdays are training days**, and the program's sessions are *projected* onto those days. The same
choice now drives **both** which workout you do **and** the shield/recovery/streak accounting — the
two used to be separate systems that ignored each other.

How the projection works (the `ScheduleResolver`, a pure function shared by `ProgramService` and
`RestService`):

- Progression is a **workout-only cursor**, `ProgramProgress.workoutIndex`, into
  `Program.workouts` (the `weekSchedule` with rest slots dropped). **Rest is calendar-derived** — a
  non-training weekday *is* a planned-rest day; rest is no longer a slot in the progression.
- On a **training weekday**, today's session is `workouts[workoutIndex]`. On a **non-training
  weekday**, today is rest. Completing a workout advances `workoutIndex` by exactly **one**
  (`mod` the workout count); `currentWeek` ticks up each time that cursor wraps to 0 (one "week" =
  one full pass of the program's workouts).
- **Forgiveness is structural.** The cursor only moves on a *completed* workout, so a missed
  anchored day is never lost — the same session simply rolls to the next training weekday, order
  intact. Training **off-anchor** (a non-training weekday) still counts and still advances; it is
  never punished (no miss, no obligation added).
- **History is frozen.** Past-day classification reads the immutable per-week `scheduleByWeekKey`
  snapshot, never a live re-projection — so editing your weekdays can never retroactively burn a
  shield or reset a streak. Settings edits apply **next Monday** (`pending`); the onboarding pick
  applies **immediately** (a brand-new user has no history to protect).
- `recommendedWeeks` (8) is **guidance only** — there is no hard finish line; the cycle repeats.

> **Legacy `currentDayIndex`.** The old 7-slot cursor is frozen at its migration value (no longer
> advanced) and kept serialized one release for rollback. The one-shot `weekdayAnchoredScheduleV1`
> migration maps it to the next actionable `workoutIndex`. Don't read `currentDayIndex` for "today".

---

## 6. Progress & persistence

Active state is a small **ProgramProgress** record stored locally:
`programId`, `currentWeek`, `workoutIndex` (the live progression cursor), `startedAt`,
`completedSessions`, plus a frozen legacy `currentDayIndex` (migration/rollback only). The chosen
training weekdays live in `RestState.trainingWeekdays` (the `rest_state_v1` key), not here.

- **Starting** a program resets all program-side bookkeeping (advance guards, snapshots, ongoing
  flags) to a clean slate.
- **Switching** prompts the reset confirmation; **quitting** clears the active program entirely.
- **Workout history is independent.** Logged `WorkoutSession`s are never deleted by switching or
  quitting a program — *"Progress will reset. Workout history stays saved."*

---

## 7. The screens (use this to read the screenshots)

**Programs Library** — a list of the three programs, each showing its name, **tier badge**
(cyan/amber/red), and days/week; the active program is indicated.

**Program Detail** — the program name + tier badge, a `X days/week – Y weeks` line (amber), the
description, then a **WEEK SCHEDULE** list. Each day renders a card:
- `DAY n` (amber) + the day **label** (neon for workout days, muted for rest),
- the **focus summary** ("chest – shoulders – triceps", or "recovery scheduled"),
- up to **6 suggested exercises** by name (workout days only).
- At the bottom: **START PROGRAM** (or **QUIT PROGRAM** in red if this one is active).

**Home** — when a program is active, today's scheduled day becomes the headline mission (start the
workout, or "recovery scheduled" on a rest day).

---

## 8. Relationship to the rest of the app

- **Rest & recovery / VIT.** Program *workout* days are registered as **scheduled training dates**,
  and program *rest* days as **planned rest** — both feed the VIT recovery meter's "did you train
  when scheduled / rest when scheduled?" credit, and rest days protect the streak.
- **Stats / XP / quests.** A program workout is just a `WorkoutSession`. It contributes to STR/AGI/
  END, XP, daily/weekly quests (Show Up, Class Focus, Volume Floor, etc.) exactly like a manual
  workout. The program doesn't add or multiply anything.
- **Progressive overload.** Weight/rep suggestions still come from your **per-exercise history**,
  not the program. The program picks *which* exercises; overload picks *how much*.

---

## 9. Extending it (for future work)

- **Add a program** = append a `Program` to the library with a 7-slot `weekSchedule`; each workout
  day needs a `focus` and a `suggestedExerciseIds` bucket of real catalog IDs.
- The **focus enum already has spare tags** (`chestTriceps`, `backBiceps`, `shouldersCore`) wired to
  muscle-group mappings, ready for finer splits (e.g. a bro-split or an Arnold split).
- The **tier string** controls the badge color (contains "ADVANCED" → red, "INTERMEDIATE" → amber,
  else cyan), so naming tiers consistently matters.

---

## 10. Cheat-sheet

- **3 programs:** Full Body 3× (beginner, 3d), Upper Lower (intermediate, 4d), Push Pull Legs
  (int/adv, 6d) — each an 8-week recommendation over a repeating **7-day cycle**.
- A **ProgramDay** = workout|rest + a **focus** (→ target muscle groups) + a **5-exercise bucket**
  (top 3 surface in the picker).
- **Active program prefills Start Workout** (muscle groups + suggested exercises) and flags the
  session; everything else logs normally.
- **Schedule is weekday-anchored + forgiving.** TRAINING GOALS weekdays decide which days are
  training; the program's workouts project onto them. `workoutIndex` advances +1 on each completed
  workout; rest is calendar-derived (any non-training weekday). A missed anchored day rolls forward,
  never lost; off-anchor training still counts. (See §5.)
- **One program at a time;** switching/quitting resets *program progress only* — **workout history
  is always kept.**
- The program layer is pure scaffolding: **it never changes how a workout is scored.**
