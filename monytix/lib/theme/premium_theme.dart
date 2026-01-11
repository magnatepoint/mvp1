import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/platform_utils.dart';

class PremiumTheme {
  // Gold color scheme
  static const Color goldPrimary = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFE8D08A);
  static const Color goldDark = Color(0xFFB8941F);
  
  // Glassmorphism colors
  static const Color glassBackground = Color(0x40FFFFFF);
  static const Color glassBorder = Color(0x80FFFFFF);
  
  // Gradient colors
  static const List<Color> goldGradient = [
    Color(0xFFD4AF37),
    Color(0xFFE8D08A),
    Color(0xFFD4AF37),
  ];
  
  static const List<Color> darkGoldGradient = [
    Color(0xFFB8941F),
    Color(0xFFD4AF37),
    Color(0xFFB8941F),
  ];

  // Get platform-specific theme
  static ThemeData getLightTheme() {
    final isIOS = PlatformUtils.isIOS;
    
    final baseTheme = isIOS
        ? CupertinoThemeData(
            primaryColor: goldPrimary,
            brightness: Brightness.light,
          )
        : ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: goldPrimary,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          );

    return ThemeData(
      useMaterial3: !isIOS,
      colorScheme: ColorScheme.fromSeed(
        seedColor: goldPrimary,
        brightness: Brightness.light,
      ),
      primaryColor: goldPrimary,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Colors.black87,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Colors.black87,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: Colors.transparent,
      ),
    );
  }

  static ThemeData getDarkTheme() {
    final isIOS = PlatformUtils.isIOS;
    
    return ThemeData(
      useMaterial3: !isIOS,
      colorScheme: ColorScheme.fromSeed(
        seedColor: goldPrimary,
        brightness: Brightness.dark,
      ),
      primaryColor: goldPrimary,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Colors.white70,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Colors.white70,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: Colors.transparent,
      ),
    );
  }
}

