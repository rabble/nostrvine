// ABOUTME: Video quality options for recording
// ABOUTME: Defines available video recording quality levels

/// Video recording quality levels.
enum DivineVideoQuality {
  /// 480p (SD) - ~640x480
  sd,

  /// 720p (HD) - ~1280x720
  hd,

  /// 1080p (Full HD) - ~1920x1080
  fhd,

  /// 2160p (4K Ultra HD) - ~3840x2160
  uhd,

  /// Highest available quality on the device
  highest,

  /// Lowest available quality on the device
  lowest
  ;

  /// Converts to a string representation for platform channels.
  String get value {
    switch (this) {
      case DivineVideoQuality.sd:
        return 'sd';
      case DivineVideoQuality.hd:
        return 'hd';
      case DivineVideoQuality.fhd:
        return 'fhd';
      case DivineVideoQuality.uhd:
        return 'uhd';
      case DivineVideoQuality.highest:
        return 'highest';
      case DivineVideoQuality.lowest:
        return 'lowest';
    }
  }
}
