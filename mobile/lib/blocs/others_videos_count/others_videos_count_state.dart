// ABOUTME: State class for OthersVideosCountBloc
// ABOUTME: Represents the video count state for another user's profile

part of 'others_videos_count_bloc.dart';

/// Enum representing the status of video count loading
enum OthersVideosCountStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Currently loading count
  loading,

  /// Count loaded successfully
  success,

  /// An error occurred while loading count
  failure,
}

/// State class for OthersVideosCountBloc
final class OthersVideosCountState extends Equatable {
  const OthersVideosCountState({
    this.status = OthersVideosCountStatus.initial,
    this.count = 0,
    this.targetPubkey,
  });

  /// The current status of video count loading
  final OthersVideosCountStatus status;

  /// The video count for the target user
  final int count;

  /// The pubkey whose video count is being viewed
  final String? targetPubkey;

  /// Create a copy with updated values
  OthersVideosCountState copyWith({
    OthersVideosCountStatus? status,
    int? count,
    String? targetPubkey,
  }) {
    return OthersVideosCountState(
      status: status ?? this.status,
      count: count ?? this.count,
      targetPubkey: targetPubkey ?? this.targetPubkey,
    );
  }

  @override
  List<Object?> get props => [status, count, targetPubkey];
}
