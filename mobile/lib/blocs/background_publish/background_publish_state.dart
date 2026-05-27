part of 'background_publish_bloc.dart';

class BackgroundUpload extends Equatable {
  const BackgroundUpload({
    required this.draft,
    required this.result,
    required this.progress,
  });

  final DivineVideoDraft draft;
  final double progress;
  final PublishResult? result;

  BackgroundUpload copyWith({
    DivineVideoDraft? draft,
    double? progress,
    PublishResult? result,
  }) {
    return BackgroundUpload(
      draft: draft ?? this.draft,
      progress: progress ?? this.progress,
      result: result ?? this.result,
    );
  }

  @override
  List<Object?> get props => [draft.id, progress, result];
}

class BackgroundPublishState extends Equatable {
  const BackgroundPublishState({
    this.uploads = const [],
    this.recentlySucceededIds = const {},
  });

  final List<BackgroundUpload> uploads;

  /// Draft IDs that completed with [PublishSuccess] in the most recent
  /// state transition. Cleared on the next emission that does not add new
  /// successes. Used by [UploadFailureListener] to distinguish true publish
  /// success from [BackgroundPublishVanished], which also removes an upload
  /// without a success result.
  final Set<String> recentlySucceededIds;

  /// Returns true if there is any upload in progress (no result yet).
  bool get hasUploadInProgress =>
      uploads.any((upload) => upload.result == null);

  BackgroundPublishState copyWith({
    List<BackgroundUpload>? uploads,
    Set<String>? recentlySucceededIds,
  }) {
    return BackgroundPublishState(
      uploads: uploads ?? this.uploads,
      recentlySucceededIds: recentlySucceededIds ?? const {},
    );
  }

  @override
  List<Object?> get props => [uploads, recentlySucceededIds];
}
