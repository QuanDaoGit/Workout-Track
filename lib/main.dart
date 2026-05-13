import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pages/root_page.dart';

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const RootPage(),
      builder: (context, child) => Stack(
        children: [
          child!,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ScanlinePainter()),
            ),
          ),
        ],
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00FF9C),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        cardColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D1A),
          foregroundColor: Color(0xFF00FF9C),
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 14,
            color: Color(0xFF00FF9C),
          ),
          shape: Border(bottom: BorderSide(color: Color(0xFF2A2A4A))),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00FF9C),
            textStyle: GoogleFonts.shareTechMono(),
            side: const BorderSide(color: Color(0xFF00FF9C), width: 1),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00FF9C),
            foregroundColor: const Color(0xFF0D0D1A),
            textStyle: GoogleFonts.shareTechMono(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
        chipTheme: const ChipThemeData(
          selectedColor: Color(0xFF00FF9C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            side: BorderSide(color: Color(0xFF2A2A4A)),
          ),
        ),
        textTheme: GoogleFonts.shareTechMonoTextTheme().copyWith(
          headlineLarge: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 18,
            color: Color(0xFF00FF9C),
          ),
          headlineMedium: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 14,
            color: Color(0xFF00FF9C),
          ),
          headlineSmall: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: Color(0xFF00FF9C),
          ),
          titleLarge: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            color: Color(0xFFE8E8FF),
          ),
          bodySmall: GoogleFonts.shareTechMono(
            color: const Color(0xFF6B6B8A),
            fontSize: 14,
          ),
          bodyMedium: GoogleFonts.shareTechMono(
            color: const Color(0xFFE8E8FF),
            fontSize: 14,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0D0D1A),
          selectedItemColor: Color(0xFF00FF9C),
          unselectedItemColor: Color(0xFF6B6B8A),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            side: BorderSide(color: Color(0xFF2A2A4A)),
          ),
        ),
      ),
    );
  }
}
