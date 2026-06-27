// ABOUTME: Event the native background uploader emits back to Dart as a
// ABOUTME: transfer progresses, completes, fails, or is cancelled.

import 'package:equatable/equatable.dart';

/// Lifecycle status of a background upload.
enum BackgroundUploadStatus {
  /// The transfer is in flight; incremental progress updates are emitted.
  running,

  /// The server accepted the upload (a 2xx response).
  completed,

  /// The upload failed — a transport error or a non-2xx response.
  failed,

  /// The upload was cancelled by the caller.
  cancelled;

  /// Parses a native status string, or `null` when it is unrecognized.
  static BackgroundUploadStatus? tryParse(String? value) {
    return switch (value) {
      'running' => BackgroundUploadStatus.running,
      'completed' => BackgroundUploadStatus.completed,
      'failed' => BackgroundUploadStatus.failed,
      'cancelled' => BackgroundUploadStatus.cancelled,
      _ => null,
    };
  }
}

/// A progress or terminal event for a background upload [taskId].
///
/// This is a data-layer result type: like an HTTP client result, a `failed`
/// event carries the raw [httpStatusCode] / [error] so the calling repository
/// can classify it. It is not BLoC state — callers should map it to their own
/// status/error model before it reaches the UI.
class BackgroundUploadEvent extends Equatable {
  /// Creates a [BackgroundUploadEvent].
  const BackgroundUploadEvent({
    required this.taskId,
    required this.status,
    this.progress = 0,
    this.httpStatusCode,
    this.responseBody,
    this.error,
  });

  /// Deserializes an event from a native platform map.
  factory BackgroundUploadEvent.fromMap(Map<dynamic, dynamic> map) {
    final taskId = map['taskId'];
    if (taskId is! String || taskId.isEmpty) {
      throw const FormatException('Background upload event needs a taskId.');
    }
    final status = BackgroundUploadStatus.tryParse(map['status'] as String?);
    if (status == null) {
      throw const FormatException('Background upload event needs a status.');
    }

    final rawProgress = map['progress'];
    final progress = rawProgress is num ? rawProgress.toDouble() : 0.0;

    return BackgroundUploadEvent(
      taskId: taskId,
      status: status,
      progress: progress.clamp(0.0, 1.0),
      httpStatusCode: (map['httpStatusCode'] as num?)?.toInt(),
      responseBody: map['responseBody'] as String?,
      error: map['error'] as String?,
    );
  }

  /// Attempts to deserialize an event, returning `null` on malformed data.
  static BackgroundUploadEvent? tryFromMap(Map<dynamic, dynamic> map) {
    try {
      return BackgroundUploadEvent.fromMap(map);
    } on Object {
      return null;
    }
  }

  /// Identifier of the `BackgroundUploadRequest` this event belongs to.
  final String taskId;

  /// Current lifecycle status.
  final BackgroundUploadStatus status;

  /// Fraction uploaded in `[0, 1]`. Only meaningful while [status] is
  /// [BackgroundUploadStatus.running]; terminal events report `1` on success.
  final double progress;

  /// HTTP status code for terminal events, when the server responded.
  final int? httpStatusCode;

  /// Response body for terminal events, when available.
  final String? responseBody;

  /// Human-readable transport error for a [BackgroundUploadStatus.failed]
  /// event, when the failure was not an HTTP status (e.g. a dropped socket).
  final String? error;

  /// Whether this event is terminal (no further events follow for [taskId]).
  bool get isTerminal => status != BackgroundUploadStatus.running;

  /// Serializes this event for tests and platform fakes.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'taskId': taskId,
      'status': status.name,
      'progress': progress,
      'httpStatusCode': httpStatusCode,
      'responseBody': responseBody,
      'error': error,
    };
  }

  @override
  List<Object?> get props => <Object?>[
    taskId,
    status,
    progress,
    httpStatusCode,
    responseBody,
    error,
  ];
}
