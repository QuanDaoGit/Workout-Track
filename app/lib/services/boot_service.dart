import 'dart:async';

import 'package:flutter/foundation.dart';

import 'class_migration_service.dart';
import 'feature_gate_service.dart';
import 'haptic_service.dart';
import 'haptic_settings_service.dart';
import 'migration_service.dart';
import 'notification_service.dart';
import 'onboarding_service.dart';
import 'sfx_service.dart';
import 'sound_settings_service.dart';
import 'stat_engine.dart';
import 'ui_sound_settings_service.dart';
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
      // Rules-version migration MUST precede every step that can call
      // calculateAllStats(): an earlier recompute would cache new-rules values
      // that the version gate would then misread as a legacy board
      // (double-scaling the v4 remaster conversion).
      await MigrationService.runStatsRecomputeIfRulesChanged();
      await MigrationService.runClearSelfReportedStatSeedOnce();
      await MigrationService.runEndStatBackfillOnce();
      await MigrationService.runTitleUnificationOnce();
      await MigrationService.runAvatarSpecSeedOnce();
      await MigrationService.runWeightLogRewardAnchorOnce();
      await MigrationService.runThemeLootCleanupOnce();
      await MigrationService.runShadowRemovalCleanupOnce();
      await MigrationService.runWeekdayAnchoredScheduleOnce();
      await MigrationService.runDecayRemovalOnce();
      // Grandfather existing installs into the feature-unlock ladder, then
      // seed the sync gate snapshot BEFORE the shell's first frame so the nav
      // never flashes a wrong lock state (Codex P4).
      await MigrationService.runFeatureGateSeedOnce();
      await FeatureGateService().load();
      await StatEngine().processMissedTrainingDays();
      await ClassMigrationService().migrateIfNeeded();
      SfxService.enabled = await SoundSettingsService().isEnabled();
      SfxService.uiSoundsEnabled = await UiSoundSettingsService().isEnabled();
      HapticService.enabled = await HapticSettingsService().isEnabled();
      // Route ALL app audio into a mix-with-others sonification context (never
      // steal focus from the user's own music) and pre-warm the micro-SFX
      // pools. The warm-up is deliberately un-awaited: it's a latency
      // optimization, not boot work — and it swallows per-asset failures.
      await SfxService.instance.applyGlobalAudioContext();
      unawaited(SfxService.instance.warmUpUiPools());
      await Units.load();
      // Local-notification plumbing (timezone DB + channels). No permission ask
      // here — that happens contextually. Defensive: never blocks the splash.
      await NotificationService.instance.init();
      // Reconcile Tier B training reminders every launch — re-arms them after a
      // reboot and picks up any schedule/time/toggle change made while away.
      // No-ops cheaply unless the user has opted in AND granted permission.
      await NotificationService.instance.syncTrainingReminders();
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
