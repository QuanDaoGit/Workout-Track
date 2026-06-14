/// How BIT — the companion mascot — addresses the user. The register picks the
/// tone; [bitAddress] resolves it to a concrete word.
///
/// Hybrid by register (see the onboarding mascot plan): the user's character
/// name carries the *intimate / daily* beats, the honorific carries the
/// *ceremony / hype* beats, and "recruit" is the *pre-embodiment* form (BIT does
/// not "know" the user yet). The honorific doubles as the fallback so a line is
/// never rendered with an empty name.
enum BitRegister {
  /// Intimate / daily beats — uses the user's character name.
  name,

  /// Ceremony / hype beats — the epic honorific.
  honorific,

  /// Pre-embodiment — BIT has not met the user yet.
  recruit,
}

/// The epic honorific, doubling as the fallback when a name is unusable.
const String _honorific = 'warrior';

/// Resolves [register] to the word BIT uses to address the user.
///
/// For [BitRegister.name], returns the trimmed [name]; when [name] is null or
/// blank it falls back to the honorific so a spoken line never renders empty.
String bitAddress(BitRegister register, {String? name}) {
  switch (register) {
    case BitRegister.name:
      final trimmed = name?.trim() ?? '';
      return trimmed.isEmpty ? _honorific : trimmed;
    case BitRegister.honorific:
      return _honorific;
    case BitRegister.recruit:
      return 'recruit';
  }
}
