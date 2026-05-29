import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import 'focus_frame.dart';

class ArcadeTextEditingController extends TextEditingController {
  ArcadeTextEditingController({super.text});

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
    return TextSpan(
      style: baseStyle,
      children: [
        for (var i = 0; i < text.length; i++)
          TextSpan(
            text: text[i],
            style: i == _echoIndex
                ? baseStyle.copyWith(color: kNeon)
                : baseStyle,
          ),
      ],
    );
  }

  @override
  void dispose() {
    _echoTimer?.cancel();
    super.dispose();
  }
}

class ArcadeTextField extends StatefulWidget {
  const ArcadeTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.hintText,
    this.suffixText,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLength,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.enabled = true,
    this.error = false,
    this.height = 56,
    this.contentPadding,
    this.style,
    this.hintStyle,
    this.suffixStyle,
    this.counterText = '',
    this.enableEcho = true,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? hintText;
  final String? suffixText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLength;
  final int? maxLines;
  final TextAlign textAlign;
  final bool autofocus;
  final bool enabled;
  final bool error;
  final double? height;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final TextStyle? suffixStyle;
  final String? counterText;
  final bool enableEcho;

  @override
  State<ArcadeTextField> createState() => _ArcadeTextFieldState();
}

class _ArcadeTextFieldState extends State<ArcadeTextField> {
  late FocusNode _ownedFocusNode;
  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _ownedFocusNode = FocusNode();
    _focusNode.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(covariant ArcadeTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFocus = oldWidget.focusNode ?? _ownedFocusNode;
    if (oldFocus != _focusNode) {
      oldFocus.removeListener(_focusChanged);
      _focusNode.addListener(_focusChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_focusChanged);
    _ownedFocusNode.dispose();
    super.dispose();
  }

  void _focusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller is ArcadeTextEditingController) {
      controller.setReduceMotion(_reduceMotion || !widget.enableEcho);
    }
    return FocusFrame(
      focused: _focusNode.hasFocus,
      error: widget.error,
      height: widget.height,
      child: TextField(
        controller: controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        inputFormatters: widget.inputFormatters,
        maxLength: widget.maxLength,
        maxLines: widget.maxLines,
        textAlign: widget.textAlign,
        cursorWidth: 8,
        cursorColor: kNeon,
        cursorOpacityAnimates: !_reduceMotion,
        style:
            widget.style ??
            AppFonts.shareTechMono(color: kText, fontSize: 16, height: 1.2),
        decoration: InputDecoration(
          border: InputBorder.none,
          counterText: widget.counterText,
          hintText: widget.hintText,
          hintStyle:
              widget.hintStyle ??
              AppFonts.shareTechMono(color: kMutedText, fontSize: 14),
          prefixIcon: widget.prefixIcon,
          suffixText: widget.suffixText,
          suffixIcon: widget.suffixIcon,
          suffixStyle:
              widget.suffixStyle ??
              AppFonts.shareTechMono(color: kMutedText, fontSize: 14),
          contentPadding:
              widget.contentPadding ??
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        onTap: widget.onTap,
        onChanged: (value) {
          if (controller is ArcadeTextEditingController && widget.enableEcho) {
            controller.handleTextChanged(value);
          }
          widget.onChanged?.call(value);
        },
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
