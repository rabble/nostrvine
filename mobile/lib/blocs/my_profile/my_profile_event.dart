// ABOUTME: Events for MyProfileBloc - loading own profile for editing
// ABOUTME: Triggers cache+fresh profile load on the profile editor screen

part of 'my_profile_bloc.dart';

/// Base class for all my profile events.
sealed class MyProfileEvent extends Equatable {
  const MyProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered to load the current user's profile for editing.
final class MyProfileLoadRequested extends MyProfileEvent {
  const MyProfileLoadRequested();
}
