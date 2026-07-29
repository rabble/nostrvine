// ABOUTME: Wire models for the crossposter service (crossposter.divine.video)
// ABOUTME: Connections, jobs, job statuses, and the typed API exception

/// Lifecycle states reported by the crossposter for a single job.
enum CrosspostJobStatus {
  queued,
  uploading,
  dispatching,
  processing,
  posted,
  failed,
  needsReauth,
  skipped,
  unknown;

  factory CrosspostJobStatus.fromWire(String? value) => switch (value) {
    'queued' => CrosspostJobStatus.queued,
    'uploading' => CrosspostJobStatus.uploading,
    'dispatching' => CrosspostJobStatus.dispatching,
    'processing' => CrosspostJobStatus.processing,
    'posted' => CrosspostJobStatus.posted,
    'failed' => CrosspostJobStatus.failed,
    'needs_reauth' => CrosspostJobStatus.needsReauth,
    'skipped' => CrosspostJobStatus.skipped,
    _ => CrosspostJobStatus.unknown,
  };

  /// Whether the crossposter is still working on the job.
  bool get isPending =>
      this == CrosspostJobStatus.queued ||
      this == CrosspostJobStatus.uploading ||
      this == CrosspostJobStatus.dispatching ||
      this == CrosspostJobStatus.processing ||
      this == CrosspostJobStatus.unknown;
}

/// A platform account link from `GET /connections`.
class CrossposterConnection {
  const CrossposterConnection({
    required this.id,
    required this.platform,
    required this.status,
    this.externalAccountName,
  });

  factory CrossposterConnection.fromJson(Map<String, dynamic> json) {
    return CrossposterConnection(
      id: json['id'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      status: json['status'] as String? ?? '',
      externalAccountName: json['externalAccountName'] as String?,
    );
  }

  final String id;
  final String platform;
  final String status;
  final String? externalAccountName;

  bool get isConnected => status == 'connected';
}

/// One crosspost job as returned by the crossposter API.
class CrosspostJob {
  const CrosspostJob({
    required this.id,
    required this.platform,
    required this.status,
    this.externalPostUrl,
    this.errorCode,
    this.errorMessage,
  });

  factory CrosspostJob.fromJson(Map<String, dynamic> json) {
    return CrosspostJob(
      id: json['id'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      status: CrosspostJobStatus.fromWire(json['status'] as String?),
      externalPostUrl: json['externalPostUrl'] as String?,
      errorCode: json['errorCode'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  final String id;
  final String platform;
  final CrosspostJobStatus status;

  /// Platform permalink, present once [status] is
  /// [CrosspostJobStatus.posted].
  final String? externalPostUrl;
  final String? errorCode;
  final String? errorMessage;
}

/// Failure from the crossposter API.
///
/// [code] carries the server's machine-readable error code
/// (`not_owner`, `not_eligible`, `not_connected`, `unauthorized`, ...)
/// when the response included one.
class CrossposterApiException implements Exception {
  const CrossposterApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Object? cause;

  @override
  String toString() =>
      'CrossposterApiException: $message '
      '(${statusCode ?? 'no status'}${code == null ? '' : ', $code'})';
}
