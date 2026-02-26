// ABOUTME: States for MyProfileBloc - loading own profile for editing
// ABOUTME: Supports cache+fresh pattern with extracted divine.video username

part of 'my_profile_bloc.dart';

/// Error types for my profile loading operations.
enum MyProfileErrorType {
  /// Profile does not exist on relay or in cache.
  notFound,

  /// Network or relay error occurred.
  networkError,
}

/// Base class for all my profile states.
sealed class MyProfileState extends Equatable {
  const MyProfileState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any profile loading has started.
final class MyProfileInitial extends MyProfileState {
  const MyProfileInitial();
}

/// Loading state - may contain cached profile while fetching fresh.
final class MyProfileLoading extends MyProfileState {
  const MyProfileLoading({
    this.profile,
    this.extractedUsername,
    this.externalNip05,
  });

  /// Cached profile to display while loading fresh data.
  /// Null if no cached profile exists.
  final UserProfile? profile;

  /// Username extracted from cached profile's NIP-05, if available.
  final String? extractedUsername;

  /// External NIP-05 identifier from cached profile (e.g., `alice@example.com`).
  /// Null if the NIP-05 is a divine.video/openvine.co domain or not set.
  final String? externalNip05;

  @override
  List<Object?> get props => [profile, extractedUsername, externalNip05];
}

/// Successfully loaded profile state.
final class MyProfileLoaded extends MyProfileState {
  const MyProfileLoaded({
    required this.profile,
    required this.isFresh,
    this.extractedUsername,
    this.externalNip05,
  });

  /// The loaded user profile.
  final UserProfile profile;

  /// Whether this profile was freshly fetched from relay (true)
  /// or loaded from cache (false).
  final bool isFresh;

  /// Username extracted from the profile's NIP-05 identifier.
  ///
  /// Supports both new subdomain format (`_@username.divine.video`)
  /// and legacy formats (`username@divine.video`, `username@openvine.co`).
  /// Null if the NIP-05 is not from a recognized domain.
  final String? extractedUsername;

  /// External NIP-05 identifier (e.g., `alice@example.com`).
  /// Null if the NIP-05 is a divine.video/openvine.co domain or not set.
  final String? externalNip05;

  @override
  List<Object?> get props => [
    profile,
    isFresh,
    extractedUsername,
    externalNip05,
  ];
}

/// Error state when profile loading fails.
final class MyProfileError extends MyProfileState {
  const MyProfileError({required this.errorType});

  /// The type of error that occurred.
  final MyProfileErrorType errorType;

  @override
  List<Object?> get props => [errorType];
}
