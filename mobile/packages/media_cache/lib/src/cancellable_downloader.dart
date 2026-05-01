import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

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
// ignore: one_member_abstracts
abstract class CancellableDownloader {
  /// Starts a cancellable download of [url] into [targetFile].
  CancellableDownload download({
    required String url,
    required File targetFile,
    Map<String, String>? headers,
  });
}

/// Default [CancellableDownloader] backed by an [http.Client].
///
/// Cancelling subscribes/unsubscribes from the streamed response, which
/// `dart:io` interprets as a signal to release the underlying socket back
/// to the pool. This sidesteps the connection-pool starvation problem that
/// occurs when stalled `flutter_cache_manager` downloads cannot be torn
/// down and continue to occupy `maxConnectionsPerHost` slots until their
/// `connectionTimeout` (often >> our stall window) trips.
class HttpCancellableDownloader implements CancellableDownloader {
  /// Creates a downloader that issues requests on the given [http.Client].
  HttpCancellableDownloader(this._client);

  final http.Client _client;

  @override
  CancellableDownload download({
    required String url,
    required File targetFile,
    Map<String, String>? headers,
  }) {
    final dl = _HttpDownload(_client, url, targetFile, headers);
    unawaited(dl._start());
    return dl;
  }
}

class _HttpDownload implements CancellableDownload {
  _HttpDownload(this._client, this._url, this._file, this._headers);

  final http.Client _client;
  final String _url;
  final File _file;
  final Map<String, String>? _headers;

  final _completer = Completer<File?>();
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
      final req = http.Request('GET', Uri.parse(_url));
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
          try {
            _sink?.add(chunk);
          } on Object catch (_) {
            // Sink errors surface in onError.
          }
        },
        onError: (Object _) async {
          await _cleanupPartial();
          _safeComplete(null);
        },
        onDone: () async {
          try {
            await _sink?.flush();
            await _sink?.close();
          } on Object catch (_) {
            // Best-effort.
          }
          _sink = null;
          _isDone = true;
          if (_isCancelled) {
            await _safeDelete();
            _safeComplete(null);
            return;
          }
          _safeComplete(_file);
        },
        cancelOnError: true,
      );
    } on Object {
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
    if (!_completer.isCompleted) _completer.complete(f);
  }

  @override
  void cancel() {
    if (_isCancelled || _isDone) return;
    _isCancelled = true;
    unawaited(_subscription?.cancel());
    unawaited(_cleanupPartial().whenComplete(() => _safeComplete(null)));
  }
}
