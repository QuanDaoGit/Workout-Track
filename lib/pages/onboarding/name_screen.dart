import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/avatar_spec.dart';
import '../../models/character.dart';
import '../../models/character_draft.dart';
import '../../models/profile_models.dart';
import '../../services/analytics_service.dart';
import '../../services/character_service.dart';
import '../../services/profile_service.dart';
import '../../services/program_service.dart';
import '../../services/rest_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/motion/arcade_name_field.dart';
import '../../widgets/motion/phosphor_tap.dart';
import '../../widgets/motion/power_on.dart';
import '../../widgets/onboarding/starter_readout_panel.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/screen_shake.dart';
import 'reminders_primer_page.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key, required this.draft});

  final CharacterDraft draft;

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen>
    with SingleTickerProviderStateMixin {
  static const _prompt = 'NAME YOUR CHARACTER';
  static const _promptStartMs = 150;
  static const _charMs = 30;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  late final ArcadeNameEditingController _nameController =
      ArcadeNameEditingController();
  late final FocusNode _focusNode = FocusNode();
  // The upper content scrolls now (the readout panel pushes the field down past
  // the keyboard line); on focus we lift the field above the keyboard.
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _fieldKey = GlobalKey();

  bool _started = false;
  bool _committing = false;
  bool _valid = false;
  bool _showError = false;
  int _errorTrigger = 0;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  String get _trimmedName => _nameController.text.trim();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  // When the field gains focus, scroll it near the top of the viewport so it
  // clears the keyboard (the readout panel above would otherwise leave it
  // hidden). Reduced motion jumps without animating.
  void _onFocusChange() {
    if (!_focusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _fieldKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.1,
        duration: _reduceMotion ? Duration.zero : kMotionBase,
        curve: kMotionCurve,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(
      AnalyticsService.instance.logOnboardingStep(AnalyticsValue.stepNameScreen),
    );
    if (_reduceMotion) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0).whenComplete(() {
      if (mounted && !_reduceMotion) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleNameChanged(String value) {
    final nextValid = _isValid(value);
    setState(() {
      _valid = nextValid;
      if (_showError) _showError = false;
    });
  }

  bool _isValid(String value) {
    final trimmed = value.trim();
    return trimmed.length >= ProfileData.minNameLength &&
        trimmed.length <= ProfileData.maxNameLength;
  }

  Future<void> _submit() async {
    if (_committing) return;
    if (!_valid) {
      setState(() {
        _showError = true;
        _errorTrigger++;
      });
      return;
    }

    // Naming is the commit point: the character is created here and the
    // start gate reveals it (no avatar step — the starter face is seeded
    // from the quiz's sex answer and editable later from the profile).
    final name = _trimmedName;
    final draft = widget.draft.copyWith(characterName: name);
    setState(() => _committing = true);
    final character = Character(
      name: name,
      calibration: draft.calibration,
      classConfirmedAt: draft.classConfirmedAt,
      characterName: name,
      createdAt: DateTime.now(),
      winningVision: draft.winningVision,
      obstacle: draft.obstacle,
      trainingWhy: draft.trainingWhy,
    );
    await CharacterService().createCharacterAndCompleteOnboarding(character);
    final selectedProgramId = draft.selectedProgramId;
    if (selectedProgramId != null) {
      await ProgramService().startProgram(selectedProgramId);
      final weekdays = draft.trainingWeekdays;
      if (weekdays != null) {
        // Immediate (no next-Monday pending): a brand-new user has no shield/
        // streak history to protect, so their chosen anchor takes effect now.
        await RestService().saveTrainingWeekdays(weekdays, immediate: true);
      }
    }
    // Mirror identity into ProfileService so Home/Profile (which read the
    // profile store, not the Character blob) show the real name + face.
    final avatarSpec = AvatarDefaults.forSex(draft.calibration.sex);
    await ProfileService().saveDisplayName(character.characterName);
    await ProfileService().saveAvatarSpec(avatarSpec);
    if (!mounted) return;
    // Terminal push: the reminders primer (one-time training-reminder opt-in)
    // then forwards to the Start Gate, which blocks system-back and clears the
    // whole stack on exit — so this route never pops back to a mounted
    // NameScreen. The latched guard also hardens against a double-commit if the
    // push is slow. The schedule was just committed above, so the primer can
    // name the user's real training days.
    await Navigator.of(context).push(
      arcadeRoute(
        (_) => RemindersPrimerPage(
          character: character,
          avatarSpec: avatarSpec,
          trainingWeekdays: widget.draft.trainingWeekdays ?? const <int>{},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final ms = (_controller.value * 2000).round();
            final promptDone = _promptStartMs + _prompt.length * _charMs;
            final prompt = _typedPrompt(ms);
            final fieldOpacity = _progress(ms, promptDone + 200, 200);
            final buttonOpacity = _progress(ms, promptDone + 400, 200);
            // The readout panel reads as context — it fades in first, ahead of
            // the typed prompt, so the plan is present while naming begins.
            final panelOpacity = _progress(ms, 0, 250);

            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NameTopBar(onBack: () => Navigator.of(context).pop()),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          kSpace4,
                          kSpace3,
                          kSpace4,
                          120,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Opacity(
                              opacity: panelOpacity,
                              child: StarterReadoutPanel(
                                draft: widget.draft,
                                onEdit: () => Navigator.of(context).pop(),
                              ),
                            ),
                            const SizedBox(height: kSpace5),
                            Semantics(
                              header: true,
                              child: Text(
                                prompt,
                                style: const TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 16,
                                  color: kNeon,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: kSpace4),
                            KeyedSubtree(
                              key: _fieldKey,
                              child: Opacity(
                                opacity: fieldOpacity,
                                child: _buildField(),
                              ),
                            ),
                            if (_showError)
                              const Padding(
                                padding: EdgeInsets.only(top: kSpace2),
                                child: Text(
                                  'INVALID NAME',
                                  style: TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 12,
                                    color: kDanger,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedPadding(
                    duration: _reduceMotion ? Duration.zero : kMotionBase,
                    curve: kMotionCurve,
                    padding: EdgeInsets.fromLTRB(
                      kSpace4,
                      0,
                      kSpace4,
                      MediaQuery.viewInsetsOf(context).bottom + kSpace5,
                    ),
                    child: Opacity(
                      opacity: buttonOpacity,
                      child: _buildButton(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildField() {
    return ScreenShake(
      trigger: _reduceMotion ? 0 : _errorTrigger,
      frames: 3,
      frameMs: 50,
      magnitude: 4,
      child: ArcadeNameField(
        controller: _nameController,
        focusNode: _focusNode,
        error: _showError,
        onChanged: _handleNameChanged,
        onSubmitted: _submit,
      ),
    );
  }

  Widget _buildButton() {
    final label = _valid
        ? 'I AM ${_trimmedName.toUpperCase()}'
        : 'ENTER A NAME';
    return Semantics(
      button: true,
      enabled: _valid,
      liveRegion: true,
      child: PowerOn(
        enabled: _valid,
        builder: (context, power) {
          final disabledFill = Color.lerp(
            kCard,
            const Color(0xFF005033),
            power,
          )!;
          final enabledFill = Color.lerp(
            const Color(0xFF005033),
            kNeon,
            power,
          )!;
          return SizedBox(
            height: 56,
            child: PixelButton(
              label: label,
              minHeight: 56,
              fontSize: 14,
              color: _valid ? enabledFill : kNeon,
              disabledColor: disabledFill,
              disabledBorderColor: kBorder,
              disabledLabelColor: kDim,
              onPressed: _valid && !_committing ? _submit : null,
            ),
          );
        },
      ),
    );
  }

  String _typedPrompt(int ms) {
    if (_reduceMotion) return _prompt;
    final count = ((ms - _promptStartMs) / _charMs).floor().clamp(
      0,
      _prompt.length,
    );
    return _prompt.substring(0, count);
  }

  double _progress(int ms, int start, int duration) {
    if (_reduceMotion) return 1;
    return ((ms - start) / duration).clamp(0.0, 1.0).toDouble();
  }
}

class _NameTopBar extends StatelessWidget {
  const _NameTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpace4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Semantics(
              button: true,
              label: 'Back',
              child: PhosphorTap(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                  ),
                  child: IconButton(
                    key: const ValueKey('name_back_button'),
                    padding: EdgeInsets.zero,
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.chevron_left_sharp,
                      color: kNeon,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
