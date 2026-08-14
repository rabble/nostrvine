// ABOUTME: Vine-inspired theme with green colors and clean design
// ABOUTME: Matches the classic Vine app aesthetic with proper styling

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic palette used by widgets that support both appearance modes.
@immutable
class VineThemeColors extends ThemeExtension<VineThemeColors> {
  /// Creates a semantic palette.
  const VineThemeColors({
    required this.background,
    required this.card,
    required this.mediaCard,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.containerLow,
    required this.primaryContainer,
    required this.nav,
    required this.onNav,
    required this.onNavMuted,
    required this.iconButton,
    required this.primaryText,
    required this.secondaryText,
    required this.mutedText,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onSurfaceMuted,
    required this.outline,
    required this.outlineMuted,
    required this.outlineDisabled,
    required this.disabled,
    required this.skeleton,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.accentPositive,
    required this.accentWarning,
    required this.inverseSurface,
    required this.inverseOnSurface,
    required this.mediaChrome,
    required this.mediaChromeForeground,
  });

  /// How often [VineThemeColorsContext.vineColors] resolved the dark fallback
  /// because the ambient [Theme] carried no [VineThemeColors] extension.
  ///
  /// Counted in debug builds only — the increment sits inside an `assert`.
  /// A bare `assert(colors != null)` is not an option: hundreds of widget
  /// tests pump a plain `MaterialApp`, which is precisely the case the
  /// fallback exists to serve. Counting instead lets a test that *does* pump
  /// the Divine theme prove the fallback never fired, which is what catches a
  /// nested `Theme`, a dialog builder with its own `ThemeData`, or an
  /// `Overlay` route silently dropping the extension on a light page.
  ///
  /// Tests that read this must reset it to `0` in `setUp` and `tearDown`.
  static int debugFallbackCount = 0;

  /// App background.
  final Color background;

  /// Card background.
  final Color card;

  /// Neutral surface that stays neutral in both modes, for chrome that must
  /// not pick up the palette's green cast — the shared-video chat bubble's
  /// frame (its thumbnail has to read as a media card rather than a coloured
  /// pill) and the classic recorder's unfilled progress track.
  ///
  /// Its dark value is [VineTheme.neutral10], which both of those had before
  /// the light-mode migration, so dark mode is unchanged. The light value is
  /// kept clear of every surface it is drawn on: [card] is white on the light
  /// palette and would vanish against the conversation, and
  /// [surfaceContainerHigh] is the recorder's own background.
  final Color mediaCard;

  /// Primary surface.
  final Color surface;

  /// Low-emphasis surface container.
  final Color surfaceContainer;

  /// High-emphasis surface container.
  final Color surfaceContainerHigh;

  /// Low-emphasis container background for inset rows and chips.
  final Color containerLow;

  /// Primary-tinted container, for chips and pills that read as "active"
  /// (a selected reaction, an applied filter). Pair with [onSurface] content.
  final Color primaryContainer;

  /// Navigation background, shared by the bottom nav and app bars.
  final Color nav;

  /// Content color on [nav] for titles, back arrows and selected tabs.
  final Color onNav;

  /// Content color on [nav] for unselected tabs and disabled nav actions.
  final Color onNavMuted;

  /// Icon button background.
  final Color iconButton;

  /// Primary text.
  final Color primaryText;

  /// Secondary text.
  final Color secondaryText;

  /// Muted text.
  final Color mutedText;

  /// Primary content on surfaces.
  final Color onSurface;

  /// Variant content on surfaces.
  final Color onSurfaceVariant;

  /// Muted content on surfaces, for hints and placeholder text.
  final Color onSurfaceMuted;

  /// Border and divider color.
  final Color outline;

  /// Low-contrast border color for containers and chips.
  final Color outlineMuted;

  /// Lowest-contrast border color, used for separators inside containers.
  final Color outlineDisabled;

  /// Disabled content color.
  final Color disabled;

  /// Placeholder color for skeleton shapes and shimmer bases.
  final Color skeleton;

  /// Background for error banners and destructive containers.
  final Color errorContainer;

  /// Content color on [errorContainer].
  final Color onErrorContainer;

  /// Healthy-status accent, drawn directly on [background] — a connected
  /// integration, a completed step.
  ///
  /// Its dark value is [VineTheme.vineGreen], so dark mode is unchanged. The
  /// brand green is 2.08:1 on the light canvas, below the 3:1 non-text floor,
  /// so the light value is the seeded tone the light `colorScheme.primary`
  /// already resolves to. Reusing it keeps one green in light mode rather
  /// than introducing a second, near-identical one.
  final Color accentPositive;

