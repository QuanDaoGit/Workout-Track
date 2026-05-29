import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum OnboardingLifterSpriteMode { failed, triumph }

class OnboardingLifterSprite extends StatelessWidget {
  const OnboardingLifterSprite({
    super.key,
    required this.mode,
    this.width = 160,
    this.height = 120,
    this.edgeColor,
    this.bodyColor,
    this.blinkProgress = 0,
  });

  final OnboardingLifterSpriteMode mode;
  final double width;
  final double height;
  final Color? edgeColor;
  final Color? bodyColor;
  final double blinkProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _OnboardingLifterSpritePainter(
          mode: mode,
          edgeColor: edgeColor,
          bodyColor: bodyColor,
          blinkProgress: blinkProgress,
        ),
      ),
    );
  }
}

class _OnboardingLifterSpritePainter extends CustomPainter {
  const _OnboardingLifterSpritePainter({
    required this.mode,
    this.edgeColor,
    this.bodyColor,
    this.blinkProgress = 0,
  });

  final OnboardingLifterSpriteMode mode;
  final Color? edgeColor;
  final Color? bodyColor;
  final double blinkProgress;

  static const _body = Color(0xFF2A2A4A);
  static const _dimBody = Color(0xFF3A3A55);
  static const _floor = Color(0xFF1A1A2E);
  static const _bench = Color(0xFF33334D);
  static const _barDim = Color(0xFF3A3A4A);

  @override
  void paint(Canvas canvas, Size size) {
    switch (mode) {
      case OnboardingLifterSpriteMode.failed:
        _withGrid(canvas, size, const Size(40, 30), _drawFailed);
      case OnboardingLifterSpriteMode.triumph:
        _withGrid(canvas, size, const Size(35, 25), _drawTriumph);
    }
  }

  void _withGrid(
    Canvas canvas,
    Size size,
    Size grid,
    void Function(Canvas canvas) draw,
  ) {
    final scale = (size.width / grid.width)
        .clamp(0.0, size.height / grid.height)
        .toDouble();
    canvas
      ..save()
      ..translate(
        (size.width - grid.width * scale) / 2,
        (size.height - grid.height * scale) / 2,
      )
      ..scale(scale);
    draw(canvas);
    canvas.restore();
  }

  void _rect(Canvas canvas, double x, double y, double w, double h, Color c) {
    final paint = Paint()
      ..color = c
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
  }

  void _drawFailed(Canvas canvas) {
    final body = bodyColor ?? _dimBody;
    final edge = edgeColor ?? kDim;

    _rect(canvas, 0, 28, 40, 1, _floor);
    _rect(canvas, 12, 22, 18, 2, _bench);
    _rect(canvas, 14, 24, 2, 4, _body);
    _rect(canvas, 26, 24, 2, 4, _body);
    _rect(canvas, 12, 27, 6, 1, _body);
    _rect(canvas, 24, 27, 6, 1, _body);

    _rect(canvas, 2, 25, 9, 1, _barDim);
    _rect(canvas, 2, 24, 1, 3, _body);
    _rect(canvas, 10, 24, 1, 3, _body);

    _rect(canvas, 18, 20, 6, 2, body);
    _rect(canvas, 22, 22, 6, 2, body);
    _rect(canvas, 26, 24, 2, 4, body);
    _rect(canvas, 25, 27, 4, 1, body);

    _rect(canvas, 18, 14, 6, 6, body);
    _rect(canvas, 18, 13, 6, 1, edge);
    _rect(canvas, 17, 16, 1, 5, body);
    _rect(canvas, 24, 16, 1, 5, body);

    _rect(canvas, 22, 9, 5, 5, body);
    _rect(canvas, 22, 8, 5, 1, edge);
    _rect(canvas, 25, 11, 1, 1, const Color(0xFF111118));
  }

  void _drawTriumph(Canvas canvas) {
    final body = bodyColor ?? _body;
    final edge = edgeColor ?? kAmber;

    _rect(canvas, 0, 23, 35, 1, _floor);

    _rect(canvas, 12, 17, 3, 6, body);
    _rect(canvas, 20, 17, 3, 6, body);
    _rect(canvas, 11, 17, 1, 6, edge);
    _rect(canvas, 23, 17, 1, 6, edge);
    _rect(canvas, 10, 22, 6, 1, body);
    _rect(canvas, 19, 22, 6, 1, body);

    _rect(canvas, 11, 14, 13, 4, body);
    _rect(canvas, 11, 13, 13, 1, edge);
    _rect(canvas, 12, 9, 11, 6, body);
    _rect(canvas, 11, 9, 1, 7, edge);
    _rect(canvas, 12, 8, 11, 1, edge);

    _rect(canvas, 8, 11, 3, 2, body);
    _rect(canvas, 7, 12, 2, 5, body);
    _rect(canvas, 6, 16, 3, 2, edge);

    _rect(canvas, 23, 9, 3, 3, body);
    _rect(canvas, 25, 6, 3, 4, body);
    _rect(canvas, 26, 2, 3, 5, body);
    _rect(canvas, 25, 0, 6, 4, body);
    _rect(canvas, 23, 8, 3, 1, edge);
    _rect(canvas, 25, 6, 1, 4, edge);
    _rect(canvas, 26, 2, 1, 5, edge);
    _rect(canvas, 25, 0, 6, 1, edge);
    _rect(canvas, 31, 1, 1, 3, edge);

    _rect(canvas, 14, 2, 7, 7, body);
    _rect(canvas, 14, 1, 7, 1, edge);
    _rect(canvas, 13, 4, 1, 4, edge);
    final blinkPhase = blinkProgress % 1;
    final isBlinkClosed = blinkPhase >= 0.48 && blinkPhase < 0.52;
    if (isBlinkClosed) {
      _rect(canvas, 17, 5, 3, 1, const Color(0xFF111118));
    } else {
      _rect(canvas, 18, 5, 1, 1, kText);
    }
    _rect(canvas, 16, 7, 4, 1, const Color(0xFF111118));
  }

  @override
  bool shouldRepaint(covariant _OnboardingLifterSpritePainter oldDelegate) {
    return mode != oldDelegate.mode ||
        edgeColor != oldDelegate.edgeColor ||
        bodyColor != oldDelegate.bodyColor ||
        blinkProgress != oldDelegate.blinkProgress;
  }
}
