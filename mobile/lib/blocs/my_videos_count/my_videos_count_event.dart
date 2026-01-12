// ABOUTME: Events for MyVideosCountBloc
// ABOUTME: Defines actions for loading and subscribing to video count

part of 'my_videos_count_bloc.dart';

/// Base class for all my videos count events
sealed class MyVideosCountEvent {
  const MyVideosCountEvent();
}

/// Request to start loading video count and subscribing to updates.
final class MyVideosCountStarted extends MyVideosCountEvent {
  const MyVideosCountStarted();
}
