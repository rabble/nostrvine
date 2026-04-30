import 'dart:async';
import 'dart:io';

/// A handle to an in-progress cache download that can be cancelled.
///
/// Created by `MediaCacheManager.cacheFileCancellable`. Cancelling the
/// operation completes the [file] future with `null` immediately.
/// The underlying HTTP download may still run to completion in the background,
/// which keeps the disk cache warm for future requests.
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

  /// Creates a pending operation backed by a [Future<File?>].
  ///
  /// If [stallTimeout] is non-null, the operation is treated as stalled
  /// (and [didStall] becomes `true`) when the future has not resolved within
  /// that duration.
  CancellableCacheOperation.fromFuture(
    Future<File?> future, {
    Duration? stallTimeout,
  }) {
    Future<void> run() async {
      try {
        final File? result;
        if (stallTimeout != null) {
          result = await future.timeout(stallTimeout);
        } else {
          result = await future;
        }
        if (!_completer.isCompleted) _completer.complete(result);
      } on TimeoutException {
        _stalled = true;
        if (!_completer.isCompleted) _completer.complete();
      } on Object {
        if (!_completer.isCompleted) _completer.complete();
      }
    }

    unawaited(run());
  }

  final _completer = Completer<File?>();
  bool _isCancelled = false;
  bool _stalled = false;

  /// The cached file when the download completes.
  ///
  /// Returns `null` if the operation was cancelled, timed out, or failed.
  Future<File?> get file => _completer.future;

  /// Whether this operation has been cancelled.
  bool get isCancelled => _isCancelled;

  /// Whether this operation was cancelled because the download did not
  /// complete within the configured stall timeout.
  bool get didStall => _stalled;

  /// Cancels the download.
  ///
  /// The [file] future completes with `null`. The underlying HTTP download
  /// may continue in the background to populate the disk cache.
  ///
  /// Calling [cancel] on an already-completed or already-cancelled operation
  /// is a no-op.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    if (!_completer.isCompleted) _completer.complete();
  }
}
