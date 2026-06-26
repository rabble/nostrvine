import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:unified_logger/unified_logger.dart';

/// Handle to an in-progress HTTP download writing to a single target file.
///
/// Cancelling tears down the underlying HTTP socket immediately and removes
/// any partial bytes written so far.
abstract class CancellableDownload {
  /// Resolves to the downloaded file when complete, or `null` on failure
  /// or cancellation.
  Future<File?> get file;

  /// Whether this download has been cancelled.
  bool get isCancelled;

  /// Tears down the underlying HTTP connection and removes the partial file.
  void cancel();
}

/// Strategy for performing cancellable file downloads.
///
/// Default implementation uses an [http.Client]. Tests inject a fake to
/// drive completion deterministically.
abstract class CancellableDownloader {
  /// Starts a cancellable download of [url] into [targetFile].
  CancellableDownload download({
    required String url,
    required File targetFile,
    Map<String, String>? headers,
  });

  /// Releases any resources owned by this downloader.
  Future<void> close();
}

/// Default [CancellableDownloader] backed by an [http.Client].
///
/// Once the response stream has started, cancelling unsubscribes from it,
/// which `dart:io` interprets as a signal to release the underlying socket
/// back to the pool. This sidesteps the connection-pool starvation problem
/// that occurs when stalled `flutter_cache_manager` downloads cannot be torn
/// down and continue to occupy `maxConnectionsPerHost` slots until their
/// `connectionTimeout` (often >> our stall window) trips.
///
/// Note: if `cancel()` is called while the initial request is still in
/// flight (before headers arrive), the socket cannot be interrupted and
/// remains in use until the response headers are received.
class HttpCancellableDownloader implements CancellableDownloader {
  /// Creates a downloader that issues requests on the given [http.Client].
  HttpCancellableDownloader(this._client);

  final http.Client _client;
  final Set<_HttpDownload> _activeDownloads = {};
  bool _isClosed = false;

  @override
  CancellableDownload download({
    required String url,
    required File targetFile,
    Map<String, String>? headers,
  }) {
    if (_isClosed) return _CompletedDownload(null);

    final dl = _HttpDownload(
      _client,
      url,
      targetFile,
      headers,
      onComplete: _activeDownloads.remove,
    );
    _activeDownloads.add(dl);
    unawaited(dl._start());
    return dl;
  }

  @override
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;

    final activeDownloads = _activeDownloads.toList(growable: false);
    for (final download in activeDownloads) {
      download.cancel();
    }
    await Future.wait<File?>(
      activeDownloads.map((download) => download.file),
    );
    _client.close();
  }
}

class _HttpDownload implements CancellableDownload {
  _HttpDownload(
    this._client,
    this._url,
    this._file,
    this._headers, {
    required this.onComplete,
  });

  final http.Client _client;
  final String _url;
  final File _file;
  final Map<String, String>? _headers;
  final void Function(_HttpDownload download) onComplete;

  final _completer = Completer<File?>();
  final _abortCompleter = Completer<void>();
  // ignore: cancel_subscriptions, owned across cancel/stream lifecycle methods.
  StreamSubscription<List<int>>? _subscription;
  IOSink? _sink;
  bool _isCancelled = false;
  bool _isDone = false;

  @override
  Future<File?> get file => _completer.future;

  @override
  bool get isCancelled => _isCancelled;

  Future<void> _start() async {
    try {
      final uri = Uri.parse(_url);
      if (uri.scheme.toLowerCase() != 'https') {
        Log.warning(
          'CancellableDownload: rejecting non-https url $_url',
          name: 'MediaCache',
          category: LogCategory.video,
        );
        _safeComplete(null);
        return;
      }

      final req = http.AbortableRequest(
        'GET',
        uri,
        abortTrigger: _abortCompleter.future,
      );
      if (_headers != null) {
        req.headers.addAll(_headers);
      }
      final response = await _client.send(req);
      if (_isCancelled) {
        unawaited(response.stream.drain<void>());
        _safeComplete(null);
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        Log.warning(
          'CancellableDownload: $_url returned HTTP ${response.statusCode}',
          name: 'MediaCache',
          category: LogCategory.video,
        );
        unawaited(response.stream.drain<void>());
        _safeComplete(null);
        return;
      }

      final parent = _file.parent;
      if (!parent.existsSync()) {
        await parent.create(recursive: true);
      }
      _sink = _file.openWrite();
      _subscription = response.stream.listen(
        (chunk) {
          if (_isCancelled) return;
          try {
            _sink?.add(chunk);
          } on Object catch (_) {
            // Sink errors surface in onError.
          }
        },
        onError: (Object error) async {
          // A stream error that races with our own cancel() is expected
          // teardown, not a download failure — only warn for real errors.
          if (!_isCancelled) {
            Log.warning(
              'CancellableDownload: stream error for $_url: $error',
              name: 'MediaCache',
              category: LogCategory.video,
            );
          }
          await _cleanupPartial();
          _safeComplete(null);
        },
        onDone: () async {
          // Mark as done before async finalization so cancel() cannot race
          // into this window and delete a successfully written file.
          _isDone = true;
          try {
            await _sink?.flush();
            await _sink?.close();
          } on Object catch (_) {
            // Best-effort.
          }
          _sink = null;
          // coverage:ignore-start
          if (_isCancelled) {
            await _safeDelete();
            _safeComplete(null);
            return;
          }
          // coverage:ignore-end
          _safeComplete(_file);
        },
        cancelOnError: true,
      );
    } on Object catch (error) {
      // cancel() fires the abort trigger, so a pending request surfaces here
      // as RequestAbortedException — that is intentional teardown, not a
      // failure, and must not pollute bug-report logs with false warnings.
      if (!_isCancelled) {
        Log.warning(
          'CancellableDownload: request failed for $_url: $error',
          name: 'MediaCache',
          category: LogCategory.video,
        );
      }
      await _cleanupPartial();
      _safeComplete(null);
    }
  }

  Future<void> _cleanupPartial() async {
    try {
      await _sink?.close();
    } on Object catch (_) {
      // Best-effort.
    }
    _sink = null;
    await _safeDelete();
  }

  Future<void> _safeDelete() async {
    try {
      if (_file.existsSync()) await _file.delete();
    } on Object catch (_) {
      // Best-effort.
    }
  }

  void _safeComplete(File? f) {
    if (_completer.isCompleted) return;
    _completer.complete(f);
    onComplete(this);
  }

  @override
  void cancel() {
    if (_isCancelled || _isDone) return;
    _isCancelled = true;
    if (!_abortCompleter.isCompleted) {
      _abortCompleter.complete();
    }
    final subscription = _subscription;
    if (subscription == null) {
      unawaited(_cleanupPartial());
      return;
    }
    unawaited(
      subscription.cancel().whenComplete(() async {
        await _cleanupPartial();
        _safeComplete(null);
      }),
    );
  }
}

class _CompletedDownload implements CancellableDownload {
  _CompletedDownload(File? file) : file = Future<File?>.value(file);

  @override
  final Future<File?> file;

  @override
  bool get isCancelled => false;

  @override
  void cancel() {}
}
