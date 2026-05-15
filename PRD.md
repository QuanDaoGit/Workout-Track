# PRD.md — Workout Tracker v1

## Purpose
Solo gym-goer logs and tracks workout sessions from their phone.
No account. No cloud. Works offline, always.

## Target User
Single user. Gym-goer. Tracks personal progress over time.

## Platform
Android first. iOS later.

## Data Storage
Local only via `shared_preferences` or `hive`.
No Firebase. No login. No sync.

---

## Features (v1)

### 1. Start Workout
- [x] Select muscle group (Chest / Back / Arms / Legs)
- [x] Set workout duration via scroll picker (hours + minutes)
- [x] Browse exercises filtered by muscle group
- [x] Select exercises from curated local database
- [x] Confirm and start session

### 2. Log Completed Workout Session
- [x] Record: date, muscle group, duration, exercises performed
- [x] Each exercise stores: sets, reps, weight per set
- [x] Save session to local storage on completion

### 3. Exercise Detail Page
- [x] Show exercise name, image, difficulty level
- [x] Show instructions/description from exercises.json
- [x] Accessible from exercise picker before selecting

### 4. Workout History
- [x] List of past sessions sorted by date (newest first)
- [x] Each entry shows: date, muscle group, duration, exercise count
- [x] Tap session → view full session detail

### 5. Progress Charts
- [x] Volume over time per muscle group (sets × reps × weight)
- [x] Workout frequency per week (bar chart)
- [x] Per-exercise personal best tracking

---

## Out of Scope (v1)
- User login / accounts
- Cloud sync / Firebase
- Social features
- AI coaching
- Push notifications
- Rest timer
- Custom exercise creation

---

## V2 Features

### Core Twist: Lifts → Combat Stats
- [x] Stat engine: map logged volume to 5 combat stats
  - Chest/Triceps volume → STR (Strength)
  - Back/Biceps volume → DEF (Defense)
  - Legs volume → VIT (Vitality / HP pool)
  - Shoulders/Core volume → AGI (Agility / dodge rate)
  - Workout variety this week (3+ muscle groups hit) → LCK (Luck / crit rate)
- [x] Stats decay only after 3 consecutive days of inactivity (−10% per day after day 3)
- [x] Stats never decay from planned rest days
- [x] Stat card visible on Profile page (5 bars, pixel style)
- [x] Stat delta shown after each completed session (+X STR, +X DEF)

### Auto-Battle System
- [ ] Battle runs automatically at midnight each day
- [ ] Enemy scales to current dungeon floor (floor = total sessions logged)
- [ ] Battle result (WIN / DEFEAT / DRAW) stored locally
- [ ] Home screen shows last battle result on app open
- [ ] Battle log: short pixel combat replay (text-based, typewriter style)
- [ ] Defeat condition: enemy HP > player HP based on stat totals
- [ ] Win rewards: pixel loot (cosmetic only — avatar frames, title badges)

### Enemy & Dungeon Progression
- [ ] 10 enemy archetypes, each floor introduces a new one
- [ ] Every 10 floors = Boss floor (harder, unique loot)
- [ ] Skip workout → dungeon floor does not advance
- [ ] Miss 3 days → floor resets by 1
- [ ] Enemy stats visible before battle on Home screen ("TONIGHT'S ENEMY")

### Workout Programs
- [ ] 3 pre-built programs: PPL, Full Body 3x, Upper/Lower
- [ ] Program schedule: assigns muscle group per day
- [ ] "Follow Program" mode replaces manual muscle group selection
- [ ] Program progress tracked (Week 1 Day 3 of 6, etc.)

### Progressive Overload Engine
- [ ] Auto-suggest next session weight/reps per exercise (+5% rule)
- [ ] Show delta vs last session inline on Exercise Session page
- [ ] Mark set as PR if it beats all-time best weight × reps

### Custom Exercises
- [ ] User creates exercise: name, muscle group, type (push/pull/legs)
- [ ] Stored locally, appears in exercise picker
- [ ] Custom exercises excluded from curated stats but included in volume calc

### Body Metrics
- [ ] Log bodyweight with date
- [ ] Line chart on Stats tab
- [ ] Optional: used as HP modifier (higher weight = higher base VIT)

### Loot & Cosmetics
- [ ] Loot chest opens on WIN (pixel animation)
- [ ] Rewards: avatar frames, rank title badges, home screen backgrounds
- [ ] Loot inventory page under Profile
- [ ] No pay-to-win. All loot from battle wins only.

---

## V2 Out of Scope

- User login / accounts
- Cloud sync / Firebase
- Social features
- AI coaching
- Push notifications
- Online multiplayer or PvP battles
- Cloud sync or user accounts
- Real-time battle animation (battles resolve offline, shown as replay)
- AI-generated workout recommendations
- Apple Health / Google Fit integration
- Social sharing or leaderboards
- Nutrition or calorie tracking
- Paid features or in-app purchases
- Push notifications (battle results shown on next app open only)
- More than 5 combat stats
- Stat resets or prestige system (V3 candidate)

---

## Design Constraints
- Theme: pixel arcade, dark mode only
- Palette: bg `0xFF0D0D1A`, card `0xFF1A1A2E`, neon `0xFF00FF9C`, red `0xFFFF2D55`, gold `0xFFFFD700`
- Fonts: PressStart2P (headings), Gotham (body)
- Border radius: 4px everywhere (sharp pixel corners)
- Buttons: FilledButton only

---

## Current Status
- [x] Home page
- [x] Start Workout page (muscle group, time picker, exercise picker)
- [x] Favorite exercises (persisted)
- [x] Log session (sets/reps/weight)
- [x] Workout history (list + calendar)
- [x] Exercise detail page
- [x] Progress charts (volume per muscle, weekly frequency, top-5 PRs)
