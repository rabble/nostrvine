import 'dart:ui';

/// Sizing and layout constants for the video editor timeline.
abstract class TimelineConstants {
  /// Height of the timeline.
  static const double height = 400;

  /// Height of the ruler bar with time labels.
  static const double rulerHeight = 32;

  /// Height of each clip thumbnail strip.
  static const double thumbnailStripHeight = 64;

  /// Width of a single thumbnail image in the strip.
  static const double thumbnailWidth = 48;

  /// Corner radius for thumbnail images.
  static const double thumbnailRadius = 4;

  /// Gap between adjacent clip containers.
  static const double clipGap = 1;

  /// Pixels rendered per second of video at 1x zoom.
  static const double pixelsPerSecond = 52;

  /// Minimum pixels per second when zoomed out.
  static const double minPixelsPerSecond = 1;

  /// Maximum pixels per second when zoomed in.
  static const double maxPixelsPerSecond = 600;

  /// Width of the playhead indicator line.
  static const double playheadWidth = 2;

  /// Width of the fixed left column (time display / audio button).
  static const double leftColumnWidth = 60;

  /// Horizontal padding around the scrollable content.
  static const double horizontalPadding = 12;

  // --- Trim handles ---

  /// Width of each trim handle (left / right).
  static const double trimHandleWidth = 16;

  /// Width of the vertical marker inside a trim handle.
  static const double trimHandleMarkerWidth = 3;

  /// Height of the vertical marker inside a trim handle.
  static const double trimHandleMarkerHeight = 32;

  /// Colour of the vertical marker inside each trim handle.
  static const Color trimHandleMarkerColor = Color(0xF0000000);

  /// Border width around a clip in trim mode.
  static const double trimBorderWidth = 2;

  /// Extra hit-test area around each trim handle.
  static const double trimHitAreaExtra = 32;

  /// Minimum trimmed duration for a clip.
  static const Duration minTrimDuration = Duration(milliseconds: 60);

  // --- Overlay strips (layers / filters / sounds) ---

  /// Height of a single row in an overlay strip.
  static const double overlayRowHeight = 40;

  /// Height of a single row in the sound overlay strip.
  ///
  /// Taller than other overlays to accommodate the waveform
  /// visualisation below the label text.
  static const double soundOverlayRowHeight = 64;

  /// Vertical gap between the clip strip and the first overlay strip.
  static const double overlayStripTopGap = 8;

  /// Vertical gap between different overlay strip sections.
  static const double overlayStripGap = 4;

  /// Bar width for the compact sound-overlay waveform.
  static const double soundWaveformBarWidth = 1;

  /// Vertical gap between overlay rows within a strip.
  static const double overlayRowGap = 6;

  /// Horizontal padding inside overlay item tiles.
  static const double overlayItemPadding = 6;

  /// Animation duration for overlay tile state changes.
  static const Duration overlayTileAnimDuration = Duration(milliseconds: 150);

  /// Border width for dragged overlay items.
  static const double dragBorderWidth = 1.5;

  /// Shadow blur radius for dragged overlay items.
  static const double dragShadowBlurRadius = 6;

  // --- Snap ---

  /// Distance in logical pixels within which a free-moving edge first
  /// snaps to a nearby snap point. Kept very small so the edge reaches
  /// the snap point naturally instead of being pulled from a distance.
  static const double snapCatchPx = 3;

  /// Logical pixels of continued finger movement absorbed while the
  /// handle is held at a snap point. After this distance the handle
  /// releases and continues smoothly from the snap position.
  static const double snapDeadZonePx = 10;
}
