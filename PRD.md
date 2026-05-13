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
- [ ] Select muscle group (Chest / Back / Arms / Legs)
- [ ] Set workout duration via scroll picker (hours + minutes)
- [ ] Browse exercises filtered by muscle group
- [ ] Select exercises from curated local database
- [ ] Confirm and start session

### 2. Log Completed Workout Session
- [ ] Record: date, muscle group, duration, exercises performed
- [ ] Each exercise stores: sets, reps, weight per set
- [ ] Save session to local storage on completion

### 3. Exercise Detail Page
- [ ] Show exercise name, image, difficulty level
- [ ] Show instructions/description from exercises.json
- [ ] Accessible from exercise picker before selecting

### 4. Workout History
- [ ] List of past sessions sorted by date (newest first)
- [ ] Each entry shows: date, muscle group, duration, exercise count
- [ ] Tap session → view full session detail

### 5. Progress Charts
- [ ] Volume over time per muscle group (sets × reps × weight)
- [ ] Workout frequency per week (bar chart)
- [ ] Per-exercise personal best tracking

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
- [ ] Log session (sets/reps/weight)
- [ ] Workout history
- [ ] Exercise detail page
- [ ] Progress charts