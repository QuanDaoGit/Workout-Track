import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../models/character_class.dart';
import '../theme/tokens.dart';
import '../widgets/class_sprite.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_shake.dart';
import '../widgets/strobe_flash.dart';

/// Cinematic reveal page after selecting a class.
/// Two-step: dark fade → sigil + name + path → CONTINUE.
class ClassRevealPage extends StatefulWidget {
  const ClassRevealPage({super.key, required this.characterClass});

  final CharacterClass characterClass;

  @override
  State<ClassRevealPage> createState() => _ClassRevealPageState();
}

class _ClassRevealPageState extends State<ClassRevealPage> {
  int _step = 0; // 0=dark, 1=icon+name+CONTINUE
  int _shakeTrigger = 0;
  int _strobeTrigger = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _step = 1;
        _shakeTrigger++;
        _strobeTrigger++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _skip() {
    if (_step >= 1) return;
    _timer?.cancel();
    setState(() {
      _step = 1;
      _shakeTrigger++;
      _strobeTrigger++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.characterClass.themeColor;

    return GestureDetector(
      onTap: _step < 1 ? _skip : null,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: ScreenShake(
            trigger: _shakeTrigger,
            magnitude: 4,
            frames: 6,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(kSpace5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_step >= 1)
                      StrobeFlash(
                        trigger: _strobeTrigger,
                        fireOnMount: true,
                        color: color,
                        opacity: 0.3,
                        child: ClassSprite(
                          assetPath:
                              'assets/classes/sigils/${widget.characterClass.name}.png',
                          placeholderTint: color,
                          size: 96,
                          placeholderLabel: widget.characterClass.displayName,
                        ),
                      ),
                    if (_step >= 1) const SizedBox(height: kSpace5),
                    if (_step >= 1)
                      Text(
                        widget.characterClass.displayName,
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 16,
                          color: color,
                        ),
                      ),
                    if (_step >= 1) const SizedBox(height: kSpace2),
                    if (_step >= 1)
                      Text(
                        'PATH OF THE ${widget.characterClass.bodyGoalLabel}',
                        style: AppFonts.shareTechMono(
                          fontSize: 12,
                          color: kMutedText,
                        ),
                      ),
                    if (_step >= 1) const SizedBox(height: kSpace5),
                    if (_step >= 1)
                      PixelButton(
                        label: 'CONTINUE',
                        color: color,
                        onPressed: () => Navigator.pop(context),
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
