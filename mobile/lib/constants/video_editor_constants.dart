import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// A text font with its style getter.
typedef TextFont = TextStyle Function({double? fontSize, Color? color});

/// Constants for the video editor feature.
class VideoEditorConstants {
  /// Key used to identify autosaved drafts in storage.
  static String autoSaveId = 'draft_autosave';

  /// Prefix key used to identify drafts being published in storage.
  static String publishPrefixId = 'draft_publish';

  /// Maximum number of tags allowed per video.
  static int tagLimit = 1 << 30; // ~1 billion

  /// Whether to enforce the tag limit in the UI.
  static bool enableTagLimit = false;

  /// Maximum recording duration for videos.
  static const maxDuration = Duration(seconds: 6, milliseconds: 300);

  /// Default time offset for extracting video thumbnails.
  static const defaultThumbnailExtractTime = Duration(milliseconds: 200);

  /// Primary accent color used in the video editor UI.
  static const primaryColor = Color(0xFFFFF140);

  /// Available colors for text overlays.
  static const colors = [
    Color(0xFFF9F7F6),
    Color(0xFF000000),
    Color(0xFF404040),
    Color(0xFF07241B),
    Color(0xFF27C58B),
    Color(0xFFD0FBCB),

    Color(0xFFCCEEFE),
    Color(0xFFDDD4FF),
    Color(0xFFE1E3FF),
    Color(0xFFFFD8C9),
    Color(0xFFFFDEEA),
    Color(0xFFF1FFC8),
    Color(0xFFFFFABB),

    Color(0xFF34BBF1),
    Color(0xFF8568FF),
    Color(0xFFA3A9FF),
    Color(0xFFFF7640),
    Color(0xFFFF7FAF),
    Color(0xFFD2FF40),
    Color(0xFFFFF140),

    Color(0xFF0A223C),
    Color(0xFF231557),
    Color(0xFF2D214D),
    Color(0xFF471F10),
    Color(0xFF3E0C1F),
    Color(0xFF272F0E),
    Color(0xFF363313),
  ];

  /// Available text fonts for text overlays.
  static const List<TextFont> textFonts = [
    GoogleFonts.inter,
    GoogleFonts.bricolageGrotesque,
    GoogleFonts.montserrat,
    GoogleFonts.anonymousPro,
    GoogleFonts.caveat,
    GoogleFonts.crimsonText,
    GoogleFonts.ibmPlexMono,
    GoogleFonts.pacifico,
    GoogleFonts.playfairDisplay,
    GoogleFonts.bebasNeue,
    GoogleFonts.poppins,
    GoogleFonts.lobster,
    GoogleFonts.oswald,
    GoogleFonts.dancingScript,
    GoogleFonts.permanentMarker,
    GoogleFonts.comfortaa,
  ];

  /// Width of drawing tool items in the draw editor toolbar.
  static double drawItemWidth = 48.0;

  /// Base font size in pixels for text overlays.
  static const double baseFontSize = 24.0;

  /// Minimum font scale multiplier for text overlays.
  static const double minFontScale = 0.5;

  /// Maximum font scale multiplier for text overlays.
  static const double maxFontScale = 4.0;

  /// Background color for the text editor overlay.
  static const Color textEditorBackground = Color(0x9B000000);

  static const uiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF000000),
  );

  /// Height of the bottom action bar in the video editor.
  static const double bottomBarHeight = 90;
}

/// Constants for the video editor clip gallery layout and animations.
class VideoEditorGalleryConstants {
  /// Viewport fraction for the PageView (80% of screen width).
  static double viewportFraction = 0.8;

  /// Minimum scale for non-centered clips.
  static double minScale = 0.85;

  /// Maximum scale for the centered clip.
  static double maxScale = 1;

  /// Minimum threshold for triggering reorder (pixels).
  static double reorderThresholdMin = 30;

  /// Maximum threshold for triggering reorder (pixels).
  static double reorderThresholdMax = 120;

  /// Factor for clamping drag offset relative to width.
  static double dragClampFactor = 0.3;

  /// Scale factor when in reorder mode.
  static double reorderScale = 0.5;

  /// Threshold for showing center overlay based on page difference.
  static double centerOverlayThreshold = 0.2;

  /// Padding around clip area for detecting leave events.
  static double clipAreaPadding = 20;

  /// Start point for offset effect (0-1 range).
  static double offsetStart = 0.4;

  /// Multiplier for falloff range calculation.
  static double falloffRangeMultiplier = 0.25;

  /// Duration for drag reset animation.
  static Duration dragResetDuration = const Duration(milliseconds: 200);

  /// Duration for page navigation animation.
  static Duration pageAnimationDuration = const Duration(milliseconds: 300);

  /// Duration for scale animations.
  static Duration scaleAnimationDuration = const Duration(milliseconds: 280);
}
