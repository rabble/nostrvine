import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// A handle to an in-progress cache download that can be cancelled.
///
/// Created by `MediaCacheManager.cacheFileCancellable`. Cancelling the
/// operation tears down the underlying HTTP stream so bandwidth is freed
/// immediately.
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
    _completer.complete(file);
  }

  /// Creates a pending operation backed by a `getFileStream` subscription.
  ///
  /// Use [cancel] to abort the download.
  CancellableCacheOperation.fromStream(
    Stream<FileResponse> stream, {
    void Function(String key, String path)? onCached,
    String? cacheKey,
  }) {
    _subscription = stream.listen(
      (response) {
        if (response is FileInfo && !_completer.isCompleted) {
          onCached?.call(cacheKey ?? '', response.file.path);
          _completer.complete(response.file);
        }
      },
      onError: (Object _) {
        if (!_completer.isCompleted) _completer.complete();
      },
      onDone: () {
        if (!_completer.isCompleted) _completer.complete();
      },
      cancelOnError: true,
    );
  }

  final _completer = Completer<File?>();
  StreamSubscription<FileResponse>? _subscription;
  bool _isCancelled = false;

  /// The cached file when the download completes.
  ///
  /// Returns `null` if the operation was cancelled or failed.
  Future<File?> get file => _completer.future;

  /// Whether this operation has been cancelled.
  bool get isCancelled => _isCancelled;

  /// Cancels the download and frees the HTTP connection.
  ///
  /// The [file] future completes with `null`. Calling [cancel] on an
  /// already-completed or already-cancelled operation is a no-op.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    unawaited(_subscription?.cancel());
    if (!_completer.isCompleted) _completer.complete();
  }
}
