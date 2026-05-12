import 'package:divine_video_player/divine_video_player.dart';

/// Sequentially attempts each URL in [sources] until one loads successfully.
///
/// Returns a record of `(source, attemptIndex)` for the URL that opened.
/// Logs each failure via [log] and re-throws the last error when every
/// source fails.
Future<(String, int)> setSourceWithFallbacks({
  required int index,
  required DivineVideoPlayerController controller,
  required List<String> sources,
  required void Function(String) log,
}) async {
  Object? lastError;
  StackTrace? lastStackTrace;

  for (var attemptIndex = 0; attemptIndex < sources.length; attemptIndex++) {
    final source = sources[attemptIndex];
    try {
      await controller.setSource(VideoClip.network(source));
      return (source, attemptIndex);
    } on Object catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
      final nextAttempt = attemptIndex + 1;
      if (nextAttempt < sources.length) {
        log(
          'Source failed index $index: '
          'failedSource=$source '
          'retrySource=${sources[nextAttempt]} '
          'attempt=$attemptIndex '
          'error=$error',
        );
        continue;
      }

      log(
        'All sources failed index $index: '
        'failedSource=$source '
        'attempt=$attemptIndex '
        'error=$error',
      );
    }
  }

  if (lastError != null && lastStackTrace != null) {
    Error.throwWithStackTrace(lastError, lastStackTrace);
  }

  throw StateError('No playback sources resolved for index $index');
}
