// ABOUTME: Public API for OS-backed background file uploads.
// ABOUTME: Enqueue file + URL + headers; OS finishes it across suspension.

import 'dart:async';

import 'package:background_uploader/background_uploader_platform_interface.dart';
import 'package:background_uploader/src/models/background_upload_event.dart';
import 'package:background_uploader/src/models/background_upload_request.dart';

export 'src/models/background_upload_event.dart';
export 'src/models/background_upload_request.dart';

/// Uploads files via the operating system's background transfer facility.
///
/// On iOS this is a background `URLSession`; on Android a foreground service.
/// Once a file is enqueued, the OS owns the transfer and continues it while
/// the app is backgrounded or suspended — unlike an in-process HTTP client,
/// whose sockets are torn down when the app is suspended.
///
/// This is a data-layer client: it speaks plain HTTP (method + headers + file)
/// and knows nothing about Blossom, Nostr, or any domain concern. Callers build
/// the request — including any signed authorization header — and map
/// [BackgroundUploadEvent]s to their own state model.
class BackgroundUploader {
  BackgroundUploader._internal();

  /// The singleton instance of [BackgroundUploader].
  static final BackgroundUploader instance = BackgroundUploader._internal();

  BackgroundUploaderPlatform get _platform =>
      BackgroundUploaderPlatform.instance;

  /// Emits progress and terminal events for every enqueued upload.
  ///
  /// Events are keyed by `taskId`; filter the stream to follow one upload.
  /// Because the OS may complete a transfer while the app is not running, an
  /// upload enqueued in a previous session can complete without a matching
  /// live event — reconcile on startup with [activeTaskIds].
  Stream<BackgroundUploadEvent> get events => _platform.events;

  /// Whether the current platform can perform OS-backed background uploads.
  Future<bool> get isSupported => _platform.isSupported();

  /// Hands [request] to the OS for background upload.
  ///
  /// Returns once the OS has accepted the task; progress and the terminal
  /// result arrive later on [events]. Throws [ArgumentError] if [request] is
  /// not internally consistent.
  Future<void> enqueue(BackgroundUploadRequest request) {
    if (request.method.trim().isEmpty) {
      throw ArgumentError.value(
        request.method,
        'request.method',
        'HTTP method must not be empty.',
      );
    }
    if (!_isAllowedUploadUrl(request.url)) {
      throw ArgumentError.value(
        request.url.toString(),
        'request.url',
        'Background uploads require an absolute https URL '
            '(cleartext http is permitted only to loopback hosts).',
      );
    }
    return _platform.enqueue(request);
  }

  /// Loopback hosts the local Docker stack serves over cleartext http. Both
  /// native platforms already permit cleartext to these (Android
  /// network-security-config, iOS `NSAllowsLocalNetworking`), so mirror that
  /// here rather than rejecting local-stack uploads.
  static const _localCleartextHosts = <String>{
    '10.0.2.2',
    'localhost',
    '127.0.0.1',
  };

  bool _isAllowedUploadUrl(Uri url) {
    if (!url.hasScheme) return false;
    if (url.isScheme('https')) return true;
    return url.isScheme('http') && _localCleartextHosts.contains(url.host);
  }

  /// Cancels the upload identified by [taskId], if it is still in flight.
  Future<void> cancel(String taskId) => _platform.cancel(taskId);

  /// Starts an OS foreground session that keeps the app process foregrounded
  /// (and its network usable) until [endForegroundSession] is called with the
  /// same [sessionId].
  ///
  /// Unlike [enqueue], this carries no transfer of its own. It exists so a
  /// caller can keep the process out of the background-network restrictions
  /// across in-process work that must not be network-starved — e.g. signing a
  /// follow-up event with a remote signer and broadcasting it to relays after
  /// a background upload completes while the app is suspended.
  ///
  /// Must be called while the app is in the foreground: Android forbids
  /// starting a foreground service from the background. On Apple platforms the
  /// session maps to a background-task assertion (iOS) or is a no-op (macOS).
  ///
  /// Throws [ArgumentError] if [sessionId] is empty.
  Future<void> beginForegroundSession(String sessionId) {
    if (sessionId.isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId', 'must not be empty');
    }
    return _platform.beginForegroundSession(sessionId);
  }

  /// Ends the foreground session started by [beginForegroundSession] for
  /// [sessionId]. Safe to call when no matching session is active.
  Future<void> endForegroundSession(String sessionId) =>
      _platform.endForegroundSession(sessionId);

  /// Task ids the OS still has in flight, for startup reconciliation.
  Future<List<String>> activeTaskIds() => _platform.activeTaskIds();

  /// Claims a terminal event for [taskId] that arrived while nothing was
  /// listening on [events] — e.g. an upload the OS finished while the app was
  /// dead — or `null` when none is buffered. Claiming removes it, so a given
  /// terminal event is handed out at most once.
  Future<BackgroundUploadEvent?> takeBufferedTerminalEvent(String taskId) =>
      _platform.takeBufferedTerminalEvent(taskId);
}
