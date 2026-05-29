import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import 'focus_frame.dart';

class ArcadeNameEditingController extends TextEditingController {
  Timer? _echoTimer;
  String _previousText = '';
  int? _echoIndex;
  bool _reduceMotion = false;

  void setReduceMotion(bool value) {
    _reduceMotion = value;
    if (value) {
      _echoTimer?.cancel();
      _echoIndex = null;
    }
  }

  void handleTextChanged(String value) {
    if (_reduceMotion) {
      _previousText = value;
      return;
    }

    final insertedOne = value.length == _previousText.length + 1;
    if (insertedOne) {
      var index = 0;
      while (index < _previousText.length &&
          index < value.length &&
          _previousText[index] == value[index]) {
        index++;
      }
      _echoIndex = index.clamp(0, value.length - 1);
      _echoTimer?.cancel();
      _echoTimer = Timer(const Duration(milliseconds: 100), () {
        _echoIndex = null;
        notifyListeners();
      });
      notifyListeners();
    } else {
      _echoIndex = null;
    }
    _previousText = value;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    if (_echoIndex == null || _echoIndex! < 0 || _echoIndex! >= text.length) {
      return TextSpan(text: text, style: baseStyle);
    }

    final children = <TextSpan>[];
    for (var i = 0; i < text.length; i++) {
      children.add(
        TextSpan(
          text: text[i],
          style: i == _echoIndex ? baseStyle.copyWith(color: kNeon) : baseStyle,
        ),
      );
    }
    return TextSpan(style: baseStyle, children: children);
  }

  @override
  void dispose() {
    _echoTimer?.cancel();
    super.dispose();
  }
}

class ArcadeNameField extends StatefulWidget {
  const ArcadeNameField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    this.error = false,
  });

  static final allowedCharacters = RegExp(r"[A-Za-z0-9 '\-]");

  final ArcadeNameEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final bool error;

  @override
  State<ArcadeNameField> createState() => _ArcadeNameFieldState();
}

class _ArcadeNameFieldState extends State<ArcadeNameField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(covariant ArcadeNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    oldWidget.focusNode.removeListener(_focusChanged);
    widget.focusNode.addListener(_focusChanged);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusChanged);
    super.dispose();
  }

  void _focusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;
    widget.controller.setReduceMotion(reduceMotion);
    final count = widget.controller.text.length;

    return FocusFrame(
      focused: widget.focusNode.hasFocus,
      error: widget.error,
      height: 56,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TextField(
            key: const ValueKey('name_input_field'),
            controller: widget.controller,
            focusNode: widget.focusNode,
            autocorrect: false,
            enableSuggestions: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.text,
            cursorWidth: 8,
            cursorColor: kNeon,
            cursorOpacityAnimates: !reduceMotion,
            maxLines: 1,
            maxLength: 16,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                ArcadeNameField.allowedCharacters,
              ),
              LengthLimitingTextInputFormatter(16),
            ],
            style: AppFonts.shareTechMono(
              color: kText,
              fontSize: 18,
              height: 1.2,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.fromLTRB(16, 17, 86, 0),
              isCollapsed: true,
            ),
            onChanged: (value) {
              widget.controller.handleTextChanged(value);
              widget.onChanged(value);
            },
            onSubmitted: (_) => widget.onSubmitted(),
          ),
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Semantics(
                label: '$count of 16 characters',
                child: Text(
                  '$count/16',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    color: kMutedText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
