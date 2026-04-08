part of 'video_import_bloc.dart';

enum VideoImportStatus {
  initial,
  validating,
  verified,
  rejected,
  importing,
  imported,
  error,
}

class VideoImportState extends Equatable {
  const VideoImportState({
    this.status = VideoImportStatus.initial,
    this.filePath,
    this.validationResult,
    this.draftId,
  });

  final VideoImportStatus status;
  final String? filePath;
  final C2paImportResult? validationResult;
  final String? draftId;

  VideoImportState copyWith({
    VideoImportStatus? status,
    String? filePath,
    C2paImportResult? validationResult,
    String? draftId,
  }) {
    return VideoImportState(
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      validationResult: validationResult ?? this.validationResult,
      draftId: draftId ?? this.draftId,
    );
  }

  @override
  List<Object?> get props => [status, filePath, validationResult, draftId];
}
