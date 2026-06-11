// "Forge Your Resolve" — three identity/commitment answers collected after
// program selection. Unlike the calibration quiz (goal/experience/frequency),
// these capture the *why*, not training context: they exist to deepen hook.
// Grounded in motivation science — autonomous, process- and identity-based
// motives predict durable adherence (Self-Determination Theory; Goal-Content
// theory; implementation-intentions). All answers are body-neutral by design.

/// Q1 — "WHAT DOES WINNING LOOK LIKE?" A self-concordant vision. Persisted for a
/// future Profile banner; not surfaced in the lean first build.
enum WinningVision {
  strongCapable,
  stillHere,
  clearHeaded,
  visiblyStronger;

  String get label => switch (this) {
    WinningVision.strongCapable => 'LOOKS AND FEELS AMAZING',
    WinningVision.stillHere => 'STILL HERE IN A YEAR',
    WinningVision.clearHeaded => 'DEEPLY CARVED',
    WinningVision.visiblyStronger => 'VISIBLY STRONGER',
  };

  String get subtext => switch (this) {
    WinningVision.strongCapable => 'love myself and be confident of how I look.',
    WinningVision.stillHere => " the consistency I've never felt before.",
    WinningVision.clearHeaded => 'lifting is my casual hobby.',
    WinningVision.visiblyStronger => 'strength goes up witt numbers.',
  };

  static WinningVision? fromName(String? raw) {
    for (final value in WinningVision.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

/// Q2 — "WHAT USUALLY GETS IN THE WAY?" A barrier the user names so the app can
/// pre-commit a coping response. `edgeLine` is the antidote surfaced at the
/// Start Gate ("YOUR EDGE"), pairing each barrier to the system that defends it.
enum Obstacle {
  time,
  motivation,
  boredom,
  missedDay;

  String get label => switch (this) {
    Obstacle.time => 'TIME',
    Obstacle.motivation => 'MOTIVATION DROPS FROM NO RESULTS',
    Obstacle.boredom => 'I GET BORED FAST',
    Obstacle.missedDay => 'ONE MISSED DAY AND MY SPIRIT DROPS',
  };

  /// Antidote copy shown under "YOUR EDGE" on the Start Gate — names the app
  /// system that defends against this specific barrier.
  String get edgeLine => switch (this) {
    Obstacle.time =>
      'Sessions flex to your week — a planned rest never breaks your build.',
    Obstacle.motivation =>
      'Every rep moves a visible stat — progress you can see, not guess.',
    Obstacle.boredom =>
      'Rotating quests and loot keep a fresh reason to show up.',
    Obstacle.missedDay =>
      'Rest shields protect your streak — recovery is part of the build.',
  };

  static Obstacle? fromName(String? raw) {
    for (final value in Obstacle.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

/// Q3 — "I TRAIN BECAUSE…" An autonomous motive (vow). `creedLine` is the full
/// quoted sentence displayed as the character's creed at the Start Gate.
enum TrainingWhy {
  feelAlive,
  doneQuitting,
  futureSelf,
  clearsHead;

  String get label => switch (this) {
    TrainingWhy.feelAlive => '…I WANT TO FEEL ALIVE.',
    TrainingWhy.doneQuitting => "…I'M DONE QUITTING ON MYSELF.",
    TrainingWhy.futureSelf => '…MY FUTURE SELF IS COUNTING ON ME.',
    TrainingWhy.clearsHead => '…IT CLEARS MY HEAD.'
  };

  String get creedLine => switch (this) {
    TrainingWhy.feelAlive => 'I train because it makes me feel alive.',
    TrainingWhy.doneQuitting => "I train because I'm done quitting on myself.",
    TrainingWhy.futureSelf =>
      'I train because my future self is counting on me.',
    TrainingWhy.clearsHead => 'I train because it clears my head.',
  };

  static TrainingWhy? fromName(String? raw) {
    for (final value in TrainingWhy.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}
