import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/class_definitions.dart';
import '../models/character_class.dart';
import '../services/class_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import '../widgets/class_sprite.dart';
import '../widgets/pixel_button.dart';
import '../widgets/type_agree_dialog.dart';
import 'class_reveal_page.dart';

/// Page displaying the three class options for the player to choose from.
class ClassSelectPage extends StatefulWidget {
  const ClassSelectPage({super.key, this.isFirstSelection = true});

  final bool isFirstSelection;

  @override
  State<ClassSelectPage> createState() => _ClassSelectPageState();
}

class _ClassSelectPageState extends State<ClassSelectPage> {
  CharacterClass? _selected;

  Future<void> _confirmSelection(CharacterClass cls) async {
    if (!widget.isFirstSelection) {
      final agreed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const TypeAgreeDialog(),
      );
      if (agreed != true || !mounted) return;
      await ClassService().switchClass(cls);
    } else {
      await ClassService().selectClass(cls);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      arcadeRoute((_) => ClassRevealPage(characterClass: cls)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(kSpace4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: kSpace4),
              const Text(
                'CHOOSE YOUR CLASS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: kAmber,
                ),
              ),
              const SizedBox(height: kSpace2),
              Text(
                'Your class determines combat abilities.',
                textAlign: TextAlign.center,
                style: GoogleFonts.shareTechMono(
                  fontSize: 13,
                  color: kMutedText,
                ),
              ),
              const SizedBox(height: kSpace5),
              for (final cls in CharacterClass.values) ...[
                _ClassCard(
                  characterClass: cls,
                  isSelected: _selected == cls,
                  onTap: () => setState(() => _selected = cls),
                ),
                const SizedBox(height: kSpace3),
              ],
              const Spacer(),
              if (_selected != null)
                PixelButton(
                  label: widget.isFirstSelection ? 'SELECT' : 'SWITCH CLASS',
                  color: _selected!.themeColor,
                  onPressed: () => _confirmSelection(_selected!),
                ),
              const SizedBox(height: kSpace4),
              if (!widget.isFirstSelection)
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'CANCEL',
                      style: GoogleFonts.shareTechMono(
                        fontSize: 12,
                        color: kMutedText,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.characterClass,
    required this.isSelected,
    required this.onTap,
  });

  final CharacterClass characterClass;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = characterClass.themeColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(kSpace4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : kCard,
          border: Border.all(
            color: isSelected ? color : kBorder,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            ClassSprite(
              assetPath: 'assets/classes/icons/${characterClass.name}.png',
              placeholderTint: color,
              size: 48,
              placeholderLabel: characterClass.displayName[0],
            ),
            const SizedBox(width: kSpace4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    characterClass.displayName,
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: kSpace1),
                  Text(
                    'PATH OF THE ${characterClass.bodyGoalLabel}',
                    style: GoogleFonts.shareTechMono(
                      fontSize: 11,
                      color: kMutedText,
                    ),
                  ),
                  const SizedBox(height: kSpace1),
                  Text(
                    focusMusclesLabel(characterClass),
                    style: GoogleFonts.shareTechMono(
                      fontSize: 11,
                      color: color.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_sharp, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
