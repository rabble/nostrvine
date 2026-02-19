// ABOUTME: Platform-aware video format filter for VideosRepository.
// ABOUTME: Filters out WebM videos on iOS/macOS (AVPlayer limitation).

import 'dart:io' show Platform;

import 'package:videos_repository/videos_repository.dart';

/// Creates a [VideoPlatformFilter] that filters out videos with formats
/// unsupported on the current platform.
///
/// Currently filters WebM videos on iOS and macOS, where AVPlayer does not
/// support the WebM container format.
///
/// On Android and other platforms, all formats are allowed.
VideoPlatformFilter createPlatformVideoFilter() {
  final isApplePlatform = Platform.isIOS || Platform.isMacOS;

  return (video) {
    if (!isApplePlatform) return false;
    return video.isWebM;
  };
}
