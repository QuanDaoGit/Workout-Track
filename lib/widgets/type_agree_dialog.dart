import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/tokens.dart';
import 'pixel_button.dart';

/// A confirmation dialog requiring the user to type "AGREE" to proceed.
/// Returns true if confirmed, false/null if cancelled.
class TypeAgreeDialog extends StatefulWidget {
  const TypeAgreeDialog({
    super.key,
    this.title = 'CONFIRM CLASS CHANGE',
    this.message = 'Switching class will reset your current class path.',
  });

  final String title;
  final String message;

  @override
  State<TypeAgreeDialog> createState() => _TypeAgreeDialogState();
}

class _TypeAgreeDialogState extends State<TypeAgreeDialog> {
  final _controller = TextEditingController();
  bool _isMatch = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final match = _controller.text.trim().toUpperCase() == 'AGREE';
      if (match != _isMatch) setState(() => _isMatch = match);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: kBorder),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 10,
          color: kAmber,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message,
            style: GoogleFonts.shareTechMono(fontSize: 13, color: kText),
          ),
          const SizedBox(height: kSpace4),
          Text(
            'Type AGREE to confirm:',
            style: GoogleFonts.shareTechMono(fontSize: 12, color: kMutedText),
          ),
          const SizedBox(height: kSpace2),
          TextField(
            controller: _controller,
            autofocus: true,
            style: GoogleFonts.shareTechMono(fontSize: 14, color: kText),
            decoration: InputDecoration(
              hintText: 'AGREE',
              hintStyle: GoogleFonts.shareTechMono(
                fontSize: 14,
                color: kMutedText.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: kBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: kAmber),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'CANCEL',
            style: GoogleFonts.shareTechMono(fontSize: 12, color: kMutedText),
          ),
        ),
        PixelButton(
          label: 'CONFIRM',
          color: _isMatch ? kDanger : kMutedText,
          onPressed: _isMatch ? () => Navigator.pop(context, true) : null,
        ),
      ],
    );
  }
}
