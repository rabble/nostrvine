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
}
