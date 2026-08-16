import 'package:infinite_video_feed/src/utils/playback_sources.dart';
import 'package:unified_logger/unified_logger.dart';

/// Logs playback failures without promoting handled media-processing retries
/// into error telemetry.
void logPlaybackFailure(
  String message, {
  required String name,
  required Object error,
  required StackTrace stackTrace,
}) {
  if (isMediaProcessingError(error)) {
    Log.warning(
      message,
      name: name,
      category: LogCategory.video,
      error: error,
      stackTrace: stackTrace,
    );
    return;
  }

  Log.error(
    message,
    name: name,
    category: LogCategory.video,
    error: error,
    stackTrace: stackTrace,
  );
}
