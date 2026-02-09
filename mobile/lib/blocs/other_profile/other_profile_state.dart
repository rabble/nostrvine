// ABOUTME: States for OtherProfileBloc - viewing another user's profile
// ABOUTME: Supports cache+fresh pattern with optional profile in loading/error states

part of 'other_profile_bloc.dart';

/// Error types for profile fetching operations.
enum OtherProfileErrorType {
  /// Profile does not exist on relay or in cache.
  notFound,

  /// Network or relay error occurred.
  networkError,
}

/// Base class for all other profile states.
sealed class OtherProfileState extends Equatable {
  const OtherProfileState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any profile loading has started.
final class OtherProfileInitial extends OtherProfileState {
  const OtherProfileInitial();
}

/// Loading state - may contain cached profile while fetching fresh.
final class OtherProfileLoading extends OtherProfileState {
  const OtherProfileLoading({this.profile});

  /// Cached profile to display while loading fresh data.
  /// Null if no cached profile exists.
  final UserProfile? profile;

  @override
  List<Object?> get props => [profile];
}

/// Successfully loaded profile state.
final class OtherProfileLoaded extends OtherProfileState {
  const OtherProfileLoaded({required this.profile, required this.isFresh});

  /// The loaded user profile.
  final UserProfile profile;

  /// Whether this profile was freshly fetched from relay (true)
  /// or loaded from cache (false).
  final bool isFresh;

  @override
  List<Object?> get props => [profile, isFresh];
}

/// Error state - may still contain cached profile to display.
final class OtherProfileError extends OtherProfileState {
  const OtherProfileError({required this.errorType, this.profile});

  /// The type of error that occurred.
  final OtherProfileErrorType errorType;

  /// Cached profile to display despite the error.
  /// Null if no cached profile exists.
  final UserProfile? profile;

  @override
  List<Object?> get props => [errorType, profile];
}
