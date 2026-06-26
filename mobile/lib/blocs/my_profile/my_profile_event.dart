// ABOUTME: Events for MyProfileBloc - own profile loading and watching
// ABOUTME: Supports one-shot load (edit screen) and stream watch (profile screen)

part of 'my_profile_bloc.dart';

/// Base class for all my profile events.
sealed class MyProfileEvent extends Equatable {
  const MyProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered to load the current user's profile for editing.
///
/// Used by the profile editor screen for one-shot cache+fresh loading.
final class MyProfileLoadRequested extends MyProfileEvent {
  const MyProfileLoadRequested();
}

/// Event triggered to watch the current user's profile reactively.
///
/// Subscribes to [ProfileRepository.watchProfile] for auto-updates
/// whenever the local DB changes (e.g., after relay fetch or profile edit).
///
/// Used by the main profile screen for live profile updates.
/// Pair with [MyProfileFetchRequested] to trigger an initial relay fetch.
final class MyProfileSubscriptionRequested extends MyProfileEvent {
  const MyProfileSubscriptionRequested();
}

/// Event triggered to fetch the current user's profile from relays.
///
/// The result is written to the local DB by [ProfileRepository], which
/// triggers the watch stream from [MyProfileSubscriptionRequested].
///
/// Non-fatal if it fails — the stream continues showing cached data.
final class MyProfileFetchRequested extends MyProfileEvent {
  const MyProfileFetchRequested();
}

/// Event triggered when the current user explicitly refreshes their profile.
///
/// Unlike [MyProfileFetchRequested], this drives visible loading/error state
/// and completes [completer] when the refresh attempt finishes so pull-to-
/// refresh controls can stop their indicator without reaching into the
/// repository layer.
final class MyProfileRefreshRequested extends MyProfileEvent {
  const MyProfileRefreshRequested({this.completer});

  /// Optional completion signal for UI refresh affordances.
  final Completer<void>? completer;
}

/// Event triggered to fetch verifier-confirmed NIP-39 identity claims for
/// the currently loaded profile.
///
/// Auto-dispatched after a successful profile load. Falls back to an empty
/// claim list if the verifier is unreachable or returns an error.
final class VerifiedClaimsRequested extends MyProfileEvent {
  const VerifiedClaimsRequested();
}
