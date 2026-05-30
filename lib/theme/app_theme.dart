import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFF2D5016); // Forest Green (#2D5016)
  static const Color primaryLight = Color(0xFF6BA84D); // Accent Matcha Green (#6BA84D)
  static const Color gold = Color(0xFFD4A574); // Premium Honey Gold (#D4A574)
  static const Color cream = Color(0xFFFDFBF7); // Warm Bakery Cream (#FDFBF7)
  static const Color charcoal = Color(0xFF1A1A1A); // Dark charcoal for high contrast text
  
  // Background & Surfaces
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color scaffoldBg = Color(0xFFF9F7F3); // Warm cream-tinted grey scaffold background
  
  // Status Colors
  static const Color success = Color(0xFF2D5016);
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color info = Color(0xFF1565C0);
  static const Color infoBg = Color(0xFFE3F2FD);

  // Text Colors (Highly legible high-contrast values)
  static const Color textPrimary = charcoal;
  static const Color textSecondary = Color(0xFF5A5A5A); // Classy muted warm grey
  static const Color textLight = Color(0xFF8F8F8F); // Soft elegant grey

  // Constants
  static const double borderRadius = 20.0;
  static const double cardPadding = 16.0;

  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: surface,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      useMaterial3: true,
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w800, color: primary, letterSpacing: -0.8),
        titleLarge: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
        titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.roboto(fontSize: 15, color: textPrimary, height: 1.4),
        bodyMedium: GoogleFonts.roboto(fontSize: 13, color: textSecondary, height: 1.4),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primary),
        titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: primary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      ),
    );
  }

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ];
}
