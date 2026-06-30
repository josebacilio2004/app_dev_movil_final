import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta Industrial Premium "Comercializadora Aly"
  static const Color primaryDark = Color(0xFF030712); // Deep Charcoal Blue
  static const Color accentOrange = Color(0xFFFD761A); // Official Logo Orange
  static const Color surfaceDark = Color(0xFF0F172A); // Slate Surface
  static const Color cardOpacity = Color(0x1A64748B); // Glass-like transparency
  static const Color textWhite = Color(0xFFF8FAFC);
  static const Color textGray = Color(0xFF94A3B8);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);

  // Sombras y Efectos
  static List<BoxShadow> premiumShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.5),
      blurRadius: 20,
      offset: const Offset(0, 10),
    )
  ];

  static BoxDecoration glassDecoration = BoxDecoration(
    color: surfaceDark.withOpacity(0.7),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.08)),
  );

  // Gradiante Industrial (Restaurado para AdminDashboard)
  static const LinearGradient industrialGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], // Índigo a Violeta
  );

  static ThemeData get industrialTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: accentOrange,
        secondary: Color(0xFF6366F1), // Indigo accents
        surface: surfaceDark,
        onSurface: textWhite,
        background: primaryDark,
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: textWhite,
        displayColor: textWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentOrange, width: 2),
        ),
        labelStyle: const TextStyle(color: textGray, fontSize: 13),
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentOrange,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 8,
          shadowColor: accentOrange.withOpacity(0.3),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 14),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: const ColorScheme.light(
        primary: accentOrange,
        secondary: Color(0xFF4F46E5),
        surface: Colors.white,
        onSurface: Color(0xFF0F172A),
        background: Color(0xFFF8FAFC),
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: const Color(0xFF0F172A),
        displayColor: const Color(0xFF0F172A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withOpacity(0.02),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentOrange, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentOrange,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          shadowColor: accentOrange.withOpacity(0.25),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 14),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
      ),
    );
  }
}
