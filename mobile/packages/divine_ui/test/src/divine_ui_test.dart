import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  group('VineTheme', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      // Prevent GoogleFonts from trying to fetch fonts at runtime
      GoogleFonts.config.allowRuntimeFetching = false;
    });
    group('colors', () {
      test('has correct vineGreen color', () {
        expect(VineTheme.vineGreen.r, closeTo(0, 0.01));
        expect(VineTheme.vineGreen.g, closeTo(0.706, 0.01));
        expect(VineTheme.vineGreen.b, closeTo(0.533, 0.01));
      });

      test('has correct vineGreenDark color', () {
        expect(VineTheme.vineGreenDark, const Color(0xFF009A72));
      });

      test('has correct vineGreenLight color', () {
        expect(VineTheme.vineGreenLight, const Color(0xFF33C49F));
      });

      test('has correct backgroundColor', () {
        expect(VineTheme.backgroundColor, const Color(0xFF000000));
      });

      test('has correct cardBackground', () {
        expect(VineTheme.cardBackground, const Color(0xFF1A1A1A));
      });

      test('has correct surface colors', () {
        expect(VineTheme.surfaceBackground, const Color(0xFF00150D));
        expect(VineTheme.onSurface, const Color(0xF2FFFFFF));
        expect(VineTheme.onSurfaceMuted, const Color(0x80FFFFFF));
      });

      test('has correct navigation colors', () {
        expect(VineTheme.primary, const Color(0xFF27C58B));
        expect(VineTheme.navGreen, const Color(0xFF00150D));
        expect(VineTheme.iconButtonBackground, const Color(0xFF032017));
        expect(VineTheme.tabIconInactive, const Color(0xFF40504A));
        expect(VineTheme.tabIndicatorGreen, const Color(0xFF27C58B));
        expect(VineTheme.cameraButtonGreen, const Color(0xFF00B386));
      });

      test('has correct text colors', () {
        expect(VineTheme.primaryText, const Color(0xFFFFFFFF));
        expect(VineTheme.secondaryText, const Color(0xFFBBBBBB));
        expect(VineTheme.lightText, const Color(0xFF888888));
        expect(VineTheme.whiteText, Colors.white);
      });

      test('has correct accent colors', () {
        expect(VineTheme.likeRed, const Color(0xFFE53E3E));
        expect(VineTheme.commentBlue, const Color(0xFF3182CE));
      });

      test('has correct utility colors', () {
        expect(VineTheme.darkOverlay, const Color(0x88000000));
        expect(VineTheme.alphaLight25, const Color(0x40FFFFFF));
        expect(VineTheme.outlineVariant, const Color(0xFF254136));
        expect(VineTheme.borderWhite25, const Color(0x40FFFFFF));
        expect(VineTheme.outlinedDisabled, const Color(0xFF032017));
        expect(VineTheme.outlineDisabled, const Color(0xFF001A12));
        expect(VineTheme.containerLow, const Color(0xFF0E2B21));
        expect(VineTheme.surfaceContainer, const Color(0xFF032017));
        expect(VineTheme.surfaceContainerHigh, const Color(0xFF000A06));
      });
    });

    group('typography - display fonts', () {
      testWidgets('displayLargeFont returns correct style', (tester) async {
        final style = VineTheme.displayLargeFont();
        expect(style.fontSize, 57);
        expect(style.fontWeight, FontWeight.w700);
      });

      testWidgets('displayMediumFont returns correct style', (tester) async {
        final style = VineTheme.displayMediumFont();
        expect(style.fontSize, 45);
        expect(style.fontWeight, FontWeight.w700);
      });

      testWidgets('displaySmallFont returns correct style', (tester) async {
        final style = VineTheme.displaySmallFont();
        expect(style.fontSize, 36);
        expect(style.fontWeight, FontWeight.w700);
      });
    });

    group('typography - headline fonts', () {
      testWidgets('headlineLargeFont returns correct style', (tester) async {
        final style = VineTheme.headlineLargeFont();
        expect(style.fontSize, 32);
        expect(style.fontWeight, FontWeight.w700);
      });

      testWidgets('headlineMediumFont returns correct style', (tester) async {
        final style = VineTheme.headlineMediumFont();
        expect(style.fontSize, 28);
        expect(style.fontWeight, FontWeight.w700);
      });

      testWidgets('headlineSmallFont returns correct style', (tester) async {
        final style = VineTheme.headlineSmallFont();
        expect(style.fontSize, 24);
        expect(style.fontWeight, FontWeight.w700);
      });
    });

    group('typography - title fonts', () {
      testWidgets('titleLargeFont returns correct style', (tester) async {
        final style = VineTheme.titleLargeFont();
        expect(style.fontSize, 22);
        expect(style.fontWeight, FontWeight.w800);
      });

      testWidgets('titleMediumFont returns correct style', (tester) async {
        final style = VineTheme.titleMediumFont();
        expect(style.fontSize, 18);
        expect(style.fontWeight, FontWeight.w800);
      });

      testWidgets('titleSmallFont returns correct style', (tester) async {
        final style = VineTheme.titleSmallFont();
        expect(style.fontSize, 14);
        expect(style.fontWeight, FontWeight.w800);
      });

      testWidgets('titleTinyFont returns correct style', (tester) async {
        final style = VineTheme.titleTinyFont();
        expect(style.fontSize, 12);
        expect(style.fontWeight, FontWeight.w800);
        expect(style.letterSpacing, 0.1);
      });
    });

    group('typography - body fonts', () {
      testWidgets('bodyLargeFont returns correct style', (tester) async {
        final style = VineTheme.bodyLargeFont();
        expect(style.fontSize, 16);
        expect(style.fontWeight, FontWeight.w400);
      });

      testWidgets('bodyMediumFont returns correct style', (tester) async {
        final style = VineTheme.bodyMediumFont();
        expect(style.fontSize, 14);
        expect(style.fontWeight, FontWeight.w400);
      });

      testWidgets('bodySmallFont returns correct style', (tester) async {
        final style = VineTheme.bodySmallFont();
        expect(style.fontSize, 12);
        expect(style.fontWeight, FontWeight.w400);
      });
    });

    group('typography - label fonts', () {
      testWidgets('labelLargeFont returns correct style', (tester) async {
        final style = VineTheme.labelLargeFont();
        expect(style.fontSize, 14);
        expect(style.fontWeight, FontWeight.w600);
      });

      testWidgets('labelMediumFont returns correct style', (tester) async {
        final style = VineTheme.labelMediumFont();
        expect(style.fontSize, 12);
        expect(style.fontWeight, FontWeight.w600);
      });

      testWidgets('labelSmallFont returns correct style', (tester) async {
        final style = VineTheme.labelSmallFont();
        expect(style.fontSize, 11);
        expect(style.fontWeight, FontWeight.w600);
      });
    });

    group('titleFont', () {
      testWidgets('returns TextStyle with default values', (tester) async {
        final style = VineTheme.titleFont();

        expect(style.fontSize, 22);
        expect(style.fontWeight, FontWeight.w800);
        expect(style.color, VineTheme.whiteText);
        expect(style.height, 28 / 22);
      });

      testWidgets('returns TextStyle with custom fontSize', (tester) async {
        final style = VineTheme.titleFont(fontSize: 30);

        expect(style.fontSize, 30);
      });

      testWidgets('returns TextStyle with custom height', (tester) async {
        final style = VineTheme.titleFont(height: 1.5);

        expect(style.height, 1.5);
      });

      testWidgets('returns TextStyle with custom color', (tester) async {
        final style = VineTheme.titleFont(color: Colors.red);

        expect(style.color, Colors.red);
      });

      testWidgets('returns TextStyle with letterSpacing', (tester) async {
        final style = VineTheme.titleFont(letterSpacing: 0.5);

        expect(style.letterSpacing, 0.5);
      });
    });

    group('bodyFont', () {
      testWidgets('returns TextStyle with default values', (tester) async {
        final style = VineTheme.bodyFont();

        expect(style.fontSize, 16);
        expect(style.fontWeight, FontWeight.w400);
        expect(style.color, VineTheme.primaryText);
      });

      testWidgets('returns TextStyle with custom fontSize', (tester) async {
        final style = VineTheme.bodyFont(fontSize: 20);

        expect(style.fontSize, 20);
      });

      testWidgets('returns TextStyle with custom fontWeight', (tester) async {
        final style = VineTheme.bodyFont(fontWeight: FontWeight.bold);

        expect(style.fontWeight, FontWeight.bold);
      });

      testWidgets('returns TextStyle with custom color', (tester) async {
        final style = VineTheme.bodyFont(color: Colors.blue);

        expect(style.color, Colors.blue);
      });

      testWidgets('returns TextStyle with custom height', (tester) async {
        final style = VineTheme.bodyFont(height: 1.8);

        expect(style.height, 1.8);
      });

      testWidgets('returns TextStyle with letterSpacing', (tester) async {
        final style = VineTheme.bodyFont(letterSpacing: 0.25);

        expect(style.letterSpacing, 0.25);
      });
    });

    group('tabTextStyle', () {
      testWidgets('returns TextStyle with default color', (tester) async {
        final style = VineTheme.tabTextStyle();

        expect(style.fontSize, 18);
        expect(style.fontWeight, FontWeight.w800);
        expect(style.height, 24 / 18);
        expect(style.color, VineTheme.whiteText);
      });

      testWidgets('returns TextStyle with custom color', (tester) async {
        final style = VineTheme.tabTextStyle(color: Colors.green);

        expect(style.color, Colors.green);
      });
    });

    group('theme', () {
      test('returns ThemeData with dark brightness', () {
        final theme = VineTheme.theme;

        expect(theme.brightness, Brightness.dark);
      });

      test('returns ThemeData with correct primaryColor', () {
        final theme = VineTheme.theme;

        expect(theme.primaryColor, VineTheme.vineGreen);
      });

      test('returns ThemeData with correct scaffoldBackgroundColor', () {
        final theme = VineTheme.theme;

        expect(theme.scaffoldBackgroundColor, VineTheme.backgroundColor);
      });

      test('returns ThemeData with correct appBarTheme', () {
        final theme = VineTheme.theme;

        expect(theme.appBarTheme.backgroundColor, VineTheme.navGreen);
        expect(theme.appBarTheme.foregroundColor, VineTheme.whiteText);
        expect(theme.appBarTheme.elevation, 1);
        expect(theme.appBarTheme.centerTitle, true);
      });

      test('returns ThemeData with correct bottomNavigationBarTheme', () {
        final theme = VineTheme.theme;

        expect(
          theme.bottomNavigationBarTheme.backgroundColor,
          VineTheme.vineGreen,
        );
        expect(
          theme.bottomNavigationBarTheme.selectedItemColor,
          VineTheme.whiteText,
        );
        expect(
          theme.bottomNavigationBarTheme.type,
          BottomNavigationBarType.fixed,
        );
      });

      test('returns ThemeData with correct textTheme', () {
        final theme = VineTheme.theme;

        expect(theme.textTheme.displayLarge?.color, VineTheme.primaryText);
        expect(theme.textTheme.displayLarge?.fontSize, 24);
        expect(theme.textTheme.titleLarge?.color, VineTheme.primaryText);
        expect(theme.textTheme.bodyLarge?.color, VineTheme.primaryText);
        expect(theme.textTheme.bodyMedium?.color, VineTheme.secondaryText);
        expect(theme.textTheme.bodySmall?.color, VineTheme.lightText);
      });

      test('returns ThemeData with correct cardTheme', () {
        final theme = VineTheme.theme;

        expect(theme.cardTheme.color, VineTheme.cardBackground);
        expect(theme.cardTheme.elevation, 2);
      });

      test('returns ThemeData with correct elevatedButtonTheme', () {
        final theme = VineTheme.theme;
        final buttonStyle = theme.elevatedButtonTheme.style;

        expect(buttonStyle, isNotNull);
      });
    });
  });
}
