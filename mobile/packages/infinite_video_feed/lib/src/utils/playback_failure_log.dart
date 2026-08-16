import 'package:infinite_video_feed/src/utils/playback_sources.dart';
import 'package:models/models.dart' show LogCategory;
import 'package:unified_logger/unified_logger.dart';

/// Logs a playback failure with appropriate log level based on error type.
///
/// Media-processing failures (HTTP 202/422) are expected transient errors
/// and are logged at WARNING level. Other failures are logged at ERROR level.
/// Both cases preserve error and stack trace details for diagnostics.
///
/// [message] - Human-readable failure description
/// [name] - Optional logger name (typically 'InfiniteVideoFeed' or similar)
/// [category] - Optional log category (typically LogCategory.video)
/// [error] - The thrown error object
/// [stackTrace] - The stack trace associated with the error
/// [errorMessage] - Optional error message for classifying the failure type
void logPlaybackFailure(
  String message, {
  String? name,
  LogCategory? category,
  Object? error,
  StackTrace? stackTrace,
  String? errorMessage,
}) {
  // Media-processing errors (HTTP 202/422) are expected during video
  // processing and should be logged at WARNING level to avoid false
  // positives in error telemetry. All other failures are logged at ERROR.
  if (isMediaProcessingError(error, errorMessage: errorMessage)) {
    Log.warning(
      message,
      name: name,
      category: category,
      error: error,
      stackTrace: stackTrace,
    );
  } else {
    Log.error(
      message,
      name: name,
      category: category,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
