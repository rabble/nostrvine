import 'package:hive_ce/hive.dart';

part 'blossom_resumable_upload_session.g.dart';

@HiveType(typeId: 3)
class BlossomResumableUploadSession {
  const BlossomResumableUploadSession({
    required this.uploadId,
    required this.uploadUrl,
    required this.chunkSize,
    required this.nextOffset,
    this.expiresAt,
    this.requiredHeaders,
  });

  @HiveField(0)
  final String uploadId;

  @HiveField(1)
  final String uploadUrl;

  @HiveField(2)
  final int chunkSize;

  @HiveField(3)
  final int nextOffset;

  @HiveField(4)
  final DateTime? expiresAt;

  @HiveField(5)
  final Map<String, String>? requiredHeaders;

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
