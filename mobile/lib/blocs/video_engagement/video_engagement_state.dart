// ABOUTME: State and supporting enums for VideoEngagementBloc.

part of 'video_engagement_bloc.dart';

/// Which engagement list a [VideoEngagementBloc] is fetching.
enum VideoEngagementType {
  /// Users who reacted with a `+` (like) to the target event.
  likers,

  /// Users who reposted (NIP-18, kind 6/16) the target event.
  reposters,
}

/// Loading status for the engagement list.
enum VideoEngagementStatus {
  /// Initial state before any load has been requested.
  initial,

  /// A relay query is in flight.
  loading,

  /// The list has been loaded successfully.
  success,

  /// The relay query failed.
  failure,
}

/// State emitted by [VideoEngagementBloc].
final class VideoEngagementState extends Equatable {
  const VideoEngagementState({
    required this.type,
    this.status = VideoEngagementStatus.initial,
    this.pubkeys = const [],
  });

  /// Whether this state is for the likers list or the reposters list.
  final VideoEngagementType type;

  /// Current load status.
  final VideoEngagementStatus status;

  /// Pubkeys of users who liked or reposted the target event, ordered by
  /// reaction recency (most recent first).
  final List<String> pubkeys;

  /// Returns a copy of this state with the supplied fields overridden.
  VideoEngagementState copyWith({
    VideoEngagementStatus? status,
    List<String>? pubkeys,
  }) {
    return VideoEngagementState(
      type: type,
      status: status ?? this.status,
      pubkeys: pubkeys ?? this.pubkeys,
    );
  }

  @override
  List<Object?> get props => [type, status, pubkeys];
}
