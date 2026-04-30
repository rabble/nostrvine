import 'dart:async';
import 'dart:developer' as developer;
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
  ///
  /// If [stallTimeout] is non-null, the download is cancelled when no
  /// stream event (progress or completion) has arrived within that
  /// duration. This kills hung HTTP streams without penalising slow but
  /// steadily-progressing downloads. Requires the source stream to emit
  /// progress events (e.g. `getFileStream(withProgress: true)`).
  CancellableCacheOperation.fromStream(
    Stream<FileResponse> stream, {
    void Function(String key, String path)? onCached,
    String? cacheKey,
    Duration? stallTimeout,
  }) {
    void resetStallTimer() {
      if (stallTimeout == null) return;
      _stallTimer?.cancel();
      _stallTimer = Timer(stallTimeout, () {
        developer.log(
          'prefetch CancellableCacheOp[$cacheKey]: '
          'stalled — no progress for ${stallTimeout.inSeconds}s, cancelling',
          name: 'MediaCache',
        );
        _stalled = true;
        cancel();
      });
    }

    try {
      _subscription = stream.listen(
        (response) {
          resetStallTimer();
          developer.log(
            'prefetch CancellableCacheOp[$cacheKey]: '
            'event=${response.runtimeType}',
            name: 'MediaCache',
          );
          if (response is FileInfo && !_completer.isCompleted) {
            _stallTimer?.cancel();
            onCached?.call(cacheKey ?? '', response.file.path);
            _completer.complete(response.file);
          }
        },
        onError: (Object error) {
          _stallTimer?.cancel();
          developer.log(
            'prefetch CancellableCacheOp[$cacheKey]: onError=$error',
            name: 'MediaCache',
          );
          if (!_completer.isCompleted) _completer.complete();
        },
        onDone: () {
          _stallTimer?.cancel();
          developer.log(
            'prefetch CancellableCacheOp[$cacheKey]: onDone '
            '(completed=${_completer.isCompleted})',
            name: 'MediaCache',
          );
          if (!_completer.isCompleted) _completer.complete();
        },
        cancelOnError: true,
      );
      resetStallTimer();
    } on Object {
      // Synchronous errors from stream.listen (e.g. a closed stream or
      // an eagerly-throwing stream factory) must not leave the completer
      // hanging — complete with null so callers don't await forever.
      _stallTimer?.cancel();
      if (!_completer.isCompleted) _completer.complete();
    }
  }

  final _completer = Completer<File?>();
  StreamSubscription<FileResponse>? _subscription;
  Timer? _stallTimer;
  bool _isCancelled = false;
  bool _stalled = false;

  /// The cached file when the download completes.
  ///
  /// Returns `null` if the operation was cancelled or failed.
  Future<File?> get file => _completer.future;

  /// Whether this operation has been cancelled.
  bool get isCancelled => _isCancelled;

  /// Whether this operation was cancelled because the underlying stream
  /// stopped emitting events for longer than the configured stall timeout.
  bool get didStall => _stalled;

  /// Cancels the download and frees the HTTP connection.
  ///
  /// The [file] future completes with `null`. Calling [cancel] on an
  /// already-completed or already-cancelled operation is a no-op.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _stallTimer?.cancel();
    unawaited(_subscription?.cancel());
    if (!_completer.isCompleted) _completer.complete();
  }
}
