import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand Colors (Light) — Wintech Agro Blue ──────────────────────────
  static const Color primaryBg = Color(0xFFF0F8FD);       // Very light blue tint
  static const Color primaryAccent = Color(0xFF1B9DD9);   // Wintech Blue
  static const Color secondaryAccent = Color(0xFF56C1E8); // Light Blue
  static const Color textDark = Color(0xFF1A2D3D);
  static const Color textGrey = Color(0xFF7A8EA0);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFD6EAF5);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57F17);
  static const Color error = Color(0xFFC62828);
  static const Color lightAccent = Color(0xFFE1F4FD);     // Very light blue tint

  // ── Brand Colors (Dark) ──────────────────────────────────────────────
  static const Color darkBg = Color(0xFF0D1B26);
  static const Color darkCard = Color(0xFF152435);
  static const Color darkCard2 = Color(0xFF1E3045);
  static const Color darkDivider = Color(0xFF2A3F52);
  static const Color darkText = Color(0xFFEEEEEE);
  static const Color darkTextGrey = Color(0xFF8BAEC5);
  static const Color darkAccentSoft = Color(0xFF003D5C); // dark blue tint

  // ── Text theme factory ────────────────────────────────────────────────
  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: GoogleFonts.hindSiliguri(
            fontSize: 28, fontWeight: FontWeight.w700, color: primary),
        displayMedium: GoogleFonts.hindSiliguri(
            fontSize: 24, fontWeight: FontWeight.w700, color: primary),
        displaySmall: GoogleFonts.hindSiliguri(
            fontSize: 20, fontWeight: FontWeight.w600, color: primary),
        headlineMedium: GoogleFonts.hindSiliguri(
            fontSize: 18, fontWeight: FontWeight.w600, color: primary),
        headlineSmall: GoogleFonts.hindSiliguri(
            fontSize: 16, fontWeight: FontWeight.w600, color: primary),
        titleLarge: GoogleFonts.hindSiliguri(
            fontSize: 15, fontWeight: FontWeight.w600, color: primary),
        titleMedium: GoogleFonts.hindSiliguri(
            fontSize: 14, fontWeight: FontWeight.w500, color: primary),
        titleSmall: GoogleFonts.hindSiliguri(
            fontSize: 13, fontWeight: FontWeight.w500, color: secondary),
        bodyLarge: GoogleFonts.hindSiliguri(
            fontSize: 15, fontWeight: FontWeight.w400, color: primary),
        bodyMedium: GoogleFonts.hindSiliguri(
            fontSize: 14, fontWeight: FontWeight.w400, color: primary),
        bodySmall: GoogleFonts.hindSiliguri(
            fontSize: 12, fontWeight: FontWeight.w400, color: secondary),
        labelLarge: GoogleFonts.hindSiliguri(
            fontSize: 14, fontWeight: FontWeight.w600, color: cardWhite),
        labelMedium: GoogleFonts.hindSiliguri(
            fontSize: 12, fontWeight: FontWeight.w500, color: secondary),
        labelSmall: GoogleFonts.hindSiliguri(
            fontSize: 11, fontWeight: FontWeight.w400, color: secondary),
      );

  // ── Light Theme ───────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.light,
        seedColor: primaryAccent,
        primary: primaryAccent,
        secondary: secondaryAccent,
        surface: primaryBg,
        onPrimary: cardWhite,
        onSecondary: cardWhite,
        onSurface: textDark,
      ),
      scaffoldBackgroundColor: primaryBg,
      textTheme: _textTheme(textDark, textGrey),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryAccent,
        foregroundColor: cardWhite,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.hindSiliguri(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: cardWhite,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: cardWhite,
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.hindSiliguri(
              fontSize: 16, fontWeight: FontWeight.w700),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAccent,
          side: const BorderSide(color: primaryAccent, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.hindSiliguri(
              fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardWhite,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        hintStyle:
            GoogleFonts.hindSiliguri(fontSize: 14, color: textGrey),
      ),
      cardTheme: CardThemeData(
        color: cardWhite,
        elevation: 2,
        shadowColor: Colors.black12,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? primaryAccent : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? primaryAccent.withValues(alpha: 0.4)
                : Colors.grey.withValues(alpha: 0.3)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardWhite,
        selectedItemColor: primaryAccent,
        unselectedItemColor: textGrey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
    );
  }

  // ── Dark Theme ────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: primaryAccent,
        primary: primaryAccent,
        secondary: secondaryAccent,
        surface: darkBg,
        onPrimary: cardWhite,
        onSecondary: cardWhite,
        onSurface: darkText,
      ),
      scaffoldBackgroundColor: darkBg,
      textTheme: _textTheme(darkText, darkTextGrey),
      appBarTheme: AppBarTheme(
        backgroundColor: darkCard,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.hindSiliguri(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: cardWhite,
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.hindSiliguri(
              fontSize: 16, fontWeight: FontWeight.w700),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAccent,
          side: const BorderSide(color: primaryAccent, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.hindSiliguri(
              fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkDivider, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkDivider, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        hintStyle:
            GoogleFonts.hindSiliguri(fontSize: 14, color: darkTextGrey),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme:
          const DividerThemeData(color: darkDivider, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? primaryAccent : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? primaryAccent.withValues(alpha: 0.4)
                : Colors.grey.withValues(alpha: 0.3)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkCard,
        selectedItemColor: primaryAccent,
        unselectedItemColor: darkTextGrey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
    );
  }
}
