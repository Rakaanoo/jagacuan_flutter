import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light Mode Colors (Cream Theme)
  static const Color lightBg = Color(0xFFFAF7F2);
  static const Color lightCard = Color(0xFFFAF6EF);
  static const Color lightSurface = Color(0xFFEFEADF);
  static const Color lightTextPrimary = Color(0xFF2C2418);
  static const Color lightTextMuted = Color(0xFF7A6F60);
  static const Color lightBorder = Color(0xFFE0D5C3);

  // Dark Mode Colors (Charcoal Theme)
  static const Color darkBg = Color(0xFF16171B);
  static const Color darkCard = Color(0xFF23242A);
  static const Color darkSurface = Color(0xFF1C1D22);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextMuted = Color(0xFFA0A5B5);
  static const Color darkBorder = Color(0xFF333644);

  // Accent Colors
  static const Color primaryAccent = Color(0xFF7C8BFF);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBg,
    colorScheme: const ColorScheme.light(
      primary: lightTextPrimary,
      secondary: primaryAccent,
      surface: lightCard,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: lightTextPrimary,
        letterSpacing: -0.3,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: lightTextPrimary,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: lightTextPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: lightTextPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: lightTextMuted,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: lightTextMuted,
      ),
    ),
    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: lightBorder, width: 1),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: primaryAccent,
      secondary: primaryAccent,
      surface: darkCard,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme)
        .copyWith(
          headlineLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: darkTextPrimary,
            letterSpacing: -0.3,
          ),
          headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: darkTextPrimary,
            letterSpacing: -0.2,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: darkTextPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: darkTextPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: darkTextPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: darkTextMuted,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: darkTextMuted,
          ),
        ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
  );

  // Dynamic Theme Helpers
  static Color bg(bool isDark) => isDark ? darkBg : lightBg;
  static Color card(bool isDark) => isDark ? darkCard : lightCard;
  static Color surface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color border(bool isDark) => isDark ? darkBorder : lightBorder;
  static Color textPrimary(bool isDark) =>
      isDark ? darkTextPrimary : lightTextPrimary;
  static Color textMuted(bool isDark) =>
      isDark ? darkTextMuted : lightTextMuted;

  // Status Badges
  static Color badgeSuccessBg(bool isDark) =>
      isDark ? const Color(0xFF16382B) : const Color(0xFFE6F4EA);
  static Color badgeSuccessBorder(bool isDark) =>
      isDark ? const Color(0xFF266E53) : const Color(0xFFA8DAB5);
  static Color badgeSuccessText(bool isDark) =>
      isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D);

  static Color badgeWarningBg(bool isDark) =>
      isDark ? const Color(0xFF382D16) : const Color(0xFFFEF7E0);
  static Color badgeWarningBorder(bool isDark) =>
      isDark ? const Color(0xFF7A5E1C) : const Color(0xFFFEE79A);
  static Color badgeWarningText(bool isDark) =>
      isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
}

extension AppThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get appBg => AppTheme.bg(isDarkMode);
  Color get appCard => AppTheme.card(isDarkMode);
  Color get appSurface => AppTheme.surface(isDarkMode);
  Color get appBorder => AppTheme.border(isDarkMode);
  Color get appTextPrimary => AppTheme.textPrimary(isDarkMode);
  Color get appTextMuted => AppTheme.textMuted(isDarkMode);
  Color get appAccent => AppTheme.primaryAccent;
  Color get appSuccess => AppTheme.success;
  Color get appWarning => AppTheme.warning;
  Color get appDanger => AppTheme.danger;

  Color get appBadgeSuccessBg => AppTheme.badgeSuccessBg(isDarkMode);
  Color get appBadgeSuccessBorder => AppTheme.badgeSuccessBorder(isDarkMode);
  Color get appBadgeSuccessText => AppTheme.badgeSuccessText(isDarkMode);

  Color get appBadgeWarningBg => AppTheme.badgeWarningBg(isDarkMode);
  Color get appBadgeWarningBorder => AppTheme.badgeWarningBorder(isDarkMode);
  Color get appBadgeWarningText => AppTheme.badgeWarningText(isDarkMode);
}
