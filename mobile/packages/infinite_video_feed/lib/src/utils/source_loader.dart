import 'package:divine_video_player/divine_video_player.dart';
import 'package:infinite_video_feed/src/utils/playback_sources.dart';

const _mediaProcessingRetryDelays = <Duration>[
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 3),
  Duration(seconds: 5),
  Duration(seconds: 8),
];

/// Waits before a same-source retry after media returns HTTP 202.
typedef SourceLoadDelay = Future<void> Function(Duration duration);

/// Signals that source loading was cancelled because the owning controller
/// window moved on while fallbacks were still in flight.
class SourceLoadAborted implements Exception {
  /// Creates an abort signal for the stale source load at [index].
  const SourceLoadAborted({required this.index, required this.source});

  /// Feed index whose source load was aborted.
  final int index;

  /// Source URL being attempted when the load became stale.
  final String source;

  @override
  String toString() =>
      'Source load aborted for stale controller index $index source=$source';
}

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
  Map<String, String>? Function(String source)? httpHeadersForSource,
  bool Function()? isLoadCurrent,
  SourceLoadDelay delay = Future<void>.delayed,
}) async {
  Object? lastError;
  StackTrace? lastStackTrace;

  void abortIfStale(String source) {
    if (isLoadCurrent != null && !isLoadCurrent()) {
      throw SourceLoadAborted(index: index, source: source);
    }
  }

  for (var attemptIndex = 0; attemptIndex < sources.length; attemptIndex++) {
    final source = sources[attemptIndex];
    abortIfStale(source);
    try {
      await controller.setSource(
        VideoClip.network(
          source,
          httpHeaders: httpHeadersForSource?.call(source) ?? const {},
        ),
      );
      abortIfStale(source);
      return (source, attemptIndex);
    } on SourceLoadAborted {
      rethrow;
    } on Object catch (error, stackTrace) {
      abortIfStale(source);
      lastError = error;
      lastStackTrace = stackTrace;
      // Only wait-and-retry a processing (HTTP 202) source when it is the last
      // resort. While a fallback is still queued — for Divine that is always
      // the guaranteed raw blob — prefer it immediately instead of stalling up
      // to ~19s for a derivative that is still transcoding.
      final isLastSource = attemptIndex == sources.length - 1;
      if (isLastSource && isMediaProcessingError(error)) {
        for (final retryDelay in _mediaProcessingRetryDelays) {
          log(
            'Source processing index $index: '
            'source=$source '
            'attempt=$attemptIndex '
            'retryInMs=${retryDelay.inMilliseconds} '
            'error=$error',
          );
          await delay(retryDelay);
          abortIfStale(source);
          try {
            await controller.setSource(
              VideoClip.network(
                source,
                httpHeaders: httpHeadersForSource?.call(source) ?? const {},
              ),
            );
            abortIfStale(source);
            return (source, attemptIndex);
          } on SourceLoadAborted {
            rethrow;
          } on Object catch (retryError, retryStackTrace) {
            abortIfStale(source);
            lastError = retryError;
            lastStackTrace = retryStackTrace;
            if (isMediaProcessingError(retryError)) {
              continue;
            }
            break;
          }
        }
      }
      final nextAttempt = attemptIndex + 1;
      if (nextAttempt < sources.length) {
        log(
          'Source failed index $index: '
          'failedSource=$source '
          'retrySource=${sources[nextAttempt]} '
          'attempt=$attemptIndex '
          'error=$lastError',
        );
        continue;
      }

      log(
        'All sources failed index $index: '
        'failedSource=$source '
        'attempt=$attemptIndex '
        'error=$lastError',
      );
    }
  }

  if (lastError != null && lastStackTrace != null) {
    Error.throwWithStackTrace(lastError, lastStackTrace);
  }

  throw StateError('No playback sources resolved for index $index');
}
