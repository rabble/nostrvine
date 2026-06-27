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
    if (!request.url.hasScheme || !request.url.isScheme('https')) {
      throw ArgumentError.value(
        request.url.toString(),
        'request.url',
        'Background uploads require an absolute https URL.',
      );
    }
    return _platform.enqueue(request);
  }

  /// Cancels the upload identified by [taskId], if it is still in flight.
  Future<void> cancel(String taskId) => _platform.cancel(taskId);

  /// Task ids the OS still has in flight, for startup reconciliation.
  Future<List<String>> activeTaskIds() => _platform.activeTaskIds();
}
