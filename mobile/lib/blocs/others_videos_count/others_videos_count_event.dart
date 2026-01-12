// ABOUTME: Events for OthersVideosCountBloc
// ABOUTME: Defines actions for loading another user's video count

part of 'others_videos_count_bloc.dart';

/// Base class for all others videos count events
sealed class OthersVideosCountEvent {
  const OthersVideosCountEvent();
}

/// Request to load another user's video count.
final class OthersVideosCountLoadRequested extends OthersVideosCountEvent {
  const OthersVideosCountLoadRequested(this.targetPubkey);

  /// The public key of the user whose video count to load
  final String targetPubkey;
}
