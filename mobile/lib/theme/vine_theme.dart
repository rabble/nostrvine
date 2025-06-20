// ABOUTME: Vine-inspired theme with characteristic green colors and clean design
// ABOUTME: Matches the classic Vine app aesthetic with proper color scheme and typography

import 'package:flutter/material.dart';

class VineTheme {
  // Classic Vine green color palette
  static const Color vineGreen = Color(0xFF00BF63);
  static const Color vineGreenDark = Color(0xFF00A855);
  static const Color vineGreenLight = Color(0xFF4DD190);
  
  // Background colors
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;
  static const Color darkOverlay = Color(0x88000000);
  
  // Text colors
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF666666);
  static const Color lightText = Color(0xFF999999);
  static const Color whiteText = Colors.white;
  
  // Accent colors
  static const Color likeRed = Color(0xFFE53E3E);
  static const Color commentBlue = Color(0xFF3182CE);
  
  static ThemeData get theme {
    return ThemeData(
      primarySwatch: _createMaterialColor(vineGreen),
      primaryColor: vineGreen,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: vineGreen,
        foregroundColor: whiteText,
        elevation: 1,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
  }
  
  static MaterialColor _createMaterialColor(Color color) {
    List strengths = <double>[.05];
    final swatch = <int, Color>{};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }
}