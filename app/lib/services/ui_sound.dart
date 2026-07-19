/// The interaction-tier sound kit — every UI sound the app can make below the
/// ceremony class, as ONE registry with ONE grammar (SFX v2, 2026-07-19).
///
/// Why a kit: the v1 pass wired 4 sounds at scattered sites and the app read
/// as "half baked, a little here a little there" on device — partial coverage
/// sounds broken, not restrained. Every sound here belongs to a ROLE with a
/// place on the loudness ladder (quiet → loud): select 0.07 < toggle/stepper
/// 0.07 < tick 0.10 = skip 0.10 < notice 0.08 < board/bit 0.15 < pad 0.18 <
/// warn 0.20 < set-log/rest-set/train 0.22 < dispatch/haul 0.25 <
/// rest-exercise 0.30 < ceremony 0.32+. All C-major, band-limited
/// (`ops/gen_ui_sfx.py`).
///
/// Collision policy (Codex): ONE sound per gesture, by construction — a site
/// wires exactly one role, and `SfxService.playUi`'s arbiter suppresses the
/// micro class for a short window after any louder role fires.
enum UiSound {
  /// ArcadeChip select — the border double-blink made audible: a 4-step
  /// rising "data zip" micro-arpeggio (digital by design; no noise
  /// transients). 3 rotated variants.
  select,

  /// Settings switch flips — state direction you can hear: on rises.
  toggleOn,

  /// …and off falls (the same pair, mirrored).
  toggleOff,

  /// Stepper increment (+15s rest, numeric +) — a bent micro-pip up.
  stepUp,

  /// Stepper decrement — the same pip bent down.
  stepDown,

  /// The universal press tick ("keycap rise", G5→C6) — every committing
  /// button, PixelButton and ArcadeFilled alike. 3 rotated variants.
  tick,

  /// Destructive-confirm buzz (E5→A4 descending) — delete/discard/reset/quit
  /// commits. Descends where confirms rise; never confusable.
  warn,

  /// The dismiss/skip release — a soft descending triangle glide (SKIP REST
  /// and explicit dismiss moments). A release, not an error.
  skip,

  /// Set logged — the core-loop confirm ("checkmark", C5→G5), neutral by
  /// design (celebration belongs to the PR/reward class). 3 variants + a 1s
  /// burst cooldown.
  setLogged,

  /// Between-SET rest elapsed — the weaker sibling: same G5→C6 identity as
  /// [restGoExercise], single voice, shorter. The smaller moment sounds
  /// smaller.
  restGoSet,

  /// Between-EXERCISE rest elapsed — the full 450ms "ready-go" chorus.
  restGoExercise,

  /// The CRT center-notice power-on blip — a notification, not a response.
  notice,

  /// TRAIN keycap, part 1: the felt down-thunk at tap-down. The app's
  /// spacebar ("heavy keycap" signature).
  trainDown,

  /// TRAIN keycap, part 2: the C5+G5 dyad engage at commit.
  trainUp,

  /// Quest board — "degauss wake": an old monitor powering on (thump →
  /// rising static → settling hum). Texture, not tones.
  boardTap,

  /// Expedition pad tap — "prime": the dispatch whoosh's little sibling
  /// (rising doppler + air). Tap and launch share one fiction.
  padTap,

  /// Expedition dispatch — the launch whoosh (matches the pad recoil).
  padDispatch,

  /// Haul/coffer collect — a chunky thunk + bright tail (reward grammar).
  haulCollect,

  /// Pressing BIT — "bi-di-bip?": three spoken syllables, the last bending
  /// up. A character response in a soft triangle timbre, deliberately not a
  /// UI square. ONE-OFF: BIT gets no wider voice without explicit
  /// product-owner sign-off.
  bitChirp,
}

/// Which rate-limit family a sound belongs to (see `SfxService.playUi`).
enum UiSoundCooldown {
  /// The shared 60ms micro window (ticks/pips) + suppression after louder
  /// roles — rapid tapping can't machine-gun, and a tick never stacks under
  /// a warn/skip/signature.
  micro,

  /// A per-sound 1s burst cooldown (set-log correction bursts).
  confirm,

  /// Self-limiting moments (rest ends, signatures) — no cooldown, but they
  /// arm the micro-suppression window.
  none,
}

