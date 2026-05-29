/// Biological sex used only to pick strength-standard thresholds during the
/// one-time onboarding calibration. Distinct from any weekly body-metrics data.
enum UserProfileSex {
  male,
  female,
  preferNotToSay;

  String get label => switch (this) {
    UserProfileSex.male => 'Male',
    UserProfileSex.female => 'Female',
    UserProfileSex.preferNotToSay => 'Prefer not to say',
  };

  static UserProfileSex fromName(String? raw) {
    for (final value in UserProfileSex.values) {
      if (value.name == raw) return value;
    }
    return UserProfileSex.preferNotToSay;
  }
}
