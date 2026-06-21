import 'package:flutter/foundation.dart';

import 'class_migration_service.dart';
import 'haptic_service.dart';
import 'haptic_settings_service.dart';
import 'migration_service.dart';
import 'notification_service.dart';
import 'onboarding_service.dart';
import 'sfx_service.dart';
import 'sound_settings_service.dart';
import 'stat_engine.dart';
import 'unit_settings_service.dart';

/// Runs the app's one-time launch work and resolves the first-screen decision.
///
/// Previously these steps ran synchronously in `main()` before `runApp` — i.e.
/// during the (now dark) native splash, where no Flutter animation can cover
/// them. Relocating them here lets the boot splash genuinely *occupy* the load
/// time (occupied-time effect) instead of faking a processing hold.
///
/// Returns whether onboarding is already complete, so the splash can route to
/// `RootPage` vs `OnboardingFlowPage` from the same future — no separate gate.
class BootService {
  const BootService();

  Future<bool> run() async {
    try {
      await MigrationService.runOnce();
      await MigrationService.runClearSelfReportedStatSeedOnce();
      await MigrationService.runEndStatBackfillOnce();
      await MigrationService.runTitleUnificationOnce();
      await MigrationService.runAvatarSpecSeedOnce();
      await MigrationService.runWeightLogRewardAnchorOnce();
      await MigrationService.runThemeLootCleanupOnce();
      await MigrationService.runShadowRemovalCleanupOnce();
      await MigrationService.runWeekdayAnchoredScheduleOnce();
      await MigrationService.runStatsRecomputeIfRulesChanged();
      await StatEngine().applyDecayIfNeeded();
      await ClassMigrationService().migrateIfNeeded();
      SfxService.enabled = await SoundSettingsService().isEnabled();
      HapticService.enabled = await HapticSettingsService().isEnabled();
      await Units.load();
      // Local-notification plumbing (timezone DB + channel). No permission ask
      // here — that happens contextually. Defensive: never blocks the splash.
      await NotificationService.instance.init();
      return OnboardingService().isComplete();
    } catch (e) {
      // A boot step must never hang or crash the splash. Fall back to the
      // onboarding decision (its own default is false → onboarding) and surface
      // the failure in logs rather than swallowing it silently.
      debugPrint('BootService: boot work failed: $e');
      try {
        return await OnboardingService().isComplete();
      } catch (_) {
        return false;
      }
    }
  }
}
