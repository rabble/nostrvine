// ABOUTME: State for FeedLoadingModerationCubit — whether a video was flagged
// ABOUTME: as moderation-restricted during the feed loading phase.

import 'package:equatable/equatable.dart';

/// The moderation-check status for a video that is still in its loading phase.
enum FeedLoadingModerationStatus {
  /// The check has not yet completed (or is not applicable for this video).
  loading,

  /// The moderation service confirmed this video is restricted.
  restricted,
}

/// State for [FeedLoadingModerationCubit].
class FeedLoadingModerationState extends Equatable {
  const FeedLoadingModerationState({
    this.status = FeedLoadingModerationStatus.loading,
  });

  final FeedLoadingModerationStatus status;

  /// Whether the video was flagged as moderation-restricted.
  bool get isRestricted => status == FeedLoadingModerationStatus.restricted;

  /// Returns a copy with the given fields replaced.
  FeedLoadingModerationState copyWith({FeedLoadingModerationStatus? status}) {
    return FeedLoadingModerationState(status: status ?? this.status);
  }

  @override
  List<Object?> get props => [status];
}
