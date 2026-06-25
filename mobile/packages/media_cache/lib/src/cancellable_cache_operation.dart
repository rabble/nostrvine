import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:media_cache/src/cancellable_downloader.dart';
import 'package:unified_logger/unified_logger.dart';

/// A handle to an in-progress cache download that can be cancelled.
///
/// Created by `MediaCacheManager.cacheFileCancellable`. Cancelling the
/// operation tears down the underlying HTTP stream immediately, freeing
/// bandwidth for higher-priority downloads.
///
/// ```dart
/// final op = cache.cacheFileCancellable(url, key: 'video_1');
///
/// // Later, if the user scrolls away:
/// op.cancel();
///
/// // The future completes with null when cancelled.
/// final file = await op.file; // null
/// ```
class CancellableCacheOperation {
  /// Creates an already-completed operation holding [file].
  CancellableCacheOperation.completed(File file) {
    _completer.complete(CancellableDownloadResult(file: file));
  }

  /// Creates a pending operation backed by [stream].
  ///
  /// Listens to [stream] for a [FileInfo] event; when one arrives the [file]
  /// future is completed with the cached file and the stream subscription is
  /// cancelled.
  CancellableCacheOperation.fromStream(
    Stream<FileResponse> stream, {
    void Function(String key, String path)? onCached,
    String? cacheKey,
  }) {
    try {
      _subscription = stream.listen(
        (response) {
          Log.debug(
            'CancellableCacheOp[$cacheKey]: '
            'event=${response.runtimeType}',
            name: 'MediaCache',
            category: LogCategory.video,
          );
          if (response is FileInfo && !_completer.isCompleted) {
            onCached?.call(cacheKey ?? '', response.file.path);
            _completer.complete(CancellableDownloadResult(file: response.file));
          }
        },
        onError: (Object error) {
          Log.warning(
            'CancellableCacheOp[$cacheKey]: onError=$error',
            name: 'MediaCache',
            category: LogCategory.video,
          );
          if (!_completer.isCompleted) {
            _completer.complete(const CancellableDownloadResult(file: null));
          }
        },
        onDone: () {
          Log.debug(
            'CancellableCacheOp[$cacheKey]: onDone '
            '(completed=${_completer.isCompleted})',
            name: 'MediaCache',
            category: LogCategory.video,
          );
          if (!_completer.isCompleted) {
            _completer.complete(const CancellableDownloadResult(file: null));
          }
        },
        cancelOnError: true,
      );
    } on Object {
      if (!_completer.isCompleted) {
        _completer.complete(const CancellableDownloadResult(file: null));
      }
    }
  }

  /// Creates a pending operation backed by a [CancellableDownload].
  ///
  /// The returned operation forwards [cancel] to the underlying download —
  /// which closes its HTTP socket immediately, freeing a connection-pool
  /// slot — instead of just unsubscribing from a higher-level stream
  /// (which would leave the pipe behind `CacheManager.getFileStream`
  /// draining the response into a temp file regardless).
  CancellableCacheOperation.fromDownload(
    CancellableDownload download, {
    void Function(File file)? onCached,
    String? cacheKey,
  }) {
    _download = download;
    unawaited(
      download.result
          .then((result) {
            final file = result.file;
            Log.debug(
              'CancellableCacheOp[$cacheKey]: download done '
              '(file=${file?.path}, cancelled=$_isCancelled)',
              name: 'MediaCache',
              category: LogCategory.video,
            );
            if (_completer.isCompleted) return;
            if (file != null && !_isCancelled) onCached?.call(file);
            _completer.complete(
              _isCancelled
                  ? const CancellableDownloadResult(file: null)
                  : result,
            );
          })
          .catchError((Object _) {
            if (!_completer.isCompleted) {
              _completer.complete(const CancellableDownloadResult(file: null));
            }
          }),
    );
  }

  final _completer = Completer<CancellableDownloadResult>();
  StreamSubscription<FileResponse>? _subscription;
  CancellableDownload? _download;
  bool _isCancelled = false;

  /// The cached file when the download completes.
  ///
  /// Returns `null` if the operation was cancelled or failed.
  Future<File?> get file async => (await result).file;

  /// The completed download result.
  Future<CancellableDownloadResult> get result => _completer.future;

  /// Whether this operation has been cancelled.
  bool get isCancelled => _isCancelled;

  /// Cancels the download.
  ///
  /// The underlying HTTP stream is torn down immediately; the [file] future
  /// completes with `null`. If the operation was already completed or
  /// cancelled, this is a no-op.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _download?.cancel();
    unawaited(_subscription?.cancel());
    if (!_completer.isCompleted) {
      _completer.complete(const CancellableDownloadResult(file: null));
    }
  }
}
