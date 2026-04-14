// ABOUTME: Bridges pooled_video_player debug logs into the app's unified logger
// ABOUTME: Enables production log exports to include video player diagnostics

import 'package:unified_logger/unified_logger.dart';

/// Creates a logging callback for [VideoFeedController.onLog] that forwards
/// messages into the app's structured logging system.
///
/// Without this bridge, pooled player logs only go to `debugPrint` and are
/// invisible in user-facing log exports.
void Function(String level, String message) pooledPlayerLogCallback() {
  return (String level, String message) {
    switch (level) {
      case 'error':
        Log.error(
          message,
          name: 'PooledPlayer',
          category: LogCategory.video,
        );
      case 'warning':
        Log.warning(
          message,
          name: 'PooledPlayer',
          category: LogCategory.video,
        );
      default:
        Log.debug(
          message,
          name: 'PooledPlayer',
          category: LogCategory.video,
        );
    }
  };
}
