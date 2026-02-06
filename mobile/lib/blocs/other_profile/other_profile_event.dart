// ABOUTME: Events for OtherProfileBloc - viewing another user's profile
// ABOUTME: Handles screen open and pull-to-refresh actions

part of 'other_profile_bloc.dart';

/// Base class for all other profile events.
sealed class OtherProfileEvent extends Equatable {
  const OtherProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered when the other profile screen is opened.
///
/// This initiates the profile loading sequence:
/// 1. Emit cached profile immediately (if available)
/// 2. Fetch fresh profile from relay
/// 3. Emit fresh profile when received
final class OtherProfileScreenOpened extends OtherProfileEvent {
  const OtherProfileScreenOpened();
}

/// Event triggered when user pulls to refresh the profile.
///
/// Re-fetches the profile from relay and updates the UI.
final class OtherProfileRefreshRequested extends OtherProfileEvent {
  const OtherProfileRefreshRequested();
}