class UiSoundSpec {
  const UiSoundSpec(
    this.assets, {
    required this.subToggle,
    required this.cooldown,
  });

  /// Asset path(s) under the flutter asset bundle; >1 = rotated variants
  /// (audio fatigues faster than visuals on repeat).
  final List<String> assets;

  /// true → gated by the "UI sounds" sub-toggle as well as master Sound;
  /// false → master Sound only (core-loop / functional cues).
  final bool subToggle;

  final UiSoundCooldown cooldown;
}

const Map<UiSound, UiSoundSpec> kUiSoundSpecs = {
  UiSound.select: UiSoundSpec(
    ['audio/ui_select_1.wav', 'audio/ui_select_2.wav', 'audio/ui_select_3.wav'],
    subToggle: true,
    cooldown: UiSoundCooldown.micro,
  ),
  UiSound.toggleOn: UiSoundSpec(
    ['audio/ui_toggle_on.wav'],
    subToggle: true,
    cooldown: UiSoundCooldown.micro,
  ),
  UiSound.toggleOff: UiSoundSpec(
    ['audio/ui_toggle_off.wav'],
    subToggle: true,
    cooldown: UiSoundCooldown.micro,
  ),
  UiSound.stepUp: UiSoundSpec(
    ['audio/ui_step_up.wav'],
    subToggle: true,
    cooldown: UiSoundCooldown.micro,
  ),
  UiSound.stepDown: UiSoundSpec(
    ['audio/ui_step_down.wav'],
    subToggle: true,
    cooldown: UiSoundCooldown.micro,
  ),
  UiSound.tick: UiSoundSpec(
    ['audio/ui_tap_1.wav', 'audio/ui_tap_2.wav', 'audio/ui_tap_3.wav'],
    subToggle: true,
    cooldown: UiSoundCooldown.micro,
  ),
  UiSound.warn: UiSoundSpec(
    ['audio/ui_warn.wav'],
    subToggle: false,
    cooldown: UiSoundCooldown.none,
  ),
  UiSound.skip: UiSoundSpec(
    ['audio/ui_skip.wav'],
    subToggle: false,
    cooldown: UiSoundCooldown.none,
  ),
  UiSound.setLogged: UiSoundSpec(
    ['audio/set_logged_1.wav', 'audio/set_logged_2.wav', 'audio/set_logged_3.wav'],
    subToggle: false,
    cooldown: UiSoundCooldown.confirm,
  ),
  UiSound.restGoSet: UiSoundSpec(
    ['audio/rest_go_set.wav'],
    subToggle: false,
    cooldown: UiSoundCooldown.none,
  ),
  UiSound.restGoExercise: UiSoundSpec(
    ['audio/rest_go.wav'],
    subToggle: false,
    cooldown: UiSoundCooldown.none,
  ),
  UiSound.notice: UiSoundSpec(
    ['audio/ui_notice.wav'],
    subToggle: true,
    cooldown: UiSoundCooldown.micro,
  ),
  UiSound.trainDown: UiSoundSpec(
    ['audio/train_down.wav'],
    subToggle: true,
    cooldown: UiSoundCooldown.none,
  ),
  UiSound.trainUp: UiSoundSpec(
    ['audio/train_up.wav'],
    subToggle: true,
    cooldown: UiSoundCooldown.none,
  ),
  UiSound.boardTap: UiSoundSpec(
    ['audio/board_tap.wav'],
    subToggle: true,
    cooldown: UiSoundCooldown.none,
  ),
  UiSound.padTap: UiSoundSpec(
    ['audio/pad_tap.wav'],
    subToggle: true,
    cooldown: UiSoundCooldown.none,
  ),
  UiSound.padDispatch: UiSoundSpec(
    ['audio/pad_dispatch.wav'],
    subToggle: false,
    cooldown: UiSoundCooldown.none,
  ),
  UiSound.haulCollect: UiSoundSpec(
    ['audio/haul_collect.wav'],
    subToggle: false,
    cooldown: UiSoundCooldown.none,
  ),
  UiSound.bitChirp: UiSoundSpec(
    ['audio/bit_chirp.wav'],
    subToggle: true,
    cooldown: UiSoundCooldown.none,
  ),
};
