// ABOUTME: Events for VideoEngagementBloc.

part of 'video_engagement_bloc.dart';

/// Base class for events handled by [VideoEngagementBloc].
sealed class VideoEngagementEvent extends Equatable {
  const VideoEngagementEvent();

  @override
  List<Object?> get props => const [];
}

/// Request the engagement list to be (re)loaded from relays.
final class VideoEngagementLoadRequested extends VideoEngagementEvent {
  const VideoEngagementLoadRequested();
}
