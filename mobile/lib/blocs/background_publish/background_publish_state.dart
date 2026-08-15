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

/// A video that just finished publishing, identified well enough for the
/// post-publish confirmation to link to it and share it.
///
/// [stableId] is the video's `d` tag. It routes `/video/<stableId>` and
/// builds the share URL without waiting for the event to propagate to a
/// relay. Null for an upload that carried no `videoId`.
///
/// [thumbnailPath] is a local file path taken from the draft, so the
/// confirmation can show the video immediately with no network fetch.
class PublishedVideo extends Equatable {
  const PublishedVideo({
    required this.draftId,
    this.stableId,
    this.thumbnailPath,
  });

  final String draftId;
  final String? stableId;
  final String? thumbnailPath;

  @override
  List<Object?> get props => [draftId, stableId, thumbnailPath];
}

class BackgroundPublishState extends Equatable {
  const BackgroundPublishState({
    this.uploads = const [],
    this.recentlyPublished = const [],
  });

  final List<BackgroundUpload> uploads;

  /// Videos that completed with [PublishSuccess] in the most recent state
  /// transition. Cleared on the next emission that does not add new
  /// successes. Used by [UploadFailureListener] to distinguish true publish
  /// success from [BackgroundPublishVanished], which also removes an upload
  /// without a success result.
  final List<PublishedVideo> recentlyPublished;

  /// Draft IDs from [recentlyPublished], for callers that only need to know
  /// *that* a draft published rather than which video it became.
  Set<String> get recentlySucceededIds =>
      recentlyPublished.map((video) => video.draftId).toSet();

  /// Returns true if there is any upload in progress (no result yet).
  bool get hasUploadInProgress =>
      uploads.any((upload) => upload.result == null);

  BackgroundPublishState copyWith({
    List<BackgroundUpload>? uploads,
    List<PublishedVideo>? recentlyPublished,
  }) {
    return BackgroundPublishState(
      uploads: uploads ?? this.uploads,
      recentlyPublished: recentlyPublished ?? const [],
    );
  }

  @override
  List<Object?> get props => [uploads, recentlyPublished];
}
