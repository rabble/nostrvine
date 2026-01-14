// ABOUTME: Exception classes for the users_repository package.

/// Exception thrown when a user profile is not found.
class UserNotFoundException implements Exception {
  /// Creates a [UserNotFoundException] for the given [pubkey].
  const UserNotFoundException(this.pubkey);

  /// The pubkey of the user that was not found.
  final String pubkey;

  @override
  String toString() =>
      'UserNotFoundException: User with pubkey $pubkey not found';
}