  /// Attention-status accent, drawn directly on [background] — an expired
  /// authorization, a step that needs the user to come back to it.
  ///
  /// Its dark value is [VineTheme.accentOrange], so dark mode is unchanged.
  /// This one labels body copy as well as icons, so the light value clears
  /// 4.5:1 rather than 3:1 — and is pitched at [accentPositive]'s ratio on
  /// [background] so the two accents carry the same weight side by side.
  final Color accentWarning;

  /// Surface that contrasts with [background], used by tertiary actions.
  final Color inverseSurface;

  /// Content color on [inverseSurface].
  final Color inverseOnSurface;

  /// Media controls background.
  final Color mediaChrome;

  /// Media controls foreground.
  final Color mediaChromeForeground;

  /// Whether this palette describes a light appearance.
  ///
  /// Derived from [background] rather than stored, so it stays correct for
  /// palettes produced by [lerp] during a theme cross-fade.
  bool get isLight => background.computeLuminance() > 0.5;

  @override
  VineThemeColors copyWith({
    Color? background,
    Color? card,
    Color? mediaCard,
    Color? surface,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? containerLow,
    Color? primaryContainer,
    Color? nav,
    Color? onNav,
    Color? onNavMuted,
    Color? iconButton,
    Color? primaryText,
    Color? secondaryText,
    Color? mutedText,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? onSurfaceMuted,
    Color? outline,
    Color? outlineMuted,
    Color? outlineDisabled,
    Color? disabled,
    Color? skeleton,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? accentPositive,
    Color? accentWarning,
    Color? inverseSurface,
    Color? inverseOnSurface,
    Color? mediaChrome,
    Color? mediaChromeForeground,
  }) => VineThemeColors(
    background: background ?? this.background,
    card: card ?? this.card,
    mediaCard: mediaCard ?? this.mediaCard,
    surface: surface ?? this.surface,
    surfaceContainer: surfaceContainer ?? this.surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
    containerLow: containerLow ?? this.containerLow,
    primaryContainer: primaryContainer ?? this.primaryContainer,
    nav: nav ?? this.nav,
    onNav: onNav ?? this.onNav,
    onNavMuted: onNavMuted ?? this.onNavMuted,
    iconButton: iconButton ?? this.iconButton,
    primaryText: primaryText ?? this.primaryText,
    secondaryText: secondaryText ?? this.secondaryText,
    mutedText: mutedText ?? this.mutedText,
    onSurface: onSurface ?? this.onSurface,
    onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
    onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
    outline: outline ?? this.outline,
    outlineMuted: outlineMuted ?? this.outlineMuted,
    outlineDisabled: outlineDisabled ?? this.outlineDisabled,
    disabled: disabled ?? this.disabled,
    skeleton: skeleton ?? this.skeleton,
    errorContainer: errorContainer ?? this.errorContainer,
    onErrorContainer: onErrorContainer ?? this.onErrorContainer,
    accentPositive: accentPositive ?? this.accentPositive,
    accentWarning: accentWarning ?? this.accentWarning,
    inverseSurface: inverseSurface ?? this.inverseSurface,
    inverseOnSurface: inverseOnSurface ?? this.inverseOnSurface,
    mediaChrome: mediaChrome ?? this.mediaChrome,
    mediaChromeForeground: mediaChromeForeground ?? this.mediaChromeForeground,
  );

