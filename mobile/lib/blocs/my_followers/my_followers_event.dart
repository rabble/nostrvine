// ABOUTME: Events for MyFollowersBloc
// ABOUTME: Defines actions for loading and follow-back operations

part of 'my_followers_bloc.dart';

/// Base class for all my followers list events
sealed class MyFollowersEvent {
  const MyFollowersEvent();
}

/// Request to load current user's followers list.
final class MyFollowersListLoadRequested extends MyFollowersEvent {
  const MyFollowersListLoadRequested();
}
