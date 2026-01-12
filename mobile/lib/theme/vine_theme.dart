// ABOUTME: Vine-inspired theme with characteristic green colors and clean design
// ABOUTME: Matches the classic Vine app aesthetic with proper color scheme and typography

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VineTheme {
  // Typography - Google Fonts
  // Bricolage Grotesque for titles (bold 800, default 22px with 28px line height)
  static TextStyle titleFont({
    double fontSize = 22,
    double? height,
    Color color = whiteText,
  }) => GoogleFonts.bricolageGrotesque(
    fontSize: fontSize,
    fontWeight: FontWeight.w800,
    height: height ?? 28 / 22,
    color: color,
  );

  // Inter for body and small text
  static TextStyle bodyFont({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color color = primaryText,
  }) => GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );

  // Classic Vine green color palette
  static const Color vineGreen = Color(0xFF00B488);
  static const Color vineGreenDark = Color(0xFF009A72);
  static const Color vineGreenLight = Color(0xFF33C49F);

  // Navigation colors
  static const Color navGreen = Color(0xFF00150D);
  static const Color iconButtonBackground = Color(0xFF032017);
  static const Color tabIconInactive = Color(0xFF40504A);
  static const Color tabIndicatorGreen = Color(0xFF27C58B);

  // Surface colors (from Figma design system)
  static const Color surfaceBackground = Color(0xFF00150D);
  static const Color onSurface = Color(0xF2FFFFFF); // rgba(255,255,255,0.95)
  static const Color onSurfaceMuted = Color(
    0x80FFFFFF,
  ); // rgba(255,255,255,0.5)
  static const Color outlineVariant = Color(0xFF254136);
  static const Color borderWhite25 = Color(
    0x40FFFFFF,
  ); // rgba(255,255,255,0.25)

  // Tab text style - Bricolage bold (800), 18px, 24px line height
  static TextStyle tabTextStyle({Color color = whiteText}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 24 / 18,
        color: color,
      );

  // Background colors
  static const Color backgroundColor = Color(0xFF000000);
  static const Color cardBackground = Color(0xFF1A1A1A);
  static const Color darkOverlay = Color(0x88000000);

  // Text colors (dark theme optimized)
  static const Color primaryText = Color(
    0xFFFFFFFF,
  ); // White for dark backgrounds
  static const Color secondaryText = Color(
    0xFFBBBBBB,
  ); // Light gray for secondary text
  static const Color lightText = Color(
    0xFF888888,
  ); // Medium gray for tertiary text
  static const Color whiteText = Colors.white;

  // Accent colors
  static const Color likeRed = Color(0xFFE53E3E);
  static const Color commentBlue = Color(0xFF3182CE);

  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: _createMaterialColor(vineGreen),
    primaryColor: vineGreen,
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: navGreen,
      foregroundColor: whiteText,
      elevation: 1,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: whiteText,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'System',
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: vineGreen,
      selectedItemColor: whiteText,
      unselectedItemColor: Color(0xAAFFFFFF),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: primaryText,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: primaryText,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: primaryText,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(
        color: secondaryText,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: TextStyle(
        color: lightText,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: vineGreen,
        foregroundColor: whiteText,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    cardTheme: const CardThemeData(
      color: cardBackground,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );

  static MaterialColor _createMaterialColor(Color color) {
    final List strengths = <double>[.05];
    final swatch = <int, Color>{};
    final r = (color.r * 255.0).round() & 0xff;
    final g = (color.g * 255.0).round() & 0xff;
    final b = (color.b * 255.0).round() & 0xff;

    for (var i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (final strength in strengths) {
      final ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.toARGB32(), swatch);
  }
}
