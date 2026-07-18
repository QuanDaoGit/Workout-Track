import 'package:shared_preferences/shared_preferences.dart';

/// User toggle for the broad UI tap-tick layer (Profile -> Settings ->
/// UI sounds), the sub-toggle under Sound.
///
/// Governs ONLY `SfxService.playUiTap` (the PixelButton press tick). Core-loop
/// sounds — set-logged, rest-end, destructive warning — and all ceremony audio
/// ride the master Sound toggle alone: they're functional/landmark feedback,
/// while pervasive ticks are the one class the restraint research flags as an
/// annoyance risk, so they get their own escape hatch. Defaults to **on**
/// (product-owner call after the 2026-07-18 audition). `main()`/BootService
/// reads it into [SfxService.uiSoundsEnabled] at boot; the Settings row
/// updates both this store and the live flag.
class UiSoundSettingsService {
  static const String _key = 'ui_sounds_enabled_v1';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
