import 'package:divine_video_player/divine_video_player.dart';

/// Signals that source loading was cancelled because the owning controller
/// window moved on while fallbacks were still in flight.
class SourceLoadAborted implements Exception {
  /// Creates an abort signal for the stale source load at [index].
  const SourceLoadAborted({
    required this.index,
    required this.source,
  });

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
