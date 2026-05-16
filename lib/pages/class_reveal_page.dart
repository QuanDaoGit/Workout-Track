import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/class_definitions.dart';
import '../models/character_class.dart';
import '../theme/tokens.dart';
import '../widgets/class_sprite.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_shake.dart';
import '../widgets/strobe_flash.dart';
import '../widgets/typewriter_text.dart';

/// Cinematic reveal page after selecting a class.
class ClassRevealPage extends StatefulWidget {
  const ClassRevealPage({super.key, required this.characterClass});

  final CharacterClass characterClass;

  @override
  State<ClassRevealPage> createState() => _ClassRevealPageState();
}

class _ClassRevealPageState extends State<ClassRevealPage> {
  int _step = 0; // 0=dark, 1=icon+name, 2=ability, 3=teaser, 4=button
  int _shakeTrigger = 0;
  int _strobeTrigger = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _runSequence();
  }

  void _runSequence() {
    _timer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _step = 1;
        _shakeTrigger++;
        _strobeTrigger++;
      });
      _timer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() => _step = 2);
        _timer = Timer(const Duration(milliseconds: 1800), () {
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

  @override
  Widget build(BuildContext context) {
    final color = widget.characterClass.themeColor;
    final primary = primaryAbility(widget.characterClass);

    return GestureDetector(
      onTap: _step < 4 ? _skip : null,
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
                    // Class icon
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

                    // Class name
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
                        style: GoogleFonts.shareTechMono(
                          fontSize: 12,
                          color: kMutedText,
                        ),
                      ),

                    if (_step >= 2) const SizedBox(height: kSpace5),

                    // Primary ability reveal
                    if (_step >= 2)
                      Container(
                        padding: const EdgeInsets.all(kSpace4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'ABILITY UNLOCKED',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 8,
                                color: color.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: kSpace2),
                            Text(
                              primary.name,
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 11,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: kSpace2),
                            TypewriterText(
                              primary.description,
                              style: GoogleFonts.shareTechMono(
                                fontSize: 12,
                                color: kText,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                    if (_step >= 3) const SizedBox(height: kSpace5),

                    // Teaser
                    if (_step >= 3)
                      Text(
                        'A second power lies ahead...',
                        style: GoogleFonts.shareTechMono(
                          fontSize: 12,
                          color: kAmber.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),

                    if (_step >= 4) const SizedBox(height: kSpace5),

                    // Continue button
                    if (_step >= 4)
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
