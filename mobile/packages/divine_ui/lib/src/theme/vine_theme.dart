// ABOUTME: Vine-inspired theme with green colors and clean design
// ABOUTME: Matches the classic Vine app aesthetic with proper styling

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Vine-inspired theme with characteristic green colors and clean design.
///
/// This is a dark-mode only design system matching the classic Vine app
/// aesthetic with proper color scheme and typography.
class VineTheme {
  // ==========================================================================
  // Typography - Google Fonts
  // ==========================================================================

  /// Font family name for Bricolage Grotesque.
  ///
  /// Use this constant instead of hardcoding `'BricolageGrotesque'` in
  /// `TextStyle(fontFamily: ...)` declarations. For full themed text styles,
  /// prefer the static methods like [displayLargeFont] instead.
  static const fontFamilyBricolage = 'BricolageGrotesque';

  // --------------------------------------------------------------------------
  // Display styles (Bricolage Grotesque, weight 700)
  // --------------------------------------------------------------------------

  /// Display large: Bricolage Grotesque 700 57/64/0
  static TextStyle displayLargeFont({Color color = whiteText}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        height: 64 / 57,
        letterSpacing: 0,
        color: color,
      );

  /// Display medium: Bricolage Grotesque 700 45/52/0
  static TextStyle displayMediumFont({Color color = whiteText}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        height: 52 / 45,
        letterSpacing: 0,
        color: color,
      );

  /// Display small: Bricolage Grotesque 700 36/44/0
  static TextStyle displaySmallFont({Color color = whiteText}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 44 / 36,
        letterSpacing: 0,
        color: color,
      );

  // --------------------------------------------------------------------------
  // Headline styles (Bricolage Grotesque, weight 700)
  // --------------------------------------------------------------------------

  /// Headline large: Bricolage Grotesque 700 32/40/0
  static TextStyle headlineLargeFont({Color color = whiteText}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        letterSpacing: 0,
        color: color,
      );

  /// Headline medium: Bricolage Grotesque 700 28/36/0
  static TextStyle headlineMediumFont({Color color = whiteText}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 36 / 28,
        letterSpacing: 0,
        color: color,
      );

  /// Headline small: Bricolage Grotesque 700 24/32/0
  static TextStyle headlineSmallFont({Color color = whiteText}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 32 / 24,
        letterSpacing: 0,
        color: color,
      );

  // --------------------------------------------------------------------------
  // Title styles (Bricolage Grotesque, weight 800)
  // --------------------------------------------------------------------------

  /// Title large: Bricolage Grotesque 800 22/28/0
  static TextStyle titleLargeFont({Color color = whiteText}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 28 / 22,
        letterSpacing: 0,
        color: color,
      );

  /// Title medium: Bricolage Grotesque 800 16/24/0.15
  static TextStyle titleMediumFont({Color color = whiteText}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        height: 24 / 16,
        letterSpacing: 0.15,
        color: color,
      );

  /// Title small: Bricolage Grotesque 800 14/20/0.1
  static TextStyle titleSmallFont({Color color = whiteText}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        height: 20 / 14,
        letterSpacing: 0.1,
        color: color,
      );

  /// Title tiny: Bricolage Grotesque 800 12/20/0.1
  static TextStyle titleTinyFont({Color color = whiteText}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 20 / 12,
        letterSpacing: 0.1,
        color: color,
      );

  // --------------------------------------------------------------------------
  // Body styles (Inter, weight 400)
  // --------------------------------------------------------------------------

  /// Body large: Inter 400 16/24/0.15
  static TextStyle bodyLargeFont({Color color = whiteText}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        letterSpacing: 0.15,
        color: color,
      );

  /// Body medium: Inter 400 14/20/0.25
  static TextStyle bodyMediumFont({Color color = whiteText}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        letterSpacing: 0.25,
        color: color,
      );

