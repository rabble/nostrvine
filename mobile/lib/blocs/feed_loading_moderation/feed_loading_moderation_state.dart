// ABOUTME: State for FeedLoadingModerationCubit — moderation result for a
// ABOUTME: video that is still loading.

import 'package:equatable/equatable.dart';

/// The moderation-check status for a video that is still in its loading phase.
enum FeedLoadingModerationStatus {
  /// The check has not yet completed (or is not applicable for this video).
  loading,

  /// The moderation service confirmed this video is blocked or quarantined.
  restricted,

  /// The moderation service confirmed this video requires adult access.
  ageRestricted,
}

/// State for [FeedLoadingModerationCubit].
class FeedLoadingModerationState extends Equatable {
  const FeedLoadingModerationState({
    this.status = FeedLoadingModerationStatus.loading,
  });

  final FeedLoadingModerationStatus status;

  /// Whether the video was flagged as blocked/quarantined by moderation.
  bool get isRestricted => status == FeedLoadingModerationStatus.restricted;

  /// Whether the video is available to adult-verified viewers only.
  bool get isAgeRestricted =>
      status == FeedLoadingModerationStatus.ageRestricted;

  /// Returns a copy with the given fields replaced.
  FeedLoadingModerationState copyWith({FeedLoadingModerationStatus? status}) {
    return FeedLoadingModerationState(status: status ?? this.status);
  }

  @override
  List<Object?> get props => [status];
}
