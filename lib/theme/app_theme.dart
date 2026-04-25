import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Color tokens từ DESIGN.md ──
  static const primary = Color(0xFF005DAC);
  static const primaryContainer = Color(0xFF1976D2);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryFixed = Color(0xFFD4E3FF);
  static const onPrimaryFixed = Color(0xFF001C3A);

  static const secondary = Color(0xFF475F84);
  static const secondaryContainer = Color(0xFFBAD3FD);
  static const onSecondary = Color(0xFFFFFFFF);

  static const tertiary = Color(0xFF944700);
  static const tertiaryContainer = Color(0xFFBA5B00);
  static const onTertiary = Color(0xFFFFFFFF);

  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onError = Color(0xFFFFFFFF);

  static const surface = Color(0xFFF8F9FA);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF3F4F5);
  static const surfaceContainer = Color(0xFFEDEEEF);
  static const surfaceContainerHigh = Color(0xFFE7E8E9);
  static const surfaceContainerHighest = Color(0xFFE1E3E4);
  static const surfaceDim = Color(0xFFD9DADB);

  static const onSurface = Color(0xFF191C1D);
  static const onSurfaceVariant = Color(0xFF414752);
  static const outline = Color(0xFF717783);
  static const outlineVariant = Color(0xFFC1C6D4);

  // ── Gradient chính (DESIGN.md: 135°) ──
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );

  // ── Typography: Manrope (headline) + Inter (body) ──
  static TextTheme _buildTextTheme(double scale) => TextTheme(
        displayLarge: GoogleFonts.manrope(
            fontSize: 57 * scale, fontWeight: FontWeight.w800),
        displayMedium: GoogleFonts.manrope(
            fontSize: 45 * scale, fontWeight: FontWeight.w800),
        displaySmall: GoogleFonts.manrope(
            fontSize: 36 * scale, fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.manrope(
            fontSize: 32 * scale, fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.manrope(
            fontSize: 28 * scale, fontWeight: FontWeight.w700),
        headlineSmall: GoogleFonts.manrope(
            fontSize: 24 * scale, fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.manrope(
            fontSize: 22 * scale, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.inter(
            fontSize: 16 * scale,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15),
        titleSmall: GoogleFonts.inter(
            fontSize: 14 * scale,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1),
        bodyLarge: GoogleFonts.inter(
            fontSize: 16 * scale, fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.inter(
            fontSize: 14 * scale, fontWeight: FontWeight.w400),
        bodySmall: GoogleFonts.inter(
            fontSize: 12 * scale, fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.inter(
            fontSize: 14 * scale,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1),
        labelMedium: GoogleFonts.inter(
            fontSize: 12 * scale,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5),
        labelSmall: GoogleFonts.inter(
            fontSize: 10 * scale,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5),
      );

  static ThemeData get light => lightWithScale(1.0);

  static ThemeData lightWithScale(double scale) {
    // Giới hạn scale để tránh quá nhỏ hoặc quá lớn
    final s = scale.clamp(0.8, 1.15);

    return ThemeData(
      useMaterial3: true,
      visualDensity: s < 1.0 ? VisualDensity.compact : VisualDensity.standard,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryFixed,
        onPrimaryContainer: onPrimaryFixed,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: Color(0xFF425B7F),
        tertiary: tertiary,
        onTertiary: onTertiary,
        tertiaryContainer: Color(0xFFFFDBC7),
        onTertiaryContainer: Color(0xFF311300),
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: Color(0xFF93000A),
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFF2E3132),
        onInverseSurface: Color(0xFFF0F1F2),
        inversePrimary: Color(0xFFA5C8FF),
      ),
      textTheme: _buildTextTheme(s),
      scaffoldBackgroundColor: surface,
      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceContainerLowest,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * s)),
        margin: EdgeInsets.zero,
      ),
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20 * s,
          fontWeight: FontWeight.w800,
          color: primary,
          letterSpacing: -0.5,
        ),
      ),
      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12 * s),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16 * s,
          vertical: 12 * s,
        ),
      ),
      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerLow,
        labelStyle: GoogleFonts.inter(
            fontSize: 10 * s, fontWeight: FontWeight.w700, letterSpacing: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 4 * s),
      ),
      // BottomNav
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.withOpacity(0.7),
        elevation: 0,
        height: 72 * s,
        indicatorColor: primary.withOpacity(0.1),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 0),
        ),
      ),
    );
  }
}