  /// Body small: Inter 400 12/16/0.4
  static TextStyle bodySmallFont({
    Color color = whiteText,
    List<FontFeature>? fontFeatures,
  }) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    letterSpacing: 0.4,
    color: color,
    fontFeatures: fontFeatures,
  );

  // --------------------------------------------------------------------------
  // Label styles (Inter, weight 600)
  // --------------------------------------------------------------------------

  /// Label large: Inter 600 14/20/0.1
  static TextStyle labelLargeFont({Color color = whiteText}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        letterSpacing: 0.1,
        color: color,
      );

  /// Label medium: Inter 600 12/16/0.5
  static TextStyle labelMediumFont({
    Color color = whiteText,
    List<FontFeature>? fontFeatures,
  }) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 16 / 12,
    letterSpacing: 0.5,
    color: color,
    fontFeatures: fontFeatures,
  );

  /// Label small: Inter 600 11/16/0.5
  static TextStyle labelSmallFont({Color color = whiteText}) =>
      GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 16 / 11,
        letterSpacing: 0.5,
        color: color,
      );

  /// Status bar style for dark backgrounds: light icons on both platforms.
  ///
  /// [SystemUiOverlayStyle.light] uses `statusBarBrightness: Brightness.light`
  /// which causes **dark** icons on iOS. This constant sets the correct
  /// brightness per platform so icons are always visible on dark backgrounds.
  static const SystemUiOverlayStyle statusBarStyle = SystemUiOverlayStyle(
    statusBarColor: transparent,
    statusBarIconBrightness: Brightness.light, // Android
    statusBarBrightness: Brightness.dark, // iOS
  );

  // Classic Vine green color palette

  /// Primary brand green color.
  static const Color vineGreen = Color(0xFF27C58B);

  /// On-primary color (text/icons on primary background).
  static const Color onPrimary = Color(0xFF00150D);

  /// Figma `primary/on-primary` token for text/icons on primary buttons.
  static const Color onPrimaryButton = Color(0xFF003824);

  /// Darker variant of the brand green.
  static const Color vineGreenDark = Color(0xFF009A72);

  /// Dark green for primary accents on dark backgrounds.
  static const Color primaryDarkGreen = Color(0xFF07241B);

  /// Lighter variant of the brand green.
  static const Color vineGreenLight = Color(0xFFD0FBCB);

  // Navigation colors

  /// Primary color.
  static const Color primary = Color(0xFF27C58B);

  /// Primary accessible color for high-contrast use on dark backgrounds.
  static const Color primaryAccessible = Color(0xFF00A572);

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

  /// Border radius for bottom sheets.
  static const double bottomSheetBorderRadius = 32;

  /// Primary content color on surfaces (95% white).
  static const Color onSurface = Color(0xF2FFFFFF);

  /// Muted content color on surfaces (50% white).
  static const Color onSurfaceMuted = Color(0x80FFFFFF);

  /// Muted content color on surfaces (55% white).
  static const Color onSurfaceMuted55 = Color(0x8CFFFFFF);

  /// Variant content color on surfaces (75% white).
  static const Color onSurfaceVariant = Color(0xBFFFFFFF);

  /// Disabled content color on surfaces (25% white).
  static const Color onSurfaceDisabled = Color(0x40FFFFFF);

  /// Error container background color.
  static const Color errorContainer = Color(0xFF410001);

  /// Error color for icons and text.
  static const Color error = Color(0xFFF44336);

  /// On-error-container color for text/icons on error container backgrounds.
  static const Color onErrorContainer = Color(0xFFFFEDEA);

  /// Primary container background color.
  static const Color primaryContainer = Color(0xFFD0FBCB);

  /// Error overlay for pressed/error state backgrounds (15% error).
  static const Color errorOverlay = Color(0x26F44336);

  /// Light alpha overlay (25% white).
  static const Color alphaLight25 = Color(0x40FFFFFF);

  /// Outline variant for borders and dividers.
  static const Color outlineVariant = Color(0xFF254136);

  /// Border color (25% white).
  static const Color borderWhite25 = Color(0x40FFFFFF);

  /// Disabled outline color.
  static const Color outlinedDisabled = Color(0xFF032017);

  /// Disabled outline color for separators.
  static const Color outlineDisabled = Color(0xFF001A12);

  /// Low-emphasis container background.
  static const Color containerLow = Color(0xFF0E2B21);

  /// Surface container background (bg/surface-container).
  static const Color surfaceContainer = Color(0xFF032017);

  /// Surface container high background (bg/surface-container-high).
  static const Color surfaceContainerHigh = Color(0xFF000A06);

  /// Muted outline color (outline/outline-muted).
  static const Color outlineMuted = Color(0xFF0E2B21);

  /// Surface container at 55% opacity.
  static const Color surfaceContainer55 = Color(0x8C032017);

  /// Surface container at 90% opacity.
  static const Color surfaceContainer90 = Color(0xE5032017);

  /// Neutral 10 color for subtle borders.
  static const Color neutral10 = Color(0xFF1B1C1C);

  // Skeleton / shimmer loading
  // TODO(design): Confirm skeleton colors and duration with design team.

  /// Base color for skeleton shimmer effects.
  static const Color skeletonBase = iconButtonBackground;

  /// Highlight color for skeleton shimmer sweep (60% alpha of base).
  static const Color skeletonHighlight = Color(0x99032017);

  /// Surface color for skeleton placeholder shapes.
  static const Color skeletonSurface = outlinedDisabled;

  /// Duration of a single skeleton shimmer sweep.
  static const Duration skeletonDuration = Duration(milliseconds: 1500);

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

  /// Camera background color
  static const Color backgroundCamera = Color(0xFF000A06);

  /// Dark overlay color.
  static const Color darkOverlay = Color(0x88000000);

  /// Scrim at 15% opacity (black 15%).
  static const Color scrim15 = Color(0x26000000);

  /// Scrim at 30% opacity (black 30%).
  static const Color scrim30 = Color(0x4D000000);

  /// Scrim at 35% opacity (black 35%).
  static const Color scrim35 = Color(0x58000000);

  /// Scrim at 65% opacity (black 65%).
  static const Color scrim65 = Color(0xA6000000);

  /// Inverse surface color (white) for tertiary buttons.
  static const Color inverseSurface = Color(0xFFFFFFFF);

  /// Inverse on-surface color (dark green) for text on inverse surfaces.
  static const Color inverseOnSurface = Color(0xFF00452D);

  // Text colors (dark theme optimized)

  /// Primary text color (white for dark backgrounds).
  static const Color primaryText = Color(0xFFFFFFFF);

  /// Secondary text color (light gray).
  static const Color secondaryText = Color(0xFFBBBBBB);

  /// Tertiary/light text color (medium gray).
  static const Color lightText = Color(0xFF888888);

  /// Off-white surface color for light-on-dark text and backgrounds.
  static const Color offWhite = Color(0xFFF9F7F6);

  /// White text color alias.
  static const Color whiteText = Colors.white;

  // Accent colors

  /// Like/heart red color.
  static const Color likeRed = Color(0xFFE53E3E);

  /// Comment blue color.
  static const Color commentBlue = Color(0xFF3182CE);

  /// Accent orange/amber color.
  static const Color accentOrange = Color(0xFFFF7640);

  /// Accent orange/amber color.
  static const Color accentOrangeBackground = Color(0xFF471F10);

  /// Accent yellow color.
  static const Color accentYellow = Color(0xFFFFF140);

  /// Accent yellow background color.
  static const Color accentYellowBackground = Color(0xFF363313);

  // --------------------------------------------------------------------------
  // Semantic status colors
  // --------------------------------------------------------------------------

  /// Warning color for status indicators and alerts.
  static const Color warning = Color(0xFFFF9800);

  /// Success color for positive status indicators.
  static const Color success = Color(0xFF4CAF50);

  /// Informational color for badges and links.
  static const Color info = Color(0xFF2196F3);

  /// Content warning amber color.
  static const Color contentWarningAmber = Color(0xFFFFB84D);

  /// Dark background tint for content-warning banners.
  static const Color contentWarningBackground = Color(0xFF4A1C00);

  // --------------------------------------------------------------------------
  // Button shadows
  // --------------------------------------------------------------------------

  /// Inner shadow for elevated buttons (10% black).
  static const Color innerShadow = Color(0x1A000000);

  /// Pressed-state inner shadow for buttons (24% black).
  static const Color innerShadowPressed = Color(0x3D000000);

  // --------------------------------------------------------------------------
  // Additional scrims
  // --------------------------------------------------------------------------

  /// Scrim at 50% opacity (black 50%).
  static const Color scrim50 = Color(0x80000000);

  /// Scrim at 70% opacity (black 70%).
  static const Color scrim70 = Color(0xB3000000);

  /// Accent blue color.
  static const Color accentBlue = Color(0xFF34BBF1);

  /// Accent blue background color.
  static const Color accentBlueBackground = Color(0xFF1A3A5C);

  /// Accent lime color.
  static const Color accentLime = Color(0xFFD2FF40);

  /// Accent lime background color.
  static const Color accentLimeBackground = Color(0xFF272F0E);

  /// Accent pink color.
  static const Color accentPink = Color(0xFFFF7FAF);

  /// Accent pink background color.
  static const Color accentPinkBackground = Color(0xFF3E0C1F);

  /// Accent violet color.
  static const Color accentViolet = Color(0xFFA3A9FF);

  /// Accent violet background color.
  static const Color accentVioletBackground = Color(0xFF2D214D);

  /// Accent violet variant color.
  static const Color accentVioletVariant = Color(0xFFE1E3FF);

  /// Accent purple color.
  static const Color accentPurple = Color(0xFF8568FF);

  /// Fully transparent color sentinel.
  static const Color transparent = Color(0x00000000);

  /// Scrim at 80% opacity (black 80%).
  static const Color scrim80 = Color(0xCC000000);

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
      systemOverlayStyle: statusBarStyle,
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
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: primary,
      selectionColor: primary.withAlpha(80),
      selectionHandleColor: primary,
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
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return whiteText;
        return onSurfaceDisabled;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary;
        return surfaceContainer;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.transparent;
        return outlineVariant;
      }),
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