  @override
  VineThemeColors lerp(covariant VineThemeColors? other, double t) {
    if (other == null) return this;
    return copyWith(
      background: Color.lerp(background, other.background, t),
      card: Color.lerp(card, other.card, t),
      mediaCard: Color.lerp(mediaCard, other.mediaCard, t),
      surface: Color.lerp(surface, other.surface, t),
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t),
      surfaceContainerHigh: Color.lerp(
        surfaceContainerHigh,
        other.surfaceContainerHigh,
        t,
      ),
      containerLow: Color.lerp(containerLow, other.containerLow, t),
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t),
      nav: Color.lerp(nav, other.nav, t),
      onNav: Color.lerp(onNav, other.onNav, t),
      onNavMuted: Color.lerp(onNavMuted, other.onNavMuted, t),
      iconButton: Color.lerp(iconButton, other.iconButton, t),
      primaryText: Color.lerp(primaryText, other.primaryText, t),
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t),
      mutedText: Color.lerp(mutedText, other.mutedText, t),
      onSurface: Color.lerp(onSurface, other.onSurface, t),
      onSurfaceVariant: Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t),
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t),
      outline: Color.lerp(outline, other.outline, t),
      outlineMuted: Color.lerp(outlineMuted, other.outlineMuted, t),
      outlineDisabled: Color.lerp(outlineDisabled, other.outlineDisabled, t),
      disabled: Color.lerp(disabled, other.disabled, t),
      skeleton: Color.lerp(skeleton, other.skeleton, t),
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t),
      onErrorContainer: Color.lerp(onErrorContainer, other.onErrorContainer, t),
      accentPositive: Color.lerp(accentPositive, other.accentPositive, t),
      accentWarning: Color.lerp(accentWarning, other.accentWarning, t),
      inverseSurface: Color.lerp(inverseSurface, other.inverseSurface, t),
      inverseOnSurface: Color.lerp(inverseOnSurface, other.inverseOnSurface, t),
      mediaChrome: Color.lerp(mediaChrome, other.mediaChrome, t),
      mediaChromeForeground: Color.lerp(
        mediaChromeForeground,
        other.mediaChromeForeground,
        t,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VineThemeColors &&
          background == other.background &&
          card == other.card &&
          mediaCard == other.mediaCard &&
          surface == other.surface &&
          surfaceContainer == other.surfaceContainer &&
          surfaceContainerHigh == other.surfaceContainerHigh &&
          containerLow == other.containerLow &&
          primaryContainer == other.primaryContainer &&
          nav == other.nav &&
          onNav == other.onNav &&
          onNavMuted == other.onNavMuted &&
          iconButton == other.iconButton &&
          primaryText == other.primaryText &&
          secondaryText == other.secondaryText &&
          mutedText == other.mutedText &&
          onSurface == other.onSurface &&
          onSurfaceVariant == other.onSurfaceVariant &&
          onSurfaceMuted == other.onSurfaceMuted &&
          outline == other.outline &&
          outlineMuted == other.outlineMuted &&
          outlineDisabled == other.outlineDisabled &&
          disabled == other.disabled &&
          skeleton == other.skeleton &&
          errorContainer == other.errorContainer &&
          onErrorContainer == other.onErrorContainer &&
          accentPositive == other.accentPositive &&
          accentWarning == other.accentWarning &&
          inverseSurface == other.inverseSurface &&
          inverseOnSurface == other.inverseOnSurface &&
          mediaChrome == other.mediaChrome &&
          mediaChromeForeground == other.mediaChromeForeground;

  @override
  int get hashCode => Object.hashAll([
    background,
    card,
    mediaCard,
    surface,
    surfaceContainer,
    surfaceContainerHigh,
    containerLow,
    primaryContainer,
    nav,
    onNav,
    onNavMuted,
    iconButton,
    primaryText,
    secondaryText,
    mutedText,
    onSurface,
    onSurfaceVariant,
    onSurfaceMuted,
    outline,
    outlineMuted,
    outlineDisabled,
    disabled,
    skeleton,
    errorContainer,
    onErrorContainer,
    accentPositive,
    accentWarning,
    inverseSurface,
    inverseOnSurface,
    mediaChrome,
    mediaChromeForeground,
  ]);
}

