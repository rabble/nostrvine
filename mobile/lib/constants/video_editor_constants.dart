import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// A text font with its style getter.
typedef TextFont = TextStyle Function({double? fontSize, Color? color});

/// Constants for the video editor feature.
class VideoEditorConstants {
  /// Key used to identify autosaved drafts in storage.
  static String autoSaveId = 'draft_autosave';

  /// Prefix key used to identify drafts being published in storage.
  static String publishPrefixId = 'draft_publish';

  /// Task ID used to identify the merge operation when rendering
  /// multiple clips into a single video.
  static String renderMergeTaskId = 'Divine_Editor_Merger';

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
    Color(0xFF27C58B),
    Color(0xFFD0FBCB),
    Color(0xFFFFF140),
    Color(0xFFD2FF40),
    Color(0xFFFF7FAF),
    Color(0xFFFF7640),
    Color(0xFFA3A9FF),
    Color(0xFF8568FF),
    Color(0xFF34BBF1),
  ];

  /// Available text fonts for text overlays, sorted by popularity.
  static const List<TextFont> textFonts = [
    GoogleFonts.inter,
    GoogleFonts.bricolageGrotesque,
    GoogleFonts.roboto,
    GoogleFonts.openSans,
    GoogleFonts.notoSans,
    GoogleFonts.montserrat,
    GoogleFonts.lato,
    GoogleFonts.poppins,
    GoogleFonts.robotoMono,
    GoogleFonts.oswald,
    GoogleFonts.raleway,
    GoogleFonts.ubuntu,
    GoogleFonts.nunito,
    GoogleFonts.rubik,
    GoogleFonts.merriweather,
    GoogleFonts.playfairDisplay,
    GoogleFonts.nunitoSans,
    GoogleFonts.lora,
    GoogleFonts.ptSans,
    GoogleFonts.workSans,
    GoogleFonts.barlow,
    GoogleFonts.quicksand,
    GoogleFonts.mulish,
    GoogleFonts.titilliumWeb,
    GoogleFonts.josefinSans,
    GoogleFonts.bebasNeue,
    GoogleFonts.comfortaa,
    GoogleFonts.lobster,
    GoogleFonts.pacifico,
    GoogleFonts.dancingScript,
    GoogleFonts.caveat,
    GoogleFonts.permanentMarker,
    GoogleFonts.crimsonText,
    GoogleFonts.ibmPlexMono,
    GoogleFonts.anonymousPro,
  ];

  /// Width of drawing tool items in the draw editor toolbar.
  static const double drawItemWidth = 48.0;

  /// Border radius applied to the video editor canvas.
  static const double canvasRadius = 32.0;

  /// Base font size in pixels for text overlays.
  static const double baseFontSize = 24.0;

  /// Minimum font scale multiplier for text overlays.
  static const double minFontScale = 0.5;

  /// Maximum font scale multiplier for text overlays.
  static const double maxFontScale = 4.0;

  /// Background color for the text editor overlay.
  static const Color textEditorBackground = Color(0x9B000000);

  static const uiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: VineTheme.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: VineTheme.surfaceContainerHigh,
  );

  /// Height of the bottom action bar in the video editor.
  static const double bottomBarHeight = 90;

  /// Target render width for the video editor output.
  static const double renderWidth = 1080;

  /// Hero animation tag for the back button in the video editor.
  static const heroBackButtonId = 'Video-Editor-Back-Button';

  /// Hero animation tag for the final clip-preview in the video editor.
  static const heroMetaPreviewId = 'Video-metadata-clip-preview-video';

  /// Hero animation tag for the audio-chip in the video editor.
  static const heroAudioChipId = 'Video-Editor-Audio-Chip';

  /// Hero animation tag for the toolbar leading (close) button.
  static const heroToolbarLeadingId = 'Video-Editor-Toolbar-Leading';

  /// Hero animation tag for the toolbar trailing (done) button.
  static const heroToolbarTrailingId = 'Video-Editor-Toolbar-Trailing';

  /// List of filter presets sorted by popularity
  static final List<FilterModel> filters = [
    PresetFilters.none,

    // Tier 1: Most popular filters
    PresetFilters.clarendon,
    PresetFilters.juno,
    PresetFilters.ludwig,
    PresetFilters.lark,
    PresetFilters.gingham,

    // Tier 2: Very popular
    PresetFilters.valencia,
    PresetFilters.xProII,
    PresetFilters.loFi,
    PresetFilters.amaro,
    PresetFilters.hudson,

    // Tier 3: Popular
    PresetFilters.nashville,
    PresetFilters.mayfair,
    PresetFilters.rise,
    PresetFilters.perpetua,
    PresetFilters.aden,

    // Tier 4: Vintage & artistic
    PresetFilters.earlybird,
    PresetFilters.f1977,
    PresetFilters.kelvin,
    PresetFilters.walden,
    PresetFilters.toaster,

    // Tier 5: Mood filters
    PresetFilters.moon,
    PresetFilters.inkwell,
    PresetFilters.willow,
    PresetFilters.slumber,
    PresetFilters.reyes,

    // Tier 6: Color boost
    PresetFilters.hefe,
    PresetFilters.sierra,
    PresetFilters.sutro,
    PresetFilters.brannan,
    PresetFilters.maven,

    // Tier 7: Specialty
    PresetFilters.crema,
    PresetFilters.ashby,
    PresetFilters.charmes,
    PresetFilters.helena,
    PresetFilters.brooklyn,
    PresetFilters.ginza,
    PresetFilters.skyline,
    PresetFilters.dogpatch,
    PresetFilters.stinson,
    PresetFilters.vesper,

    // Essential filters
    FilterModel(
      name: 'Cinematic',
      filters: [
        ColorFilterAddons.colorOverlay(0, 140, 140, 0.08),
        ColorFilterAddons.colorOverlay(255, 140, 50, 0.05),
        ColorFilterAddons.contrast(0.1),
        ColorFilterAddons.saturation(-0.1),
      ],
    ),
    FilterModel(
      name: 'Faded',
      filters: [
        ColorFilterAddons.contrast(-0.1),
        ColorFilterAddons.brightness(0.08),
        ColorFilterAddons.saturation(-0.15),
      ],
    ),
    FilterModel(
      name: 'Dramatic',
      filters: [
        ColorFilterAddons.contrast(0.25),
        ColorFilterAddons.brightness(-0.05),
        ColorFilterAddons.saturation(0.1),
      ],
    ),
    FilterModel(
      name: 'Dreamy',
      filters: [
        ColorFilterAddons.brightness(0.1),
        ColorFilterAddons.saturation(-0.1),
        ColorFilterAddons.contrast(-0.08),
        ColorFilterAddons.colorOverlay(255, 220, 255, 0.05),
      ],
    ),
    FilterModel(
      name: 'Glow',
      filters: [
        ColorFilterAddons.brightness(0.12),
        ColorFilterAddons.contrast(-0.05),
        ColorFilterAddons.saturation(-0.05),
      ],
    ),
    FilterModel(
      name: 'Noir',
      filters: [
        ColorFilterAddons.grayscale(),
        ColorFilterAddons.contrast(0.2),
        ColorFilterAddons.brightness(-0.05),
      ],
    ),
    FilterModel(
      name: 'Vivid',
      filters: [
        ColorFilterAddons.saturation(0.4),
        ColorFilterAddons.contrast(0.1),
      ],
    ),
    FilterModel(
      name: 'Muted',
      filters: [
        ColorFilterAddons.saturation(-0.3),
        ColorFilterAddons.brightness(0.05),
      ],
    ),

    // Simple color tints
    FilterModel(
      name: 'Ruby',
      filters: [ColorFilterAddons.addictiveColor(50, 0, 0)],
    ),
    FilterModel(
      name: 'Ocean',
      filters: [ColorFilterAddons.addictiveColor(0, 0, 50)],
    ),
    FilterModel(
      name: 'Forest',
      filters: [ColorFilterAddons.addictiveColor(0, 40, 0)],
    ),
    FilterModel(
      name: 'Sunset',
      filters: [ColorFilterAddons.addictiveColor(60, 30, 0)],
    ),
    FilterModel(
      name: 'Violet',
      filters: [ColorFilterAddons.addictiveColor(40, 0, 50)],
    ),
    FilterModel(
      name: 'Mint',
      filters: [ColorFilterAddons.addictiveColor(0, 50, 40)],
    ),
    FilterModel(
      name: 'Coral',
      filters: [ColorFilterAddons.addictiveColor(50, 20, 10)],
    ),
    FilterModel(
      name: 'Arctic',
      filters: [ColorFilterAddons.addictiveColor(0, 30, 60)],
    ),
  ];
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

  /// Maximum upward Y clamp (pixels) during drag — prevents clip from
  /// leaving the gallery area upward. Downward movement is unclamped so
  /// the clip can always reach the delete zone.
  static double dragYClampUp = 40;

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
