import 'package:hive_ce/hive.dart';

part 'blossom_resumable_upload_session.g.dart';

/// Tracks the state of a resumable Blossom upload session.
@HiveType(typeId: 3)
class BlossomResumableUploadSession {
  /// Creates a [BlossomResumableUploadSession].
  const BlossomResumableUploadSession({
    required this.uploadId,
    required this.uploadUrl,
    required this.chunkSize,
    required this.nextOffset,
    this.expiresAt,
    this.requiredHeaders,
  });

  /// Server-assigned identifier for this upload session.
  @HiveField(0)
  final String uploadId;

  /// URL to which chunk data is PUT.
  @HiveField(1)
  final String uploadUrl;

  /// Size in bytes of each upload chunk.
  @HiveField(2)
  final int chunkSize;

  /// Byte offset for the next chunk to upload.
  @HiveField(3)
  final int nextOffset;

  /// When this session expires on the server.
  @HiveField(4)
  final DateTime? expiresAt;

  /// Headers the server requires on every chunk PUT.
  @HiveField(5)
  final Map<String, String>? requiredHeaders;

  /// Returns a copy with the given fields replaced.
  BlossomResumableUploadSession copyWith({
    String? uploadId,
    String? uploadUrl,
    int? chunkSize,
    int? nextOffset,
    DateTime? expiresAt,
    Map<String, String>? requiredHeaders,
  }) => BlossomResumableUploadSession(
    uploadId: uploadId ?? this.uploadId,
    uploadUrl: uploadUrl ?? this.uploadUrl,
    chunkSize: chunkSize ?? this.chunkSize,
    nextOffset: nextOffset ?? this.nextOffset,
    expiresAt: expiresAt ?? this.expiresAt,
    requiredHeaders: requiredHeaders ?? this.requiredHeaders,
  );
}