/// Convenient access to the semantic palette of the active theme.
extension VineThemeColorsContext on BuildContext {
  /// Semantic colors for the resolved appearance mode.
  ///
  /// Falls back to [VineTheme.darkColors] so widgets pumped without the
  /// Divine theme (older widget tests, isolated previews) keep the
  /// pre-light-mode appearance instead of Material defaults.
  ///
  /// The fallback is silent by design, so a light-mode page whose ambient
  /// [Theme] lost the extension renders dark tokens with nothing to notice
  /// it. Debug builds count those resolutions in
  /// [VineThemeColors.debugFallbackCount] so a test can assert the fallback
  /// never fires on a themed tree.
  VineThemeColors get vineColors {
    final colors = Theme.of(this).extension<VineThemeColors>();
    if (colors != null) return colors;
    assert(() {
      VineThemeColors.debugFallbackCount++;
      return true;
    }(), 'counter-only assert; never fails');
    return VineTheme.darkColors;
  }
}

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
  static TextStyle displayLargeFont({Color? color}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        height: 64 / 57,
        letterSpacing: 0,
        color: color,
      );

  /// Display medium: Bricolage Grotesque 700 45/52/0
  static TextStyle displayMediumFont({Color? color}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        height: 52 / 45,
        letterSpacing: 0,
        color: color,
      );

  /// Display small: Bricolage Grotesque 700 36/44/0
  static TextStyle displaySmallFont({Color? color}) =>
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
  static TextStyle headlineLargeFont({Color? color}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        letterSpacing: 0,
        color: color,
      );

  /// Headline medium: Bricolage Grotesque 700 28/36/0
  static TextStyle headlineMediumFont({Color? color}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 36 / 28,
        letterSpacing: 0,
        color: color,
      );

  /// Headline small: Bricolage Grotesque 700 24/32/0
  static TextStyle headlineSmallFont({Color? color}) =>
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
  static TextStyle titleLargeFont({Color? color}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 28 / 22,
        letterSpacing: 0,
        color: color,
      );

  /// Stat number: Bricolage Grotesque 800 20/28/0 — matches the Figma
  /// profile stat-column number style (Followers / Following / Likes /
  /// Loops). Sits between `titleLargeFont` (22) and `titleMediumFont` (16).
  static TextStyle statNumberFont({Color? color}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 28 / 20,
        letterSpacing: 0,
        color: color,
      );

  /// Title medium: Bricolage Grotesque 800 16/24/0.15
  static TextStyle titleMediumFont({Color? color}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        height: 24 / 16,
        letterSpacing: 0.15,
        color: color,
      );

  /// Title small: Bricolage Grotesque 800 14/20/0.1
  static TextStyle titleSmallFont({Color? color}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        height: 20 / 14,
        letterSpacing: 0.1,
        color: color,
      );

  /// Title tiny: Bricolage Grotesque 800 12/20/0.1
  static TextStyle titleTinyFont({Color? color}) =>
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
  static TextStyle bodyLargeFont({Color? color}) => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    letterSpacing: 0.15,
    color: color,
  );

  /// Body medium: Inter 400 14/20/0.25
  static TextStyle bodyMediumFont({Color? color}) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    letterSpacing: 0.25,
    color: color,
  );

  /// Body small: Inter 400 12/16/0.4
  static TextStyle bodySmallFont({
    Color? color,
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
  static TextStyle labelLargeFont({Color? color}) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    letterSpacing: 0.1,
    color: color,
  );

  /// Label medium: Inter 600 12/16/0.5
  static TextStyle labelMediumFont({
    Color? color,
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
  static TextStyle labelSmallFont({Color? color}) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 16 / 11,
    letterSpacing: 0.5,
    color: color,
  );

  /// Caption pill: Chivo Mono 300 16/24/0.5 — used by the inline subtitle
  /// pill above the author row in the home / fullscreen video overlays.
  /// Intentionally mono per the Figma captions block, distinct from the
  /// app's Inter / Bricolage Grotesque body families. Callers add the
  /// `shadow25` drop shadow via `.copyWith(shadows: ...)` when rendering
  /// over video content.
  static TextStyle captionPillFont({Color? color}) => GoogleFonts.chivoMono(
    fontSize: 16,
    fontWeight: FontWeight.w300,
    height: 24 / 16,
    letterSpacing: 0.5,
    color: color,
  );

  /// Inline code: Chivo Mono 300 13/20/0.25 — sized to sit flush with
  /// `bodyMediumFont` in chat bubbles so a monospace run inside a DM
  /// message doesn't shift the baseline. Uses the same Chivo Mono
  /// weight already bundled for `captionPillFont` so tests don't need
  /// runtime font fetching. Callers pair this with a translucent
  /// background paint so the code chip reads on both sent-bubble
  /// (primaryAccessible) and received-bubble (surfaceContainer)
  /// backgrounds.
  static TextStyle codeFont({Color? color}) => GoogleFonts.chivoMono(
    fontSize: 13,
    fontWeight: FontWeight.w300,
    height: 20 / 13,
    letterSpacing: 0.25,
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

  /// Status bar style for light backgrounds: dark icons on both platforms.
  static const SystemUiOverlayStyle lightStatusBarStyle = SystemUiOverlayStyle(
    statusBarColor: transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
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

  /// Border radius for shell-level bottom corners (outer edge of the
  /// rounded region painted over the nav).
  static const double shellCornerRadius = 30;

  /// Border radius for the top of a tab container nested inside a shell
  /// — 2 px larger than [shellCornerRadius] so the inner surface
  /// visibly sits within the nav-rounded outer shell.
  static const double shellInnerCornerRadius = 32;

  /// Border radius for bottom sheets.
  static const double bottomSheetBorderRadius = 32;

  /// `minChildSize` for a draggable sheet that must not be dismissed by
  /// accident.
  ///
  /// [DraggableScrollableSheet] pops its modal on reaching `minChildSize`, so
  /// a floor set close to the size the sheet opens at turns an overscroll
  /// flick at the top of the content into a dismissal — and a sheet that
  /// returns its result on pop loses the pending selection with it. Half the
  /// viewport keeps drag-to-dismiss reachable but out of reach of a twitch.
  static const double bottomSheetDismissFloor = 0.5;

  /// Primary content color on surfaces (95% white).
  static const Color onSurface = Color(0xF2FFFFFF);

  /// Muted content color on surfaces (50% white).
  static const Color onSurfaceMuted = Color(0x80FFFFFF);

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

  /// Duration of a single skeleton shimmer sweep.
  static const Duration skeletonDuration = Duration(milliseconds: 1500);

  /// Default duration for UI animations and transitions.
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);

  /// Tab text style using Bricolage Grotesque bold.
  static TextStyle tabTextStyle({Color? color}) =>
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

  /// Figma `effects/shadow-25` drop-shadow color (25% black). Use as the
  /// color for [Shadow] / [BoxShadow] drops on elements layered above
  /// video content (caption pills, floating popups, etc.).
  static const Color shadow25 = Color(0x40000000);

  /// Figma `effects/shadow-10` drop-shadow pair, for use in
  /// [TextStyle.shadows] on text overlaid on video content or other
  /// bright surfaces (caption block, action-button labels, feed-mode
  /// label, etc.). Paired with [buttonBoxShadows] for the BoxShadow
  /// equivalent on Container/DecoratedBox surfaces.
  static const List<Shadow> buttonShadows = [
    Shadow(color: innerShadow, offset: Offset(0.4, 0.4), blurRadius: 0.6),
    Shadow(color: innerShadow, offset: Offset(1, 1), blurRadius: 1),
  ];

  /// Figma `effects/shadow-10` drop-shadow pair, for use in
  /// [BoxDecoration.boxShadow]. Same offsets/blur as [buttonShadows]
  /// but as [BoxShadow] instead of [Shadow].
  static const List<BoxShadow> buttonBoxShadows = [
    BoxShadow(color: innerShadow, offset: Offset(0.4, 0.4), blurRadius: 0.6),
    BoxShadow(color: innerShadow, offset: Offset(1, 1), blurRadius: 1),
  ];

  /// Raised-button drop shadow for the appearance mode described by [colors].
  ///
  /// Null on the light palette. [buttonBoxShadows] is an *inward* emboss that
  /// lifts a button off a near-black surface; a light surface needs an outward
  /// drop shadow instead, and the buttons cannot draw one — they paint their
  /// decoration through [Ink], and Material hard-clips ink features to its own
  /// bounds (`_RenderInkFeatures.paint`), so the outward half is guillotined
  /// at the button's edge and reads as a cut line. Every light-mode fill
  /// (saturated green, saturated red, dark green, or grey with an explicit
  /// outline) already separates itself from the page, so the button goes flat
  /// there rather than shipping a clipped shadow. Giving light mode a real
  /// drop shadow means moving the decoration outside the [Material] first.
  static List<BoxShadow>? buttonBoxShadowsFor(VineThemeColors colors) =>
      colors.isLight ? null : buttonBoxShadows;

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

  /// Semantic colors that change with the selected appearance mode.
  ///
  /// Existing static color constants remain available for compatibility while
  /// screens migrate incrementally to [Theme.of].
  static const VineThemeColors darkColors = VineThemeColors(
    background: backgroundColor,
    card: cardBackground,
    mediaCard: neutral10,
    surface: surfaceBackground,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    containerLow: containerLow,
    primaryContainer: primaryDarkGreen,
    nav: navGreen,
    onNav: whiteText,
    onNavMuted: onSurfaceDisabled,
    iconButton: iconButtonBackground,
    primaryText: primaryText,
    secondaryText: secondaryText,
    mutedText: lightText,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    onSurfaceMuted: onSurfaceMuted,
    outline: outlineVariant,
    outlineMuted: outlineMuted,
    outlineDisabled: outlineDisabled,
    disabled: onSurfaceDisabled,
    skeleton: skeletonBase,
    errorContainer: errorContainer,
    onErrorContainer: likeRed,
    accentPositive: vineGreen,
    accentWarning: accentOrange,
    inverseSurface: inverseSurface,
    inverseOnSurface: inverseOnSurface,
    mediaChrome: scrim80,
    mediaChromeForeground: whiteText,
  );

  /// Warm off-white content surfaces with dark-green anchors, inspired by
  /// Vine's original clean playback UI.
  static const VineThemeColors lightColors = VineThemeColors(
    background: Color(0xFFF9F7F6),
    card: Color(0xFFFFFFFF),
    mediaCard: Color(0xFFDCD7D2),
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF0EEEC),
    surfaceContainerHigh: Color(0xFFE7E4E1),
    containerLow: Color(0xFFEDF3EF),
    primaryContainer: Color(0xFFE7F5EE),
    nav: Color(0xFFFFFFFF),
    onNav: Color(0xFF07241B),
    onNavMuted: Color(0x6607241B),
    iconButton: Color(0xFFE7F5EE),
    primaryText: Color(0xFF07241B),
    secondaryText: Color(0xFF385149),
    mutedText: Color(0xFF5F7069),
    onSurface: Color(0xFF17382D),
    onSurfaceVariant: Color(0xFF526B61),
    onSurfaceMuted: Color(0x8C17382D),
    outline: Color(0xFFB7C9C1),
    outlineMuted: Color(0xFFDCE7E2),
    outlineDisabled: Color(0xFFEBF1EE),
    disabled: Color(0x6638584C),
    skeleton: Color(0xFFE7E4E1),
    errorContainer: Color(0xFFFFE7E2),
    onErrorContainer: Color(0xFF8C1D18),
    accentPositive: Color(0xFF226A4C),
    accentWarning: Color(0xFFAE3100),
    inverseSurface: Color(0xFF07241B),
    inverseOnSurface: Color(0xFFFFFFFF),
    mediaChrome: Color(0xF2F9F7F6),
    mediaChromeForeground: Color(0xFF07241B),
  );

  /// Scrim at 80% opacity (black 80%).
  static const Color scrim80 = Color(0xCC000000);

  /// The complete theme data for the app.
  ///
  /// Kept as a `static final` (not a getter) so its object identity is
  /// stable across rebuilds. `MaterialApp` wraps the theme in an internal
  /// `AnimatedTheme`; a fresh `ThemeData` on every access fails its
  /// `identical`/`==` check — partly because sub-themes here use
  /// `WidgetStateProperty.resolveWith(...)` closures that never compare
  /// equal — and triggers a full `ThemeData.lerp` (TextTheme/Typography
  /// lerp + `Theme` InheritedWidget rebuild cascade) on every rebuild
  /// above `MaterialApp`.
  static final ThemeData theme = _buildTheme(Brightness.dark, darkColors);

  /// Theme data for the experimental light appearance.
  static final ThemeData lightTheme = _buildTheme(
    Brightness.light,
    lightColors,
  );

  static ThemeData _buildTheme(Brightness brightness, VineThemeColors colors) {
    final isLight = brightness == Brightness.light;
    // Material 3 ignores `primarySwatch`, so without an explicit scheme this
    // falls back to the M3 baseline — a purple primary that surfaces on every
    // widget defaulting to `colorScheme.primary` (RefreshIndicator, bare
    // progress indicators, Chip, Slider).
    final seeded = ColorScheme.fromSeed(
      seedColor: vineGreen,
      brightness: brightness,
    );
    // Dark mode pins the exact brand green. Light mode keeps the seeded tone,
    // which is the same hue darkened to clear contrast on a white surface —
    // vineGreen itself only reaches ~2.2:1 there.
    final scheme = isLight
        ? seeded
        : seeded.copyWith(primary: vineGreen, onPrimary: onPrimary);
    return ThemeData(
      brightness: brightness,
      primarySwatch: _createMaterialColor(vineGreen),
      primaryColor: vineGreen,
      colorScheme: scheme,
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
      scaffoldBackgroundColor: colors.background,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.nav,
        foregroundColor: colors.onNav,
        elevation: 1,
        centerTitle: true,
        systemOverlayStyle: isLight ? lightStatusBarStyle : statusBarStyle,
        titleTextStyle: TextStyle(
          color: colors.onNav,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'System',
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: colors.primaryText,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: colors.primaryText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: colors.primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: colors.secondaryText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: colors.mutedText,
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
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.mediaChromeForeground;
          }
          return colors.disabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isLight ? vineGreen : onPrimary;
          }
          return colors.surfaceContainer;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return colors.outline;
        }),
      ),
    );
  }

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
