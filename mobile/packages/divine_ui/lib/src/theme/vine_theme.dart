// ABOUTME: Vine-inspired theme with green colors and clean design
// ABOUTME: Matches the classic Vine app aesthetic with proper styling

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Vine-inspired theme with characteristic green colors and clean design.
///
/// This is a dark-mode only design system matching the classic Vine app
/// aesthetic with proper color scheme and typography.
class VineTheme {
  // Typography - Google Fonts
  // Bricolage Grotesque for titles (bold 800, 22px with 28px line height)

  /// Title font style using Bricolage Grotesque.
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

  /// Body font style using Inter.
  static TextStyle bodyFont({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color color = primaryText,
    double? height,
  }) => GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
  );

  // Classic Vine green color palette

  /// Primary brand green color.
  static const Color vineGreen = Color(0xFF00B488);

  /// Darker variant of the brand green.
  static const Color vineGreenDark = Color(0xFF009A72);

  /// Lighter variant of the brand green.
  static const Color vineGreenLight = Color(0xFF33C49F);

  // Navigation colors

  /// Navigation bar green background.
  static const Color navGreen = Color(0xFF00150D);

  /// Icon button background color.
  static const Color iconButtonBackground = Color(0xFF032017);

  /// Inactive tab icon color.
  static const Color tabIconInactive = Color(0xFF40504A);

  /// Tab indicator green color.
  static const Color tabIndicatorGreen = Color(0xFF27C58B);

  /// Camera button green color.
  static const Color cameraButtonGreen = Color(0xFF00B386);

  // Surface colors (from Figma design system)

  /// Background color for surfaces like bottom sheets.
  static const Color surfaceBackground = Color(0xFF00150D);

  /// Primary content color on surfaces (95% white).
  static const Color onSurface = Color(0xF2FFFFFF);

  /// Muted content color on surfaces (50% white).
  static const Color onSurfaceMuted = Color(0x80FFFFFF);

  /// Light alpha overlay (25% white).
  static const Color alphaLight25 = Color(0x40FFFFFF);

  /// Outline variant for borders and dividers.
  static const Color outlineVariant = Color(0xFF254136);

  /// Border color (25% white).
  static const Color borderWhite25 = Color(0x40FFFFFF);

  /// Disabled outline color.
  static const Color outlinedDisabled = Color(0xFF032017);

  /// Low-emphasis container background.
  static const Color containerLow = Color(0xFF0E2B21);

  /// Tab text style using Bricolage Grotesque bold.
  static TextStyle tabTextStyle({Color color = whiteText}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 24 / 18,
        color: color,
      );

  // Background colors

  /// Primary background color (black).
  static const Color backgroundColor = Color(0xFF000000);

  /// Card and elevated surface background.
  static const Color cardBackground = Color(0xFF1A1A1A);

  /// Dark overlay color.
  static const Color darkOverlay = Color(0x88000000);

  // Text colors (dark theme optimized)

  /// Primary text color (white for dark backgrounds).
  static const Color primaryText = Color(0xFFFFFFFF);

  /// Secondary text color (light gray).
  static const Color secondaryText = Color(0xFFBBBBBB);

  /// Tertiary/light text color (medium gray).
  static const Color lightText = Color(0xFF888888);

  /// White text color alias.
  static const Color whiteText = Colors.white;

  // Accent colors

  /// Like/heart red color.
  static const Color likeRed = Color(0xFFE53E3E);

  /// Comment blue color.
  static const Color commentBlue = Color(0xFF3182CE);

  /// The complete theme data for the app.
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
    final strengths = <double>[.05];
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
