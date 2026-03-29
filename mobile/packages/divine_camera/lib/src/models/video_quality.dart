// ABOUTME: Video quality options for recording
// ABOUTME: Defines available video recording quality levels

import 'dart:ui';

/// Video recording quality levels.
enum DivineVideoQuality {
  /// 480p (SD) - 640x480
  sd(resolution: Size(480, 640), bitrate: 2_000_000),

  /// 720p (HD) - 1280x720
  hd(resolution: Size(720, 1280), bitrate: 4_000_000),

  /// 1080p (Full HD) - 1080x1920
  fhd(resolution: Size(1080, 1920), bitrate: 8_000_000),

  /// 2160p (4K Ultra HD) - 2160x3840
  uhd(resolution: Size(2160, 3840), bitrate: 20_000_000),

  /// Highest available quality on the device.
  /// Defaults to UHD (4K) - actual resolution determined at runtime.
  highest(resolution: Size(2160, 3840), bitrate: 20_000_000),

  /// Lowest available quality on the device.
  /// Defaults to SD - actual resolution determined at runtime.
  lowest(resolution: Size(480, 640), bitrate: 2_000_000),
  ;

  const DivineVideoQuality({required this.resolution, required this.bitrate});

  /// The target resolution for this quality level.
  final Size resolution;

  /// The target bitrate in bits per second for this quality level.
  final int bitrate;

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
