// ABOUTME: Describes a single file upload to hand to the OS background
// ABOUTME: uploader (URLSession on iOS, a foreground service on Android).

import 'package:equatable/equatable.dart';

/// A request to upload one file in the background.
///
/// The OS owns the transfer once enqueued, so it continues while the app is
/// backgrounded or suspended. The request carries only what the native side
/// needs to build a single HTTP request — it has no knowledge of Blossom,
/// Nostr, or any other domain concern; the caller is responsible for building
/// the [url] and signed [headers] before enqueuing.
class BackgroundUploadRequest extends Equatable {
  /// Creates a [BackgroundUploadRequest].
  ///
  /// [taskId] must be a stable, non-empty identifier the caller can use to
  /// correlate later `BackgroundUploadEvent`s back to this request; it is also
  /// the handle passed to `cancel`. [filePath] must point at a readable file
  /// on disk — the native side streams from it directly to keep memory bounded.
  BackgroundUploadRequest({
    required this.taskId,
    required this.url,
    required this.filePath,
    this.method = 'PUT',
    this.notificationTitle = 'Uploading',
    Map<String, String> headers = const <String, String>{},
  }) : assert(taskId != '', 'taskId must not be empty'),
       assert(filePath != '', 'filePath must not be empty'),
       headers = Map<String, String>.unmodifiable(headers);

  /// Stable identifier used to correlate events and to cancel the upload.
  final String taskId;

  /// Destination URL for the upload request.
  final Uri url;

  /// Absolute path to the file streamed as the request body.
  final String filePath;

  /// HTTP method for the upload. Defaults to `PUT` (Blossom BUD-01).
  final String method;

  /// Title shown on the Android foreground-service notification while this
  /// upload runs. Ignored on Apple platforms, which use no notification. The
  /// caller owns this copy so the plugin stays free of app/localization
  /// concerns.
  final String notificationTitle;

  /// Request headers (e.g. the signed authorization header).
  final Map<String, String> headers;

  /// Serializes this request for the platform channel.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'taskId': taskId,
      'url': url.toString(),
      'filePath': filePath,
      'method': method,
      'notificationTitle': notificationTitle,
      'headers': headers,
    };
  }

  @override
  List<Object?> get props => <Object?>[
    taskId,
    url,
    filePath,
    method,
    notificationTitle,
    headers,
  ];
}
