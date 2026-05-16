import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/class_definitions.dart';
import '../models/character_class.dart';
import '../services/class_service.dart';
import '../services/loot_service.dart';
import '../theme/tokens.dart';
import '../widgets/class_sprite.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_shake.dart';
import '../widgets/strobe_flash.dart';
import '../widgets/typewriter_text.dart';

/// Cinematic page for ultimate ability unlock.
/// More dramatic than class reveal — gold strobe, heavier shake.
class UltimateUnlockPage extends StatefulWidget {
  const UltimateUnlockPage({super.key});

  @override
  State<UltimateUnlockPage> createState() => _UltimateUnlockPageState();
}

class _UltimateUnlockPageState extends State<UltimateUnlockPage> {
  int _step = 0;
  int _shakeTrigger = 0;
  int _strobeTrigger = 0;
  Timer? _timer;
  CharacterClass? _cls;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cls = await ClassService().getCurrentClass();
    if (!mounted) return;
    setState(() => _cls = cls);
    _runSequence();
  }

  void _runSequence() {
    _timer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _step = 1;
        _shakeTrigger++;
      });
      _timer = Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          _step = 2;
          _strobeTrigger++;
          _shakeTrigger++;
        });
        _timer = Timer(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          setState(() => _step = 3);
          _timer = Timer(const Duration(milliseconds: 1500), () {
            if (!mounted) return;
            setState(() => _step = 4);
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _skip() {
    if (_step >= 4) return;
    _timer?.cancel();
    setState(() => _step = 4);
  }

  Future<void> _complete() async {
    await ClassService().clearPendingUltimateReveal();
    // Grant the epic frame for this class.
    if (_cls != null) {
      final frameId = 'frame_epic_${_cls!.name}';
      await LootService().grantItem(frameId);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_cls == null) return const Scaffold(backgroundColor: kBg);

    final color = _cls!.themeColor;
    final ultimate = ultimateAbility(_cls!);

    return GestureDetector(
      onTap: _step < 4 ? _skip : null,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: ScreenShake(
            trigger: _shakeTrigger,
            magnitude: 6,
            frames: 8,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(kSpace5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title
                    if (_step >= 1)
                      StrobeFlash(
                        trigger: _strobeTrigger,
                        fireOnMount: true,
                        color: kAmber,
                        opacity: 0.4,
                        toggles: 8,
                        child: const Text(
                          'ULTIMATE UNLOCKED',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 12,
                            color: kAmber,
                          ),
                        ),
                      ),
                    if (_step >= 1) const SizedBox(height: kSpace5),

                    // Class sigil
                    if (_step >= 2)
                      ClassSprite(
                        assetPath: 'assets/classes/sigils/${_cls!.name}.png',
                        placeholderTint: color,
                        size: 80,
                        placeholderLabel: _cls!.displayName,
                      ),
                    if (_step >= 2) const SizedBox(height: kSpace5),

                    // Ability card
                    if (_step >= 2)
                      Container(
                        padding: const EdgeInsets.all(kSpace4),
                        decoration: BoxDecoration(
                          color: kAmber.withValues(alpha: 0.08),
                          border: Border.all(color: kAmber.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            Text(
                              ultimate.name,
                              style: const TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 12,
                                color: kAmber,
                              ),
                            ),
                            const SizedBox(height: kSpace3),
                            TypewriterText(
                              ultimate.description,
                              style: GoogleFonts.shareTechMono(
                                fontSize: 13,
                                color: kText,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                    if (_step >= 3) const SizedBox(height: kSpace5),

                    // Reward note
                    if (_step >= 3)
                      Text(
                        'EPIC FRAME UNLOCKED',
                        style: GoogleFonts.shareTechMono(
                          fontSize: 11,
                          color: kAmber.withValues(alpha: 0.7),
                        ),
                      ),

                    if (_step >= 4) const SizedBox(height: kSpace5),

                    // Done button
                    if (_step >= 4)
                      PixelButton(
                        label: 'CLAIM POWER',
                        color: kAmber,
                        onPressed: _complete,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
