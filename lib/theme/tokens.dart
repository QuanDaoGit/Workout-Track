import 'package:flutter/material.dart';

// Palette — single source of truth for arcade theme colors.
const kBg = Color(0xFF11111F);
const kBgGradientTop = Color(0xFF15152C);
const kBgGradientBottom = Color(0xFF0E0E1B);
const kCard = Color(0xFF1C1C34);
const kSurface2 = Color(0xFF232342);
const kSurface3 = Color(0xFF2A2A4E);
const kBorder = Color(0xFF36365E);
const kBorderVariant = Color(0xFF45437A);
const kBorderDark = Color(0xFF2A2A3E);
const kNeon = Color(0xFF00FF9C);
const kNeonDark = Color(0xFF009955);
const kText = Color(0xFFE8E8FF);
const kMutedText = Color(0xFF9494B8);
const kDim = Color(0xFF555577);

// Accent colors — officially part of the palette as of this UI polish pass.
const kAmber = Color(0xFFFFD700);
const kAmberDark = Color(0xFFFFA500);
const kCyan = Color(0xFF00BFFF);
const kDanger = Color(0xFFFF2D55);

// Spacing scale (4/8/12/16/24).
const kSpace1 = 4.0;
const kSpace2 = 8.0;
const kSpace3 = 12.0;
const kSpace4 = 16.0;
const kSpace5 = 24.0;

// Shared layout rules for primary mobile surfaces.
const kHomeHorizontalPadding = 16.0;
const kCardPadding = 16.0;
const kCardRadius = 4.0;
const kSectionGap = 16.0;
const kButtonHeight = 48.0;
const kPrimaryCardBorderWidth = 1.2;

// Focused neon bloom for emissive depth on dark surfaces.
List<BoxShadow> neonGlow({Color color = kNeon, double opacity = 0.22, double blur = 16}) =>
    [BoxShadow(color: color.withValues(alpha: opacity), blurRadius: blur, spreadRadius: -2)];
